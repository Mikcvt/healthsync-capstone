/**
 * SWITCHED OFF (Oct 22, 2026): none of these handlers is routed in index.ts.
 * The box now talks to the patient's phone over Bluetooth
 * (BLE_CONNECT_ON_DEMAND.md: "device endpoints are not planned"). Kept for now;
 * delete this file if the Bluetooth design never needs it.
 *
 * Device endpoints — used only by the ESP32 Smart Medicine Box. The app never
 * calls them.
 *
 * Authentication: for now the serial in the path is trusted alone. The Worker
 * looks up the active devices doc with that serial and the patient it is
 * paired to. A device key comes in Phase 5 (FIRMWARE_ARCHITECTURE.md).
 *
 * GET  /device/:serial/state    → { server_time, lit, buzz }   (Phase 1, routed)
 * GET  /device/:serial/schedule → offline cache                (Phase 4, NOT routed yet)
 * POST /device/:serial/dose     → button confirms a dose       (Phase 2, NOT routed yet)
 */

import type { Env } from '../index';
import { getAccessToken, parseServiceAccount } from '../lib/google-auth';
import { Firestore } from '../lib/firestore';
import { error, json } from '../lib/http';

// ─── shared auth helper ───────────────────────────────────────────────────────

interface ResolvedDevice {
	deviceId: string;
	patientRef: string;
	status: unknown;
	lastSync: unknown;
}

async function resolveDevice(serial: string, db: Firestore): Promise<ResolvedDevice | null> {
	const rows = await db.query('devices', [
		// The app saves serials in upper case.
		{ field: 'serial_number', value: serial.trim().toUpperCase() },
		{ field: 'is_active', value: true },
	], 1);
	if (rows.length === 0) return null;
	const d = rows[0].data;
	const patientRef = typeof d.patient_ref === 'string' ? d.patient_ref : '';
	if (!patientRef) return null;
	return { deviceId: rows[0].id, patientRef, status: d.status, lastSync: d.last_sync };
}

// ─── GET /device/:serial/state ───────────────────────────────────────────────

const MINUTE_MS = 60_000;

/**
 * A dose lights its compartment from its scheduled time until it is this old:
 * the "Due now" and "Late" windows of lib/utils/dose_timing.dart. At 60 min the
 * sweep marks it missed anyway.
 */
const LIT_WINDOW_MINUTES = 60;

/** The box polls every 60 s; writing the heartbeat at most this often caps it at 288 writes a day. */
const HEARTBEAT_EVERY_MINUTES = 5;

/**
 * Which compartments should light right now. The ESP32 polls this every 60 s.
 *
 * Response: { server_time, lit, buzz }
 *   lit  — compartments (1–8, sorted) with a pending or snoozed dose that came
 *          due in the last 60 minutes. Taken, skipped, missed and cancelled
 *          doses drop out, so a Done in the app turns the LED off on the next poll.
 *   buzz — false while every lit dose is snoozed in the app and its snooze has
 *          not ended, so the box stays quiet through a snooze.
 *
 * Worked out from dose_logs (which the materializer creates), not from
 * schedules.led_active: nothing in the app or the Worker ever sets that true.
 */
export async function handleDeviceState(serial: string, env: Env): Promise<Response> {
	const sa = parseServiceAccount(env.FIREBASE_SA_KEY);
	const accessToken = await getAccessToken(sa, env.TOKEN_CACHE);
	const db = new Firestore(sa.project_id, accessToken);

	const device = await resolveDevice(serial, db);
	if (!device) return error('Device not found.', 404, 'device_not_found');

	const now = new Date();

	// Uses the sweep's status + scheduled_at index, so no new index is needed.
	// It spans every patient, so the patient is filtered below; a 60-minute
	// window keeps that to a handful of rows.
	const due = await db.query('dose_logs', [
		{ field: 'status', op: 'IN', value: ['pending', 'snoozed'] },
		{ field: 'scheduled_at', op: 'GREATER_THAN', value: new Date(now.getTime() - LIT_WINDOW_MINUTES * MINUTE_MS) },
		{ field: 'scheduled_at', op: 'LESS_THAN_OR_EQUAL', value: now },
	], 200);

	const lit = new Set<number>();
	let buzz = false;
	const columnBySchedule = new Map<string, number | null>();

	for (const dose of due) {
		if (dose.data.patient_ref !== device.patientRef || dose.data.is_active === false) continue;
		const scheduleId = typeof dose.data.schedule_ref === 'string' ? dose.data.schedule_ref : '';
		if (!scheduleId) continue;

		if (!columnBySchedule.has(scheduleId)) {
			columnBySchedule.set(scheduleId, boxColumn(await db.get('schedules', scheduleId)));
		}
		const column = columnBySchedule.get(scheduleId);
		if (column == null) continue; // not in the box (liquid, inhaler, no compartment)

		lit.add(column);
		if (!isSnoozing(dose.data, now)) buzz = true;
	}

	// Heartbeat: status + last_sync are what the app shows as "Online" / last
	// seen. Only these two fields are written; the rest of the doc is untouched.
	const lastSync = device.lastSync instanceof Date ? device.lastSync.getTime() : 0;
	if (device.status !== 'online' || now.getTime() - lastSync >= HEARTBEAT_EVERY_MINUTES * MINUTE_MS) {
		await db.set('devices', device.deviceId, { status: 'online', last_sync: now });
	}

	return json({
		server_time: now.toISOString(),
		lit: [...lit].sort((a, b) => a - b),
		buzz,
	});
}

