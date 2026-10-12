/**
 * Memoised document reads for one Worker invocation.
 *
 * Every caregiver alert reads the same handful of documents: the patient's
 * profile, both users, the caregiver's preferences, the schedule and the
 * medicine. Uncached, each alert spent six or more subrequests on reads alone,
 * so a sweep with a few alerts could hit the free plan's 50-subrequest ceiling
 * and every alert after that point threw. Cached, a second alert for the same
 * patient costs only the push and the write.
 *
 * Scoped to one request or one cron run. Nothing outlives the invocation, so a
 * changed preference is picked up on the next run.
 */

import { Firestore } from './firestore';

type Doc = Record<string, unknown> | null;

export class ReadCache {
	private readonly memo = new Map<string, Promise<Doc>>();

	constructor(private readonly db: Firestore) {}

	get(collection: string, id: string): Promise<Doc> {
		const key = `${collection}/${id}`;
		let hit = this.memo.get(key);
		if (!hit) {
			hit = this.db.get(collection, id);
			// A failed read is not remembered, so a later alert can try again.
			hit.catch(() => this.memo.delete(key));
			this.memo.set(key, hit);
		}
		return hit;
	}
}
