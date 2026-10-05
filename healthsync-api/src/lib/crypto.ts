/**
 * RS256 signing primitives.
 *
 * Workers have no Node crypto and no Firebase Admin SDK, so every JWT this
 * service produces is signed here with WebCrypto. The free plan allows 10ms of
 * CPU per invocation and an RSA sign costs a few milliseconds of that, which is
 * why callers cache their tokens rather than re-signing per request.
 */

export function base64UrlEncode(input: ArrayBuffer | Uint8Array | string): string {
	let bytes: Uint8Array;
	if (typeof input === 'string') {
		bytes = new TextEncoder().encode(input);
	} else if (input instanceof Uint8Array) {
		bytes = input;
	} else {
		bytes = new Uint8Array(input);
	}

	let binary = '';
	for (let i = 0; i < bytes.length; i++) {
		binary += String.fromCharCode(bytes[i]);
	}
	return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function base64UrlDecodeToString(input: string): string {
	const padded = input.replace(/-/g, '+').replace(/_/g, '/');
	const binary = atob(padded.padEnd(padded.length + ((4 - (padded.length % 4)) % 4), '='));
	const bytes = new Uint8Array(binary.length);
	for (let i = 0; i < binary.length; i++) {
		bytes[i] = binary.charCodeAt(i);
	}
	return new TextDecoder().decode(bytes);
}

/**
 * A service account's `private_key` is PEM-wrapped PKCS#8. JSON.parse already
 * turned its `\n` escapes into real newlines, so we only strip the armour.
 */
function pemToPkcs8(pem: string): ArrayBuffer {
	const body = pem
		.replace(/-----BEGIN PRIVATE KEY-----/, '')
		.replace(/-----END PRIVATE KEY-----/, '')
		.replace(/\s+/g, '');
	const binary = atob(body);
	const bytes = new Uint8Array(binary.length);
	for (let i = 0; i < binary.length; i++) {
		bytes[i] = binary.charCodeAt(i);
	}
	return bytes.buffer;
}

let cachedSigningKey: CryptoKey | null = null;
let cachedSigningKeySource = '';

/**
 * Imports and memoises the signing key for the lifetime of the isolate. Reusing
 * it across requests on a warm isolate saves the import cost entirely.
 */
async function getSigningKey(privateKeyPem: string): Promise<CryptoKey> {
	if (cachedSigningKey && cachedSigningKeySource === privateKeyPem) {
		return cachedSigningKey;
	}
	const key = await crypto.subtle.importKey(
		'pkcs8',
		pemToPkcs8(privateKeyPem),
		{ name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
		false,
		['sign'],
	);
	cachedSigningKey = key;
	cachedSigningKeySource = privateKeyPem;
	return key;
}

/** Signs a JWT with RS256 and returns the compact serialisation. */
export async function signJwt(
	payload: Record<string, unknown>,
	privateKeyPem: string,
	header: Record<string, unknown> = {},
): Promise<string> {
	const fullHeader = { alg: 'RS256', typ: 'JWT', ...header };
	const signingInput = `${base64UrlEncode(JSON.stringify(fullHeader))}.${base64UrlEncode(JSON.stringify(payload))}`;

	const key = await getSigningKey(privateKeyPem);
	const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(signingInput));

	return `${signingInput}.${base64UrlEncode(signature)}`;
}
