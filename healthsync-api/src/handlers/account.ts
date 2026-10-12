/**
 * POST /account/delete — a caregiver deletes their account and every patient
 * account they manage, with all of the data behind them.
 *
 * POST /patients/delete — a caregiver deletes one patient account (removing
 * the patient, or approving the patient's own deletion request). Same purge,
 * one uid.
 *
 * Deleting used to be done by the app alone: it set the caregiver's
 * users.is_active to false and deleted their Auth account. Nothing else was
 * touched, and a client could not have done more — the rules forbid deleting
 * dose logs, and only the service account can delete another user's Auth
 * account. So the patients' schedules stayed is_active: true, and the 5-minute
 * cron kept materialising their doses, marking them missed, and alerting a
 * caregiver who no longer existed (whose users doc still held an FCM token).
 * Every orphaned schedule cost Firestore reads and writes, around the clock.
 *
 * The delete runs in three stages:
 *
 *   1. An `account_deletions` job is written first. If anything after it
 *      fails, or the request runs out of subrequests, the purge cron finishes
 *      the job.
 *   2. The bleeding stops: push tokens cleared, patient_profile.caregiver_ref
 *      blanked (the sweep finds nobody to alert), Auth accounts deleted.
 *   3. Everything is purged, schedules first so the materialiser stops, then
 *      dose logs so the sweep stops, then the rest.
 *
 * The job is kept for an hour after the request. A deleted account's ID token
 * stays valid for up to an hour, and a patient's phone can write with it in
 * that time (its push token, for one). The cron re-runs the purge until the
 * hour is up, which catches those writes.
 *
 * Dose logs are never deleted anywhere else. Removing them here is what account
 * deletion means, and Google Play's data deletion policy requires it.
 */

import type { Env } from '../index';
import { deleteAuthUsers, getAccessToken, lookupAuthUsers, parseServiceAccount, verifyIdToken } from '../lib/google-auth';
import { Firestore } from '../lib/firestore';
import { error, getBearerToken, json } from '../lib/http';

/** The app re-enters the password right before calling; anything older is refused. */
const RECENT_AUTH_SECONDS = 5 * 60;

/** Outlasts the one-hour life of an ID token issued before the delete. */
const STRAGGLER_WINDOW_MS = 65 * 60 * 1000;

/** Firestore's limit on values in one `IN` filter. */
const IN_LIMIT = 30;

/** Documents fetched and deleted per round trip. A commit holds at most 500. */
const PAGE = 400;

/** A caregiver with more patients than this is finished by the cron. */
const MAX_PATIENTS = 90;

/**
 * Free plan: 50 external subrequests per invocation. The request spends about
 * eight before the purge starts, the cron about three.
 */
const REQUEST_PURGE_BUDGET = 36;
const CRON_PURGE_BUDGET = 44;
const MAX_JOBS_PER_RUN = 3;

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

function chunks<T>(items: T[], size: number): T[][] {
	const out: T[][] = [];
	for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
	return out;
}

/**
 * The verified caller of a delete, or the response refusing them. A phone left
 * unlocked must not be enough to erase a patient's record, so the sign-in must
 * be under five minutes old: the app asks for the password right before.
 */
async function recentCaller(
	request: Request,
	env: Env,
): Promise<{ uid: string; sa: ReturnType<typeof parseServiceAccount> } | Response> {
	const idToken = getBearerToken(request);
	if (!idToken) return error('Sign in required.', 401, 'unauthenticated');

	const sa = parseServiceAccount(env.FIREBASE_SA_KEY);

	let uid: string;
	let authTime: number | undefined;
	try {
		({ uid, authTime } = await verifyIdToken(idToken, sa.project_id));
	} catch {
		return error('Your session has expired. Please sign in again.', 401, 'invalid_token');
	}

	if (!authTime || Date.now() / 1000 - authTime > RECENT_AUTH_SECONDS) {
		return error('Please enter your password again to confirm.', 401, 'reauth_required');
	}
	return { uid, sa };
}

export async function handleDeleteAccount(request: Request, env: Env): Promise<Response> {
	const caller = await recentCaller(request, env);
	if (caller instanceof Response) return caller;
	const { uid: callerUid, sa } = caller;

	const accessToken = await getAccessToken(sa, env.TOKEN_CACHE);
	const db = new Firestore(sa.project_id, accessToken);

	// A missing users doc is a half-finished signup: still deletable.
	const callerDoc = await db.get('users', callerUid);
	if (callerDoc && callerDoc.account_type !== 'caregiver') {
		return error('Patient accounts are deleted by their care partner.', 403, 'forbidden');
	}

	const patientUids = await patientsOf(db, callerUid);
	const uids = [callerUid, ...patientUids];
	const now = new Date();

	// 1. The job, before anything is touched.
	await db.set('account_deletions', callerUid, {
		uids,
		requested_by: callerUid,
		requested_at: now,
		finalize_after: new Date(now.getTime() + STRAGGLER_WINDOW_MS),
		passes: 0,
	});

	// 2. Stop alerts and sign-ins. Each step is retried by the cron if it fails.
	try {
		await stopTheBleeding(db, uids, patientUids, now);
		await deleteAuthUsers(accessToken, sa.project_id, uids);
	} catch (err) {
		console.error(`Account ${callerUid}: early shutdown failed, the cron will retry:`, err);
	}

	// 3. As much of the purge as fits; the cron does the rest.
	let complete = false;
	try {
		complete = await purgeAccounts(db, accessToken, sa.project_id, uids, { left: REQUEST_PURGE_BUDGET });
	} catch (err) {
		console.error(`Account ${callerUid}: purge interrupted, the cron will finish it:`, err);
	}

	console.log(`Account ${callerUid} deleted with ${patientUids.length} patient(s); purge complete: ${complete}.`);
	return json({ deleted: true, patients_deleted: patientUids.length, purge_complete: complete });
}

