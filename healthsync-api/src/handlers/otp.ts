/**
 * POST /otp/redeem — the managed patient's entire login.
 *
 * Unauthenticated by necessity: the patient has no account credentials to
 * present. The code itself is the secret, so this endpoint is the one place in
 * the system where getting the checks wrong hands out account access.
 */

import type { Env } from '../index';
import { createCustomToken, getAccessToken, parseServiceAccount } from '../lib/google-auth';
import { Firestore } from '../lib/firestore';
import { clientIp, error, isRateLimited, json, recordFailure } from '../lib/http';

interface RedeemBody {
	code?: string;
}

export async function handleRedeemOtp(request: Request, env: Env): Promise<Response> {
	const ip = clientIp(request);
	if (await isRateLimited(env.TOKEN_CACHE, ip)) {
		return error('Too many attempts. Please wait a few minutes and try again.', 429, 'rate_limited');
	}

	let body: RedeemBody;
	try {
		body = (await request.json()) as RedeemBody;
	} catch {
		return error('Invalid request body.', 400, 'bad_request');
	}

	const code = body.code?.trim().toUpperCase().replace(/-/g, '');
	if (!code) {
		return error('Please enter your code.', 400, 'missing_code');
	}

	const sa = parseServiceAccount(env.FIREBASE_SA_KEY);
	const accessToken = await getAccessToken(sa, env.TOKEN_CACHE);
	const db = new Firestore(sa.project_id, accessToken);

	const otp = await db.get('otp_codes', code);

	// Every failure path below returns the same shape of information to the
	// caller but is counted, so guessing is slow and unprofitable.
	if (!otp) {
		await recordFailure(env.TOKEN_CACHE, ip);
		return error('That code is not valid. Check it and try again.', 404, 'invalid_code');
	}

	if (otp.used === true) {
		await recordFailure(env.TOKEN_CACHE, ip);
		return error('That code has already been used. Ask your caregiver for a new one.', 409, 'code_used');
	}

	const expiresAt = otp.expires_at instanceof Date ? otp.expires_at : new Date(String(otp.expires_at));
	if (!(expiresAt instanceof Date) || Number.isNaN(expiresAt.getTime()) || expiresAt.getTime() < Date.now()) {
		await recordFailure(env.TOKEN_CACHE, ip);
		return error('That code has expired. Ask your caregiver for a new one.', 410, 'code_expired');
	}

	const patientUid = typeof otp.patient_ref === 'string' ? otp.patient_ref : '';
	if (!patientUid) {
		return error('This code is not linked to an account. Contact your caregiver.', 500, 'code_corrupt');
	}

	// Burn the code before handing out the token. If the token mint failed after
	// this point the patient would need a new code, which is the safe direction
	// to fail — the opposite order would leave a redeemed code replayable.
	await db.set('otp_codes', code, { used: true, redeemed_at: new Date() });

	const customToken = await createCustomToken(sa, patientUid);

	const patient = await db.get('users', patientUid);

	return json({
		token: customToken,
		uid: patientUid,
		first_name: patient?.first_name ?? '',
		last_name: patient?.last_name ?? '',
	});
}
