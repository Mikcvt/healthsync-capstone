/**
 * The cron sweep — the late and missed rules (DOSE_LOGIC_PROPOSAL.md, 2.3).
 *
 *   +30 min, nothing recorded   → caregiver gets "Running late" (once)
 *   +60 min, nothing recorded   → dose marked missed, caregiver alerted
 *
 * This is the job that genuinely cannot live in the app: a dose must be marked
 * missed whether or not anyone's phone is awake. It also backstops
 * /dose-events: any taken, skipped or missed dose whose caregiver alert did not
 * land is retried here (docs/archive/CAREGIVER_ALERTS_FIX.md).
 */

import { Firestore } from '../lib/firestore';
import { ReadCache } from '../lib/read-cache';
import { notifyCaregiver, notifyLowStockIfCrossed } from './dose-events';

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
 * The app reports Done and Skip once its 5-second Undo window closes. If that
 * report has not landed this long after the patient acted, the sweep sends the
 * alert itself.
 */
const BACKSTOP_AFTER_MINUTES = 2;

/** App-reported outcomes older than this are not retried. */
const BACKSTOP_WINDOW_MINUTES = 30;

/**
 * Missed doses whose alert failed are retried for this long after the dose
 * time. Long enough to outlast an FCM outage, short enough that a caregiver is
 * not told about this morning's dose at midnight.
 */
const MISSED_RETRY_HOURS = 6;

/**
 * Bounded so one run stays inside the free plan's 50 external subrequests and
 * 10ms CPU. The alert budget is shared by every pass: it used to be 8 per
 * pass, which allowed 24 alerts in one run, far past the subrequest limit.
 *
 * Rough cost of one run: ~15 subrequests for materialise and the sweep's own
 * queries and commits; 2-3 per alert (push, record, dose flag); 4 cold reads
 * per patient and 2 per medicine, cached after the first alert. Five alerts
 * keeps a run with two patients under 50. Whatever does not fit is picked up
 * five minutes later.
 */
const MAX_DOSES_PER_RUN = 40;
const MAX_ALERTS_PER_RUN = 5;

type Row = { id: string; data: Record<string, unknown> };

/** State shared by the passes of one sweep. */
interface SweepRun {
	db: Firestore;
	accessToken: string;
	projectId: string;
	now: number;
	reads: ReadCache;
	alertsLeft: number;
	/** Doses already tried this run, so the backstop does not retry them at once. */
	attempted: Set<string>;
}

type Outcome = 'delivered' | 'suppressed' | 'failed';

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
): Promise<{ late: number; missed: number; notified: number; recovered: number }> {
	const run: SweepRun = {
		db,
		accessToken,
		projectId,
		now: Date.now(),
		reads: new ReadCache(db),
		alertsLeft: MAX_ALERTS_PER_RUN,
		attempted: new Set(),
	};

	// Newly missed doses get the alert budget first, then running-late, then
	// retries of earlier failures.
	const { missed, notified } = await runMissedPass(run);
	const late = await runLatePass(run);

	// Its own try: the backstop queries need composite indexes (see
	// firestore.indexes.json). If they are not deployed yet, the late and
	// missed passes above must still have run.
	let recovered = 0;
	try {
		recovered = await runBackstop(run);
	} catch (err) {
		console.error('Alert backstop failed:', err);
	}
	return { late, missed, notified, recovered };
}

async function alert(run: SweepRun, dose: Row, status: string): Promise<Outcome> {
	const patientUid = typeof dose.data.patient_ref === 'string' ? dose.data.patient_ref : '';
	if (!patientUid) return 'suppressed';
	run.attempted.add(dose.id);
	try {
		const outcome = await notifyCaregiver(run.db, run.accessToken, run.projectId, {
			patientUid,
			status,
			log: dose.data,
			doseLogId: dose.id,
			reads: run.reads,
		});
		// A suppressed alert costs a cached read or two, not a push, so it does
		// not use up the budget.
		if (outcome === 'delivered') run.alertsLeft--;
		return outcome;
	} catch (err) {
		// One unreachable caregiver must not abort the rest of the sweep.
		run.alertsLeft--;
		console.error(`Could not alert caregiver (${status}) for dose ${dose.id}:`, err);
		return 'failed';
	}
}

/** Doses an hour past their time with nothing recorded become missed. */
async function runMissedPass(run: SweepRun): Promise<{ missed: number; notified: number }> {
	const { db, now } = run;
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
			// missed_at: when the sweep wrote it off. A dose the patient acted
			// on before this, offline, is accepted when it syncs (firestore.rules)
			// and the caregiver gets a correction (dose-copy.ts).
			data: { status: 'missed', led_active: false, missed_at: new Date(now) },
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

	// Doses that do not fit the budget keep caregiver_notified false; the
	// backstop alerts them on a later run. They used to be marked missed and
	// then never alerted at all.
	let notified = 0;
	for (const dose of stale) {
		if (run.alertsLeft <= 0) break;
		if (dose.data.caregiver_notified === true) continue;
		const missedLog = { ...dose.data, status: 'missed' };
		if ((await alert(run, { id: dose.id, data: missedLog }, 'missed')) === 'delivered') {
			notified++;
			await db.set('dose_logs', dose.id, { caregiver_notified: true });
		}
	}

	return { missed: stale.length, notified };
}

