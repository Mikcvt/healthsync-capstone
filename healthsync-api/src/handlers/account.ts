/**
 * Account deletion, with a 30-day window to change your mind.
 *
 * POST /account/delete — the caller deletes their own account.
 *   A care partner: their account and every patient account they manage. Needs
 *   a sign-in under five minutes old (the app asks for the password first).
 *   A managed patient: their own account, no approval needed. They have no
 *   password to re-enter, so no recent sign-in is asked for; the 30 days are
 *   the safety net instead. Their care partner is told at once.
 *
 * POST /patients/delete — a care partner deletes one of their patients.
 *
 * POST /account/restore — undoes a deletion within the 30 days. Restores the
 *   caller's own account (and the patients deleted with it), or, with a
 *   patient_uid, one of the caller's patients.
 *
 * A deletion runs in two stages:
 *
 *   1. At once: an `account_deletions` job is written, then the accounts are
 *      paused — marked inactive with the purge date, push tokens cleared,
 *      schedules switched off (flagged, so a restore revives exactly those),
 *      and doses already created but not yet taken cancelled. No reminder,
 *      late or missed alert goes out for a paused account, and patient phones
 *      sign themselves out when they see the mark.
 *   2. After 30 days, the purge cron deletes everything, schedules first so
 *      the materialiser stops, then dose logs so the sweep stops, then the
 *      rest, then the Auth accounts. It re-runs the purge for another hour: a
 *      deleted account's ID token stays valid that long, and a phone can
 *      write with it in that time.
 *
 * Dose logs are never deleted anywhere else. Removing them here is what account
 * deletion means, and Google Play's data deletion policy requires it.
 */

import type { Env } from '../index';
import { sendPush } from '../lib/fcm';
import { deleteAuthUsers, getAccessToken, lookupAuthUsers, parseServiceAccount, verifyIdToken } from '../lib/google-auth';
import { Firestore } from '../lib/firestore';
import { error, getBearerToken, json } from '../lib/http';

/** How long a deleted account can still be restored. */
const GRACE_MS = 30 * 24 * 60 * 60 * 1000;

/** A care partner re-enters the password right before deleting; anything older is refused. */
const RECENT_AUTH_SECONDS = 5 * 60;

/** Outlasts the one-hour life of an ID token issued before the purge. */
const STRAGGLER_WINDOW_MS = 65 * 60 * 1000;

/** Firestore's limit on values in one `IN` filter. */
const IN_LIMIT = 30;

/** Documents fetched and deleted per round trip. A commit holds at most 500. */
const PAGE = 400;

/** A caregiver with more patients than this is finished by the cron. */
const MAX_PATIENTS = 90;

/**
 * Free plan: 50 external subrequests per invocation. The cron spends about
 * three before the purge starts.
 */
const CRON_PURGE_BUDGET = 44;
const MAX_JOBS_PER_RUN = 3;

/** Doses in these states are still open, so a paused account must not keep them. */
const OPEN_DOSE_STATUSES = ['pending', 'snoozed'];

/**
 * Where each account's data lives, in the order it is removed. Schedules come
 * first: once they are gone the materialiser creates no more doses. Dose logs
 * come next, leaving the sweep nothing to alert on.
 *
 * Patients are found through patient_profile, never through
 * caregiver_patient_links: the rules let a caregiver create a link naming any
 * patient_ref, so a link proves nothing about who a patient belongs to.
 */
const STEPS: Array<{ collection: string; field: string }> = [
	{ collection: 'schedules', field: 'patient_ref' },
	{ collection: 'dose_logs', field: 'patient_ref' },
	{ collection: 'patient_medications', field: 'patient_ref' },
	{ collection: 'notifications', field: 'user_ref' },
	// The caregiver's alerts about a patient belong to the caregiver
	// (user_ref) but name the patient here. Deleting one patient must take
	// them too.
	{ collection: 'notifications', field: 'patient_ref' },
	{ collection: 'devices', field: 'patient_ref' },
	{ collection: 'otp_codes', field: 'caregiver_ref' },
	{ collection: 'otp_codes', field: 'patient_ref' },
	{ collection: 'caregiver_patient_links', field: 'caregiver_ref' },
	{ collection: 'caregiver_patient_links', field: 'patient_ref' },
];

