/**
 * The cron sweep — the late and missed rules (DOSE_LOGIC_PROPOSAL.md, 2.3).
 *
 *   +30 min, nothing recorded   → caregiver gets "Running late" (once)
 *   +60 min, nothing recorded   → dose marked missed, caregiver alerted
 *
 * This is the job that genuinely cannot live in the app: a dose must be marked
 * missed whether or not anyone's phone is awake. It also backstops
 * /dose-events: a missed dose whose alert was dropped keeps
 * caregiver_notified false, and a skip whose call never arrived is picked up
 * here a couple of minutes later.
 */

import { Firestore } from '../lib/firestore';
import { notifyCaregiver } from './dose-events';

/** The caregiver is told the patient is running late at this point. */
const LATE_AFTER_MINUTES = 30;

/** An undecided dose becomes missed at this point. */
const MISSED_AFTER_MINUTES = 60;

/**
 * How long a snoozed dose stays open after its snooze ends. The app re-fires
 * the reminder when the snooze expires; this is the patient's time to answer
 * it before the sweep writes the dose off.
 */
const SNOOZE_GRACE_MINUTES = 10;

/**
 * A skip is reported by the app once its Undo window closes. If that call has
 * not arrived this long after the skip, the sweep sends the alert itself.
 */
const SKIP_BACKSTOP_AFTER_MINUTES = 2;

/** Skips older than this are not retried, so a caregiver who cannot be reached is not retried forever. */
const SKIP_BACKSTOP_WINDOW_MINUTES = 30;

/**
 * Bounded so one run stays inside the free plan's 50 external subrequests and
 * 10ms CPU. Each alert costs several reads, so alerts are capped lower than
 * status changes.
 */
const MAX_DOSES_PER_RUN = 40;
const MAX_ALERTS_PER_RUN = 8;

type Row = { id: string; data: Record<string, unknown> };

const minutes = (n: number) => n * 60 * 1000;

function asDate(value: unknown): Date | null {
	if (value instanceof Date) return value;
	if (typeof value === 'string') {
		const parsed = new Date(value);
		return Number.isNaN(parsed.getTime()) ? null : parsed;
	}
	return null;
}

export async function runSweep(
	db: Firestore,
	accessToken: string,
	projectId: string,
): Promise<{ late: number; missed: number; notified: number; skipsRecovered: number }> {
	const now = Date.now();
	const late = await runLatePass(db, accessToken, projectId, now);
	const { missed, notified } = await runMissedPass(db, accessToken, projectId, now);
	const skipsRecovered = await runSkipBackstop(db, accessToken, projectId, now);
	return { late, missed, notified, skipsRecovered };
}

async function alert(
	db: Firestore,
	accessToken: string,
	projectId: string,
	dose: Row,
	status: string,
): Promise<boolean> {
	const patientUid = typeof dose.data.patient_ref === 'string' ? dose.data.patient_ref : '';
	if (!patientUid) return false;
	try {
		return await notifyCaregiver(db, accessToken, projectId, {
			patientUid,
			status,
			medicationName: 'their medication',
			log: dose.data,
		});
	} catch (err) {
		// One unreachable caregiver must not abort the rest of the sweep.
		console.error(`Could not alert caregiver (${status}) for dose ${dose.id}:`, err);
		return false;
	}
}

/**
 * Doses 30 to 60 minutes past their time with nothing recorded: tell the
 * caregiver once. The status does not change — the patient still has until
 * the hour to take it.
 */
async function runLatePass(db: Firestore, accessToken: string, projectId: string, now: number): Promise<number> {
	const lateCutoff = new Date(now - minutes(LATE_AFTER_MINUTES));
	const missedCutoff = new Date(now - minutes(MISSED_AFTER_MINUTES));

	const window = (status: string) =>
		db.query(
			'dose_logs',
			[
				{ field: 'status', value: status },
				{ field: 'scheduled_at', op: 'LESS_THAN', value: lateCutoff },
				{ field: 'scheduled_at', op: 'GREATER_THAN_OR_EQUAL', value: missedCutoff },
			],
			MAX_DOSES_PER_RUN,
		);

	const due = [...(await window('pending')), ...(await window('snoozed'))]
		.filter((dose) => dose.data.late_notified !== true)
		.slice(0, MAX_ALERTS_PER_RUN);
	if (due.length === 0) return 0;

	for (const dose of due) {
		await alert(db, accessToken, projectId, dose, 'late');
	}

	// Marked whether or not the alert got through: "running late" is sent
	// once, and the missed alert at the hour is what must not be lost.
	await db.commit(
		due.map((dose) => ({
			collection: 'dose_logs',
			id: dose.id,
			data: { late_notified: true },
		})),
	);
	return due.length;
}

