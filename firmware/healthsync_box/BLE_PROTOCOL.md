# HealthSync box ↔ phone: Bluetooth protocol (DRAFT)

> **Status:** draft by the box side (Christian), Oct 24, 2026, implemented in
> firmware 0.3.0 (Phase 3). **For Miko to confirm or change** (DEV-27, open
> questions M1–M4 and C1, C4 in `BLE_CONNECT_ON_DEMAND.md`). Nothing here is
> final until both sides agree. **No security yet** (Phase 4, question C3).

## 1. Connection

| Item | Value |
|---|---|
| Role | Box = peripheral (NimBLE-Arduino 2.5.1). Phone = central (flutter_blue_plus) |
| Advertised name | `HealthSync-0001` = `"HealthSync-"` + the box serial without `HS-` |
| Service UUID | `908a611a-cdae-4717-843a-8929f91d551b` (in the advertisement; the name is in the scan response) |
| **command** characteristic | `a8672cae-3524-49a5-9a57-696fd57e7b72` · phone → box · write (with or without response), up to 512 bytes |
| **reply** characteristic | `c7b37ff8-2e2b-4156-8130-34df10d433e5` · box → phone · notify |
| Packet size | The phone must request **MTU 247** after connecting. Every reply fits in one notification at MTU 247; at the default 23 the box cannot reply |
| Idle | The box disconnects a phone that sends nothing for **60 s**, then advertises again |

Every message is **one JSON object** with an `"op"` field, UTF-8, one per
write or notification. The box answers every command with exactly one reply,
except `events` (several `event` replies, then `events_end`).

## 2. Messages

| Phone sends | Box replies |
|---|---|
| `{"op":"hello"}` | `{"op":"hello","serial":"HS-0001","fw":"0.3.0","utc":1761300000,"clock_ok":true,"sched_ver":"2026-10-24T09:41:00Z","count":3,"last_seq":6,"acked":2,"pending":4,"sd":true}` |
| `{"op":"set_time","utc":1761300000}` | `{"op":"ok"}` · UTC seconds since 1970 |
| `{"op":"sched_begin","ver":"<text>","count":3}` | `{"op":"ok"}` · `ver` up to 31 characters (e.g. the newest `schedules.updated_at`); `count` 0–24 |
| `{"op":"sched_item","sid":"sc_K3pT8mQa","comp":3,"time":"08:00","days":[1,2,3,4,5,6,7]}` | `{"op":"ok"}` · one per dose time; `sid` = `schedules` document id (up to 24 characters); `comp` 1–6; `time` 24-hour `HH:MM`; `days` like `days_of_week` (1 = Monday … 7 = Sunday; empty or missing = every day) |
| `{"op":"sched_commit"}` | `{"op":"ok","count":3}` · the stored schedule is replaced in one step |
| `{"op":"events","after":2,"max":20}` | `{"op":"event","e":{…}}` × n, then `{"op":"events_end","sent":n,"last":6}` · `after` defaults to the last acked seq; `max` ≤ 20 |
| `{"op":"ack","seq":6}` | `{"op":"ok","pending":0}` · the phone stored every event up to `seq` |
| `{"op":"app_done","sid":"sc_K3pT8mQa","date":"2026-10-24","time":"08:00"}` | `{"op":"ok"}` · the dose was taken or skipped in the app: the box stops that alarm and does **not** log it |
| anything invalid | `{"op":"error","msg":"…"}` |

### An event

```json
{"seq":7,"type":"taken","comp":3,"date":"2026-10-24","time":"08:00","at":"2026-10-24T00:04:31Z","timing":"on_time","sid":"sc_K3pT8mQa"}
```

| Field | Meaning |
|---|---|
| `seq` | Increases by 1 per event and never repeats (kept in flash). Collect with `events`, store, then `ack` |
| `type` | `taken` (button) or `missed` (no press within 60 min) |
| `comp` | Compartment 1–6 |
| `date`, `time` | The dose's Manila date and time. **`{sid}_{date}_{time}` = the app's dose_log id** (`DoseLogModel.idFor`), so writing the event under that id can never create a duplicate |
| `at` | When it was pressed, or marked missed (UTC, ISO 8601) |
| `timing` | `on_time` (0–29 min), `late` (30–59 min), `early` (up to 30 min before, nearest dose time only); empty for missed |
| `sid` | Empty for dose times added from the bench console |

Suggested mapping to Firestore (Miko to decide, M3): `taken` → `status:
"taken"`, `confirmed_via: "button"`, `taken_at: at`, `timing`; `missed` →
`status: "missed"` unless the app already has a final status.

## 3. A full sync

```
connect → request MTU 247 → subscribe to reply
hello                          (see clock_ok, sched_ver, pending)
set_time {utc}                 (every sync: the phone's clock is the reference)
if sched_ver differs from the app's:
    sched_begin {ver, count} → sched_item × count → sched_commit
events {after: acked}          → event × n → events_end
    store each event in Firestore under {sid}_{date}_{time}
ack {seq: last stored}
app_done for doses handled in the app that are still due (optional)
disconnect
```

## 4. Box rules the app can rely on

- **Times:** the box keeps UTC on its DS3231 clock and compares dose times in
  Manila time (UTC+8), like the Worker.
- **Alarm:** from the dose time until +60 min the compartment LED is on and
  the buzzer gives 5 beeps a minute. A button press (held 0.3–10 s, then let
  go) takes every lit dose. With nothing lit, a press takes the nearest dose
  time within the next 30 min early. After +60 min the dose is `missed`.
- **Re-sending the same schedule** keeps doses that are due right now lit
  (unchanged dose times keep their "added" time). A dose time added after its
  time today starts tomorrow.
- **Only dose times with a compartment 1–6** should be sent; liquids, inhalers
  and compartments 7–8 stay phone-only.
- **No phone, no problem:** the box alarms and logs on its own (SD card, or
  flash without a card) and hands the events over at the next sync.

## 5. Not decided yet

- Security (C3): passkey bonding or an app-level secret. Until then any phone
  in range can connect.
- When the app connects (M2) and which schedule wins offline (M4): the box
  simply takes whatever the last `sched_commit` sent.
- Power saving (C2) may lengthen the advertising interval; the app should allow
  a few seconds to find the box.
