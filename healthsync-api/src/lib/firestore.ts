/**
 * Firestore over the REST API.
 *
 * Admin credentials bypass security rules entirely, which is exactly why the
 * `otp_codes` collection is unreadable from the app: only this file touches it.
 *
 * Note the subrequest budget — 50 external fetches per invocation on the free
 * plan — so the sweep uses one runQuery and one batched commit rather than a
 * request per document.
 */

const BASE = 'https://firestore.googleapis.com/v1';

export type FirestoreValue =
	| { stringValue: string }
	| { booleanValue: boolean }
	| { integerValue: string }
	| { doubleValue: number }
	| { timestampValue: string }
	| { nullValue: null }
	| { arrayValue: { values?: FirestoreValue[] } }
	| { mapValue: { fields?: Record<string, FirestoreValue> } };

export interface FirestoreDocument {
	name: string;
	fields?: Record<string, FirestoreValue>;
	createTime?: string;
	updateTime?: string;
}

/** Converts a plain JS value into Firestore's tagged-union wire format. */
export function toValue(value: unknown): FirestoreValue {
	if (value === null || value === undefined) return { nullValue: null };
	if (value instanceof Date) return { timestampValue: value.toISOString() };
	if (typeof value === 'string') return { stringValue: value };
	if (typeof value === 'boolean') return { booleanValue: value };
	if (typeof value === 'number') {
		return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
	}
	if (Array.isArray(value)) {
		return { arrayValue: { values: value.map(toValue) } };
	}
	if (typeof value === 'object') {
		const fields: Record<string, FirestoreValue> = {};
		for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
			fields[k] = toValue(v);
		}
		return { mapValue: { fields } };
	}
	return { stringValue: String(value) };
}

/** The inverse of {@link toValue}. */
export function fromValue(value: FirestoreValue | undefined): unknown {
	if (!value) return undefined;
	if ('stringValue' in value) return value.stringValue;
	if ('booleanValue' in value) return value.booleanValue;
	if ('integerValue' in value) return Number(value.integerValue);
	if ('doubleValue' in value) return value.doubleValue;
	if ('timestampValue' in value) return new Date(value.timestampValue);
	if ('nullValue' in value) return null;
	if ('arrayValue' in value) return (value.arrayValue.values ?? []).map(fromValue);
	if ('mapValue' in value) return fromFields(value.mapValue.fields);
	return undefined;
}

export function fromFields(fields: Record<string, FirestoreValue> | undefined): Record<string, unknown> {
	const out: Record<string, unknown> = {};
	for (const [k, v] of Object.entries(fields ?? {})) {
		out[k] = fromValue(v);
	}
	return out;
}

export function toFields(data: Record<string, unknown>): Record<string, FirestoreValue> {
	const fields: Record<string, FirestoreValue> = {};
	for (const [k, v] of Object.entries(data)) {
		fields[k] = toValue(v);
	}
	return fields;
}

/** The trailing path segment of a document's resource name. */
export function docId(name: string): string {
	return name.substring(name.lastIndexOf('/') + 1);
}

export class Firestore {
	private readonly root: string;

	constructor(
		private readonly projectId: string,
		private readonly accessToken: string,
	) {
		this.root = `${BASE}/projects/${projectId}/databases/(default)/documents`;
	}

	private headers(): HeadersInit {
		return {
			Authorization: `Bearer ${this.accessToken}`,
			'Content-Type': 'application/json',
		};
	}

	/** Returns null when the document does not exist, rather than throwing. */
	async get(collection: string, id: string): Promise<Record<string, unknown> | null> {
		const response = await fetch(`${this.root}/${collection}/${encodeURIComponent(id)}`, {
			headers: this.headers(),
		});
		if (response.status === 404) return null;
		if (!response.ok) {
			throw new Error(`Firestore get failed (${response.status}): ${await response.text()}`);
		}
		const doc = (await response.json()) as FirestoreDocument;
		return fromFields(doc.fields);
	}

