/**
 * POST /patients — a caregiver creates a managed patient account.
 *
 * The patient never signs up. This mints their Auth account and Firestore
 * documents so that by the time they type their OTP, their schedule is already
 * waiting for them.
 */

import type { Env } from '../index';
import { createAuthUser, getAccessToken, parseServiceAccount, randomPassword, verifyIdToken } from '../lib/google-auth';
import { Firestore } from '../lib/firestore';
import { error, getBearerToken, json } from '../lib/http';

interface CreatePatientBody {
	first_name?: string;
	last_name?: string;
	phone?: string;
	medical_conditions?: string;
	allergies?: string;
	emergency_contact?: string;
	emergency_phone?: string;
}

/**
 * Managed patients have no real inbox, but Firebase Auth requires an email.
 * A routable-looking domain would risk mail actually being sent somewhere, so
 * this uses a reserved-by-RFC .invalid suffix.
 */
function syntheticEmail(uidSeed: string): string {
	return `patient-${uidSeed}@healthsync.invalid`;
}

/** The caregiver's form collects free text; Firestore holds an array. */
function splitList(raw: string | undefined): string[] {
	if (!raw) return [];
	return raw
		.split(',')
		.map((item) => item.trim())
		.filter((item) => item.length > 0);
}

export async function handleCreatePatient(request: Request, env: Env): Promise<Response> {
	const idToken = getBearerToken(request);
	if (!idToken) return error('Sign in required.', 401, 'unauthenticated');

	const sa = parseServiceAccount(env.FIREBASE_SA_KEY);

	let caregiverUid: string;
	try {
		({ uid: caregiverUid } = await verifyIdToken(idToken, sa.project_id));
	} catch {
		return error('Your session has expired. Please sign in again.', 401, 'invalid_token');
	}

	let body: CreatePatientBody;
	try {
		body = (await request.json()) as CreatePatientBody;
	} catch {
		return error('Invalid request body.', 400, 'bad_request');
	}

	const firstName = body.first_name?.trim() ?? '';
	const lastName = body.last_name?.trim() ?? '';
	if (!firstName || !lastName) {
		return error("Please provide the patient's first and last name.", 400, 'missing_name');
	}

	const accessToken = await getAccessToken(sa, env.TOKEN_CACHE);
	const db = new Firestore(sa.project_id, accessToken);

	// The role claim is never taken from the request body — a patient could
	// otherwise call this endpoint and create accounts of their own.
	const caregiver = await db.get('users', caregiverUid);
	if (!caregiver || caregiver.account_type !== 'caregiver') {
		return error('Only caregivers can add patients.', 403, 'forbidden');
	}

	const seed = crypto.randomUUID().split('-')[0];
	const patientUid = await createAuthUser(accessToken, sa.project_id, {
		email: syntheticEmail(seed),
		password: randomPassword(),
		displayName: `${firstName} ${lastName}`,
	});

	const now = new Date();

	await db.set('users', patientUid, {
		uid: patientUid,
		role: 'patient',
		account_type: 'managed',
		first_name: firstName,
		last_name: lastName,
		email: '',
		phone: body.phone?.trim() ?? '',
		can_edit_medications: false,
		created_at: now,
		is_active: true,
	});

	await db.set('patient_profile', patientUid, {
		profile_id: patientUid,
		user_ref: patientUid,
		caregiver_ref: caregiverUid,
		// Arrays, not strings: the app models these as List<String> and its
		// parser threw a TypeError on the string form, which took down the
		// whole patient_profile stream.
		medical_conditions: splitList(body.medical_conditions),
		allergies: splitList(body.allergies),
		emergency_contact: body.emergency_contact?.trim() ?? '',
		emergency_phone: body.emergency_phone?.trim() ?? '',
		created_at: now,
	});

	const linkId = crypto.randomUUID();
	await db.set('caregiver_patient_links', linkId, {
		link_id: linkId,
		caregiver_ref: caregiverUid,
		patient_ref: patientUid,
		linked_since: now,
		linked_by: caregiverUid,
		status: 'active',
		can_view_schedule: true,
		can_receive_alerts: true,
		can_edit_medications: true,
		created_at: now,
		is_active: true,
	});

	return json({ uid: patientUid, first_name: firstName, last_name: lastName }, 201);
}
