/**
 * HealthSync API — the privileged sidecar to the Flutter app.
 *
 * Firebase runs on the free Spark plan, where Cloud Functions cannot deploy at
 * all. This Worker covers the four jobs a client is incapable of doing safely:
 *
 *   POST /patients      caregiver creates a managed patient's Auth account
 *   POST /otp/redeem    code in, Firebase custom token out (no password login)
 *   POST /dose-events   dose outcome fans out to the caregiver over FCM
 *   cron every 5 min    marks unconfirmed doses missed after 30 minutes
 *
 * Everything else the app does — every read and every write a user is permitted
 * to make — goes straight from Flutter to Firestore under the security rules.
 */

import { handleCreatePatient } from './handlers/patients';
import { handleRedeemOtp } from './handlers/otp';
import { handleDoseEvent } from './handlers/dose-events';
import { runSweep } from './handlers/sweep';
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
		ctx.waitUntil(
			runSweep(env)
				.then((result) => {
					if (result.missed > 0) {
						console.log(`Sweep: ${result.missed} dose(s) marked missed, ${result.notified} caregiver(s) notified.`);
					}
				})
				.catch((err) => console.error('Sweep failed:', err)),
		);
	},
} satisfies ExportedHandler<Env>;