/** Documents keyed by the uid itself, deleted last. */
const IDENTITY_COLLECTIONS = ['users', 'patient_profile', 'caregiver_profile'];

interface Budget {
	left: number;
}

type Caller = { uid: string; authTime?: number; sa: ReturnType<typeof parseServiceAccount> };

function chunks<T>(items: T[], size: number): T[][] {
	const out: T[][] = [];
	for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
	return out;
}

/** The verified caller, or the response refusing them. */
async function verifiedCaller(request: Request, env: Env): Promise<Caller | Response> {
	const idToken = getBearerToken(request);
	if (!idToken) return error('Sign in required.', 401, 'unauthenticated');

	const sa = parseServiceAccount(env.FIREBASE_SA_KEY);
	try {
		const { uid, authTime } = await verifyIdToken(idToken, sa.project_id);
		return { uid, authTime, sa };
	} catch {
		return error('Your session has expired. Please sign in again.', 401, 'invalid_token');
	}
}

/**
 * A phone left unlocked must not be enough to delete a care partner's patients,
 * so their sign-in must be under five minutes old.
 */
function needsReauth(caller: Caller): Response | null {
	if (!caller.authTime || Date.now() / 1000 - caller.authTime > RECENT_AUTH_SECONDS) {
		return error('Please enter your password again to confirm.', 401, 'reauth_required');
	}
	return null;
}

function asDate(value: unknown): Date | null {
	return value instanceof Date && !Number.isNaN(value.getTime()) ? value : null;
}

function readBody(request: Request): Promise<{ patient_uid?: string } | null> {
	return request.json().then(
		(body) => (body && typeof body === 'object' ? (body as { patient_uid?: string }) : {}),
		() => null,
	);
}

export async function handleDeleteAccount(request: Request, env: Env): Promise<Response> {
	const caller = await verifiedCaller(request, env);
	if (caller instanceof Response) return caller;
	const { uid: callerUid, sa } = caller;

	const accessToken = await getAccessToken(sa, env.TOKEN_CACHE);
	const db = new Firestore(sa.project_id, accessToken);
	const callerDoc = await db.get('users', callerUid);
	const now = new Date();

	// Already on its way out: say when, rather than restarting the 30 days.
	const scheduled = asDate(callerDoc?.deletion_scheduled_for);
	if (scheduled) return json({ deleted: true, purge_after: scheduled.toISOString() });

	if (callerDoc?.account_type === 'managed') {
		return deleteManagedPatient(db, accessToken, sa.project_id, callerUid, callerDoc, now);
	}

	const stale = needsReauth(caller);
	if (stale) return stale;

	// No users doc: a half-finished signup with nothing to restore. Purged by
	// the next cron run.
	if (!callerDoc) {
		await writeJob(db, callerUid, [callerUid], callerUid, now, now);
		await deleteAuthUsers(accessToken, sa.project_id, [callerUid]);
		return json({ deleted: true, patients_deleted: 0, purge_after: now.toISOString() });
	}

	const patientUids = await patientsOf(db, callerUid);
	const uids = [callerUid, ...patientUids];
	const purgeAfter = new Date(now.getTime() + GRACE_MS);

	await writeJob(db, callerUid, uids, callerUid, now, purgeAfter);
	await pauseAccounts(db, uids, callerUid, now, purgeAfter);

	console.log(`Account ${callerUid} scheduled for deletion with ${patientUids.length} patient(s) on ${purgeAfter.toISOString()}.`);
	return json({ deleted: true, patients_deleted: patientUids.length, purge_after: purgeAfter.toISOString() });
}

/**
 * A managed patient deletes their own account. Their care partner is told but
 * cannot stop it: Google Play requires that the person who asks for deletion
 * gets it. The care partner can restore it within the 30 days if it was a
 * mistake.
 */
