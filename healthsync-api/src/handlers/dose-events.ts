/**
 * POST /dose-events — fans a dose outcome out to the caregiver.
 *
 * This stands in for the Firestore trigger that Cloud Functions would have
 * given us. The app writes the dose log to Firestore directly and *then* calls
 * this, fire-and-forget: a failure here must never cost the patient their
 * confirmation. The cron sweep is the backstop.
 */

import type { Env } from '../index';
import { getAccessToken, parseServiceAccount, verifyIdToken } from '../lib/google-auth';
import { Firestore } from '../lib/firestore';
import { sendPush } from '../lib/fcm';
import { error, getBearerToken, json } from '../lib/http';
import { alertKindFor, caregiverCopy, MISSED_SWITCH_KINDS } from '../lib/dose-copy';

interface DoseEventBody {
	dose_log_id?: string;
	status?: string;
	medication_name?: string;
}

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
			const profile = await db.get('patient_profile', logPatient);
			if (profile?.caregiver_ref !== callerUid) {
				return error('You cannot report this dose.', 403, 'forbidden');
			}
		}
		patientUid = logPatient;
		scheduleId = typeof log.schedule_ref === 'string' ? log.schedule_ref : '';
	}

	const notified = await notifyCaregiver(db, accessToken, sa.project_id, {
		patientUid,
		status,
		medicationName: body.medication_name ?? 'their medication',
		log,
	});

	if (body.dose_log_id && notified) {
		await db.set('dose_logs', body.dose_log_id, { caregiver_notified: true });
	}

	// The app has already decremented stock before calling this, so the
	// schedule holds the post-dose count.
	if (status === 'taken' && scheduleId) {
		await notifyLowStockIfCrossed(db, accessToken, sa.project_id, {
			patientUid,
			scheduleId,
			medicationName: body.medication_name ?? 'their medication',
		});
	}

	return json({ notified });
}

/**
 * Pushes a low-stock alert to the caregiver when a dose brings a compartment
 * down to its threshold, and again when it empties. Firing only on those two
 * crossings, rather than on every dose below the threshold, keeps it from
 * repeating with each remaining pill.
 */
async function notifyLowStockIfCrossed(
	db: Firestore,
	accessToken: string,
	projectId: string,
	params: { patientUid: string; scheduleId: string; medicationName: string },
): Promise<void> {
	const schedule = await db.get('schedules', params.scheduleId);
	if (!schedule || schedule.patient_ref !== params.patientUid) return;

	const remaining = typeof schedule.pills_remaining === 'number' ? schedule.pills_remaining : NaN;
	const threshold = typeof schedule.low_stock_threshold === 'number' ? schedule.low_stock_threshold : 5;
	if (remaining !== threshold && remaining !== 0) return;

	const profile = await db.get('patient_profile', params.patientUid);
	const caregiverUid = typeof profile?.caregiver_ref === 'string' ? profile.caregiver_ref : '';
	if (!caregiverUid) return;

	const prefs = await db.get('caregiver_profile', caregiverUid);
	if (prefs?.alert_pref_low_stock === false) return;

	const patient = await db.get('users', params.patientUid);
	const patientName = [patient?.first_name, patient?.last_name].filter(Boolean).join(' ') || 'Your patient';
	const column = typeof schedule.mat_box_column === 'number' ? schedule.mat_box_column : null;
	const where = column ? ` in compartment ${column}` : '';

	const title = remaining === 0 ? 'Out of stock' : 'Low medicine stock';
	const message =
		remaining === 0
			? `${patientName}'s ${params.medicationName}${where} is empty. Please refill it.`
			: `${patientName}'s ${params.medicationName}${where} is running low (${remaining} left).`;

	const caregiver = await db.get('users', caregiverUid);
	const fcmToken = typeof caregiver?.fcm_token === 'string' ? caregiver.fcm_token : '';
	const sent = fcmToken
		? await sendPush(accessToken, projectId, {
				token: fcmToken,
				title,
				body: message,
				data: { type: 'low_stock', patient_ref: params.patientUid },
			})
		: false;

	// Recorded even when the push could not be sent, so the alert still shows
	// in the caregiver's Alerts tab.
	const notifId = crypto.randomUUID();
	await db.set('notifications', notifId, {
		notif_id: notifId,
		user_ref: caregiverUid,
		notification_type: 'low_stock',
		title,
		message,
		sent_at: new Date(),
		channel: sent ? 'fcm' : 'in_app',
		is_active: true,
	});
}

/**
 * Tells the patient's caregiver about a dose: a push if their phone has a
 * token, and always a record in their Alerts tab. Shared with the cron sweep
 * so alerts read identically however they were detected.
 *
 * [status] is the reported dose status, or 'late' for the sweep's 30-minute
 * running-late pass; [log] supplies times, timing and reason for the wording.
 * Returns true when the caregiver has the alert (pushed or recorded), which is
 * what `caregiver_notified` means.
 */
export async function notifyCaregiver(
	db: Firestore,
	accessToken: string,
	projectId: string,
	params: {
		patientUid: string;
		status: string;
		medicationName: string;
		log?: Record<string, unknown> | null;
	},
): Promise<boolean> {
	const profile = await db.get('patient_profile', params.patientUid);
	const caregiverUid = typeof profile?.caregiver_ref === 'string' ? profile.caregiver_ref : '';
	if (!caregiverUid) return false;

	const kind = alertKindFor(params.status, params.log ?? null);

	// The "Missed dose alerts" switch in caregiver settings covers late,
	// missed, skipped and corrections. Absent means on.
	if (MISSED_SWITCH_KINDS.has(kind)) {
		const prefs = await db.get('caregiver_profile', caregiverUid);
		if (prefs?.alert_pref_missed === false) return false;
	}

	const patient = await db.get('users', params.patientUid);
	const patientName = [patient?.first_name, patient?.last_name].filter(Boolean).join(' ') || 'Your patient';
	const copy = caregiverCopy(kind, patientName, params.medicationName, params.log ?? null);

	const caregiver = await db.get('users', caregiverUid);
	const fcmToken = typeof caregiver?.fcm_token === 'string' ? caregiver.fcm_token : '';
	const sent = fcmToken
		? await sendPush(accessToken, projectId, {
				token: fcmToken,
				title: copy.title,
				body: copy.body,
				data: { type: kind, patient_ref: params.patientUid },
			})
		: false;

	// Recorded even when the push could not be sent, so the alert still shows
	// in the caregiver's Alerts tab.
	const notifId = crypto.randomUUID();
	await db.set('notifications', notifId, {
		notif_id: notifId,
		user_ref: caregiverUid,
		notification_type: kind,
		title: copy.title,
		message: copy.body,
		sent_at: new Date(),
		channel: sent ? 'fcm' : 'in_app',
		is_active: true,
	});

	return true;
}
