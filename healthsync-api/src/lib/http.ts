/** Shared HTTP helpers: JSON responses, bearer extraction, brute-force guard. */

export function json(data: unknown, status = 200): Response {
	return new Response(JSON.stringify(data), {
		status,
		headers: { 'Content-Type': 'application/json' },
	});
}

export function error(message: string, status = 400, code?: string): Response {
	return json({ error: message, code: code ?? 'error' }, status);
}

export function getBearerToken(request: Request): string | null {
	const header = request.headers.get('Authorization');
	if (!header?.startsWith('Bearer ')) return null;
	const token = header.substring(7).trim();
	return token.length > 0 ? token : null;
}

export function clientIp(request: Request): string {
	return request.headers.get('CF-Connecting-IP') ?? 'unknown';
}

const MAX_FAILURES = 10;
const WINDOW_SECONDS = 600;

/**
 * Throttles OTP guessing.
 *
 * Only *failed* attempts are counted, so a caregiver handing out codes normally
 * never writes to KV — which matters because the free plan allows 1000 KV
 * writes a day. Once an IP is blocked the counter stops incrementing too, so
 * a single attacker cannot exhaust the quota by hammering one address.
 *
 * This is defence in depth, not the only defence: a Cloudflare Rate Limiting
 * rule on /otp/redeem is the cheaper outer layer and costs no KV at all.
 */
export async function isRateLimited(cache: KVNamespace, ip: string): Promise<boolean> {
	const raw = await cache.get(`otp_fail:${ip}`);
	return raw !== null && Number(raw) >= MAX_FAILURES;
}

export async function recordFailure(cache: KVNamespace, ip: string): Promise<void> {
	const key = `otp_fail:${ip}`;
	const current = Number((await cache.get(key)) ?? '0');
	if (current >= MAX_FAILURES) return;
	await cache.put(key, String(current + 1), { expirationTtl: WINDOW_SECONDS });
}