async function deleteManagedPatient(
	db: Firestore,
	accessToken: string,
	projectId: string,
	patientUid: string,
	patient: Record<string, unknown>,
	now: Date,
): Promise<Response> {
	const purgeAfter = new Date(now.getTime() + GRACE_MS);
	await writeJob(db, patientUid, [patientUid], patientUid, now, purgeAfter);
	await pauseAccounts(db, [patientUid], patientUid, now, purgeAfter);

	try {
		const profile = await db.get('patient_profile', patientUid);
		const caregiverUid = typeof profile?.caregiver_ref === 'string' ? profile.caregiver_ref : '';
		if (caregiverUid) {
			const name = String(patient.first_name ?? '').trim() || 'Your patient';
			await tellCaregiver(db, accessToken, projectId, caregiverUid, patientUid, {
				title: `${name} is deleting their account`,
				message:
					`${name} asked to delete their HealthSync account. Their reminders have stopped, and ` +
					`everything will be permanently deleted on ${manilaDate(purgeAfter)}. ` +
					`You can restore it from My Patients until then.`,
			});
		}
	} catch (err) {
		// The deletion stands; the care partner still sees it on the patient card.
		console.error(`Patient ${patientUid}: could not tell the care partner:`, err);
	}

	console.log(`Patient ${patientUid} scheduled their own deletion on ${purgeAfter.toISOString()}.`);
	return json({ deleted: true, purge_after: purgeAfter.toISOString() });
}

/**
 * A care partner deletes one managed patient. Only the care partner named on
 * the patient's profile may: that field is written by the Worker alone,
 * whereas a caregiver_patient_links document can be created by any caregiver
 * for any uid, so it is never consulted.
 */
export async function handleDeletePatient(request: Request, env: Env): Promise<Response> {
	const caller = await verifiedCaller(request, env);
	if (caller instanceof Response) return caller;
	const stale = needsReauth(caller);
	if (stale) return stale;
	const { uid: callerUid, sa } = caller;

	const body = await readBody(request);
	if (!body) return error('Invalid request body.', 400, 'bad_request');
	const patientUid = body.patient_uid?.trim() ?? '';
	if (!patientUid || patientUid === callerUid) {
		return error('Choose a patient to delete.', 400, 'bad_request');
	}

	const accessToken = await getAccessToken(sa, env.TOKEN_CACHE);
	const db = new Firestore(sa.project_id, accessToken);

	const patient = await ownedPatient(db, callerUid, patientUid);
	if (patient instanceof Response) return patient;

	const scheduled = asDate(patient.deletion_scheduled_for);
	if (scheduled) return json({ deleted: true, purge_after: scheduled.toISOString() });

	const now = new Date();
	const purgeAfter = new Date(now.getTime() + GRACE_MS);
	await writeJob(db, patientUid, [patientUid], callerUid, now, purgeAfter);
	await pauseAccounts(db, [patientUid], callerUid, now, purgeAfter);

	console.log(`Patient ${patientUid} scheduled for deletion by ${callerUid} on ${purgeAfter.toISOString()}.`);
	return json({ deleted: true, purge_after: purgeAfter.toISOString() });
}

/**
 * Undoes a deletion inside the 30 days. Without patient_uid it restores the
 * caller's own account and every patient deleted with it; with one, it restores
 * that patient, who must be the caller's own.
 */