	/**
	 * Merges [data] into a document, creating it if absent.
	 *
	 * The updateMask is essential, not optional: a REST PATCH without one
	 * REPLACES the whole document, so writing `{used: true}` to an OTP code
	 * would delete its patient_ref, expires_at and everything else. Every field
	 * not named here is left untouched.
	 */
	async set(collection: string, id: string, data: Record<string, unknown>): Promise<void> {
		const mask = Object.keys(data)
			.map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
			.join('&');

		const response = await fetch(`${this.root}/${collection}/${encodeURIComponent(id)}?${mask}`, {
			method: 'PATCH',
			headers: this.headers(),
			body: JSON.stringify({ fields: toFields(data) }),
		});
		if (!response.ok) {
			throw new Error(`Firestore set failed (${response.status}): ${await response.text()}`);
		}
	}

	/**
	 * Runs a structured query. Each `where` is an equality unless an operator is
	 * given; `OPERATOR` values follow Firestore's FieldFilter enum, e.g.
	 * `LESS_THAN` for the sweep's age cutoff.
	 */
	async query(
		collection: string,
		where: Array<{ field: string; op?: string; value: unknown }>,
		limit = 100,
	): Promise<Array<{ id: string; data: Record<string, unknown> }>> {
		const filters = where.map((w) => ({
			fieldFilter: {
				field: { fieldPath: w.field },
				op: w.op ?? 'EQUAL',
				value: toValue(w.value),
			},
		}));

		const response = await fetch(`${this.root}:runQuery`, {
			method: 'POST',
			headers: this.headers(),
			body: JSON.stringify({
				structuredQuery: {
					from: [{ collectionId: collection }],
					where: filters.length === 1 ? filters[0] : { compositeFilter: { op: 'AND', filters } },
					limit,
				},
			}),
		});

		if (!response.ok) {
			throw new Error(`Firestore query failed (${response.status}): ${await response.text()}`);
		}

		const rows = (await response.json()) as Array<{ document?: FirestoreDocument }>;
		return rows
			.filter((row) => row.document)
			.map((row) => ({
				id: docId(row.document!.name),
				data: fromFields(row.document!.fields),
			}));
	}

	/** Deletes many documents in one request. */
	async deleteAll(targets: Array<{ collection: string; id: string }>): Promise<void> {
		if (targets.length === 0) return;

		for (let i = 0; i < targets.length; i += 400) {
			const chunk = targets.slice(i, i + 400);
			const response = await fetch(`${BASE}/projects/${this.projectId}/databases/(default)/documents:commit`, {
				method: 'POST',
				headers: this.headers(),
				body: JSON.stringify({
					writes: chunk.map((t) => ({
						delete: `projects/${this.projectId}/databases/(default)/documents/${t.collection}/${t.id}`,
					})),
				}),
			});
			if (!response.ok) {
				throw new Error(`Firestore delete failed (${response.status}): ${await response.text()}`);
			}
		}
	}

	/**
	 * Applies many writes as one request. Each write merges the fields given,
	 * leaving the rest of the document untouched.
	 */
	async commit(writes: Array<{ collection: string; id: string; data: Record<string, unknown> }>): Promise<void> {
		if (writes.length === 0) return;

		const response = await fetch(`${BASE}/projects/${this.projectId}/databases/(default)/documents:commit`, {
			method: 'POST',
			headers: this.headers(),
			body: JSON.stringify({
				writes: writes.map((w) => ({
					update: {
						name: `projects/${this.projectId}/databases/(default)/documents/${w.collection}/${w.id}`,
						fields: toFields(w.data),
					},
					updateMask: { fieldPaths: Object.keys(w.data) },
				})),
			}),
		});

		if (!response.ok) {
			throw new Error(`Firestore commit failed (${response.status}): ${await response.text()}`);
		}
	}
}