/**
 * Deletes one managed patient and everything recorded for them. Used both when
 * the caregiver removes a patient and when they approve the patient's own
 * request; "removing" used to only switch the patient off, keeping the login,
 * the medicines and every dose log indefinitely.
 *
 * Only the caregiver named on the patient's profile may do this. That field is
 * written by the Worker alone; a caregiver_patient_links document can be
 * created by any caregiver for any uid, so it is never consulted.
 */
export async function handleDeletePatient(request: Request, env: Env): Promise<Response> {
	const caller = await recentCaller(request, env);
	if (caller instanceof Response) return caller;
	const { uid: callerUid, sa } = caller;

	let body: { patient_uid?: string };
	try {
		body = (await request.json()) as { patient_uid?: string };
	} catch {
		return error('Invalid request body.', 400, 'bad_request');
	}
	const patientUid = body.patient_uid?.trim() ?? '';
	if (!patientUid || patientUid === callerUid) {
		return error('Choose a patient to delete.', 400, 'bad_request');
	}

	const accessToken = await getAccessToken(sa, env.TOKEN_CACHE);
	const db = new Firestore(sa.project_id, accessToken);

	const [profile, patient] = await Promise.all([db.get('patient_profile', patientUid), db.get('users', patientUid)]);
	// One answer for "not yours" and "not there": neither tells the caller
	// anything about another caregiver's patients.
	if (profile?.caregiver_ref !== callerUid || (patient && patient.account_type !== 'managed')) {
		return error('That patient could not be found.', 404, 'patient_not_found');
	}

	const now = new Date();
	await db.set('account_deletions', patientUid, {
		uids: [patientUid],
		requested_by: callerUid,
		requested_at: now,
		finalize_after: new Date(now.getTime() + STRAGGLER_WINDOW_MS),
		passes: 0,
	});

	try {
		await stopTheBleeding(db, [patientUid], [patientUid], now);
		await deleteAuthUsers(accessToken, sa.project_id, [patientUid]);
	} catch (err) {
		console.error(`Patient ${patientUid}: early shutdown failed, the cron will retry:`, err);
	}

	let complete = false;
	try {
		complete = await purgeAccounts(db, accessToken, sa.project_id, [patientUid], { left: REQUEST_PURGE_BUDGET });
	} catch (err) {
		console.error(`Patient ${patientUid}: purge interrupted, the cron will finish it:`, err);
	}

	console.log(`Patient ${patientUid} deleted by ${callerUid}; purge complete: ${complete}.`);
	return json({ deleted: true, purge_complete: complete });
}

/**
 * The managed patients a caregiver owns: those whose patient_profile names them
 * and whose users doc is a managed account. Another caregiver's account is
 * never included, whatever a profile says.
 */
async function patientsOf(db: Firestore, caregiverUid: string): Promise<string[]> {
	const profiles = await db.query('patient_profile', [{ field: 'caregiver_ref', value: caregiverUid }], MAX_PATIENTS);
	const candidates = profiles.map((p) => p.id).filter((id) => id !== caregiverUid);
	if (candidates.length === 0) return [];

	const notManaged = new Set<string>();
	for (const chunk of chunks(candidates, IN_LIMIT)) {
		const users = await db.query('users', [{ field: 'uid', op: 'IN', value: chunk }], IN_LIMIT);
		for (const u of users) {
			if (u.data.account_type !== 'managed') notManaged.add(u.id);
		}
	}
	return candidates.filter((id) => !notManaged.has(id));
}

/**
 * One commit that makes every account inert before the slow part: no push
 * token to send to, and no caregiver_ref for the sweep to alert.
 */
async function stopTheBleeding(db: Firestore, uids: string[], patientUids: string[], now: Date): Promise<void> {
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

	// Identity documents last, then Auth again in case the early delete failed.
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
 * The purge cron: finishes interrupted deletions and re-sweeps recent ones
 * until their straggler window has passed. Costs one query when idle.
 */
export async function runAccountPurge(db: Firestore, accessToken: string, projectId: string): Promise<{ finished: number }> {
	const now = new Date();
	const jobs = await db.query(
		'account_deletions',
		[{ field: 'requested_at', op: 'LESS_THAN_OR_EQUAL', value: now }],
		MAX_JOBS_PER_RUN,
	);

	const budget: Budget = { left: CRON_PURGE_BUDGET };
	let finished = 0;
	for (const job of jobs) {
		const uids = Array.isArray(job.data.uids) ? job.data.uids.filter((u): u is string => typeof u === 'string') : [];
		const done = await purgeAccounts(db, accessToken, projectId, uids, budget);

		const finalizeAfter = job.data.finalize_after instanceof Date ? job.data.finalize_after : now;
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
 * Finds caregivers deleted before this endpoint existed: users docs left with
 * is_active false whose Auth account is gone. Their patients' schedules are
 * what kept the cron busy. Each one becomes an ordinary deletion job.
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
	// deleted_at is set by this file, so those already have a job.
	const candidates = inactive.filter((u) => !(u.data.deleted_at instanceof Date)).map((u) => u.id);
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
			// The Auth accounts are long gone; no stragglers to wait for.
			finalize_after: now,
			passes: 0,
		});
		await stopTheBleeding(db, uids, patientUids, now);
	}
	return orphans.length;
}
