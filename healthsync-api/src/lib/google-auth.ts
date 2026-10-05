/**
 * Everything that needs the Firebase service account key: OAuth access tokens
 * for Firestore and FCM, Firebase custom tokens for OTP sign-in, and
 * verification of ID tokens presented by the app.
 */

import { base64UrlDecodeToString, signJwt } from './crypto';

export interface ServiceAccount {
	project_id: string;
	private_key: string;
	client_email: string;
}

const TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';
const CUSTOM_TOKEN_AUDIENCE = 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit';

/** JWK form, so WebCrypto can import the keys directly without ASN.1 parsing. */
const GOOGLE_JWKS_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

const SCOPES = [
	'https://www.googleapis.com/auth/datastore',
	'https://www.googleapis.com/auth/firebase.messaging',
	'https://www.googleapis.com/auth/identitytoolkit',
].join(' ');

const ACCESS_TOKEN_CACHE_KEY = 'google_access_token';
/** Google issues these for 3600s; we refresh early so none is used near expiry. */
const ACCESS_TOKEN_TTL_SECONDS = 3300;

export function parseServiceAccount(raw: string | undefined): ServiceAccount {
	if (!raw) {
		throw new Error('FIREBASE_SA_KEY is not set. Run: wrangler secret put FIREBASE_SA_KEY');
	}
	const parsed = JSON.parse(raw) as ServiceAccount;
	if (!parsed.private_key || !parsed.client_email || !parsed.project_id) {
		throw new Error('FIREBASE_SA_KEY is missing project_id, client_email or private_key.');
	}
	return parsed;
}

/**
 * An OAuth access token for Firestore and FCM, cached in KV.
 *
 * The cache is the reason this fits the free plan's CPU budget: without it
 * every request would pay for an RSA signature plus a round trip to Google.
 */
export async function getAccessToken(sa: ServiceAccount, cache: KVNamespace): Promise<string> {
	const cached = await cache.get(ACCESS_TOKEN_CACHE_KEY);
	if (cached) return cached;

	const now = Math.floor(Date.now() / 1000);
	const assertion = await signJwt(
		{
			iss: sa.client_email,
			scope: SCOPES,
			aud: TOKEN_ENDPOINT,
			iat: now,
			exp: now + 3600,
		},
		sa.private_key,
	);

	const response = await fetch(TOKEN_ENDPOINT, {
		method: 'POST',
		headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
		body: new URLSearchParams({
			grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
			assertion,
		}),
	});

	if (!response.ok) {
		throw new Error(`Token exchange failed (${response.status}): ${await response.text()}`);
	}

	const { access_token: accessToken } = (await response.json()) as { access_token: string };
	await cache.put(ACCESS_TOKEN_CACHE_KEY, accessToken, { expirationTtl: ACCESS_TOKEN_TTL_SECONDS });
	return accessToken;
}

/**
 * Mints a Firebase custom token. The app exchanges this via
 * signInWithCustomToken() for a real session — this is what lets a managed
 * patient sign in with no email and no password.
 */
export async function createCustomToken(sa: ServiceAccount, uid: string, claims?: Record<string, unknown>): Promise<string> {
	const now = Math.floor(Date.now() / 1000);
	return signJwt(
		{
			iss: sa.client_email,
			sub: sa.client_email,
			aud: CUSTOM_TOKEN_AUDIENCE,
			uid,
			iat: now,
			// Firebase rejects custom tokens older than an hour. The session the
			// app trades it for lasts indefinitely, so this is only the window
			// in which the token must be redeemed.
			exp: now + 3600,
			...(claims ? { claims } : {}),
		},
		sa.private_key,
	);
}

interface Jwk {
	kid: string;
	kty: string;
	alg: string;
	use: string;
	n: string;
	e: string;
}

let jwksCache: { keys: Record<string, CryptoKey>; fetchedAt: number } | null = null;
const JWKS_TTL_MS = 60 * 60 * 1000;

async function getGooglePublicKey(kid: string): Promise<CryptoKey | null> {
	if (!jwksCache || Date.now() - jwksCache.fetchedAt > JWKS_TTL_MS) {
		const response = await fetch(GOOGLE_JWKS_URL);
		if (!response.ok) throw new Error(`Could not fetch Google JWKS (${response.status})`);
		const { keys } = (await response.json()) as { keys: Jwk[] };

		const imported: Record<string, CryptoKey> = {};
		for (const jwk of keys) {
			imported[jwk.kid] = await crypto.subtle.importKey(
				'jwk',
				{ kty: jwk.kty, n: jwk.n, e: jwk.e, alg: 'RS256', ext: true },
				{ name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
				false,
				['verify'],
			);
		}
		jwksCache = { keys: imported, fetchedAt: Date.now() };
	}
	return jwksCache.keys[kid] ?? null;
}

export interface VerifiedToken {
	uid: string;
	email?: string;
}

/**
 * Verifies a Firebase ID token from the app.
 *
 * Signature, issuer, audience and expiry are all checked. Skipping any of these
 * would let a caller forge a uid and act as any user, so there is no "trusted
 * caller" shortcut anywhere in this service.
 */
export async function verifyIdToken(idToken: string, projectId: string): Promise<VerifiedToken> {
	const parts = idToken.split('.');
	if (parts.length !== 3) throw new Error('Malformed token');

	const header = JSON.parse(base64UrlDecodeToString(parts[0])) as { kid?: string; alg?: string };
	const payload = JSON.parse(base64UrlDecodeToString(parts[1])) as {
		sub?: string;
		aud?: string;
		iss?: string;
		exp?: number;
		email?: string;
	};

	if (header.alg !== 'RS256') throw new Error('Unexpected token algorithm');
	if (!header.kid) throw new Error('Token has no key id');
	if (payload.aud !== projectId) throw new Error('Token audience mismatch');
	if (payload.iss !== `https://securetoken.google.com/${projectId}`) throw new Error('Token issuer mismatch');
	if (!payload.sub) throw new Error('Token has no subject');
	if (!payload.exp || payload.exp < Math.floor(Date.now() / 1000)) throw new Error('Token expired');

	const key = await getGooglePublicKey(header.kid);
	if (!key) throw new Error('Unknown token key id');

	const signature = Uint8Array.from(atob(parts[2].replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));
	const valid = await crypto.subtle.verify(
		'RSASSA-PKCS1-v1_5',
		key,
		signature,
		new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
	);
	if (!valid) throw new Error('Invalid token signature');

	return { uid: payload.sub, email: payload.email };
}

/**
 * Creates a Firebase Auth user via the Identity Toolkit admin API.
 *
 * Managed patients get a random password that is generated, used to satisfy the
 * API, and then discarded — they authenticate only through OTP-minted custom
 * tokens, so nobody ever needs to know it.
 */
export async function createAuthUser(
	accessToken: string,
	projectId: string,
	params: { email: string; password: string; displayName?: string },
): Promise<string> {
	const response = await fetch(
		`https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts`,
		{
			method: 'POST',
			headers: {
				Authorization: `Bearer ${accessToken}`,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({
				email: params.email,
				password: params.password,
				displayName: params.displayName,
				emailVerified: false,
			}),
		},
	);

	if (!response.ok) {
		throw new Error(`Could not create account (${response.status}): ${await response.text()}`);
	}

	const { localId } = (await response.json()) as { localId: string };
	return localId;
}

/** A password nobody records, for an account nobody logs into with a password. */
export function randomPassword(): string {
	const bytes = new Uint8Array(24);
	crypto.getRandomValues(bytes);
	return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}
