/**
 * Turns `schedules` (recurring intent) into `dose_logs` (dated instances).
 *
 * Nothing in the system did this. Dose logs were only ever created at the moment
 * a patient tapped "I took my dose", already set to `taken`, so no document with
 * `status: 'pending'` ever existed — and the sweep, which looks for exactly
 * that, could never mark anything missed. The 30-minute rule the project is
 * graded on had no input.
 *
 * This runs on the same 5-minute cron as the sweep rather than on its own
 * schedule, and shares that invocation's access token.
 *
 * Idempotency comes from the document id, not from a transaction: a log is
 * `{schedule_id}_{YYYY-MM-DD}_{HH:mm}`, so re-running the job on a dose that
 * already exists is a no-op. The alternative — merging into a deterministic id
 * blindly — would reset a `taken` dose back to `pending` every five minutes.
 */

import { Firestore } from '../lib/firestore';

/**
 * The project is deployed for one clinic in Manila, and schedules store wall
 * clock time ("08:00 PM") as the caregiver typed it. Workers run in UTC, so
 * without this offset a dose set for 8 AM Manila would materialise against the
 * wrong calendar day for eight hours of every day.
 *
 * A per-patient timezone belongs on the `users` document if the app is ever
 * deployed more widely; this constant is the honest single-region version.
 */
const MANILA_UTC_OFFSET_HOURS = 8;

/** How far ahead to create logs. One day is enough for a 5-minute cron. */
const HORIZON_DAYS = 2;

/** Bounded to stay inside the free plan's 10ms CPU and 50 subrequests. */
const MAX_SCHEDULES = 200;
const MAX_EXISTING_LOGS = 600;
const MAX_WRITES_PER_RUN = 40;

interface ScheduleRow {
	id: string;
	data: Record<string, unknown>;
}

/** Local civil date in Manila, as {y, m, d} plus the weekday (1 = Monday). */
function manilaParts(instant: Date): { key: string; weekday: number } {
	const shifted = new Date(instant.getTime() + MANILA_UTC_OFFSET_HOURS * 3600_000);
	const y = shifted.getUTCFullYear();
	const m = String(shifted.getUTCMonth() + 1).padStart(2, '0');
	const d = String(shifted.getUTCDate()).padStart(2, '0');
	// getUTCDay() is 0 = Sunday; the app models 1 = Monday, 7 = Sunday.
	const day = shifted.getUTCDay();
	return { key: `${y}-${m}-${d}`, weekday: day === 0 ? 7 : day };
}

/**
 * The UTC instant for a Manila wall-clock time on a given local date.
 */
function manilaInstant(dateKey: string, hour: number, minute: number): Date {
	const [y, m, d] = dateKey.split('-').map(Number);
	return new Date(Date.UTC(y, m - 1, d, hour - MANILA_UTC_OFFSET_HOURS, minute));
}

/**
 * Parses the stored display time. Accepts "08:00 PM", "8:00 pm" and "20:00",
 * matching the app's own parser — a time this cannot read is skipped rather
 * than guessed at, because a dose placed at the wrong hour is worse than a
 * dose the sweep never sees.
 */
export function parseScheduleTime(raw: unknown): { hour: number; minute: number; label: string } | null {
	if (typeof raw !== 'string') return null;
	const text = raw.trim().toUpperCase();
	const match = /^(\d{1,2}):(\d{2})\s*(AM|PM)?$/.exec(text);
	if (!match) return null;

	let hour = Number(match[1]);
	const minute = Number(match[2]);
	const period = match[3];
	if (minute > 59) return null;

	if (period) {
		if (hour < 1 || hour > 12) return null;
		// 12 AM is midnight and 12 PM is noon — the one pair a naive
		// "+12 for PM" gets wrong in both directions.
		hour = period === 'AM' ? (hour === 12 ? 0 : hour) : hour === 12 ? 12 : hour + 12;
	} else if (hour > 23) {
		return null;
	}

	return { hour, minute, label: text };
}

/**
 * Whether a schedule runs on [weekday]. Handles both shapes the field has been
 * written in: integers (the Flutter model, 1 = Monday) and short day names
 * (the schema in CLAUDE.md). An absent or empty value means every day.
 */
function runsOnWeekday(daysOfWeek: unknown, weekday: number): boolean {
	if (!Array.isArray(daysOfWeek) || daysOfWeek.length === 0) return true;

	const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
	const wantedName = names[weekday - 1].toLowerCase();

	return daysOfWeek.some((entry) => {
		if (typeof entry === 'number') return entry === weekday;
		if (typeof entry === 'string') {
			const value = entry.trim().toLowerCase();
			if (/^\d+$/.test(value)) return Number(value) === weekday;
			return value.startsWith(wantedName);
		}
		return false;
	});
}

function asDate(value: unknown): Date | null {
	if (value instanceof Date) return value;
	if (typeof value === 'string') {
		const parsed = new Date(value);
		return Number.isNaN(parsed.getTime()) ? null : parsed;
	}
	return null;
}

/**
 * How long after a dose time a newly created schedule still counts for it.
 *
 * Entering a medicine at 8:03 for an 8:00 dose should still produce today's
 * dose; entering it at 11:00 should not.
 */
const CREATION_GRACE_MS = 15 * 60 * 1000;