/** The schedule's compartment, or null when it has none or is no longer active. */
function boxColumn(schedule: Record<string, unknown> | null): number | null {
	if (!schedule || schedule.is_active !== true) return null;
	const column = schedule.mat_box_column;
	return typeof column === 'number' && Number.isInteger(column) && column >= 1 && column <= 8 ? column : null;
}

function isSnoozing(dose: Record<string, unknown>, now: Date): boolean {
	return dose.status === 'snoozed'
		&& dose.snoozed_until instanceof Date
		&& dose.snoozed_until.getTime() > now.getTime();
}

// ─── GET /device/:serial/schedule ────────────────────────────────────────────

/**
 * Returns today's full schedule so the box can show upcoming doses even when
 * led_active is not yet true (e.g. before the dose window opens).
 *
 * Response: { date: string, slots: [{ compartment, times: string[] }] }
 */
export async function handleDeviceSchedule(serial: string, env: Env): Promise<Response> {
	const sa = parseServiceAccount(env.FIREBASE_SA_KEY);
	const accessToken = await getAccessToken(sa, env.TOKEN_CACHE);
	const db = new Firestore(sa.project_id, accessToken);

	const device = await resolveDevice(serial, db);
	if (!device) return error('Device not found.', 404, 'device_not_found');

	const schedules = await db.query('schedules', [
		{ field: 'patient_ref', value: device.patientRef },
		{ field: 'is_active', value: true },
	], 50);

	// Group dose times by compartment column.
	const byColumn: Record<number, string[]> = {};
	for (const s of schedules) {
		const col = s.data.mat_box_column;
		if (typeof col !== 'number' || col < 1 || col > 8) continue;
		const times = s.data.dose_times;
		if (!Array.isArray(times)) continue;
		byColumn[col] = (byColumn[col] ?? []).concat(times.map(String));
	}

	const slots = Object.entries(byColumn).map(([col, times]) => ({
		compartment: Number(col),
		times: times.sort(),
	}));

	const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
	return json({ date: today, slots });
}

// ─── POST /device/:serial/dose ───────────────────────────────────────────────

/**
 * The physical button was pressed. Body: { compartment: number }
 *
 * Turns off the LED for that compartment and marks the matching pending dose
 * log as taken (confirmed_via: "button"). Whoever acts first wins — if the
 * app already marked it taken, the LED is already off and this is a no-op.
 *
 * Response: { ok: true, compartment: number }
 */
export async function handleDeviceDose(
	serial: string,
	request: Request,
	env: Env,
): Promise<Response> {
	let body: { compartment?: unknown };
	try {
		body = (await request.json()) as { compartment?: unknown };
	} catch {
		return error('Invalid request body.', 400, 'bad_request');
	}

	const compartment = typeof body.compartment === 'number' ? body.compartment : null;
	if (!compartment || compartment < 1 || compartment > 8) {
		return error('compartment must be 1–8.', 400, 'bad_request');
	}

	const sa = parseServiceAccount(env.FIREBASE_SA_KEY);
	const accessToken = await getAccessToken(sa, env.TOKEN_CACHE);
	const db = new Firestore(sa.project_id, accessToken);

	const device = await resolveDevice(serial, db);
	if (!device) return error('Device not found.', 404, 'device_not_found');

	// Find the active schedule for this compartment.
	const schedules = await db.query('schedules', [
		{ field: 'patient_ref', value: device.patientRef },
		{ field: 'mat_box_column', value: compartment },
		{ field: 'is_active', value: true },
	], 1);

	if (schedules.length === 0) {
		return error('No active schedule for that compartment.', 404, 'no_schedule');
	}

	const scheduleId = schedules[0].id;

	// Turn off the LED immediately.
	await db.set('schedules', scheduleId, { led_active: false });

	// Find the pending dose log for today and mark it taken.
	const today = new Date().toISOString().slice(0, 10);
	const doseLogs = await db.query('dose_logs', [
		{ field: 'patient_ref', value: device.patientRef },
		{ field: 'schedule_ref', value: scheduleId },
		{ field: 'scheduled_date', value: today },
		{ field: 'status', value: 'pending' },
	], 1);

	if (doseLogs.length > 0) {
		await db.set('dose_logs', doseLogs[0].id, {
			status: 'taken',
			taken_at: new Date(),
			confirmed_via: 'button',
		});
	}

	return json({ ok: true, compartment });
}