/**
 * Doses 30 to 60 minutes past their time with nothing recorded: tell the
 * caregiver once. The status does not change — the patient still has until
 * the hour to take it.
 */
async function runLatePass(run: SweepRun): Promise<number> {
	const { db, now } = run;
	if (run.alertsLeft <= 0) return 0;
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

	const due = [...(await window('pending')), ...(await window('snoozed'))].filter(
		(dose) => dose.data.late_notified !== true,
	);

	const tried: Row[] = [];
	for (const dose of due) {
		if (run.alertsLeft <= 0) break;
		await alert(run, dose, 'late');
		tried.push(dose);
	}
	if (tried.length === 0) return 0;

	// Marked whether or not the alert got through: "running late" is sent
	// once, and the missed alert at the hour is what must not be lost. Doses
	// the budget did not reach stay unmarked and are tried on the next run.
	await db.commit(
		tried.map((dose) => ({
			collection: 'dose_logs',
			id: dose.id,
			data: { late_notified: true },
		})),
	);
	return tried.length;
}

/**
 * Retries caregiver alerts that never landed (caregiver_notified still false):
 *
 *   1. Taken, skipped or missed doses the app reported, where /dose-events
 *      never arrived — the app was killed during the Undo window, was offline,
 *      or the Worker errored. This used to cover skips only, so a confirmed
 *      dose whose report was lost never reached the caregiver, and neither did
 *      its low-stock alert.
 *   2. Doses the sweep itself marked missed whose alert failed or did not fit
 *      the budget. The missed pass queries only pending and snoozed doses, so
 *      once a dose was missed nothing ever looked at it again.
 */
async function runBackstop(run: SweepRun): Promise<number> {
	const { db, now } = run;
	if (run.alertsLeft <= 0) return 0;

	// Index: caregiver_notified + synced_at.
	//
	// synced_at is when the change reached the SERVER, stamped by Firestore.
	// It used to be logged_at, the patient's own time: a dose logged offline
	// and synced two hours later was already outside the 30-minute window when
	// it arrived, so its alert was never sent.
	const reported = await db.query(
		'dose_logs',
		[
			{ field: 'caregiver_notified', value: false },
			{ field: 'synced_at', op: 'GREATER_THAN_OR_EQUAL', value: new Date(now - minutes(BACKSTOP_WINDOW_MINUTES)) },
			{ field: 'synced_at', op: 'LESS_THAN', value: new Date(now - minutes(BACKSTOP_AFTER_MINUTES)) },
		],
		MAX_DOSES_PER_RUN,
	);

	// Index: status + caregiver_notified + scheduled_at.
	const swept = await db.query(
		'dose_logs',
		[
			{ field: 'status', value: 'missed' },
			{ field: 'caregiver_notified', value: false },
			{ field: 'scheduled_at', op: 'GREATER_THAN_OR_EQUAL', value: new Date(now - MISSED_RETRY_HOURS * minutes(60)) },
			{ field: 'scheduled_at', op: 'LESS_THAN', value: new Date(now - minutes(MISSED_AFTER_MINUTES)) },
		],
		MAX_DOSES_PER_RUN,
	);

	const seen = new Set<string>();
	const waiting = [...reported, ...swept].filter((dose) => {
		if (seen.has(dose.id) || run.attempted.has(dose.id)) return false;
		seen.add(dose.id);
		const status = dose.data.status;
		if (status !== 'taken' && status !== 'skipped' && status !== 'missed') return false;
		// The patient acted moments ago: the app's own report is probably
		// still on its way, and alerting now would send it twice.
		const loggedAt = asDate(dose.data.logged_at);
		return !loggedAt || now - loggedAt.getTime() > minutes(BACKSTOP_AFTER_MINUTES);
	});

	let recovered = 0;
	for (const dose of waiting) {
		if (run.alertsLeft <= 0) break;
		const status = dose.data.status as string;
		if ((await alert(run, dose, status)) !== 'delivered') continue;
		recovered++;
		await db.set('dose_logs', dose.id, { caregiver_notified: true });

		// A lost "taken" report also lost its low-stock check.
		const scheduleId = typeof dose.data.schedule_ref === 'string' ? dose.data.schedule_ref : '';
		const patientUid = typeof dose.data.patient_ref === 'string' ? dose.data.patient_ref : '';
		if (status === 'taken' && scheduleId && patientUid && dose.data.stock_counted !== false) {
			try {
				await notifyLowStockIfCrossed(db, run.accessToken, run.projectId, {
					patientUid,
					scheduleId,
					reads: run.reads,
				});
			} catch (err) {
				console.error(`Low-stock backstop failed for dose ${dose.id}:`, err);
			}
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
