/**
 * POST /dose-events — fans a dose outcome out to the caregiver.
 *
 * This stands in for the Firestore trigger that Cloud Functions would have
 * given us. The app writes the dose log to Firestore directly and *then* calls
 * this, fire-and-forget: a failure here must never cost the patient their
 * confirmation. The cron sweep's backstop retries any alert that did not land.
 */

import type { Env } from '../index';
import { getAccessToken, parseServiceAccount, verifyIdToken } from '../lib/google-auth';
import { Firestore } from '../lib/firestore';
import { sendPush } from '../lib/fcm';
import { error, getBearerToken, json } from '../lib/http';
import { ReadCache } from '../lib/read-cache';
import { alertKindFor, caregiverCopy, MISSED_SWITCH_KINDS } from '../lib/dose-copy';

interface DoseEventBody {
	dose_log_id?: string;
	status?: string;
	medication_name?: string;
}

/** Used only when the dose's medicine cannot be found at all. */
const FALLBACK_MEDICATION_NAME = 'their medication';

/**
 * What became of one caregiver alert.
 *
 *   delivered   the caregiver has it: pushed, or recorded in their Alerts tab
 *   suppressed  nobody to tell (no linked caregiver) or the caregiver switched
 *               this kind of alert off
 *
 * A failure is thrown, not returned, so callers can tell "do not retry" from
 * "retry later".
 */
export type AlertOutcome = 'delivered' | 'suppressed';

export async function handleDoseEvent(request: Request, env: Env): Promise<Response> {
	const idToken = getBearerToken(request);
	if (!idToken) return error('Sign in required.', 401, 'unauthenticated');

	const sa = parseServiceAccount(env.FIREBASE_SA_KEY);

	let callerUid: string;
	try {
		({ uid: callerUid } = await verifyIdToken(idToken, sa.project_id));
	} catch {
		return error('Your session has expired. Please sign in again.', 401, 'invalid_token');
	}

	let body: DoseEventBody;
	try {
		body = (await request.json()) as DoseEventBody;
	} catch {
		return error('Invalid request body.', 400, 'bad_request');
	}

	const status = body.status ?? 'taken';
	const accessToken = await getAccessToken(sa, env.TOKEN_CACHE);
	const db = new Firestore(sa.project_id, accessToken);
	const reads = new ReadCache(db);

	// The dose log is the authority on whose dose this is — never the caller's
	// own uid, and never a field in the request body.
	//
	// Two bugs lived here. Using callerUid as the patient meant a caregiver
	// confirming a dose on a patient's behalf looked up the caregiver's own
	// patient_profile, found no caregiver_ref, and silently notified nobody.
	// And writing caregiver_notified without checking ownership let any signed-in
	// user suppress the missed-dose alert for any dose log id they could guess.
	let patientUid = callerUid;
	let scheduleId = '';
	let log: Record<string, unknown> | null = null;

	if (body.dose_log_id) {
		log = await db.get('dose_logs', body.dose_log_id);
		if (!log) {
			return error('That dose could not be found.', 404, 'dose_not_found');
		}

		const logPatient = typeof log.patient_ref === 'string' ? log.patient_ref : '';
		if (!logPatient) {
			return error('That dose is not linked to a patient.', 409, 'dose_corrupt');
		}

		// The caller must be the patient, or that patient's caregiver.
		if (logPatient !== callerUid) {
			const profile = await reads.get('patient_profile', logPatient);
			if (profile?.caregiver_ref !== callerUid) {
				return error('You cannot report this dose.', 403, 'forbidden');
			}
		}
		patientUid = logPatient;
		scheduleId = typeof log.schedule_ref === 'string' ? log.schedule_ref : '';
	}

	const medicationName = body.medication_name?.trim() || (await medicationNameFor(reads, log));

	const outcome = await notifyCaregiver(db, accessToken, sa.project_id, {
		patientUid,
		status,
		medicationName,
		log,
		doseLogId: body.dose_log_id,
		reads,
	});
	const notified = outcome === 'delivered';

	if (body.dose_log_id && notified) {
		await db.set('dose_logs', body.dose_log_id, { caregiver_notified: true });
	}

	// The app has already decremented stock before calling this, so the
	// schedule holds the post-dose count.
	// stock_counted false: taken while the count read 0. The care partner was
	// told "Out of stock" when it reached 0; saying it again on every such
	// dose would only repeat it.
	if (status === 'taken' && scheduleId && log?.stock_counted !== false) {
		await notifyLowStockIfCrossed(db, accessToken, sa.project_id, {
			patientUid,
			scheduleId,
			medicationName,
			reads,
		});
	}

	return json({ notified });
}

/**
 * The medicine a dose log belongs to, by name: dose log → schedule →
 * patient_medications. The sweep has no app to tell it the name, and every
 * alert it sent used to read "has not taken their medication".
 */
export async function medicationNameFor(
	reads: ReadCache,
	log: Record<string, unknown> | null | undefined,
): Promise<string> {
	const scheduleId = typeof log?.schedule_ref === 'string' ? log.schedule_ref : '';
	if (!scheduleId) return FALLBACK_MEDICATION_NAME;

	const schedule = await reads.get('schedules', scheduleId);
	const patMedId = typeof schedule?.pat_med_ref === 'string' ? schedule.pat_med_ref : '';
	if (!patMedId) return FALLBACK_MEDICATION_NAME;

	const medication = await reads.get('patient_medications', patMedId);
	const name = typeof medication?.medication_name === 'string' ? medication.medication_name.trim() : '';
	return name || FALLBACK_MEDICATION_NAME;
}

