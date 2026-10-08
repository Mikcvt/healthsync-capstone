/**
 * HealthSync API — the privileged sidecar to the Flutter app.
 *
 * Firebase runs on the free Spark plan, where Cloud Functions cannot deploy at
 * all. This Worker covers the four jobs a client is incapable of doing safely:
 *
 *   POST /patients      caregiver creates a managed patient's Auth account
 *   POST /otp/redeem    code in, Firebase custom token out (no password login)
 *   POST /dose-events   dose outcome fans out to the caregiver over FCM
 *   cron every 5 min    materialises upcoming doses, then marks unconfirmed
 *                       ones missed after 30 minutes
 *
 * Everything else the app does — every read and every write a user is permitted
 * to make — goes straight from Flutter to Firestore under the security rules.
 */

import { handleCreatePatient } from './handlers/patients';
import { handleRedeemOtp } from './handlers/otp';
import { handleDoseEvent } from './handlers/dose-events';
import { runMaterialize } from './handlers/materialize';
import { runSweep } from './handlers/sweep';
import { Firestore } from './lib/firestore';
import { getAccessToken, parseServiceAccount } from './lib/google-auth';
import { error, json } from './lib/http';

export interface Env {
	/** The Firebase service account JSON. Set with: wrangler secret put FIREBASE_SA_KEY */
	FIREBASE_SA_KEY: string;
	/** Caches the Google OAuth access token and OTP failure counters. */
	TOKEN_CACHE: KVNamespace;
}

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		const url = new URL(request.url);
		const route = `${request.method} ${url.pathname}`;

		try {
			switch (route) {
				case 'GET /health':
					return json({ status: 'ok', service: 'healthsync-api' });

				case 'POST /patients':
					return await handleCreatePatient(request, env);

				case 'POST /otp/redeem':
					return await handleRedeemOtp(request, env);

				case 'POST /dose-events':
					return await handleDoseEvent(request, env);

				default:
					return error('Not found.', 404, 'not_found');
			}
		} catch (err) {
			// Log the detail, return none of it: these messages can carry
			// Firestore paths and token fragments.
			console.error(`${route} failed:`, err);
			return error('Something went wrong. Please try again.', 500, 'internal_error');
		}
	},

	async scheduled(event: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
		ctx.waitUntil(runCron(env));
	},
} satisfies ExportedHandler<Env>;

/**
 * The 5-minute cron, in order: create the dose logs that are coming, then mark
 * the ones that have gone unconfirmed.
 *
 * Both jobs share one access token and one Firestore client. That is not tidiness
 * — the free plan allows 10ms of CPU and 50 subrequests per invocation, and
 * minting a second OAuth token would spend an RSA signature for nothing.
 *
 * Materialising runs first so a dose created this minute is eligible for the
 * sweep in 30 minutes rather than 35.
 */
async function runCron(env: Env): Promise<void> {
	const sa = parseServiceAccount(env.FIREBASE_SA_KEY);
	const accessToken = await getAccessToken(sa, env.TOKEN_CACHE);
	const db = new Firestore(sa.project_id, accessToken);

	// A failure in one job must not cancel the other: an unreachable caregiver
	// should never stop tomorrow's doses from being created.
	try {
		const { created } = await runMaterialize(db);
		if (created > 0) {
			console.log(`Materialise: created ${created} pending dose log(s).`);
		}
	} catch (err) {
		console.error('Materialise failed:', err);
	}

	try {
		const { late, missed, notified, skipsRecovered } = await runSweep(db, accessToken, sa.project_id);
		if (late > 0) {
			console.log(`Sweep: ${late} running-late alert(s) sent.`);
		}
		if (missed > 0) {
			console.log(`Sweep: ${missed} dose(s) marked missed, ${notified} caregiver(s) notified.`);
		}
		if (skipsRecovered > 0) {
			console.log(`Sweep: ${skipsRecovered} skip alert(s) sent by the backstop.`);
		}
	} catch (err) {
		console.error('Sweep failed:', err);
	}
}
