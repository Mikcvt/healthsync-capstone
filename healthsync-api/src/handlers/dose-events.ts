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

	const notified = await notifyCaregiver(db, accessToken, sa.project_id, {
		patientUid: callerUid,
		status,
		medicationName: body.medication_name ?? 'their medication',
	});

	if (body.dose_log_id && notified) {
		await db.set('dose_logs', body.dose_log_id, { caregiver_notified: true });
	}

	return json({ notified });
}

/**
 * Looks up the patient's caregiver and pushes to them. Shared with the cron
 * sweep so missed-dose alerts read identically however they were detected.
 */
export async function notifyCaregiver(
	db: Firestore,
	accessToken: string,
	projectId: string,
	params: { patientUid: string; status: string; medicationName: string },
): Promise<boolean> {
	const profile = await db.get('patient_profile', params.patientUid);
	const caregiverUid = typeof profile?.caregiver_ref === 'string' ? profile.caregiver_ref : '';
	if (!caregiverUid) return false;

	const caregiver = await db.get('users', caregiverUid);
	const fcmToken = typeof caregiver?.fcm_token === 'string' ? caregiver.fcm_token : '';
	if (!fcmToken) return false;

	const patient = await db.get('users', params.patientUid);
	const patientName = [patient?.first_name, patient?.last_name].filter(Boolean).join(' ') || 'Your patient';

	const copy =
		params.status === 'missed'
			? { title: 'Missed dose', body: `${patientName} has not taken ${params.medicationName}.` }
			: { title: 'Dose taken', body: `${patientName} took ${params.medicationName}.` };

	const sent = await sendPush(accessToken, projectId, {
		token: fcmToken,
		title: copy.title,
		body: copy.body,
		data: { type: params.status === 'missed' ? 'missed' : 'confirmed', patient_ref: params.patientUid },
	});

	if (sent) {
		const notifId = crypto.randomUUID();
		await db.set('notifications', notifId, {
			notif_id: notifId,
			user_ref: caregiverUid,
			notification_type: params.status === 'missed' ? 'missed' : 'confirmed',
			title: copy.title,
			message: copy.body,
			sent_at: new Date(),
			channel: 'fcm',
			is_active: true,
		});
	}

	return sent;
}