/** Whether [dateKey] falls inside the schedule's start and end dates. */
function withinRange(schedule: Record<string, unknown>, dateKey: string): boolean {
	const dayStart = manilaInstant(dateKey, 23, 59);
	const dayEnd = manilaInstant(dateKey, 0, 0);

	const start = asDate(schedule.start_date);
	if (start && start.getTime() > dayStart.getTime()) return false;

	const end = asDate(schedule.end_date);
	if (end && end.getTime() < dayEnd.getTime()) return false;

	return true;
}

export async function runMaterialize(db: Firestore): Promise<{ created: number }> {
	const now = new Date();

	const schedules = (await db.query('schedules', [{ field: 'is_active', value: true }], MAX_SCHEDULES)) as ScheduleRow[];
	if (schedules.length === 0) return { created: 0 };

	// Which logs already exist in the window. One query, so re-runs cost a
	// fixed two subrequests rather than one read per dose.
	const windowStart = new Date(manilaParts(now).key + 'T00:00:00Z');
	const existing = await db.query(
		'dose_logs',
		[{ field: 'scheduled_at', op: 'GREATER_THAN_OR_EQUAL', value: windowStart }],
		MAX_EXISTING_LOGS,
	);
	const known = new Set(existing.map((row) => row.id));

	const writes: Array<{ collection: string; id: string; data: Record<string, unknown> }> = [];
	const expectedIds = new Set<string>();

	for (let dayOffset = 0; dayOffset < HORIZON_DAYS; dayOffset++) {
		const target = new Date(now.getTime() + dayOffset * 86_400_000);
		const { key: dateKey, weekday } = manilaParts(target);

		for (const schedule of schedules) {
			if (writes.length >= MAX_WRITES_PER_RUN) break;

			const patientRef = typeof schedule.data.patient_ref === 'string' ? schedule.data.patient_ref : '';
			if (!patientRef) continue;
			if (!runsOnWeekday(schedule.data.days_of_week, weekday)) continue;
			if (!withinRange(schedule.data, dateKey)) continue;

			const time = parseScheduleTime(schedule.data.scheduled_time);
			if (!time) {
				console.warn(`Schedule ${schedule.id} has an unreadable scheduled_time; skipped.`);
				continue;
			}

			const hhmm = `${String(time.hour).padStart(2, '0')}:${String(time.minute).padStart(2, '0')}`;
			const logId = `${schedule.id}_${dateKey}_${hhmm}`;

			// Every id the current schedules justify, whether or not it already
			// exists. Anything pending and future outside this set belongs to a
			// dose time that has since been edited away.
			expectedIds.add(logId);

			if (known.has(logId)) continue;

			const scheduledAt = manilaInstant(dateKey, time.hour, time.minute);

			// A dose cannot predate the schedule that defines it.
			//
			// Adding a medicine at 11am with an 8am dose time used to create
			// that morning's 8am dose, which the sweep then marked missed half
			// an hour later. Nobody could have taken it: the medicine did not
			// exist, no reminder fired, and the patient was blamed for it.
			//
			// GRACE_MS covers the realistic case of entering a dose a minute or
			// two after its time and still wanting it counted today. Older
			// schedules carry no created_at, so they fall back to start_date and
			// behave exactly as before.
			const createdAt = asDate(schedule.data.created_at);
			if (createdAt && scheduledAt.getTime() + CREATION_GRACE_MS < createdAt.getTime()) {
				continue;
			}

			writes.push({
				collection: 'dose_logs',
				id: logId,
				data: {
					dose_log_id: logId,
					schedule_ref: schedule.id,
					patient_ref: patientRef,
					scheduled_date: dateKey,
					scheduled_time: time.label,
					scheduled_at: scheduledAt,
					status: 'pending',
					snooze_count: 0,
					confirmed_via: '',
					// False, always. Only a successful push sets this true, and
					// hardcoding it the other way is what disarmed the sweep.
					caregiver_notified: false,
					dose_count: 1,
					skipped_reason: '',
					recorded_by: 'system',
					created_at: now,
					is_active: true,
				},
			});
			known.add(logId);
		}
	}

	// Retire future pending logs that no longer match any live schedule.
	//
	// Editing a dose time does not rewrite the logs already materialised for it:
	// the id encodes the old time, so a new one is created and the old one is
	// left behind. Nobody confirms it, the sweep marks it missed 30 minutes
	// later, and the caregiver gets a false alert while adherence is skewed.
	//
	// Only future and only `pending` are touched — a dose already taken, missed
	// or snoozed is history and must never be rewritten.
	const stale: Array<{ collection: string; id: string }> = [];
	for (const row of existing) {
		if (row.data.status !== 'pending') continue;

		const at = row.data.scheduled_at;
		const when = at instanceof Date ? at : new Date(String(at));
		if (Number.isNaN(when.getTime()) || when.getTime() <= now.getTime()) continue;

		if (!expectedIds.has(row.id)) {
			stale.push({ collection: 'dose_logs', id: row.id });
		}
	}

	if (stale.length > 0) {
		await db.deleteAll(stale);
		console.log(`Materialise: retired ${stale.length} orphaned pending dose log(s).`);
	}

	if (writes.length === 0) return { created: 0 };

	await db.commit(writes);
	return { created: writes.length };
}