/** Doses an hour past their time with nothing recorded become missed. */
async function runMissedPass(
	db: Firestore,
	accessToken: string,
	projectId: string,
	now: number,
): Promise<{ missed: number; notified: number }> {
	const cutoff = new Date(now - minutes(MISSED_AFTER_MINUTES));

	// The reason dose_logs carries a scheduled_at timestamp rather than
	// separate date and time strings: "older than an hour" is one range query.
	const pending = await db.query(
		'dose_logs',
		[
			{ field: 'status', value: 'pending' },
			{ field: 'scheduled_at', op: 'LESS_THAN', value: cutoff },
		],
		MAX_DOSES_PER_RUN,
	);

	// Snoozed doses too. Querying only 'pending' meant one snooze followed by
	// silence left a dose snoozed forever: never missed, caregiver never told.
	// Same status + scheduled_at index as above, so no new composite index.
	const snoozed = await db.query(
		'dose_logs',
		[
			{ field: 'status', value: 'snoozed' },
			{ field: 'scheduled_at', op: 'LESS_THAN', value: cutoff },
		],
		MAX_DOSES_PER_RUN,
	);
	const abandoned = snoozed.filter((dose) => snoozeExpired(dose.data.snoozed_until, now));

	const stale = [...pending, ...abandoned].slice(0, MAX_DOSES_PER_RUN);
	if (stale.length === 0) return { missed: 0, notified: 0 };

	await db.commit(
		stale.map((dose) => ({
			collection: 'dose_logs',
			id: dose.id,
			data: { status: 'missed', led_active: false },
		})),
	);

	// Turn off the box LED for each affected schedule so the patient is not
	// still being prompted for a dose the system has already written off.
	const scheduleIds = [
		...new Set(stale.map((d) => d.data.schedule_ref).filter((s): s is string => typeof s === 'string')),
	];
	if (scheduleIds.length > 0) {
		await db.commit(
			scheduleIds.map((id) => ({
				collection: 'schedules',
				id,
				data: { led_active: false },
			})),
		);
	}

	let notified = 0;
	const toAlert = stale.filter((dose) => dose.data.caregiver_notified !== true).slice(0, MAX_ALERTS_PER_RUN);
	for (const dose of toAlert) {
		if (await alert(db, accessToken, projectId, dose, 'missed')) {
			notified++;
			await db.set('dose_logs', dose.id, { caregiver_notified: true });
		}
	}

	return { missed: stale.length, notified };
}

/**
 * Skips whose /dose-events call never arrived — the app is killed during the
 * Undo window, or offline. Retried only for a short window after the skip.
 */
async function runSkipBackstop(db: Firestore, accessToken: string, projectId: string, now: number): Promise<number> {
	// A skip can be logged up to 3 hours early and up to an hour late, so a
	// window around now catches every recent one with the existing
	// status + scheduled_at index.
	const skipped = await db.query(
		'dose_logs',
		[
			{ field: 'status', value: 'skipped' },
			{ field: 'scheduled_at', op: 'GREATER_THAN_OR_EQUAL', value: new Date(now - minutes(4 * 60)) },
			{ field: 'scheduled_at', op: 'LESS_THAN', value: new Date(now + minutes(4 * 60)) },
		],
		MAX_DOSES_PER_RUN,
	);

	const waiting = skipped
		.filter((dose) => {
			if (dose.data.caregiver_notified === true) return false;
			const loggedAt = asDate(dose.data.logged_at);
			if (!loggedAt) return false;
			const age = now - loggedAt.getTime();
			return age > minutes(SKIP_BACKSTOP_AFTER_MINUTES) && age < minutes(SKIP_BACKSTOP_WINDOW_MINUTES);
		})
		.slice(0, MAX_ALERTS_PER_RUN);

	let recovered = 0;
	for (const dose of waiting) {
		if (await alert(db, accessToken, projectId, dose, 'skipped')) {
			recovered++;
			await db.set('dose_logs', dose.id, { caregiver_notified: true });
		}
	}
	return recovered;
}

/**
 * Whether a snoozed dose's last snooze, plus the grace period, is over. A log
 * written before snoozed_until existed has none; the cutoff it has already
 * passed is the only rule left for it.
 */
function snoozeExpired(snoozedUntil: unknown, now: number): boolean {
	if (!(snoozedUntil instanceof Date)) return true;
	return snoozedUntil.getTime() + minutes(SNOOZE_GRACE_MINUTES) < now;
}