/**
 * Pushes a low-stock alert to the caregiver when a dose brings a compartment
 * down to its threshold, and again when it empties. Firing only on those two
 * crossings, rather than on every dose below the threshold, keeps it from
 * repeating with each remaining pill.
 */
export async function notifyLowStockIfCrossed(
	db: Firestore,
	accessToken: string,
	projectId: string,
	params: { patientUid: string; scheduleId: string; medicationName?: string; reads?: ReadCache },
): Promise<void> {
	const reads = params.reads ?? new ReadCache(db);
	const schedule = await reads.get('schedules', params.scheduleId);
	if (!schedule || schedule.patient_ref !== params.patientUid) return;

	const remaining = typeof schedule.pills_remaining === 'number' ? schedule.pills_remaining : NaN;
	const threshold = typeof schedule.low_stock_threshold === 'number' ? schedule.low_stock_threshold : 5;
	if (remaining !== threshold && remaining !== 0) return;

	const profile = await reads.get('patient_profile', params.patientUid);
	const caregiverUid = typeof profile?.caregiver_ref === 'string' ? profile.caregiver_ref : '';
	if (!caregiverUid) return;

	const prefs = await reads.get('caregiver_profile', caregiverUid);
	if (prefs?.alert_pref_low_stock === false) return;

	const patient = await reads.get('users', params.patientUid);
	const patientName = [patient?.first_name, patient?.last_name].filter(Boolean).join(' ') || 'Your patient';
	const column = typeof schedule.mat_box_column === 'number' ? schedule.mat_box_column : null;
	const where = column ? ` in compartment ${column}` : '';

	const medicationName =
		params.medicationName || (await medicationNameFor(reads, { schedule_ref: params.scheduleId }));

	const title = remaining === 0 ? 'Out of stock' : 'Low medicine stock';
	const message =
		remaining === 0
			? `${patientName}'s ${medicationName}${where} is empty. Please refill it.`
			: `${patientName}'s ${medicationName}${where} is running low (${remaining} left).`;

	await deliver(db, accessToken, projectId, reads, {
		caregiverUid,
		patientUid: params.patientUid,
		kind: 'low_stock',
		title,
		message,
	});
}

/**
 * Tells the patient's caregiver about a dose: a push if their phone has a
 * token, and always a record in their Alerts tab. Shared with the cron sweep
 * so alerts read identically however they were detected.
 *
 * [status] is the reported dose status, or 'late' for the sweep's 30-minute
 * running-late pass; [log] supplies times, timing and reason for the wording.
 * When [medicationName] is not given it is looked up from the dose log.
 */
export async function notifyCaregiver(
	db: Firestore,
	accessToken: string,
	projectId: string,
	params: {
		patientUid: string;
		status: string;
		medicationName?: string;
		log?: Record<string, unknown> | null;
		doseLogId?: string;
		reads?: ReadCache;
	},
): Promise<AlertOutcome> {
	const reads = params.reads ?? new ReadCache(db);
	const profile = await reads.get('patient_profile', params.patientUid);
	const caregiverUid = typeof profile?.caregiver_ref === 'string' ? profile.caregiver_ref : '';
	if (!caregiverUid) return 'suppressed';

	const kind = alertKindFor(params.status, params.log ?? null);

	// The "Missed dose alerts" switch in caregiver settings covers late,
	// missed, skipped and corrections. Absent means on.
	if (MISSED_SWITCH_KINDS.has(kind)) {
		const prefs = await reads.get('caregiver_profile', caregiverUid);
		if (prefs?.alert_pref_missed === false) return 'suppressed';
	}

	const patient = await reads.get('users', params.patientUid);
	const patientName = [patient?.first_name, patient?.last_name].filter(Boolean).join(' ') || 'Your patient';
	const medicationName = params.medicationName || (await medicationNameFor(reads, params.log));
	const copy = caregiverCopy(kind, patientName, medicationName, params.log ?? null);

	await deliver(db, accessToken, projectId, reads, {
		caregiverUid,
		patientUid: params.patientUid,
		doseLogId: params.doseLogId,
		kind,
		title: copy.title,
		message: copy.body,
	});
	return 'delivered';
}

/**
 * Pushes one alert to the caregiver's phone and records it in their Alerts
 * tab. The record is written even when the push cannot be sent, so the alert
 * is never lost just because the phone had no token.
 *
 * patient_ref and dose_log_ref let the Alerts tab open the patient the alert
 * is about; without them a caregiver with two patients had only the wording
 * to go on.
 */
async function deliver(
	db: Firestore,
	accessToken: string,
	projectId: string,
	reads: ReadCache,
	alert: {
		caregiverUid: string;
		patientUid: string;
		doseLogId?: string;
		kind: string;
		title: string;
		message: string;
	},
): Promise<void> {
	const caregiver = await reads.get('users', alert.caregiverUid);
	const fcmToken = typeof caregiver?.fcm_token === 'string' ? caregiver.fcm_token : '';
	const sent = fcmToken
		? await sendPush(accessToken, projectId, {
				token: fcmToken,
				title: alert.title,
				body: alert.message,
				data: {
					type: alert.kind,
					patient_ref: alert.patientUid,
					...(alert.doseLogId ? { dose_log_ref: alert.doseLogId } : {}),
				},
			})
		: false;

	const notifId = crypto.randomUUID();
	await db.set('notifications', notifId, {
		notif_id: notifId,
		user_ref: alert.caregiverUid,
		patient_ref: alert.patientUid,
		dose_log_ref: alert.doseLogId ?? null,
		notification_type: alert.kind,
		title: alert.title,
		message: alert.message,
		sent_at: new Date(),
		read_at: null,
		channel: sent ? 'fcm' : 'in_app',
		is_active: true,
	});
}