export async function handleRestoreAccount(request: Request, env: Env): Promise<Response> {
	const caller = await verifiedCaller(request, env);
	if (caller instanceof Response) return caller;
	const { uid: callerUid, sa } = caller;

	const body = await readBody(request);
	if (!body) return error('Invalid request body.', 400, 'bad_request');
	const patientUid = body.patient_uid?.trim() ?? '';

	const accessToken = await getAccessToken(sa, env.TOKEN_CACHE);
	const db = new Firestore(sa.project_id, accessToken);

	let jobId = callerUid;
	if (patientUid && patientUid !== callerUid) {
		const patient = await ownedPatient(db, callerUid, patientUid);
		if (patient instanceof Response) return patient;
		jobId = patientUid;
	}

	const job = await db.get('account_deletions', jobId);
	const purgeAfter = asDate(job?.purge_after);
	if (!job || !purgeAfter) {
		return error('This account is not scheduled for deletion.', 404, 'not_scheduled');
	}
	if (purgeAfter.getTime() <= Date.now()) {
		return error('The 30 days have passed and this account has been deleted.', 410, 'already_deleted');
	}

	const uids = Array.isArray(job.uids) ? job.uids.filter((u): u is string => typeof u === 'string') : [];
	await restoreAccounts(db, uids, new Date());
	// Last, so a restore that fails halfway can simply be tried again.
	await db.deleteMany([{ collection: 'account_deletions', id: jobId }]);

	console.log(`Deletion ${jobId} restored by ${callerUid} (${uids.length} account(s)).`);
	return json({ restored: true, accounts: uids.length });
}

/**
 * The patient's users doc when [caregiverUid] owns them, or a refusal. One
 * answer for "not yours" and "not there": neither tells the caller anything
 * about another caregiver's patients.
 */
async function ownedPatient(
	db: Firestore,
	caregiverUid: string,
	patientUid: string,
): Promise<Record<string, unknown> | Response> {
	const [profile, patient] = await Promise.all([db.get('patient_profile', patientUid), db.get('users', patientUid)]);
	if (profile?.caregiver_ref !== caregiverUid || !patient || patient.account_type !== 'managed') {
		return error('That patient could not be found.', 404, 'patient_not_found');
	}
	return patient;
}

/**
 * The managed patients a caregiver owns: those whose patient_profile names them
 * and whose users doc is a managed account. Another caregiver's account is
 * never included, whatever a profile says.
 *
 * A patient already being deleted on their own job is left out, so restoring
 * the care partner never brings back a patient who asked to leave.
 */
async function patientsOf(db: Firestore, caregiverUid: string): Promise<string[]> {
	const profiles = await db.query('patient_profile', [{ field: 'caregiver_ref', value: caregiverUid }], MAX_PATIENTS);
	const candidates = profiles.map((p) => p.id).filter((id) => id !== caregiverUid);
	if (candidates.length === 0) return [];

	const excluded = new Set<string>();
	for (const chunk of chunks(candidates, IN_LIMIT)) {
		const users = await db.query('users', [{ field: 'uid', op: 'IN', value: chunk }], IN_LIMIT);
		for (const u of users) {
			if (u.data.account_type !== 'managed' || asDate(u.data.deletion_scheduled_for)) excluded.add(u.id);
		}
	}
	return candidates.filter((id) => !excluded.has(id));
}

function writeJob(db: Firestore, jobId: string, uids: string[], requestedBy: string, now: Date, purgeAfter: Date): Promise<void> {
	return db.set('account_deletions', jobId, {
		uids,
		requested_by: requestedBy,
		requested_at: now,
		purge_after: purgeAfter,
		finalize_after: new Date(purgeAfter.getTime() + STRAGGLER_WINDOW_MS),
		passes: 0,
	});
}

/**
 * Makes [uids] inert for the 30 days without losing anything: no reminders, no
 * alerts, no sign-in by code, and phones sign themselves out.
 */
