/**
 * The cron sweep — the 30-minute missed-dose rule.
 *
 * This is the job that genuinely cannot live in the app: a dose must be marked
 * missed whether or not anyone's phone is awake. It also doubles as the backstop
 * for /dose-events, since a dropped notification call leaves caregiver_notified
 * false and gets picked up here.
 */

import { Firestore } from '../lib/firestore';
import { notifyCaregiver } from './dose-events';

/** Spec: no confirmation after 30 minutes is a missed dose. */
const MISSED_AFTER_MINUTES = 30;

/**
 * Bounded so one run stays inside the free plan's 50 external subrequests and
 * 10ms CPU. At a 5-minute cadence this clears far more than a real deployment
 * of this size will ever produce.
 */
const MAX_DOSES_PER_RUN = 40;

export async function runSweep(
	db: Firestore,
	accessToken: string,
	projectId: string,
): Promise<{ missed: number; notified: number }> {
	const cutoff = new Date(Date.now() - MISSED_AFTER_MINUTES * 60 * 1000);

	// One query, one commit — the reason dose_logs carries a scheduled_at
	// timestamp rather than separate date and time strings.
	const stale = await db.query(
		'dose_logs',
		[
			{ field: 'status', value: 'pending' },
			{ field: 'scheduled_at', op: 'LESS_THAN', value: cutoff },
		],
		MAX_DOSES_PER_RUN,
	);

	if (stale.length === 0) {
		return { missed: 0, notified: 0 };
	}

	await db.commit(
		stale.map((dose) => ({
			collection: 'dose_logs',
			id: dose.id,
			data: { status: 'missed', led_active: false },
		})),
	);

	// Turn off the box LED for each affected schedule so the patient is not
	// still being prompted for a dose the system has already written off.
	const scheduleIds = [...new Set(stale.map((d) => d.data.schedule_ref).filter((s): s is string => typeof s === 'string'))];
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
	for (const dose of stale) {
		const patientUid = typeof dose.data.patient_ref === 'string' ? dose.data.patient_ref : '';
		if (!patientUid) continue;
		if (dose.data.caregiver_notified === true) continue;

		try {
			const sent = await notifyCaregiver(db, accessToken, projectId, {
				patientUid,
				status: 'missed',
				medicationName: 'their medication',
			});
			if (sent) notified++;
		} catch (err) {
			// One unreachable caregiver must not abort the rest of the sweep.
			console.error(`Could not notify caregiver for dose ${dose.id}:`, err);
		}
	}

	return { missed: stale.length, notified };
}
