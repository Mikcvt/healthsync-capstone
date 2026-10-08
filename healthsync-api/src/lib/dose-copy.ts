/**
 * What the caregiver is told about a dose, worded once for /dose-events and
 * the cron sweep alike (DOSE_LOGIC_PROPOSAL.md, sections 2.3, 7.3 and 9).
 *
 * Pure functions with no I/O, so the wording can be checked without Firestore.
 */

/** The project serves one clinic in Manila; see materialize.ts. */
const MANILA_UTC_OFFSET_HOURS = 8;

/** The kinds of caregiver alert, which are also the notification types. */
export type AlertKind = 'confirmed' | 'late' | 'missed' | 'skipped' | 'correction';

/**
 * Alerts covered by the caregiver's "Missed dose alerts" switch. Confirmations
 * are not switchable.
 */
export const MISSED_SWITCH_KINDS: ReadonlySet<AlertKind> = new Set<AlertKind>([
	'late',
	'missed',
	'skipped',
	'correction',
]);

function asDate(value: unknown): Date | null {
	if (value instanceof Date) return value;
	if (typeof value === 'string') {
		const parsed = new Date(value);
		return Number.isNaN(parsed.getTime()) ? null : parsed;
	}
	return null;
}

/** "8:05 PM" in Manila time. */
export function manilaClock(instant: Date): string {
	const shifted = new Date(instant.getTime() + MANILA_UTC_OFFSET_HOURS * 3600_000);
	const h24 = shifted.getUTCHours();
	const minute = String(shifted.getUTCMinutes()).padStart(2, '0');
	const hour = h24 % 12 === 0 ? 12 : h24 % 12;
	return `${hour}:${minute} ${h24 >= 12 ? 'PM' : 'AM'}`;
}

/** "2 hrs 10 mins", "1 hr", "35 mins", "1 min". */
export function spanInWords(milliseconds: number): string {
	const total = Math.floor(Math.abs(milliseconds) / 60_000);
	const hours = Math.floor(total / 60);
	const minutes = total % 60;
	const mins = (n: number) => (n === 1 ? '1 min' : `${n} mins`);
	if (hours === 0) return mins(minutes);
	const h = hours === 1 ? '1 hr' : `${hours} hrs`;
	return minutes === 0 ? h : `${h} ${mins(minutes)}`;
}

/**
 * Which alert a reported dose status becomes. A dose taken with timing
 * `logged_late` was missed and then corrected, so the caregiver — who has
 * already been told it was missed — gets a correction, not "Dose taken".
 */
export function alertKindFor(status: string, log: Record<string, unknown> | null): AlertKind {
	if (status === 'late') return 'late';
	if (status === 'missed') return 'missed';
	if (status === 'skipped') return 'skipped';
	if (log?.timing === 'logged_late') return 'correction';
	return 'confirmed';
}

/** Title and body for one caregiver alert. */
export function caregiverCopy(
	kind: AlertKind,
	patientName: string,
	medicationName: string,
	log: Record<string, unknown> | null,
): { title: string; body: string } {
	const scheduledAt = asDate(log?.scheduled_at);
	const takenAt = asDate(log?.taken_at);
	const due = scheduledAt ? ` It was due at ${manilaClock(scheduledAt)}.` : '';

	switch (kind) {
		case 'late':
			return {
				title: 'Running late',
				body: `${patientName} has not taken ${medicationName} yet.${due}`,
			};
		case 'missed':
			return {
				title: 'Missed dose',
				body: `${patientName} has not taken ${medicationName}.${due}`,
			};
		case 'skipped': {
			const reason = typeof log?.skipped_reason === 'string' ? log.skipped_reason.trim() : '';
			return {
				title: 'Dose skipped',
				body: `${patientName} skipped ${medicationName}${reason ? ` — ${reason}` : ''}.`,
			};
		}
		case 'correction':
			return {
				title: 'Dose update',
				body: takenAt
					? `Update: ${patientName} says they took ${medicationName} at ${manilaClock(takenAt)} (logged later).`
					: `Update: ${patientName} says they took ${medicationName} (logged later).`,
			};
		case 'confirmed': {
			const timing = log?.timing;
			if (takenAt && scheduledAt && timing === 'early') {
				return {
					title: 'Dose taken early',
					body: `${patientName} took ${medicationName} early (${spanInWords(scheduledAt.getTime() - takenAt.getTime())} before).`,
				};
			}
			if (takenAt && scheduledAt && timing === 'late') {
				return {
					title: 'Dose taken late',
					body: `${patientName} took ${medicationName} late (${spanInWords(takenAt.getTime() - scheduledAt.getTime())} after).`,
				};
			}
			return { title: 'Dose taken', body: `${patientName} took ${medicationName}.` };
		}
	}
}