async function pauseAccounts(db: Firestore, uids: string[], requestedBy: string, now: Date, purgeAfter: Date): Promise<void> {
	await db.commit(
		uids.map((uid) => ({
			collection: 'users',
			id: uid,
			data: {
				is_active: false,
				fcm_token: null,
				deletion_requested_at: now,
				deletion_requested_by: requestedBy,
				deletion_scheduled_for: purgeAfter,
			},
		})),
	);

	for (const chunk of chunks(uids, IN_LIMIT)) {
		// Filtered here rather than in the query: patient_ref alone needs no
		// composite index. updated_at makes the materialiser run within five
		// minutes and cancel any future dose these schedules had.
		const schedules = await db.query('schedules', [{ field: 'patient_ref', op: 'IN', value: chunk }], PAGE);
		await db.commit(
			schedules
				.filter((s) => s.data.is_active === true)
				.map((s) => ({
					collection: 'schedules',
					id: s.id,
					data: { is_active: false, led_active: false, paused_for_deletion: true, updated_at: now },
				})),
		);

		// Doses already due would otherwise be swept as missed and alerted on.
		for (const status of OPEN_DOSE_STATUSES) {
			try {
				const open = await db.query(
					'dose_logs',
					[
						{ field: 'patient_ref', op: 'IN', value: chunk },
						{ field: 'status', value: status },
					],
					PAGE,
				);
				await db.commit(
					open.map((d) => ({
						collection: 'dose_logs',
						id: d.id,
						data: { status: 'cancelled', cancelled_reason: 'account_deleted' },
					})),
				);
			} catch (err) {
				// Future doses are still cancelled by the materialiser; at worst
				// one already due is reported missed.
				console.error(`Could not cancel ${status} doses while pausing:`, err);
			}
		}
	}
}

/**
 * Reverses [pauseAccounts]. Only schedules it switched off come back on; a
 * medicine archived before the deletion stays archived. Future doses it
 * cancelled are revived by the materialiser, which the updated_at stamp runs
 * within five minutes. Patients need a new code from their care partner to
 * sign back in, since their phones signed out.
 */
async function restoreAccounts(db: Firestore, uids: string[], now: Date): Promise<void> {
	await db.commit(
		uids.map((uid) => ({
			collection: 'users',
			id: uid,
			data: {
				is_active: true,
				deletion_requested_at: null,
				deletion_requested_by: null,
				deletion_scheduled_for: null,
			},
		})),
	);

	for (const chunk of chunks(uids, IN_LIMIT)) {
		const schedules = await db.query('schedules', [{ field: 'patient_ref', op: 'IN', value: chunk }], PAGE);
		await db.commit(
			schedules
				.filter((s) => s.data.paused_for_deletion === true)
				.map((s) => ({
					collection: 'schedules',
					id: s.id,
					data: { is_active: true, paused_for_deletion: false, updated_at: now },
				})),
		);
	}
}

/** Pushes one alert to the care partner and records it in their Alerts tab. */
async function tellCaregiver(
	db: Firestore,
	accessToken: string,
	projectId: string,
	caregiverUid: string,
	patientUid: string,
	alert: { title: string; message: string },
): Promise<void> {
	const caregiver = await db.get('users', caregiverUid);
	const fcmToken = typeof caregiver?.fcm_token === 'string' ? caregiver.fcm_token : '';
	const sent = fcmToken
		? await sendPush(accessToken, projectId, {
				token: fcmToken,
				title: alert.title,
				body: alert.message,
				data: { type: 'account_deletion', patient_ref: patientUid },
			})
		: false;

	const notifId = crypto.randomUUID();
	await db.set('notifications', notifId, {
		notif_id: notifId,
		user_ref: caregiverUid,
		patient_ref: patientUid,
		dose_log_ref: null,
		notification_type: 'account_deletion',
		title: alert.title,
		message: alert.message,
		sent_at: new Date(),
		read_at: null,
		channel: sent ? 'fcm' : 'in_app',
		is_active: true,
	});
}

/** "Nov 12, 2026", in Manila time, for messages. */
function manilaDate(at: Date): string {
	return at.toLocaleDateString('en-US', { timeZone: 'Asia/Manila', month: 'short', day: 'numeric', year: 'numeric' });
}

/**
 * Deletes everything belonging to [uids]. Returns true when nothing is left,
 * false when the budget ran out first. Safe to run any number of times.
 */
