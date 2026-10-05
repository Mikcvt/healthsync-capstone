/**
 * Firebase Cloud Messaging, HTTP v1.
 *
 * This is the piece a client genuinely cannot do: sending a push to *another*
 * user's device needs an OAuth token from the service account. The legacy
 * server-key API that once allowed it was retired in 2024.
 */

export interface PushMessage {
	token: string;
	title: string;
	body: string;
	data?: Record<string, string>;
}

/**
 * Sends one push. Returns false instead of throwing when the device token is
 * stale — a caregiver who reinstalled the app should not fail the dose write
 * that triggered the notification.
 */
export async function sendPush(accessToken: string, projectId: string, message: PushMessage): Promise<boolean> {
	const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
		method: 'POST',
		headers: {
			Authorization: `Bearer ${accessToken}`,
			'Content-Type': 'application/json',
		},
		body: JSON.stringify({
			message: {
				token: message.token,
				notification: { title: message.title, body: message.body },
				data: message.data ?? {},
				android: {
					priority: 'HIGH',
					notification: { channel_id: 'healthsync_doses' },
				},
			},
		}),
	});

	if (response.ok) return true;

	// 404 / UNREGISTERED means the token no longer maps to an install.
	if (response.status === 404 || response.status === 400) {
		console.warn(`FCM rejected token (${response.status}): ${await response.text()}`);
		return false;
	}

	throw new Error(`FCM send failed (${response.status}): ${await response.text()}`);
}