async function purgeAccounts(
	db: Firestore,
	accessToken: string,
	projectId: string,
	uids: string[],
	budget: Budget,
): Promise<boolean> {
	for (const chunk of chunks(uids, IN_LIMIT)) {
		for (const step of STEPS) {
			for (;;) {
				if (budget.left < 2) return false;
				budget.left--;
				const rows = await db.query(step.collection, [{ field: step.field, op: 'IN', value: chunk }], PAGE);
				if (rows.length === 0) break;

				budget.left--;
				await db.deleteMany(rows.map((r) => ({ collection: step.collection, id: r.id })));
				if (rows.length < PAGE) break;
			}
		}
	}

	// Identity documents last, then the Auth accounts.
	const identity = uids.flatMap((uid) => IDENTITY_COLLECTIONS.map((collection) => ({ collection, id: uid })));
	for (const refs of chunks(identity, PAGE)) {
		if (budget.left < 1) return false;
		budget.left--;
		await db.deleteMany(refs);
	}
	if (budget.left < 1) return false;
	budget.left--;
	await deleteAuthUsers(accessToken, projectId, uids);
	return true;
}

/**
 * The purge cron: carries out deletions whose 30 days are up, and re-sweeps
 * them until their straggler window has passed. Costs one query when idle.
 */
export async function runAccountPurge(db: Firestore, accessToken: string, projectId: string): Promise<{ finished: number }> {
	const now = new Date();
	const jobs = await db.query(
		'account_deletions',
		[{ field: 'purge_after', op: 'LESS_THAN_OR_EQUAL', value: now }],
		MAX_JOBS_PER_RUN,
	);

	const budget: Budget = { left: CRON_PURGE_BUDGET };
	let finished = 0;
	for (const job of jobs) {
		const uids = Array.isArray(job.data.uids) ? job.data.uids.filter((u): u is string => typeof u === 'string') : [];
		const done = await purgeAccounts(db, accessToken, projectId, uids, budget);

		const finalizeAfter = asDate(job.data.finalize_after) ?? now;
		if (done && now.getTime() >= finalizeAfter.getTime()) {
			if (budget.left < 1) break;
			budget.left--;
			await db.deleteMany([{ collection: 'account_deletions', id: job.id }]);
			finished++;
		} else if (budget.left >= 1) {
			budget.left--;
			const passes = typeof job.data.passes === 'number' ? job.data.passes : 0;
			await db.set('account_deletions', job.id, { passes: passes + 1, last_pass_at: now });
		}
		if (budget.left < 2) break;
	}
	return { finished };
}

/**
 * Finds caregivers deleted before /account/delete existed: users docs left
 * with is_active false whose Auth account is gone. Their patients' schedules
 * are what kept the cron busy. Each one becomes a deletion due at once — the
 * Auth accounts are long gone, so there is nothing to restore.
 *
 * Auth is checked, not just is_active: the old in-app delete set is_active
 * false *before* deleting the Auth account, and the Auth delete fails when the
 * sign-in is not recent. Those caregivers still have working accounts.
 */
export async function enqueueOrphanedCaregivers(db: Firestore, accessToken: string, projectId: string): Promise<number> {
	const inactive = await db.query(
		'users',
		[
			{ field: 'account_type', value: 'caregiver' },
			{ field: 'is_active', value: false },
		],
		10,
	);
	// Those with deleted_at or a deletion date already have a job.
	const candidates = inactive
		.filter((u) => !asDate(u.data.deleted_at) && !asDate(u.data.deletion_scheduled_for))
		.map((u) => u.id);
	if (candidates.length === 0) return 0;

	const alive = await lookupAuthUsers(accessToken, projectId, candidates);
	const orphans = candidates.filter((uid) => !alive.has(uid));

	const now = new Date();
	for (const caregiverUid of orphans) {
		const patientUids = await patientsOf(db, caregiverUid);
		const uids = [caregiverUid, ...patientUids];
		await db.set('account_deletions', caregiverUid, {
			uids,
			requested_by: 'orphan_scan',
			requested_at: now,
			purge_after: now,
			finalize_after: now,
			passes: 0,
		});
		await db.commit([
			...uids.map((uid) => ({
				collection: 'users',
				id: uid,
				data: { is_active: false, fcm_token: null, deleted_at: now },
			})),
			...patientUids.map((uid) => ({
				collection: 'patient_profile',
				id: uid,
				data: { caregiver_ref: '' },
			})),
		]);
	}
	return orphans.length;
}
