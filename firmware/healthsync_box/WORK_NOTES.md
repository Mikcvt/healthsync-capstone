# HealthSync Box — Work Notes

> Running summary of what the team decided and what comes next.
> Started October 19, 2026. Update it at the end of every work session.
> **This is the one file to read first.** The three architecture docs
> (`FIRMWARE_ARCHITECTURE.md`, `HARDWARE_ASSESSMENT.md`, root
> `HARDWARE_ARCHITECTURE.md`) hold the design; this file holds where we are.

> **Oct 22, 2026: the transport changed.** The box now talks to the patient's
> phone over **BLE, connect-on-demand**: no Wi-Fi, no hotspot, no direct
> box-to-cloud link, no device secret. Read
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md) first. The
> design details there are pending confirmation by Miko and Christian.
> Sections 0, 2, 4, 6, 7, 8, 9, 10 and 11 below describe the Wi-Fi/Worker
> link and are marked **SUPERSEDED**; they are kept for the record. The
> decision is logged in §5.

---

## ★ Start here — status at the end of October 25, 2026

**Design:** the box talks to the patient's phone over **Bluetooth,
connect-on-demand** (`BLE_CONNECT_ON_DEMAND.md`). The box has no Wi-Fi and
never talks to the cloud; the phone relays to Firebase.

| Phase (plan: §12) | Status |
|---|---|
| 0 Cleanup | ✅ Oct 22: Wi-Fi code removed from the firmware (kept in git history, commit 286c33b); Worker `/state` switched off (`index.ts` = `release`) |
| 1 Offline alarm from a stored schedule | ✅ Passed on the bench Oct 23 (§13) |
| 2 Dose log on the SD card | ✅ Passed Oct 24, including the no-card fallback (§14) |
| 3 Bluetooth server | ✅ Passed Oct 24 with nRF Connect, firmware 0.3.0 (§15). T5 (re-send while lit) checked by Christian on the bench, Oct 25 |
| 4 Security | ✅ Passed Oct 25 (fw 0.4.0): passkey pairing (code on the label), hold 5 s → pairing mode, running light (§17). Then fw 0.4.1: one straight tone per event, alarm every 5 min, no early take (§17.9) |
| 5 With Miko's app + battery | Next: box-only part (power saving, status signals, current measurement). The app part waits for Miko's Bluetooth work (7.1.x) |
| 6 Final box | Waits for the print (HW-19) |
| 7 Hardware papers | Later (HW-07, HW-21, HW-12, DEF-03) |

**Hardware facts (all verified on the bench):** pins in §3. The button is a
6 mm **normally-closed** panel button: pressed = HIGH (`BUTTON_PRESSED_LEVEL`).
SD card MOSI 19 / MISO 23 are swapped vs the ESP32 default and work. DS3231 on
3V3 with a CR2032 (safe on 3V3). The buzzer was in backwards on Oct 22 and was
fixed by turning it round.

**For Miko:** `firmware/healthsync_box/BLE_PROTOCOL.md` is the draft protocol
(UUIDs, messages, sync order, how a box event maps to the app's dose id,
section 5 security: passkey pairing), implemented in firmware 0.4.1. Christian tells Miko to pull this branch.

**Next session, in order:**
1. Quick bench check of firmware 0.4.1 (§17.9): the new tones, no early take.
2. Phase 5, box-only part (no need to wait for Miko): power saving (battery
   life, now about one day), status signals without a laptop, measure the real
   current. The app part of Phase 5 waits for Miko's Bluetooth work.
3. Still to confirm on the bench (HARDWARE_ARCHITECTURE.md 4.7): buzzer 5 V or
   3.3 V type; microSD module type and which pin feeds it.

**Pairing code:** box HS-0001's 6-digit code is in `secrets.h` (`BLE_PASSKEY`, git-ignored) and goes on the label; it is not written in the repo.

**On this PC:** Arduino IDE with ESP32 core 3.3.12, NimBLE-Arduino 2.5.1,
ArduinoJson 7.4.3, RTClib; Worker packages installed (`npm ci`). Christian's
phone has nRF Connect. The Firebase key is in `healthsync-api/.dev.vars`
(git-ignored); the box does not use it.

**Git:** work up to Oct 25 is pushed to `feature/medbox-integration` (end of Oct 25).
`main` and `release` are untouched. Before each session, check GitHub for
teammates' pushes and show what changed before merging.

The sections below are history, kept for the record.

---

## History: Oct 22 notes (Wi-Fi → Bluetooth switch)

The team tracker (read Oct 22) says that on **Oct 21 the box switched from
Wi-Fi to Bluetooth (BLE)**: the box talks to the phone, and the phone relays
to Firestore (tasks HW-08, HW-09, HW-10, DEV-27). If that is final:
- Phase 1 as built (box asks the Worker over Wi-Fi) and Phase 3 (Wi-Fi setup
  hotspot) are **shelved**; they stay in git history (commit 286c33b).
- The Firebase key (section 9) is no longer needed for the box.
- Next firmware work: a Bluetooth server per Miko's spec (DEV-27), with LEDs,
  buzzer, button, RTC and SD carried over.

The tracker also lists the button as a **6 mm NC (normally closed) panel
button**, which explains the Oct 20 "held when untouched, up when pressed"
symptom: the firmware may need pressed = HIGH instead of a rewire.

Full task-by-task review: `docs/archive/TRACKER_REVIEW_2026-10-22.md`.

**Confirmed by Christian, Oct 22:** Bluetooth is final, and the button on the
board is the **6 mm NC panel button**. So: no rewire; the firmware reads
pressed = HIGH (HW-26, **done Oct 22**: `BUTTON_PRESSED_LEVEL HIGH` in
`config.h`, used by `button.cpp` and `hw_test`; compiles; retest pending).

**Oct 22: back to Phase 1 (option A, Christian).** Bluetooth waits for Miko's
spec, so the Wi-Fi Phase 1 is tested now as a backup demo and to prove the
LED/buzzer logic. Christian has Firebase access and makes the key himself
(section 9). Steps: section 7.4.

**Oct 22 note:** the PC was on `192.168.43.164` (looks like a phone hotspot),
not the home Wi-Fi the box uses, and `config.h` points to `192.168.1.11`. The PC
and the box must be on the **same** Wi-Fi, and `config.h` must have the PC's
current IP. The Wi-Fi work is shelved, and
the Bluetooth firmware waits for Miko's spec (DEV-27).

---

## 0. History: status at the end of October 20, 2026

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). The Wi-Fi,
> Worker (`/state`), Firebase-key and setup-hotspot items and the "next
> steps" in this section belong to the old link. The bench results for the
> LEDs, buzzer, SD card and DS3231 still stand. Kept for the record.

| Item | Status |
|---|---|
| **Bluetooth phases** | Phase 0 cleanup ✅ (Oct 22); **Phase 1 offline alarm ✅ passed (Oct 23)**; **Phase 2 dose log ✅ complete (Oct 24)**; **Phase 3 Bluetooth written, compiles; nRF Connect test: §15.7**; protocol for Miko: `BLE_PROTOCOL.md` |
| Old Phase 1 firmware (LED + buzzer sync, Wi-Fi) | ✅ Written, compiles. ⏳ Not yet tested against real Firebase data |
| Phase 1 Worker change (`/state`) | ✅ Written, typecheck clean. Runs locally only (`wrangler dev`), **not deployed** |
| Box Wi-Fi | ✅ Works on the bench |
| ✅ **Button** | It is a 6 mm **NC** button, so it read inverted. Fixed in firmware Oct 22 (`BUTTON_PRESSED_LEVEL HIGH`, HW-26); **retest pending**. No rewire needed. Stuck-button safeguard added so this cannot keep opening setup |
| SD card (swapped MOSI/MISO) | ✅ Passed on the bench Oct 20 |
| DS3231 clock | ✅ Passed on the bench Oct 20 (found 0x68 + 0x57; kept time while unplugged) |
| Firebase key | ✅ Oct 22: Christian generated it; put into `healthsync-api/.dev.vars` (git-ignored) and **verified**: a local Worker answered `device_not_found` for a fake serial, so it reaches Firestore. Delete the downloaded `.json` |
| LEDs + buzzer + button check | ✅ Passed on the bench Oct 20 (`hw_test/`) |
| Wi-Fi setup (Phase 3) | ✅ Approved and written Oct 20, compiles (87% flash). Hold-to-open works; the crash after **Save** is fixed but **not retested yet**. ⏳ Rest of the bench test: **section 11.5** |
| Setup hotspot password | 🔑 **`medbox7349`** (in `secrets.h`; print it on the box label) |
| Git | Work of Oct 19–20 committed and pushed to `feature/medbox-integration` (Oct 20, end of day). Not merged anywhere; `main` and `release` untouched |

**Next steps, in order (from Oct 21):**
1. ~~Rewire the button~~ (not needed: NC button, fixed in firmware Oct 22). Do the 1-minute
   no-touch test.
2. Upload `healthsync_box.ino` (crash fix + safeguard), then finish the Phase 3
   test: hold to open/close setup, Save a Wi-Fi (two beeps, no crash),
   unplug/replug, router off 2 min, router off 6 min (11.5).
3. Firebase key (teammate, section 9) → Phase 1 pass check (7.4, 7.5).
4. Phase 2 (button confirms the dose).

**Note:** the board runs an older upload of the main firmware (from before
the stuck-button safeguard). Re-upload it before testing.

---

## 1. Ground rules

1. **Ask first, every time.** Nothing is edited, committed or deployed
   without the team's OK.
2. **Branch:** `feature/medbox-integration`. Never work on `main` or
   `release`. (Checked Oct 19: this branch = `release` + 1 commit, the
   firmware docs. There is no local `release` branch, so it cannot be edited
   by accident.)
3. **Scope:** `firmware/healthsync_box/`. Files outside it only when the box
   cannot work without them, and **never anything that may affect the app**.
   The app is final.
4. **One phase at a time**, most important first. A phase is done only when
   its pass check works on the real box.

---

## 2. How the system works

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). "The box does
> not connect to the phone" and "the box needs its own Wi-Fi" no longer hold:
> the box now syncs with the patient's phone over BLE, on demand. The line
> below, "Bluetooth setup from the app was rejected: it needs app changes",
> is reversed by the Oct 22 decision. Kept for the record.

- The **care partner** sets each medicine, its dose times and its
  compartment in the app. The app already does reminders, notifications and
  alarms on the phone.
- At dose time the **box** lights that compartment's LED and sounds the
  buzzer.
- The **button** silences the box (Phase 1) and later confirms the dose
  (Phase 2).

**The box does not connect to the phone.** The box and the phone each talk
to the cloud on their own:

```
Box ──own Wi-Fi──► Cloudflare Worker ──► Firestore ◄── App (phone)
```

- "Connecting the box to the app" = typing the box's serial (for example
  `HS-0001`) on the app's Smart box screen. That already works in the app. The
  Worker then knows whose schedule belongs to that box.
- The box needs its **own Wi-Fi**. It does not use the phone's internet.

### How the box gets Wi-Fi

| When | How |
|---|---|
| Before Oct 20 | Wi-Fi name and password typed into `secrets.h` (removed since) |
| Since Phase 3 (Oct 20) | **Setup hotspot (WiFiManager):** see sections 10 and 11. The Wi-Fi is chosen on the box's setup page and saved in the ESP32's flash |

- A phone's **mobile hotspot** can be the chosen network, but then the box
  works only while that hotspot is on.
- ESP32 = **2.4 GHz Wi-Fi only**.
- Bluetooth setup from the app was rejected: it needs app changes.

---

## 3. Hardware (confirmed wiring)

| Part | GPIO | Notes |
|---|---|---|
| LED compartment 1–6 | 13, 14, 25, 26, 32, 33 | 6 compartments only |
| Buzzer | 17 | Through the NPN transistor, HIGH = sound |
| Button | 16 | 6 mm **NC** panel button wired to **GND**, `INPUT_PULLUP`: idle LOW, **pressed HIGH** (`BUTTON_PRESSED_LEVEL HIGH`). No 10 kΩ resistor |
| SD SCK | 18 | |
| SD MOSI | **19** | ⚠️ **Swapped** vs. the ESP32 default (default MOSI is 23) |
| SD MISO | **23** | ⚠️ **Swapped** vs. the ESP32 default (default MISO is 19) |
| SD CS | 15 | |
| DS3231 SDA / SCL | 21 / 22 | |

- **Remember the MOSI/MISO swap.** Firmware uses
  `SPI.begin(18, /*MISO*/ 23, /*MOSI*/ 19, 15)`. If the SD card will not
  start, swap these two first.
- Board must be **ESP32-WROOM** (GPIO 16/17 are not free on a WROVER).
- The app offers compartments 1–8. We only build 6; the firmware ignores 7–8.

---

## 4. Phases

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). These phases
> assume Wi-Fi polling of the Worker, a Wi-Fi setup hotspot and a device key.
> The new firmware tasks are in docs/archive/ACTION_PLAN.md Step 7. Kept for the record.

| Phase | Goal | Status |
|---|---|---|
| **1** | LED + buzzer sync with the Worker and Firestore. Button silences the box only (temporary) | 🔧 Approved and written Oct 19; firmware compiles (ESP32 core 3.3.12, 78% flash). **Testing on the bench (7.4)** |
| **2** | Button confirms the dose (`confirmed_via: "button"`, care partner push) | Later |
| 3 | Wi-Fi setup hotspot | Later |
| 4 | Offline: DS3231 + SD card (schedule cache, queued presses) | Later |
| 5 | Device key (`X-Device-Key`) | Later |

---

## 5. Decisions so far

| # | Decision | Answer |
|---|---|---|
| 1 | Branch | Keep `feature/medbox-integration` |
| 2 | Compartments | 6 (ignore 7–8 in the app) |
| 3 | Button wiring | GPIO 16 → GND, internal pull-up |
| 4 | SD wiring | SCK 18, CS 15, MOSI 19, MISO 23 (swapped) |
| 5 | Wi-Fi setup | Setup hotspot (Phase 3), built Oct 20 with the proposals in 10.5 |
| 6 | Buzzer | **5 short beeps every minute** while a dose is due. **No quiet hours** |
| 7 | Editing outside `firmware/` | Only if needed, never anything that affects the app |
| 8 | Test Wi-Fi password in `config.example.h` and the two Wi-Fi test sketches | ✅ Solved Oct 20: `config.example.h` has placeholders only; `wifi_connect_test/` and `wifi_scan_test/` deleted (Christian's OK). The password was never committed |
| 9 | LED source | `lit` worked out from `dose_logs` by the Worker (nothing in the app sets `led_active` to true, so it cannot be used) |
| #__ *(number to be assigned)* | **BLE connect-on-demand replaces the Wi-Fi/Worker device link** (Oct 22, 2026) | The medbox talks to the patient's phone over BLE, connect-on-demand: the app connects, syncs and disconnects. No Wi-Fi, no hotspot, no direct box-to-cloud link, no device secret. The box stays optional (DEC-8); the app works fully with no box. Design details pending confirmation by Miko and Christian: [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md) |

Decisions 5 (Wi-Fi setup hotspot) and 9 (LED source from the Worker) are
**SUPERSEDED by the Oct 22, 2026 BLE decision.** See
[BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md).

---

## 6. Worker URL

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). The box no
> longer calls the Worker, so it needs no Worker URL. The warning about
> deploying the shared Worker still applies to anyone deploying it. Kept for
> the record.

| What | URL |
|---|---|
| Production Worker (used by the app) | `https://healthsync-api.healthsync12.workers.dev` (the default in `lib/services/api_service.dart`). `/health` answered `ok` on Oct 19 |
| Current `config.h` | `https://meets-pump-put-caribbean.trycloudflare.com`: a temporary tunnel to a Worker running on someone's PC. It changes every time the tunnel restarts |

⚠️ **The production Worker is shared with the app.** Deploying it from this
branch replaces the code the app is using right now. We do not know whether
the live Worker matches `release` exactly. **Ask the lead software developer
before any `wrangler deploy`.**

---

## 7. Phase 1 plan (approved Oct 19, code written)

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). Phase 1 polls
> `GET /device/{serial}/state` over Wi-Fi; the box no longer talks to the
> Worker. Kept for the record.

### 7.1 What Phase 1 does

1. Boot: self-test (LEDs 1→6, 150 ms each, one chirp), connect to Wi-Fi
2. Every 60 s: `GET /device/{serial}/state` → `{ "lit": [3], "buzz": true }`
3. LEDs on for the compartments in `lit`, all others off
4. Buzzer: 5 short beeps when an LED lights, then every 60 s
5. Button: LEDs and buzzer off at once, on the box only. Those compartments
   stay off until their dose is no longer due. Nothing is sent to the Worker;
   the dose is still confirmed in the app
6. LED turns off by itself when the dose is taken or skipped in the app
   (≤60 s), or missed at +60 min

### 7.2 Firmware changes (`firmware/healthsync_box/`)

| File | Change |
|---|---|
| `config.h` | Worker URL; `LED_COUNT 6`; buzzer pattern (5 beeps, about 200 ms on / 150 ms off, repeat every 60 s); SD pin constants for Phase 4 with the swap comment. Pins stay as they are |
| `leds.cpp/h` | **Bug fix:** the pin array is `[8]` with 6 entries, so the last two are 0 and the code drives **GPIO 0** (a boot pin). Make it 6. Add `leds_self_test()` 1→6 |
| `buzzer.cpp/h` | Non-blocking 5-beep pattern (`buzzer_start/stop/update`, uses `millis()`, no `delay()`), so the button and polling keep working while it beeps |
| `button.cpp/h` | Keep `INPUT_PULLUP` + 50 ms debounce; return "pressed" once per press (no compartment number) |
| `net.cpp/h` | HTTPS to the Worker; reconnect Wi-Fi if it drops; read `lit` (was `compartments`) and `buzz`; ignore numbers outside 1–6; 8 s timeout. Remove `net_post_dose()` (comes back properly in Phase 2) |
| `healthsync_box.ino` | Poll every 60 s; "silenced" memory for the button; drive LEDs + buzzer |
| `secrets.h` | No change |

### 7.3 Worker change (outside `firmware/`, needed for Phase 1)

| File | Change | Affects the app? |
|---|---|---|
| `healthsync-api/src/handlers/device.ts` | Rewrite only `handleDeviceState`: find the box's patient by serial; query `dose_logs` with status `pending`/`snoozed` and `scheduled_at` in the last 60 min (uses the **existing** `status + scheduled_at` index, so no index deploy); look up each due dose's `mat_box_column`; return `lit` and `buzz`; update `devices.status = "online"` and `last_sync` at most every 5 min | No. The app never calls `/device/*`. The heartbeat only sets the two fields the app already shows ("Online", last seen). `columns_active` is no longer written |
| `healthsync-api/src/index.ts` | Route only `GET /device/{serial}/state` for now. `/schedule` and `/dose` stay unrouted until their phases | No. Only adds a path the app does not use |

Not touched: the app (`lib/`), `firestore.rules`, `firestore.indexes.json`,
the cron jobs, every other Worker endpoint.

Leave as they are until their phase: `handleDeviceSchedule` (Phase 4) and
`handleDeviceDose` (Phase 2). Today `/dose` marks a dose taken with no
timing, no pill count and no care partner push, so it must not be routed yet.

**Free-plan cost:** about 2 Firestore reads per poll when nothing is due,
~2,900 reads/day for one box (the limit is 50,000/day). Heartbeat ≤ 288
writes/day.

### 7.4 How we test without touching the live app (Christian runs it)

The Worker runs **on the PC** with `npx wrangler dev`: it uses the key already
in `healthsync-api/.dev.vars`, reads and writes the real Firestore, and does
**not** run the cron jobs. The production Worker and the app stay untouched;
the production cron keeps creating dose logs as usual. The box reaches the PC
over the same Wi-Fi (`http://<PC IP>:8787`), so no tunnel is needed.
(`cloudflared` is not installed on this PC; a tunnel is only needed if the box
and the PC are on different networks.)

Deploy to production only after Phase 1 passes, and only with the lead
software developer's OK.

**Step by step**

A. Arduino IDE (once)
1. File → Open → `firmware/healthsync_box/healthsync_box.ino`
2. Tools → Board → esp32 → **ESP32 Dev Module**
3. Library Manager: **ArduinoJson** must be version **7.x**
4. Plug in the ESP32 → Tools → Port → the new COM port (none? install the
   CP210x or CH340 USB driver)

B. `secrets.h`: `DEVICE_SERIAL` in capitals, e.g. `HS-0001`. The box's Wi-Fi
   (set in setup, 11.5) must be the **same router the PC uses**, 2.4 GHz.

C. App (care partner): pair the box with that exact serial on the Smart box
   screen, and put a tablet/capsule medicine in compartment **1–6**.

D. Worker on the PC (terminal in `healthsync-api/`)
1. ~~`npm ci`~~ done Oct 19 (wrangler 4.147.0; lockfile unchanged)
2. ~~`npx tsc --noEmit`~~ done Oct 19: clean
3. `npx wrangler dev --ip 0.0.0.0` → "Ready on http://0.0.0.0:8787". Allow the
   Windows firewall prompt for **Private networks**. Keep this window open
4. `ipconfig` → IPv4 Address of the Wi-Fi adapter, e.g. `192.168.1.23`
5. Browser on the PC: `http://localhost:8787/device/HS-0001/state` → expect
   `{"server_time":"…","lit":[],"buzz":false}`
6. `config.h`: `#define WORKER_BASE_URL "http://192.168.1.23:8787"` (your IP)

E. Upload (→). If it hangs on "Connecting…", hold the **BOOT** button on the
   ESP32 until it starts writing.

F. Serial Monitor, **115200** baud. Expect: self-test (LEDs 1→6 + chirp),
   `Wi-Fi connected, IP …`, then `Poll: lit=0x00 silenced=0x00 buzz=0` every
   60 s. The built-in blue LED is on while Wi-Fi is connected. Each poll also
   shows up in the `wrangler dev` window.

G. Run the pass check (7.5). Set test doses **10–15 min ahead** so the
   production cron has time to create the dose log.

**Troubleshooting**

| Serial Monitor says | Check |
|---|---|
| `Wi-Fi not connected yet (status 1)` | Wrong network name, or it is 5 GHz only |
| `… (status 4)` or `(status 6)` | Wrong password |
| `GET /state failed: -1 connection refused` | `wrangler dev` not running, not started with `--ip 0.0.0.0`, wrong PC IP, or firewall blocked it |
| `GET /state failed: 404 … device_not_found` | Serial in `secrets.h` ≠ serial paired in the app |
| `GET /state failed: 500` | Read the error in the `wrangler dev` window and send it |
| `lit=0x00` at dose time | Firestore → `dose_logs`: is there a `pending` log for that dose? Is the medicine's compartment 1–6 (not empty, not 7–8)? |
| Board resets when it beeps | Power: use a better USB cable/port or a 5 V 2 A adapter |

`lit` is a bitmask: `0x01` = compartment 1, `0x02` = 2, `0x04` = 3,
`0x08` = 4, `0x10` = 5, `0x20` = 6 (added together when several are due).

### 7.5 Phase 1 pass check

| # | Do | Expect |
|---|---|---|
| 1 | In the app, pair the box with the serial in `secrets.h` | `devices` doc exists |
| 2 | Add a medicine in compartment 1–6, dose time a few minutes ahead | Pending dose log appears (production cron) |
| 3 | Wait for the dose time | That LED lights and the buzzer gives 5 beeps within 60 s, repeating every minute |
| 4 | Press the button | LED + buzzer off at once and stay off |
| 5 | New dose, tap Done in the app | LED off within 60 s, no button |
| 6 | New dose, snooze in the app | LED stays on, buzzer quiet until the snooze ends |
| 7 | New dose, ignore it | LED off after the sweep marks it missed (~60–65 min) |
| 8 | Unplug the router for 2 min, plug it back | Box reconnects by itself and keeps polling |

---

## 8. Open items

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). The items about
> the Worker, the Firebase key, Wi-Fi passwords and the production deploy
> belong to the old link. The open questions for the BLE design are in
> BLE_CONNECT_ON_DEMAND.md §4. Kept for the record.

1. ~~Phase 1 approval~~ — approved Oct 19. Now: **bench test (7.4, 7.5)**.
2. **Before the first commit of Phase 1:** `config.example.h` holds a real
   Wi-Fi password and is tracked by git; `wifi_connect_test/` and
   `wifi_scan_test/` (untracked) hold one too. They must not be pushed.
3. ~~Who runs the test Worker~~ — Christian, on the PC, over the LAN (7.4).
4. **Production deploy:** ask the lead software developer when Phase 1 passes.
5. ~~`HARDWARE_ASSESSMENT.md` reverted on disk~~ — our version put back Oct 19.
6. **Not committed yet.** Commit Phase 1 only after the pass check, and only
   after item 2.
6b. **Blocker found Oct 19:** `healthsync-api/.dev.vars` holds only a
   placeholder (`paste_the_en…`), not the Firebase service account key, so
   `wrangler dev` cannot reach Firestore. Get the key for `healthsyncapp-b546b`
   from the lead software developer (or Firebase console → Project settings →
   Service accounts → Generate new private key). It goes only in `.dev.vars`
   (git-ignored), never in the repo or a group chat.
   Bench results so far: box joins Wi-Fi (IP 192.168.1.20), button works
   ("nothing to silence"); `GET /state` refused because no local Worker was
   running and `config.h` still had the old tunnel URL. PC IP: 192.168.1.11.
   Since then: `wrangler dev` runs and `/health` answers on
   `http://192.168.1.11:8787`; `config.h` now points there. **Waiting for the
   key from the group**, then re-upload and run 7.5.
7. **While waiting for the key (Oct 19):**
   - Fake-Worker test (Option A) postponed; the team wants to test on real
     Firebase data.
   - **B1 SD card check:** `sd_test/sd_test.ino` written and compiles (uses
     the ESP32 core's SD library, our swapped MOSI/MISO). Card: 16 GB, checked
     working on the PC. **PASSED on the bench Oct 20**: write + read-back
     matched at 4 MHz with SCK 18 / MISO 23 / MOSI 19 / CS 15, so the swapped
     wiring is correct as is.
   - Note: the board now runs `sd_test`, not the main firmware. Re-upload
     `healthsync_box.ino` before the next Phase 1 test.
   - B1 DS3231 check: `rtc_test/rtc_test.ino` written Oct 20 and compiles.
     Scans I2C (expects 0x68 + 0x57), sets the clock once per upload (build
     stamp kept in ESP32 flash), prints the time every second. Pass = finds
     0x68 and the time keeps running after 1 min unplugged. **PASSED Oct 20:**
     found 0x57 and 0x68; after unplugging, "Clock NOT set this boot" and the
     time ran on (00:21:03 → 00:22:53). Coin cell holds the time.
   - Hardware confirmed on the bench: button, Wi-Fi, SD card, DS3231.
     Not yet confirmed: the boot self-test (LEDs 1→6 in compartment order +
     one chirp) of the main firmware.
   - `hw_test/hw_test.ino` written Oct 20 and compiles: LEDs 1→6 slowly (800
     ms each, printed with GPIO), all 6 on, the 5-beep alarm, then every
     button press lights the next compartment + chirp. Warns if the button
     reads pressed when idle. **PASSED Oct 20**: all LEDs in the right
     compartments, buzzer, button ("everything is working properly").
   - **Coin cell is a CR2032** (not rechargeable). The ZS-042 board has a
     charging path (≈200 Ω resistor marked `201` + a small diode) meant for
     an LIR2032. With the DS3231 on **3.3 V** (our wiring) the cell sees only
     about 2.7 V after the diode, below its own 3 V, so it is practically not
     charged: safe as is. Only if the DS3231 is ever moved to 5 V/VIN: remove
     that resistor or use an LIR2032. **Confirmed Oct 20: DS3231 VCC is on
     the ESP32's 3V3 pin**, so the CR2032 is safe as is. Keep it on 3V3.
   - Why the SD output had no header lines: the Serial Monitor connects
     about a second after an upload, so the first lines were printed before
     it listened. PASS is only printed if every step worked. `rtc_test` waits
     2 s before printing for this reason.
   - Wi-Fi setup (Phase 3): discussed (section 10) and built (section 11).
8. **Later:** mark the box `offline` when it stops polling (needs the Worker's
   cron, Phase 3+), Phase 2 decision "one press = all lit compartments?".

---

## 9. For the Firebase teammate: putting the key in

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). The key in
> `.dev.vars` was needed so a local Worker could answer the box's `/state`
> polls. The box no longer calls the Worker. The rule that the key never goes
> in the repo, a commit, a screenshot or the group chat still applies. Kept
> for the record.

**Why:** the box asks the Worker which LEDs to light, and the Worker reads
Firestore with the **Firebase service account key**. For testing we run the
Worker on a PC (`wrangler dev`), not the live one, so the app is never
affected. That PC needs the key in `healthsync-api/.dev.vars`, which today
holds only placeholder text.

⚠️ The key is **full admin access to the whole Firebase project**. Never put
it in the repo, a commit, a screenshot or the group chat. `.dev.vars` is
git-ignored (`.gitignore` line 163), so it is safe there.

### 9.1 Get the key

1. Firebase console → project **healthsyncapp-b546b** → ⚙ **Project settings**
   → **Service accounts** → **Generate new private key** → **Generate key**.
   A `.json` file downloads.
   - Making a new key does **not** switch off the old one, so the live Worker
     and the app keep working.
   - Or reuse the key file you already have, if you still have it.
2. Keep the file in **Downloads**, not inside the project folder.

### 9.2 Put it in `.dev.vars`

Do this on the PC that will run the Worker (see 9.3 for which PC).

1. Open the key `.json` file in VS Code or Notepad. Select all (Ctrl+A),
   copy (Ctrl+C).
2. In VS Code, open `healthsync-api/.dev.vars`. Select all and delete.
3. Type `FIREBASE_SA_KEY='` (with the single quote), paste the key (Ctrl+V),
   then type `'` (one single quote) at the very end. It looks like:
   ```
   FIREBASE_SA_KEY='{
     "type": "service_account",
     "project_id": "healthsyncapp-b546b",
     ...
   }'
   ```
   Several lines are fine. Use **single** quotes, not double quotes.
4. Save (Ctrl+S). Then delete the `.json` from Downloads and empty the
   Recycle Bin.

### 9.3 Run the Worker: which PC?

The box connects to whatever address is in `config.h`.

**Option 1 (simplest): on Christian's PC**, the one the box already points to
(`http://192.168.1.11:8787`, same Wi-Fi as the box). Put the key there
(9.2), then in a terminal:
1. `cd healthsync-api`
2. If `wrangler dev` is already running, stop it with **Ctrl+C**.
3. `npx wrangler dev --ip 0.0.0.0` → wait for "Ready on http://0.0.0.0:8787".
   Allow the Windows firewall prompt for **Private networks**.
4. Browser: `http://localhost:8787/device/<SERIAL>/state` (the serial paired in
   the app) → `{"server_time":"…","lit":[],"buzz":false}` means the key works.
   An error page with `invalid_grant` or `PEM` means the key was pasted wrong:
   redo 9.2.

**Option 2: on the teammate's own PC, elsewhere.** The box cannot reach
another house's PC directly, so it needs a tunnel:
1. Install the tunnel tool once: `winget install --id Cloudflare.cloudflared`
2. Put the key in (9.2), then terminal 1: `cd healthsync-api` →
   `npx wrangler dev`
3. Terminal 2: `cloudflared tunnel --url http://localhost:8787` → it prints
   an address like `https://xxxx.trycloudflare.com`.
4. Send that address to Christian. He sets
   `#define WORKER_BASE_URL "https://xxxx.trycloudflare.com"` in `config.h`
   and re-uploads. (The address changes every time the tunnel restarts.)
5. Keep both terminals open during the test.

**Never** run `npx wrangler deploy` for this. That replaces the live Worker the
app uses, and only the lead software developer decides that.

### 9.4 After the key works

Christian re-uploads `healthsync_box.ino` (the board currently runs a test
sketch) and runs the Phase 1 pass check in 7.5.

---

## 10. Wi-Fi discussion (Phase 3 design, built Oct 20)

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). No Wi-Fi and no
> hotspot. Kept for the record.

### 10.1 What we agreed already

- The box has its **own** Wi-Fi connection. It does not use the phone's
  internet, and pairing in the app does not give it a connection.
- Pairing (typing the serial in the app) only tells the cloud which patient
  the box belongs to.
- ESP32 = **2.4 GHz only**.
- Before Phase 3, Wi-Fi was typed into `secrets.h`; since Oct 20 it is set
  on the box's setup page.

### 10.2 Proposed setup flow (care partner, once, at installation)

The patient never has to do this.

1. Plug the box in. With no saved Wi-Fi it opens its own hotspot
   **`HealthSync-0001`** (the serial) and shows it is in setup mode (see 10.5,
   item 4).
2. On the phone: Settings → Wi-Fi → join `HealthSync-0001`, password from the
   box's label.
3. A setup page opens by itself. If not, open a browser and go to
   `192.168.4.1`.
4. Tap the home Wi-Fi in the list, type its password, tap **Save**.
5. The box restarts, joins the home Wi-Fi and beeps twice. It remembers the
   Wi-Fi in its flash memory, through power cuts.
6. Phone goes back to its normal Wi-Fi by itself.

Library: WiFiManager (tzapu, already installed). No app change.

### 10.3 When the Wi-Fi goes down or changes

| Situation | What the box does |
|---|---|
| Router restarts / internet down for a while | Keeps its LEDs as they were, retries every 60 s, reconnects by itself. Nothing to do. Until Phase 4 (offline), a dose that comes due **during** the outage does not light the box; the **phone reminder still works** (mobile data) |
| New router or new Wi-Fi password | Cannot connect any more → setup hotspot again: automatically after 5 minutes without Wi-Fi, or by holding the button 5 s (11.4) |
| Box moved to another house | Same as a new router |

### 10.4 Phone hotspot instead of home Wi-Fi

Works: in step 4 of 10.2, pick the phone's hotspot. But:
- The box works only while the hotspot is **on and nearby**. If the phone
  leaves the house, the box stops updating.
- The hotspot must be 2.4 GHz: iPhone → Personal Hotspot → turn on
  **Maximize Compatibility**; Android → Hotspot → AP band **2.4 GHz**.
- Data: about 5–10 MB a day at one check per minute over HTTPS.
- Good as a **backup or for the demo**; home Wi-Fi is better for daily use.

### 10.5 Decisions for the team (before Phase 3 is built)

| # | Question | Proposal |
|---|---|---|
| 1 | Open the setup hotspot **automatically** when the saved Wi-Fi is not found? | Yes, after 5 min without Wi-Fi; it keeps trying the old Wi-Fi meanwhile |
| 2 | Manual way to reopen setup | ~~Hold the button while plugging the box in~~ → **changed Oct 20: hold 5 s at any time while no LED is lit** (11.4). A dose press only happens while LEDs are lit, so the two never clash |
| 3 | Hotspot password | Yes, printed on the box label, so neighbours cannot change the Wi-Fi |
| 4 | How the box shows "setup mode" | The built-in LED may be hidden in the case, so: compartment LEDs 1 and 6 blink slowly + one beep |
| 5 | After Phase 3 | Remove Wi-Fi from `secrets.h` and `config.example.h` (this also solves 8.2) |

Answers: **Christian approved all five proposals on Oct 20** and Phase 3 was
built with them. The team can still change any of them (each is one setting
in `config.h` or one small change).

---

## 11. Phase 3: Wi-Fi setup hotspot (approved and written Oct 20, bench test pending)

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). No hotspot. The
> button rewiring notes in 11.5 still describe the bench button as it is
> wired today; how "dose taken" is recorded is now open question C5. Kept for
> the record.

**Setup hotspot password: `medbox7349`** (for box `HS-0001`'s hotspot
`HealthSync-0001`). It lives in `secrets.h` as `SETUP_AP_PASSWORD`; print it on
the box label. It only lets someone into the box's setup page, which opens
only in setup mode.

Built on the proposals in 10.5. If the team answers differently, only the
matching line changes. Phase 3 does **not** need the Firebase key, and touches
**no** Worker or app file.

### 11.1 What the box will do

```
power on → try the saved Wi-Fi first (15 s)
  ├─ connected ──────► normal (Phase 1: poll every 60 s)
  ├─ nothing saved ──► SETUP MODE
  └─ saved, not found ► keep retrying; still nothing after 5 min → SETUP MODE
                          (if nobody joins setup within 5 min, it closes and
                           retries the saved Wi-Fi for 5 min, then reopens, and
                           so on — so a Wi-Fi that comes back is rejoined)

any time, no LED lit: button held 5 s (LEDs fill up 1→6) ──► SETUP MODE
                      (saved Wi-Fi kept until a new one is saved)

SETUP MODE
  - hotspot "HealthSync-0001" (from the serial), password from the label
  - compartment LEDs 1 and 6 blink slowly, one beep when it starts
  - setup page at 192.168.4.1 (opens by itself on most phones),
    titled "HealthSync box setup", showing only "Configure Wi-Fi"
  - after Save: joins the Wi-Fi, two beeps, setup closes, normal polling
  - wrong password: stays in setup, try again
  - button held 5 s again: setup closes, back to the saved Wi-Fi (one chirp)
```

- The Wi-Fi is remembered in the ESP32's flash: through power cuts and
  re-uploads of the same firmware.
- A short outage (router restart) does **not** open setup; only 5 minutes
  without Wi-Fi does.
- While in setup the box cannot check for doses (it has no internet anyway);
  phone reminders still work.

### 11.2 Files

| File | Change |
|---|---|
| `net.cpp/h` | Replace the fixed `WiFi.begin(SSID, PASSWORD)` with WiFiManager in non-blocking mode (`net_process()` every loop), the 5-minute rule, setup start/stop |
| `button.cpp/h` | Add `button_down_ms()` (how long it is held) for the 5-second hold |
| `config.h` | `SETUP_HOLD_MS 5000`, `SETUP_HOLD_SHOW_MS 300`, `SETUP_AFTER_NO_WIFI_MS 300000`, `SETUP_WINDOW_MS 300000`, `SETUP_BLINK_MS 1000`; Wi-Fi tries use the existing `WIFI_CONNECT_TIMEOUT_MS` (15 s) |
| `healthsync_box.ino` | The 5-second hold at any time with no LED lit (LEDs fill up 1→6 while held; a press that silenced a dose never counts as a hold), setup-mode signals (LEDs 1 + 6 blink, one beep in, two beeps after Save) and no polling while in setup |
| `secrets.h` (git-ignored) | Remove `WIFI_SSID` / `WIFI_PASSWORD`; add `SETUP_AP_PASSWORD` (8+ characters, printed on the label) |
| `config.example.h` | Placeholders only (`DEVICE_SERIAL`, `SETUP_AP_PASSWORD`): **solves 8.2**, so the repo no longer has a real Wi-Fi password |
| `wifi_connect_test/`, `wifi_scan_test/` | Proposal: delete. No longer needed, and they hold a real Wi-Fi password |
| `FIRMWARE_ARCHITECTURE.md`, `HARDWARE_ARCHITECTURE.md` Step 10, this file | Update to what was built |

Not touched: Worker, app, Firestore. Library: WiFiManager 2.0.17 (installed;
compile-checked with ESP32 core 3.3.12 on Oct 20).

**Flash:** 87% after Phase 3 (was 78%). Phase 4 (SD + clock) will likely need
Arduino IDE → Tools → Partition Scheme → **Huge APP (3MB No OTA/1MB SPIFFS)**.
That is a menu setting, not a code change.

### 11.3 Phase 3 pass check

| # | Do | Expect |
|---|---|---|
| 1 | With no LED lit, hold the button 5 s | LEDs fill up 1→6, then LEDs 1 + 6 blink, one beep; phone sees `HealthSync-0001` |
| 1b | In setup, hold the button 5 s again | Setup closes (one chirp), box rejoins the saved Wi-Fi |
| 2 | Phone joins it with the label password | Setup page opens (or go to `192.168.4.1`) |
| 3 | Pick the home Wi-Fi, type the password, Save | Two beeps; Serial shows `Wi-Fi connected` and polls |
| 4 | Unplug and plug back in | Connects by itself, no setup mode |
| 5 | Router off 2 min, back on | No setup mode; reconnects by itself |
| 6 | Router off more than 5 min | Setup mode opens; router back on → it closes and reconnects |
| 7 | In setup, type a wrong Wi-Fi password | Stays in setup; can try again |
| 8 | Use a phone hotspot (2.4 GHz) as the network | Box connects and polls |
| 9 | Join `HealthSync-0001` without the password | Refused |

### 11.4 Changes after the first bench run (Oct 20)

1. **Bug fixed:** the box said `No Wi-Fi saved yet` and opened setup although
   a Wi-Fi was saved (it then connected to it). Cause: it asked "is a Wi-Fi
   saved?" before the ESP32 had loaded its saved settings. Now it **tries the
   saved Wi-Fi first** and only then asks. A brand-new box therefore opens
   setup about 15 s after power-up instead of at once. The status code is
   printed on that line.
2. **Button hold changed (Christian):** holding while plugging in was hard to
   time, because the box connects to the saved Wi-Fi straight away. Now:
   **hold 5 s at any time while no LED is lit** (LEDs fill up 1→6 while held)
   → setup opens; the same hold in setup closes it. Opening setup no longer
   forgets the saved Wi-Fi. Replaces 10.5 #2.
3. **Crash fixed (Oct 20):** after **Save** in setup the ESP32 crashed
   (`Guru Meditation Error: Core 1 panic'ed (LoadProhibited)`) and rebooted.
   Decoded backtrace: `net_process()` → `stopSetup()` →
   `WiFiManager::stopConfigPortal()` → `shutdownConfigPortal()`. WiFiManager
   had already closed the hotspot itself after the successful Save; closing
   it again used its freed web server. Now `stopSetup()` closes it only if
   `wm.getConfigPortalActive()` is still true. The Wi-Fi had been saved
   before the crash, so the box connected after rebooting.
   - How to decode a crash next time: copy the `Backtrace:` line and ask;
     it is decoded with `xtensa-esp32-elf-addr2line` against the build's
     `.elf`.
4. **Stuck-button safeguard (approved Oct 20):** a button already down at
   boot is ignored until it has been released once (Serial: `Button: was
   already down at start-up, ignored until released`), and one held more than
   30 s (`BUTTON_STUCK_MS`) prints a warning and is ignored until released.
   A jammed or miswired button can therefore open setup at most once, and
   setup closes by itself after 5 unused minutes. Compiles, 87%.

### 11.5 Phase 3 bench test, step by step (Christian)

The `wrangler dev` Worker does **not** need to run for this test (without the
Firebase key, polls show `GET /state failed: …`, which is expected).

1. Arduino IDE: **File → Open** → `firmware/healthsync_box/healthsync_box.ino`
   (the main firmware, not a test sketch). Board **ESP32 Dev Module**, port
   **COM7**. **Upload**.
2. Serial Monitor at **115200**. Press **EN**.
   - The box probably connects straight away: the Wi-Fi from the old
     `secrets.h` is still saved in the ESP32's flash from earlier uploads.
     That is fine and also proves "remembers the Wi-Fi".
3. **Open setup by hand (test 11.3 #1):** after the box has started (Serial
   shows `Wi-Fi connected` or `Poll failed`), with **no LED lit**, press and
   **hold** the button. LEDs fill up 1→6 (~5 s). Let go when LEDs 1 and 6
   start blinking and it beeps. Serial shows `Button held 5 s: opening Wi-Fi
   setup` and `SETUP MODE: on the phone join Wi-Fi "HealthSync-0001"`.
   - To check 11.3 #1b: hold 5 s again → setup closes with a chirp, then
     hold once more to reopen it for step 4.
4. **Phone:** Settings → Wi-Fi → join **HealthSync-0001**, password
   **medbox7349**. A setup page opens; if not, open Chrome and go to
   `192.168.4.1`. First try joining **without** / with a wrong password →
   refused (#9).
5. On the page: **Configure WiFi** → tap your home Wi-Fi → type its password →
   **Save**. Box: two beeps, blinking stops; Serial: `Wi-Fi connected to
   "…", IP …` (#2, #3). Try once with a wrong Wi-Fi password first: it stays
   in setup (#7).
6. Unplug and plug back in (no button) → connects by itself, no setup (#4).
7. Router off 2 min, on again → no setup, reconnects (#5).
8. Router off 6 min → after 5 min setup opens by itself (LEDs 1 + 6 blink).
   Router back on → within about 5 min setup closes and the box reconnects
   (#6).
9. Optional: repeat 3–5 choosing your phone's hotspot (2.4 GHz) (#8).

Send the Serial Monitor output and which steps passed.

**Bench results (Oct 20, after the 11.4 changes):**

| Step | Result |
|---|---|
| 1–2 Upload, boot | ✅ Connected straight to the saved home Wi-Fi (IP 192.168.1.20): the "No Wi-Fi saved" bug is fixed |
| Short press, nothing lit | ✅ `Button: nothing to silence (hold 5 s for Wi-Fi setup)` |
| 3 Hold 5 s | ✅ `Button held 5 s: opening Wi-Fi setup` → `SETUP MODE …HealthSync-0001` |
| Setup signals | ✅ LEDs 1 + 6 blink, one beep. Built-in blue LED stays on (still connected to the home Wi-Fi in the background): normal |
| 4 Hold 5 s in setup to close | ❌ Nothing printed. Likely the hold was cut short: in setup there is no fill-up to show progress, and the button seems noisy (below) |
| ⚠️ Button | Christian: it reacts **without being pressed and to very light presses**; maybe the wires. Likely cause: the ESP32's weak internal pull-up (~45 kΩ) on long breadboard wires picks up noise, worse while the Wi-Fi radio sends (setup hotspot). A noise blip also restarts the 5 s hold timer. Proposed fixes in 11.7 |
| Hold with the debug prints | ✅ `Button down`, `holding... 1–4 s`, then setup opened at 5 s. The prints went on past 10 s with no `Button up` (kept holding, or stuck? to check) |
| 5–6 Save a Wi-Fi in setup | ❌→🔧 Crashed right after Save (fixed, 11.4 #3; retest). Before the fix: box connects. "It comes back to my Wi-Fi" = the **phone**, which is normal: the hotspot closes after Save, so the phone rejoins the home Wi-Fi |
| 7–9 | _pending_ |

**Update Oct 20 (later):** with the debug prints the button reads **held
when nobody touches it** (`holding... 40 s` after boot) and shows `Button up`
**when pressed**. So it is a wiring fault, not noise: GPIO 16 and GND are
connected while the button is idle (two legs that are always joined inside
the button, or both wires in the same breadboard strip), and pressing the
button loosens that contact for a moment. The 10 kΩ resistor was not added
and is not the fix for this.

> **Superseded Oct 22:** the button is a 6 mm **normally-closed (NC)** panel
> button, so it reads LOW idle and HIGH when pressed. That was the cause, not
> the wiring. Fixed in firmware (`BUTTON_PRESSED_LEVEL HIGH`, HW-26). The steps
> below are kept only for a normally-open button.

Rewire, step by step (normally-open button only):
1. Unplug the USB.
2. Pull the button out and put it back **across the breadboard's middle
   gap**: two legs on one side of the gap, two on the other, pushed fully in.
3. Pick two **diagonally opposite** legs (e.g. top-left and bottom-right).
   Diagonal legs are always the pair the button switches.
4. GPIO 16 wire → a hole in the same 5-hole strip as one of those legs.
   GND wire → a hole in the same strip as the other. The two wires must **not**
   share a strip, and nothing else may sit in those two strips.
5. Plug in, Serial Monitor at 115200, press EN. Pass: **no** `Button down`
   for 1 minute without touching it; a press gives `Button down`, letting go
   gives `Button up after 0.x s`.

### 11.7 Button noise: fixes (Oct 20; cause found Oct 22: NC button, see 11.5)

Firmware part **approved and done Oct 20** (compiles, 87%). `BUTTON_DEBUG 1`
in `config.h` turns the prints on; set it to 0 once the button is fixed.
Hardware part: Christian to do, result _pending_.

Hardware (Christian):
1. Use two **diagonally opposite** legs of the tactile button (always the
   switched pair), wires pushed fully in, as short as possible.
2. Add the spare **10 kΩ resistor from GPIO 16 to 3V3** (an external pull-up,
   about 4× stronger than the internal one). The button stays GPIO 16 → GND.
   If it fixes the noise, update the docs (the 10 kΩ becomes "used").

Firmware:
1. While the button is held, show the 1→6 fill-up in setup mode too.
2. Temporary Serial prints: `Button down`, `holding… 1 s, 2 s…`,
   `Button up after 2.3 s`.
3. `BUTTON_DEBOUNCE_MS` 50 → 80 ms, so short blips are ignored.

### 11.6 Order

The original order was Phase 2 (button confirms dose) before Phase 3. Phase 2
needs the Firebase key; Phase 3 does not. Decided Oct 20: **Phase 3 first**
while waiting for the key, then Phase 2.

---

## 12. New phase plan for Bluetooth (proposed Oct 22, waiting for approval)

**Why a new plan:** the Oct 22 decision (`BLE_CONNECT_ON_DEMAND.md`) replaces
the Wi-Fi/Worker link. The old Phases 1–5 (sections 4, 7, 11) are kept for
the record. Mona's branch `docs/ble-connect-on-demand` was merged into ours
locally on Oct 22 (merge `e14affb`); no other team pushes were waiting.

**Key point:** the box must alarm **without the phone** (P5). So the first
phases need neither Bluetooth nor Miko's app, and the Bluetooth phase can be
tested with the free **nRF Connect** phone app before Miko's app exists.

| Phase | Goal | Needs | Answers / tasks |
|---|---|---|---|
| **0. Cleanup** | Remove the Wi-Fi code from the firmware (old Phase 1 Worker polling, old Phase 3 setup hotspot; kept in git history). Switch off the Worker `/state` route (code kept for now; remove later if not needed) | Christian's OK (given Oct 22) | Decisions 3 and 4 below |
| **1. Offline alarm from a stored schedule** | The box keeps a schedule (compartment 1–6, time, days) and, from the DS3231 clock alone, lights the LED and beeps at dose time until +60 min; the button marks the dose taken (in a −30 to +59 min window, as in DOSE_LOGIC_PROPOSAL 3.5) | Nothing new: a test schedule typed in the Serial Monitor | P5, HW-09 (core) |
| **2. Dose log on the microSD** | Every taken/missed dose is saved on the SD card with a sequence number and the app's own dose id `{schedule_id}_{YYYY-MM-DD}_{HH:mm}`, so a repeated sync never makes a duplicate; survives power cuts | Phase 1 | C4, 7.2.2, HW-10 (part) |
| **3. Bluetooth server (NimBLE)** | The phone can set the time, write the schedule, read the dose log and acknowledge it. Tested with nRF Connect. Remove the Wi-Fi code (frees flash) | Phase 2; a draft characteristic list agreed with Miko (DEV-27) | C1, 7.2.1, HW-08 |
| **4. Security** | Only the paired phone can write (passkey bonding or an app secret) | Phase 3; decision with Miko | C3, 7.2.4 |
| **5. With Miko's app + battery** | Real pairing/sync from the app; wake/low-power choice; 18650 + 134N3P wiring | Miko's app work (7.1.x); measurements | C2, C6–C8, HW-21, HW-22 |
| **6. Final box** | Everything mounted in the printed v2.2 enclosure (6 compartments, LEDs under lids 1–6, NC button, buzzer, 18650); full hardware test with a video per function; demo kit | Printed parts (HW-19), Phases 1–5 | HW-20, HW-11, HW-22, HW-13 (Gate 4) |
| **7. Hardware papers** | Hardware facts for Ch3; v2.2 wiring guide; test results for Ch4/Ch5; your Q&A answers (hardware, offline, security) | Phases 1–6 results | HW-07, HW-21, HW-12, DEF-03 |

**Still true from before:** pins (§3), the 6 mm NC button fix, the 5-beep
alarm, the stuck-button safeguard, the SD and DS3231 bench tests.

**Corrections for `BLE_CONNECT_ON_DEMAND.md` (to tell Mona):** X6: the button
is on **GPIO 16** (NC, firmware fixed), not GPIO 5. C2: GPIO 13 is **LED 1**,
not spare; a wake pin must be another free pin (candidates: 4, 27, 34, 35, 36,
39). One merged note in §11.5 still points to the button "rewiring notes";
those are superseded by the NC finding.

**Full list shown to Christian Oct 22** (phases 0, 6 and 7 added).

**Answers Oct 22:** 2. do **not** push yet; push everything at the end of the
day. 3. switch the Worker `/state` route **off** for now; remove it later if it
is not needed. 4. remove the old Wi-Fi Phase 1 (done in Phase 0).

**Decisions needed:**
1. Approve this phase order (0–7).
2. Push the local commits (`614ca8d` + merge `e14affb`) to `feature/medbox-integration`.
3. The Worker `/state` code on our branch: remove it (the decision says device
   endpoints are not planned) or keep it unrouted.
4. The old Wi-Fi Phase 1 test: skip it (proposed) or run it once as a bench check.


---

## 13. Phase 0 done, Phase 1 plan (Oct 22)

### 13.1 Phase 0 (cleanup): done Oct 22

- Removed `net.cpp`/`net.h` (Wi-Fi, WiFiManager, Worker polling, setup
  hotspot) and their settings from `config.h`; `healthsync_box.ino` now only
  runs the self-test and reports the button (stuck-button safeguard and debug
  prints kept). All of it stays in git history (commit 286c33b).
- `secrets.h` keeps `DEVICE_SERIAL` (future Bluetooth name); the Wi-Fi setup
  password was removed from it and from `config.example.h`.
- Worker: the `/state` route is **switched off**; `healthsync-api/src/index.ts`
  is identical to `release` again. `device.ts` stays, unrouted, marked
  "switched off" (delete it if Bluetooth never needs it). Typecheck clean.
- Firmware compiles: **20% flash** (was 87% with Wi-Fi), room for Bluetooth.
- The old Wi-Fi password is still saved inside the ESP32 chip from earlier
  uploads; nothing uses it. Harmless.

### 13.2 Phase 1 plan: offline alarm from a stored schedule (waiting for approval)

**What the box will do (no phone, no Bluetooth yet):**

1. Keep the time on the DS3231. The clock holds **UTC**; the box adds 8 hours
   (Manila, `TZ_OFFSET_MIN 480`) to compare with dose times, like the Worker.
2. Keep a schedule of up to 24 dose times: compartment 1–6, time (HH:MM),
   days (every day, or chosen weekdays). Saved in the ESP32 flash memory, so
   it survives power cuts. (Phase 3 lets the phone write it over Bluetooth.)
3. At a dose time: that compartment's LED on + 5 beeps every minute, until
   the dose is taken or 60 min have passed (then **missed**, LED off). A dose
   due at 23:30 stays lit past midnight correctly.
4. Button while LEDs are lit: **all lit doses taken** (team proposal "confirm
   all"), LEDs and buzzer off, two short confirm beeps. Button with nothing
   lit: if a dose is due within the next 30 min, it is taken **early**
   (DOSE_LOGIC_PROPOSAL 3.5); otherwise one long beep ("nothing due").
5. Taken and missed doses are remembered in flash, so a reboot never relights
   a dose already handled. (Phase 2 adds the full log on the SD card.)

**Bench commands** (Serial Monitor, line ending "Newline"; Phase 3 replaces
them with Bluetooth):

| Command | Does |
|---|---|
| `time 2026-10-23 14:00` | Set the clock (the Manila time you type; stored as UTC) |
| `add 3 14:02` | Compartment 3 at 14:02, every day |
| `add 2 08:00 mon,wed,fri` | Only on those days |
| `list` | Show the schedule with numbers |
| `del 2` | Delete entry 2 |
| `clear` | Delete the whole schedule |
| `status` | Clock time, what is lit, what was taken or missed today |

**Files:**

| File | Change |
|---|---|
| `rtc_clock.cpp/h` | Written (was empty): start the DS3231, read/set UTC, Manila time helpers, "lost power" warning |
| `schedule.cpp/h` | Written (was empty): the entries, saving them in flash, "what is due now", mark taken/missed, remembered across reboots |
| `console.cpp/h` | New: the bench commands above |
| `healthsync_box.ino` | Once a second: due compartments → LEDs + buzzer; button → taken / early / nothing due |
| `config.h` | `TZ_OFFSET_MIN 480`, `DUE_WINDOW_MIN 60`, `EARLY_WINDOW_MIN 30`, `MAX_SCHEDULES 24`, `BEEP_NOTHING_MS` |
| `storage.cpp/h` | Not touched (Phase 2) |

Not touched: the app, the Worker, Firestore. Libraries: RTClib (installed),
Preferences (built in).

### 13.3 Phase 1 pass check (Christian, after upload)

| # | Do | Expect |
|---|---|---|
| 1 | `time` with the real time, then `status` | Correct Manila time; after unplugging 1 min it is still right |
| 2 | `add 3 <now + 2 min>` | At that minute LED 3 + 5 beeps, repeating every minute |
| 3 | Press the button | LED 3 off, buzzer off, two confirm beeps; `status` says taken |
| 4 | Unplug, plug back in | Schedule still there (`list`); the taken dose does not relight |
| 5 | `add 5 <now + 2 min>`, wait for it, then `time` 61 min later | LED 5 lights, then goes off as **missed** |
| 6 | `add 1 <now + 20 min>`, press now | Taken **early**, two beeps |
| 7 | Press with nothing due | One long beep |
| 8 | Two compartments due at once, one press | Both taken |
| 9 | `add 2 23:59`, set the time to 23:58, wait past midnight | Still lit after 00:00 |


### 13.4 Bench check after Phase 0 (Oct 22): wiring fault suspected

Uploaded the Phase 0 firmware. Result: **LEDs do not light** in the self-test,
**the buzzer sounds non-stop**, and the button reads **held** although nobody
presses it (`holding... 10 s`). The LED/buzzer code is unchanged since the
Oct 20 `hw_test` pass, and the firmware never keeps the buzzer on, so this is
the breadboard: most likely a loose or missing **GND** connection, or parts
put back differently after the caliper measurement (HW-24). The button reading
"held" with both settings (LOW on Oct 20, HIGH now) also means its circuit is
not connected. Steps: check every GND, the buzzer transistor wiring, then
`hw_test`. Phase 1 waits until the bench passes `hw_test` again.

**Update Oct 22 (later): `hw_test` passes again.** LEDs 1→6 in order, the
5-beep alarm, and the button gives exactly one `Press #n` + `released` per
press with `BUTTON_PRESSED = HIGH`, which confirms the NC setting. The bench is
good; Phase 1 can start once approved.


### 13.5 Phase 1 written (Oct 22), bench test pending

Approved Oct 22. Files: `rtc_clock.cpp/h` and `schedule.cpp/h` (were empty),
new `console.cpp/h`, `healthsync_box.ino`, `config.h`, `buzzer.cpp/h`
(`buzzer_beep_ms`). Compiles with no errors or warnings: **25% flash**.

Changes from the 13.2 plan:
- **Button press = press and let go**, held 0.3–10 s (`BUTTON_CONFIRM_MS`,
  `BUTTON_CONFIRM_MAX_MS`). With the NC button a wire that loses contact reads
  as "pressed"; counting only deliberate press-and-release stops a loose wire
  from marking a dose taken. Shorter taps print "too short, ignored".
- A dose time added **after** its time today starts tomorrow (like the app's
  materializer).
- `add` refuses until the clock is set; with the clock not set nothing alarms.

Logic check on the PC (JavaScript copy of the rules, not the C++ itself;
18/18 pass): weekday mapping, lit 14:02–15:01, missed at 15:02 once, one press
takes two lit doses, early 20 min before but not 40, a 23:59 dose still lit at
00:30 and missed at 00:59, a 00:10 dose taken early at 23:50, Mon/Wed/Fri
days, added-after-its-time.

**Note:** `rtc_test` left the DS3231 on Manila time, but Phase 1 reads it as
UTC, so the first `status` shows 8 hours ahead until the time is set (step 2).

### 13.6 Phase 1 bench test, step by step (Christian)

Before: in the Serial Monitor set the line ending (drop-down at the bottom
right) to **Newline** and the speed to **115200**. Replace `HH:MM` with real
times; "now" = the PC clock.

1. Open `firmware/healthsync_box/healthsync_box.ino` → **Upload** → Serial
   Monitor → press **EN**. Expect `Phase 1: offline alarm`, LEDs 1→6, one chirp.
2. Type `time 2026-10-23 HH:MM` (today's date, now) → `status`: the clock matches
   the PC.
3. `add 3 HH:MM` (now + 2 min). At that minute: **LED 3 + 5 beeps**, again every
   minute. `status` → `DUE NOW (lit)`.
4. Press the button about half a second and let go → `Dose TAKEN: compartment
   3 … on time`, LED off, **two beeps**.
5. Unplug the USB, plug back in → `status`: entry still there, `TAKEN`, LED 3
   stays off.
6. `add 5 HH:MM` (now + 2 min); when LED 5 lights, type `time` with the same date
   and a time **61 minutes later** → `Dose MISSED: compartment 5`, LED off.
   Then set the real time again with `time`.
7. `add 1 HH:MM` (now + 20 min) and press right away → `TAKEN … early (20 min
   before)`, two beeps.
8. Press with nothing lit and nothing within 30 min → `Button: nothing due`,
   **one long beep**.
9. `add 2 HH:MM` and `add 4 HH:MM` (same time, now + 2 min) → both light; one press
   → both `TAKEN`.
10. Tap the button very quickly → `too short, ignored`.
11. `add 6 23:59`, then `time <today> 23:58`, wait until 00:01 → LED 6 still lit,
    `status` says `DUE NOW`. Set the real time again.
12. Clean up: `clear`, then `time` with the real time.

Send the Serial Monitor output and which steps passed.


**Phase 1 bench result (Oct 23): PASSED.** Christian ran the tests and
reported "all of them are working". Seen in the Serial Monitor screenshots:
- `time 2026-10-23 23:55` set the clock; `status` showed it.
- `add 3 23:55 thurs` on a Friday → `not today` (day filter; "thurs" accepted).
- `Dose TAKEN: compartment 1, 23:55 … on time` after a 0.8 s press.
- `Button: 163 ms is too short, ignored`.
- `Button: nothing due` (long beep).
- `add 1 00:11` + `add 2 00:11`, one press at 00:10 → both `TAKEN … early
  (1 min before)`.
- `clear` → all dose times deleted.
- Missed (step 6), power cut (step 5) and midnight (step 11): reported working.

Note: Christian edited lines 16–17 of `console.cpp` (help text only) to show
example values instead of the `YYYY-MM-DD HH:MM` / `<1-6>` placeholders. It
changes only what `help` prints; restore the placeholders if wanted.

**Tracker effect:** HW-09 is now partly met on the box itself (a due dose lights
its LED and beeps at the due time from the stored schedule; the button marks
it taken). "Shows as taken in the app" needs Phase 3 (Bluetooth) and Phase 5
(Miko's app).


---

## 14. Phase 2 plan: dose log on the microSD (Oct 23, waiting for approval)

**Goal:** every taken or missed dose is written to the SD card, so when the
phone connects (Phase 3) it can collect each one exactly once and send it to
Firebase. Answers open question **C4** (no duplicates on repeated syncs) and
part of task 7.2.2 / HW-10.

### 14.1 What the box will do

1. On every **TAKEN** or **MISSED**, append one line to `/doselog.jsonl` on the
   SD card, then close the file at once, so a power cut loses nothing:
   ```json
   {"seq":7,"type":"taken","comp":3,"date":"2026-10-24","time":"00:32","at":"2026-10-23T16:33:10Z","timing":"on_time","sid":""}
   ```
   - `seq`: a number that only goes up (1, 2, 3 …), kept in flash so it never
     repeats, even after a power cut. The phone uses it to know what it already
     has.
   - `date` + `time`: the dose's Manila date and time. With `sid` (the app's
     schedule id, sent by the phone from Phase 3) they make the app's own dose
     id `{sid}_{date}_{time}`, so the same dose can never be created twice in
     Firestore.
   - `at`: when the button was pressed (or the dose was marked missed), in UTC.
   - `timing`: `on_time`, `late` or `early` (taken only).
2. Keep the number of the last event the phone confirmed ("acked"). Events
   after it are **pending**. Phase 3 lets the phone read pending events and
   ack them; Phase 2 simulates that with a console command.
3. **No SD card, or it fails:** the box still alarms normally, prints a
   warning, and keeps the last 32 events in flash instead, so nothing is lost
   until the card is back.
4. Schedule entries get a place for the app's schedule id (`sid`), empty for
   doses added from the console. This changes the stored format once: the
   first boot after the upload starts with an empty schedule (re-add the test
   doses).

### 14.2 New bench commands

| Command | Does |
|---|---|
| `log` | Show the last 10 events |
| `pending` | How many events the phone has not collected yet |
| `ack <seq>` | Pretend the phone collected everything up to `seq` (Phase 3 does this over Bluetooth) |
| `sd` | SD card status: found or not, size, log file size |

### 14.3 Files

| File | Change |
|---|---|
| `storage.cpp/h` | Written (was empty): start the SD card with our pins (SCK 18, MISO 23, MOSI 19, CS 15), append an event, read the last events, count pending, flash fallback |
| `schedule.cpp/h` | On TAKEN/MISSED, hand the event to `storage`; entries get `sid` (format version 2) |
| `console.cpp/h` | `log`, `pending`, `ack`, `sd` |
| `healthsync_box.ino` | Start the SD card at boot |
| `config.h` | `LOG_FILE "/doselog.jsonl"`, `LOG_FALLBACK_MAX 32` |

Not touched: the app, the Worker, Firestore. Libraries: SD and SPI (built in).

### 14.4 Phase 2 pass check

| # | Do | Expect |
|---|---|---|
| 1 | Boot with the card in | `SD card OK` and the size |
| 2 | Take a dose, let another be missed (clock jump, as in Phase 1) | `log` shows both lines with seq 1 and 2 |
| 3 | Unplug, plug back in, `log` | Both lines still there; the next event gets seq 3 (no repeat) |
| 4 | `pending` → `ack 2` → `pending` | 2 pending, then 0 |
| 5 | Card into the PC | `doselog.jsonl` opens in Notepad with the same lines |
| 6 | Boot **without** the card, take a dose | Warning, alarm still works, event kept in flash (`log`) |


### 14.5 Phase 2 written (Oct 23), bench test pending

Approved Oct 23 (with restoring the `help` placeholders, done). Files:
`storage.cpp/h` (was empty), `schedule.cpp/h` (`sid` field, format version 2,
every TAKEN/MISSED goes to the log), `console.cpp/h` (`log`, `pending`, `ack`,
`sd`; help text back to `time YYYY-MM-DD HH:MM` / `add <1-6> <HH:MM>`),
`healthsync_box.ino` (card started before the schedule), `config.h`
(`LOG_FILE`, `LOG_FALLBACK_MAX`). Compiles with no errors or warnings: **29%
flash**; uses the ESP32 core's SD library.

Rules in the code:
- The `seq` is saved in flash **before** the line is written, so a number is
  never handed out twice, even if the power fails in between.
- The file is opened, appended and closed for every event.
- If a card write fails, the box switches to the flash fallback until the next
  boot; at a boot that finds a card, waiting events move to the card first.
- `ack` also deletes flash copies the phone already has.
- Not done yet: shrinking the file once everything is acked (it grows by about
  150 bytes per dose: a year of 6 doses a day is about 330 KB, fine on 16 GB).

### 14.6 Phase 2 bench test, step by step (Christian)

Serial Monitor: line ending **Newline**, **115200**. `HH:MM` = real times.

1. Open `healthsync_box.ino` → **Upload** → press **EN**. Expect `SD card: OK, …
   MB, /doselog.jsonl is 0 bytes` and `0 dose time(s) stored` (the format
   changed once, so the schedule is empty). If the clock says `NOT SET`, type
   `time 2026-10-23 HH:MM`.
2. `add 3 HH:MM` (now + 2 min). When LED 3 lights, press and let go →
   `Dose TAKEN …` then `logged #1 on the SD card`.
3. `add 5 HH:MM` (now + 2 min). When LED 5 lights, type `time` with a time 61 min
   later → `Dose MISSED …` and `logged #2`. Set the real time again.
4. `log` → both lines, each marked `*` (not collected yet).
5. Unplug the USB, plug back in → `log` still shows #1 and #2; `pending` → 2.
6. `ack 2` → `Pending: 0`; `log` → no `*`.
7. Take one more dose (as in step 2) → `logged #3` (not #1 again).
8. Unplug, take the SD card out, put it in the PC → open `doselog.jsonl` with
   Notepad: three lines. Put the card back.
9. **Without the card:** unplug, remove the card, plug in → `WARNING: no SD
   card`. Add and take a dose → `logged #4 in flash`; `log` shows it `(in
   flash)`. Unplug, put the card back, plug in → `Moved 1 event(s) from flash
   to the SD card`; `log` shows #4.
10. Clean up: `clear` (the log stays on the card).

Send the Serial Monitor output and which steps passed.

**Phase 2 bench results (Oct 23–24):**

| Step | Result |
|---|---|
| 1 Boot | ✅ `SD card: OK, 14832 MB, /doselog.jsonl is 0 bytes`, `0 dose time(s) stored` |
| 2 Taken | ✅ `Dose TAKEN: compartment 1 … on time` → `logged #1 on the SD card` |
| 3 Missed | ✅ clock jump → `Dose MISSED: compartment 2, 00:33` → `logged #2` |
| Early (extra) | ✅ one press at 00:34 took compartments 1 and 5 (00:37) and 2 (00:45) early → #3, #4, #5. "Confirm all" includes every dose within the next 30 min; **team to confirm** this, or take only the nearest dose time |
| 4 `log` | ✅ five JSON lines, all `*`; `at` in UTC (16:34Z = 00:34 Manila) |
| 6 `ack 2` | ✅ `Pending: 3` (correct: #3–#5 remain; Christian first thought the schedule caused it) |
| 7 No repeat | ✅ numbers kept going up (#3, #4, #5) |
| 8 Card in the PC | ⏭ skipped: the laptop has no SD slot. Covered by `log`, which reads the lines back from the card file, and by the power-cut step. Optional later with a USB card reader |
| 9 Without a card | ✅ passed Oct 24 (below) |

Notes: a garbled `������` line came from the Serial Monitor while the Arduino
IDE was busy ("Downloading index"); the command still worked. The IDE's Auto
Format (Ctrl+T) re-indented `console.cpp` to 2 spaces; content unchanged.

**Step 9 (no card) passed, Oct 24:** `WARNING: no SD card`, dose 4 taken with
the alarm working, `logged #6 in flash (1 waiting for a card)`, `log` showed
it. Card back in → `SD card: OK, /doselog.jsonl is 744 bytes`, `waiting in
flash 0`, and `log` lists #6 from the card. 744 bytes is exactly the six
lines #1–#6 (five would be 618), so #6 reached the card. The "Moved 1
event(s)" line was printed at a boot the Serial Monitor did not catch
(plugging in starts the box before the monitor connects).

**Phase 2: COMPLETE (Oct 24).**

**Change after Phase 2 (team decision, Oct 24):** an early press takes only
the **nearest** dose time within 30 min (all compartments at that same time),
not every dose in the window. Checked on the PC: a press at 00:34 takes
compartments 1 + 5 (00:37) but not 2 (00:45); the next press takes 2; a 00:10
dose is still taken early at 23:50. Compiles (29%). Quick bench check: two dose
times 8 minutes apart, press 3 minutes before the first: only the first is
taken.


---

## 15. Phase 3 plan: Bluetooth server (Oct 24, waiting for approval)

**Goal:** the phone can do over Bluetooth what the bench console does today:
set the clock, send the schedule, collect the dose log and acknowledge it, and
tell the box a dose was handled in the app. Connect-on-demand: the phone
connects, syncs, disconnects (BLE_CONNECT_ON_DEMAND.md P2, P6). Answers C1
(NimBLE with the clock and SD card) and is task 7.2.1 / HW-08.

Miko's spec (DEV-27) has not arrived, so the box side proposes a **draft
protocol** for Miko to confirm or change. Testing needs no app: the free
**nRF Connect** phone app can send these messages by hand.

### 15.1 Draft protocol (to confirm with Miko)

- The box advertises as **`HealthSync-0001`** (from `DEVICE_SERIAL`), with one
  custom service and two characteristics:
  - **command** (phone → box, write): one JSON message per write
  - **reply** (box → phone, notify): one JSON message per notification
- The phone asks for a larger packet size (MTU 247) on connect, so each
  message fits in one packet.

| Phone sends | Box replies | Purpose |
|---|---|---|
| `{"op":"hello"}` | `{"op":"hello","serial":"HS-0001","fw":"…","utc":…,"sched_ver":"…","last_seq":6,"acked":2,"pending":4,"sd":true}` | First message of every sync |
| `{"op":"set_time","utc":1761300000}` | `{"op":"ok"}` | The phone's clock sets the DS3231 |
| `{"op":"sched_begin","ver":"2026-10-24T09:41:00Z","count":3}` | `{"op":"ok"}` | Start sending the schedule |
| `{"op":"sched_item","sid":"sc_K3pT8mQa","comp":3,"time":"08:00","days":[1,2,3,4,5,6,7]}` × count | `{"op":"ok"}` each | One dose time; `days` as in the app (1 = Monday … 7 = Sunday) |
| `{"op":"sched_commit"}` | `{"op":"ok","count":3}` | Replace the stored schedule in one step |
| `{"op":"events","after":2,"max":10}` | one `{"op":"event",…}` per event (the same line as the SD log), then `{"op":"events_end","last":6}` | Collect pending events |
| `{"op":"ack","seq":6}` | `{"op":"ok","pending":0}` | The phone saved them in Firebase |
| `{"op":"app_done","sid":"sc_K3pT8mQa","date":"2026-10-24","time":"08:00"}` | `{"op":"ok"}` | A dose was taken/skipped in the app: the box turns that LED off without logging it again |
| anything wrong | `{"op":"error","msg":"…"}` | |

Rules:
- `sched_commit` keeps the "added" time of dose times that did not change, so
  a re-sync never stops a dose that is due right now from lighting.
- Only schedules with a compartment 1–6 are sent; the app keeps the rest
  phone-only.
- `app_done` answers the "Done in the app while the LED is lit" case; without
  it the box would keep beeping until the button or +60 min.
- No security yet: anyone nearby can connect. That is Phase 4 (C3).

### 15.2 Files

| File | Change |
|---|---|
| `ble.cpp/h` | New: NimBLE server, advertising, command/reply characteristics, larger packet size |
| `protocol.cpp/h` | New: reads each JSON command (ArduinoJson) and calls the clock, schedule and storage functions; builds the replies |
| `schedule.cpp/h` | Replace-in-one-step (`sched_begin/item/commit`), keep "added" times, `app_done` |
| `storage.cpp/h` | Read events after a given seq (for `events`) |
| `healthsync_box.ino` | Start Bluetooth; refresh the LEDs after a sync |
| `config.h` | Service and characteristic IDs, `FIRMWARE_VERSION` |
| `BLE_PROTOCOL.md` | New: the protocol above as a one-page spec for Miko (DEV-27) |

The bench console stays (useful for tests). Not touched: the app, the Worker,
Firestore.

### 15.3 What needs installing (with OK)

- **NimBLE-Arduino** library (Arduino Library Manager; not installed yet).
- **nRF Connect for Mobile** (Nordic Semiconductor) on Christian's Android
  phone, from the Play Store.

### 15.4 Phase 3 pass check (Christian, with nRF Connect)

| # | Do | Expect |
|---|---|---|
| 1 | nRF Connect → Scan | `HealthSync-0001` appears |
| 2 | Connect, enable notifications on **reply**, write `{"op":"hello"}` to **command** | The hello reply with serial, seq numbers, SD status |
| 3 | Write `set_time` with the current UTC seconds | Serial Monitor `status` shows the right Manila time |
| 4 | Write `sched_begin` (count 1), one `sched_item` for now + 2 min, `sched_commit` | `list` shows it; at that minute the LED lights |
| 5 | Write `app_done` for that dose | LED off, no new log line |
| 6 | Take another dose with the button, then write `events` with `after` = last acked | The event arrives as a notification; then `ack` → pending 0 |
| 7 | Disconnect | The box advertises again; the alarm keeps working |
| 8 | Repeat `sched_*` with the same items while a dose is lit | The LED stays lit (added times kept) |

### 15.5 Decisions and notes (Oct 24)

- **Option A approved:** Phase 3 is tested with nRF Connect; the real app gets
  Bluetooth from Miko (7.1.x) and is joined in Phase 5. The app has no
  Bluetooth code or permission today, and the team does not change the app.
- **The finished box needs no laptop and no EN press.** It starts by itself on
  power (battery or USB), gets its time and schedule from the phone over
  Bluetooth, keeps its clock on the coin cell and its schedule and log in flash
  and on the SD card. EN, the laptop and the Serial Monitor are bench tools.
- **To check with the print student:** the ESP32's own USB port must stay
  reachable after assembly (a hole or a removable lid), or firmware fixes
  cannot be uploaded. The v2.2 side USB port may be charging-only (134N3P).
- **Proposed for Phase 5:** status signals without a laptop (e.g. a blink
  pattern at power-on if the SD card is missing or the clock is not set).
- **Battery: one rechargeable 18650 through the 134N3P (charge + 5 V).** Rough
  estimate: ESP32 with Bluetooth always on ≈ 50–60 mA at 5 V → about **1 day**
  per charge from a 2,500–3,000 mAh cell. Several days needs power saving
  (C2 wake pin, light sleep, slower CPU) in Phase 5. Measure the real current
  then.
- **No battery level** in this build (no monitoring; CLAUDE.md "no phantom
  features"). Adding it = a voltage divider (two resistors) to a free ADC pin
  (e.g. 34/35): a team decision, not planned.


### 15.6 Phase 3 written (Oct 24), bench test pending

Approved Oct 24 (option A: test with nRF Connect). Installed
**NimBLE-Arduino 2.5.1** (Arduino libraries folder). New files: `ble.cpp/h`
(server, advertising, queue to loop(), idle drop, status LED on GPIO 2),
`protocol.cpp/h` (the messages), **`BLE_PROTOCOL.md`** (one-page draft spec for
Miko, DEV-27). Updated: `schedule.cpp/h` (sync begin/item/commit, keeps
"added" times, `app_done`, version), `storage.cpp/h` (`storage_events_after`),
`healthsync_box.ino`, `config.h` (UUIDs, `FIRMWARE_VERSION "0.3.0"`). Compiles
with no errors or warnings: **54% flash**, 12% RAM.

Design notes:
- Commands arrive on the Bluetooth task and are queued; loop() handles them, so
  the schedule, clock and SD card are only touched from one place.
- NimBLE 2.x does not re-advertise after a disconnect by default:
  `advertiseOnDisconnect(true)` is set.
- The 128-bit service id fills the advertisement, so the name is in the scan
  response.
- Replies need MTU 247 (the phone asks for it); at the default 23 the box
  prints "does not fit packet size" on the Serial Monitor.

### 15.7 Phase 3 bench test with nRF Connect, step by step (Christian)

**Setup (once):**
1. Android phone: Play Store → install **nRF Connect for Mobile** (by Nordic
   Semiconductor). Turn on Bluetooth (and Location, if the phone asks).
2. PC: upload `healthsync_box.ino`, Serial Monitor at 115200, Newline, press
   **EN**. Expect `fw 0.3.0, Phase 3: Bluetooth` and `Bluetooth: advertising as
   "HealthSync-0001"`. Check the clock with `status`; set it with `time` if
   needed.

**Connect:**
3. nRF Connect → **SCANNER** → **SCAN** → `HealthSync-0001` → **CONNECT**.
   Serial: `Bluetooth: phone connected`. The ESP32's blue LED turns on.
4. Top right **⋮** → **Request MTU** → `247` → OK. Serial: `packet size 247`.
5. Open the service `908a611a-…` (shown as "Unknown Service"). It has two
   characteristics: `a8672cae-…` (write = **command**) and `c7b37ff8-…`
   (notify = **reply**).
6. On the **reply** characteristic tap the **triple-arrow** icon to turn on
   notifications.

**Sending a message:** on the **command** characteristic tap the **up-arrow**
→ change the format from BYTE ARRAY to **TEXT** → type the message → **SEND**.
The answer shows under the reply characteristic and, more readably, in the
Serial Monitor as `BLE < …` (every message the phone sends shows as `BLE > …`).

| # | Send | Expect |
|---|---|---|
| T1 | `{"op":"hello"}` | `{"op":"hello","serial":"HS-0001","fw":"0.3.0",…}` |
| T2 | `{"op":"set_time","utc":NUMBER}` — get NUMBER on the PC in PowerShell: `[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()`, then send within a few seconds | `{"op":"ok"}`; Serial `status` shows the right Manila time |
| T3 | `{"op":"sched_begin","ver":"test1","count":1}` → `{"op":"sched_item","sid":"test-a","comp":3,"time":"HH:MM"}` (now + 2 min) → `{"op":"sched_commit"}` | `ok` ×2, then `{"op":"ok","count":1}`; `list` shows it; at HH:MM LED 3 lights |
| T4 | While LED 3 is lit: `{"op":"app_done","sid":"test-a","date":"YYYY-MM-DD","time":"HH:MM"}` (today, same time) | `ok`; LED 3 off; `status` says `done in the app`; `log` has no new line |
| T5 | New test dose: T3 again with `"ver":"test2"`, `"sid":"test-b"`, `"comp":5`, now + 2 min. When LED 5 lights, send the same three messages again | LED 5 **stays lit** |
| T6 | Press the button (LED 5 taken), then `{"op":"events","after":0}` | One `event` per logged dose, then `events_end` with `last` (watch the Serial Monitor: nRF Connect shows only the newest value) |
| T7 | `{"op":"ack","seq":LAST}` (the `last` from T6) | `{"op":"ok","pending":0}` |
| T8 | `{"op":"nope"}` | `{"op":"error","msg":"unknown op"}` |
| T9 | **DISCONNECT** in nRF Connect | Serial `phone disconnected, advertising again`; the box shows up in SCAN again; alarms still work |
| T10 | Connect and send nothing for 60 s | Serial `phone silent for 60 s, disconnecting` |

T6 with the SD card in also answers **C1** (Bluetooth, clock and SD card
together). Clean up afterwards: `clear` in the Serial Monitor.

**Phase 3 bench results (Oct 24, nRF Connect):**

| Test | Result |
|---|---|
| Connect + MTU | ✅ `phone connected (packet size 247)` |
| Not JSON | ✅ `hi` → `{"op":"error","msg":"not JSON"}` |
| T1 hello | ✅ serial HS-0001, fw 0.3.0, clock_ok true (box time 2026-10-24 01:28) |
| T3 schedule sync | ✅ `sched_begin`/`sched_item` (test-a, comp 3, 01:32)/`sched_commit` → `{"op":"ok","count":1}`, "Schedule replaced by the phone" |
| T4 app_done | ✅ (second run, `test-c`, comp 1, 02:00): `Dose done in the app: compartment 1, 02:00 … alarm off`; `status` → `done in the app` |
| T5 re-send while lit | ✅ checked by Christian on the bench Oct 25 (no screenshot) |
| T6 events | ✅ all 7 events from the SD card as `event` notifications, then `events_end` sent 7, last 7. **Answers C1:** Bluetooth + DS3231 + SD work together |
| T7 ack | ✅ `ack 7` → `pending 0` |
| T8 unknown op | ✅ `{"op":"error","msg":"unknown op"}` |
| T9 disconnect | ✅ `phone disconnected, advertising again` |
| T10 idle drop | not run (optional) |

Christian found the message format hard to follow at first; the session reply
explained that nRF Connect plays the app's part and gave each message ready to
copy. Offered: a console `demo` command that prints the messages with the time
filled in.

**Phase 3: COMPLETE (Oct 24)**, declared by Christian; T5 to check next session. BLE_PROTOCOL.md goes to Miko through this branch (Christian tells him to pull).


---

## 16. Phases vs the tracker (Oct 25)

Tracker read Oct 25 (Christian's tasks). It already carries the Oct 24 firmware
results in its notes.

| Phase | Status | Tracker tasks |
|---|---|---|
| 0 Cleanup | ✅ Oct 22 | — |
| 1 Offline alarm from a stored schedule | ✅ Oct 23 | HW-09 (box side done; "shows as taken in the app" waits for Phase 5) |
| 2 Dose log on the SD card | ✅ Oct 24 | HW-10 (box side done; the upload to Firebase waits for Phase 5, DEV-17/DEV-29) |
| 3 Bluetooth server | ✅ Oct 24–25 | HW-08 (For Review: box side passed with nRF Connect; the real proof needs the app, DEV-28/DEV-29/PM-11) |
| 4 Security | ⏭ next | open question C3 |
| 5 With Miko's app + battery | waits for Miko | HW-09, HW-10 final proof; HW-15; power saving (C2); status signals without a laptop |
| 6 Final box | waits for the print | HW-27 → HW-17 → HW-19 → HW-20 → HW-11 → HW-22 → HW-13; HW-16 |
| 7 Hardware papers | later | HW-07, HW-21, HW-12, HW-26 (figures), DEF-03 |

**Complete on the tracker:** HW-01, 02, 03, 04, 05, 06, 14, 18, 24, 25.
**For Review:** HW-08, HW-23 (Siemonne confirms the spools), HW-26 (pins
verified in §3 → can be Complete).
**In Progress:** HW-09, HW-10, HW-15 (Complete once DEC-18 is logged), HW-16.
**Not Started:** HW-07, 11, 12, 13, 17, 19, 20, 21, 22, 27.

Suggested tracker edits (Christian, by hand): HW-08 note "T5 passed on the
bench, Oct 25"; HW-26 → Complete.

### 16.1 ESP32 USB access in the finished box (HW-27 point 2)

- The ESP32's own micro-USB port is the **only way to upload new firmware**
  and to read the Serial Monitor. The box has no Wi-Fi, so no over-the-air
  updates (Bluetooth updates are possible but large and risky; not planned).
- The side USB port of the design charges the battery through the 134N3P; it
  has **no data path** to the ESP32, so it cannot be used for uploads.
- Options for the print student: (a) mount the ESP32 at an outside wall with a
  hole lined up with its micro-USB port (simplest); (b) a screwed or
  clip-on panel over the electronics. Either way leave room for the cable plug.
- Uploads normally need no button press. If this board ever needs BOOT held,
  a small pinhole over BOOT (and EN) helps; otherwise open the panel.
- Before plugging a PC cable into a battery-powered box, check that the board
  takes power from both safely (DevKit boards usually have a diode on the USB
  5 V line; to be checked on our board). If the box gets an on/off switch,
  switch the battery off while uploading.

### 16.2 When does the project go into Firebase?

- **The box never goes into Firebase.** Its firmware runs only on the ESP32,
  and the box has no internet and holds no key.
- What reaches Firebase is the box's **data**, through the patient's phone:
  Miko's app collects the dose events over Bluetooth (`events`) and writes them
  as `dose_logs` under the app's own dose id with `confirmed_via: "button"`,
  then sends `ack`. That is **Phase 5**, built by Miko against
  `BLE_PROTOCOL.md`, and tested together on the bench.
- Already in Firebase and used by the box design: the `devices` document
  (pairing by serial in the app) and `schedules.mat_box_column` (which
  compartment). Nothing to deploy from the box side; the Worker `/state` route
  stays switched off.
- The Firebase key in `healthsync-api/.dev.vars` is not needed by the box.

### 16.3 Oct 25 updates

- **ESP32 USB access: solved.** Christian: the box design has an open area
  over the ESP32, so its USB port stays reachable for uploads (HW-27 point 2).
- **Firebase (Christian's question):** Firebase *is* used. The box is not
  connected to it directly; the patient's phone carries the data both ways
  (schedule Firebase → app → box; doses box → app → Firebase). See 16.2.
- **`HARDWARE_ARCHITECTURE.md` updated:** the Step 3 pin map was already
  correct and is now marked re-checked against firmware 0.3.0. Also: parts list
  (18650, holder, 134N3P, Bluetooth ESP32, button rule), built-in LED = Bluetooth
  light, 4.2 debounce 80 ms and press-and-release, **4.6 Power rewritten for
  the 18650**, **new 4.7 "Voltage of each part"**, **Step 5 power budget without
  Wi-Fi** (about 50–75 mA typical, roughly one day per charge, estimates).
- **To confirm on the bench (marked "Check" in 4.7):** is the buzzer a 5 V or a
  3.3 V type, and is the microSD module the blue 5 V one (with a regulator) or a
  3.3 V breakout, and which pin feeds it?


---

## 17. Phase 4 plan: security (Oct 25, waiting for approval)

**Goal:** only the patient's paired phone can control the box (open question
C3, task 7.2.4). Today (Phase 3) any phone in range can connect and send
commands. The box itself still needs no key and no internet.

### 17.1 The two options

| | A. Bluetooth pairing with a passkey (recommended) | B. A secret word inside every message |
|---|---|---|
| How | Standard Bluetooth "Secure Connections" pairing. First time only, Android shows its normal "Bluetooth pairing request" box and the user types the box's **6-digit passkey** (printed on the label). After that the phone reconnects with no code, and every message is **encrypted** | The app adds a secret to every command; the box checks it |
| Strength | Encrypted link (AES); a nearby phone cannot read or send anything | The secret travels **unencrypted** over Bluetooth, so anyone listening could copy it, unless extra crypto is added |
| Work for Miko's app | Small: Android shows the pairing box by itself the first time the app writes to the box (or the app calls `createBond()`) | More: store the secret, add it to every message |
| What a panelist hears | "BLE Secure Connections with a passkey, the industry standard" | "A password in the message" |

### 17.2 Proposed behaviour (option A)

1. **Pairing mode:** with no LED lit, hold the button **5 s** (LEDs fill up 1→6)
   → pairing mode for **2 minutes**: LEDs 1 and 6 blink, one beep. Only then can
   a new phone pair.
2. The phone connects; Android asks for the PIN; type the box's passkey → the
   phone is **paired** (two beeps). Pairing mode closes.
3. Afterwards that phone reconnects at any time, without a PIN, encrypted.
4. **Any phone that is not paired** is disconnected at once (Serial: "not
   paired, rejected"), unless pairing mode is open and it knows the passkey.
   A wrong PIN fails and the box disconnects it.
5. The box remembers up to 3 paired phones (library default). Bench command
   `unpair` forgets them all (e.g. a new phone); `bonds` shows how many.
6. The command and reply characteristics require an encrypted, authenticated
   link; without pairing they cannot be used at all.

### 17.3 Files

| File | Change |
|---|---|
| `ble.cpp/h` | Security on (bonding, passkey, Secure Connections), encrypted characteristics, pairing window, reject unpaired phones, pairing result |
| `healthsync_box.ino` | 5 s hold (nothing lit) → pairing mode; LEDs 1 + 6 blink; beeps |
| `console.cpp/h` | `pair` (open pairing mode from the bench), `unpair`, `bonds` |
| `config.h` | `PAIRING_HOLD_MS 5000`, `PAIRING_WINDOW_MS 120000` |
| `secrets.h` / `config.example.h` | `BLE_PASSKEY` (6 digits per box; placeholder in the example) |
| `BLE_PROTOCOL.md` | New "Security" section for Miko |

Not touched: the app, the Worker, Firebase.

### 17.4 Phase 4 pass check (nRF Connect)

| # | Do | Expect |
|---|---|---|
| 1 | Connect without pairing mode | Box disconnects: "not paired, rejected" |
| 2 | Hold the button 5 s | LEDs 1 + 6 blink, one beep: pairing mode |
| 3 | Connect, write `{"op":"hello"}` | Android asks for a PIN; type the passkey → paired, two beeps, hello reply |
| 4 | Disconnect and reconnect (pairing mode closed) | Works with no PIN |
| 5 | Pair with a wrong PIN (after `unpair` + forgetting the box on the phone) | Pairing fails, box disconnects |
| 6 | `unpair` on the bench, then connect | Rejected until paired again (also tap "Forget" for HealthSync-0001 in Android's Bluetooth settings) |
| 7 | Alarm, button and log during all this | Unchanged |

### 17.5 Decisions (Oct 25)

- **Option A approved** (Bluetooth pairing, encrypted).
- **Pairing mode = press the button 5 times** (Christian), not a 5 s hold.
  Proposed rule so it never clashes with taking a dose: with a dose lit, the
  first press takes it at once and the rest of that burst is ignored; with
  nothing lit, quick taps are counted (a short tick each) and 5 taps less than
  about 1 s apart open pairing mode for 2 minutes, while 1–4 taps count as one
  normal press (early dose or "nothing due"). Side effect: with nothing lit, a
  single press answers about 1 s later. **Waiting for confirmation.**
- **How the user gets the 6-digit code (Christian's question):** the box has no
  screen. Proposed: the code is flashed into `secrets.h` and printed on a label
  under the box and on a card that comes with it; the care partner pairs once
  at setup. Alternative offered: no code ("Just Works"), pairing allowed only
  during the 2-minute window opened by the 5 presses (still encrypted; weaker
  against someone nearby at that moment). **Waiting for the choice.**

**Update Oct 25 (later):**
- **Code: on a label** (decided). The 6-digit passkey is flashed into
  `secrets.h` and printed on a label under the box and on a card; the care
  partner types it once at setup.
- **Hold vs. 5 presses:** Christian asked which avoids confusion. Recommended
  **hold 5 s**: an anxious patient taps repeatedly far more often than holding
  for 5 s; single presses stay instant (5 presses would delay every lone press
  by about 1 s); the LEDs filling up 1→6 show progress. Rule: with a dose lit, a
  press (up to 10 s) always takes the dose and never opens pairing; with
  nothing lit, 0.3–5 s = normal press, 5 s or more = pairing mode.
- **Pairing-mode signal:** a running light (LEDs 1→6 chasing) instead of LEDs 1
  and 6 blinking, so it cannot look like "take compartments 1 and 6".
- Waiting for Christian's final choice (hold or presses).


### 17.6 Phase 4 written (Oct 25), bench test pending

Decided: **option A**, the **code on a label**, **hold 5 s** (Christian chose it
over 5 presses after the comparison in 17.5), **running light 1→6** for
pairing mode. Firmware **0.4.0**, compiles with no errors or warnings (55%
flash).

- **The code:** a random 6-digit `BLE_PASSKEY` for HS-0001 is in `secrets.h`
  (git-ignored). Not written in these notes or the repo, by decision; print it
  on the label under the box and on the card. `config.example.h` has a
  placeholder.
- `ble.cpp/h`: LE Secure Connections + MITM + bonding, identity keys exchanged
  (Android changes its address every few minutes), characteristics need an
  encrypted, authenticated link, the box asks for encryption on every connect.
  **Pairing gate:** the library asks the firmware for the code; inside pairing
  mode it gets the label code, outside it a random one, so a new phone can never
  pair outside the window. A failed or missing pairing disconnects the phone; a
  phone that has not paired within 30 s is dropped.
- `healthsync_box.ino`: with nothing lit, holding 1–5 s fills the LEDs 1→6; at
  5 s pairing mode opens (one beep, running light, 2 min). A press that starts
  with a dose lit always takes the dose. Phone paired → two beeps, mode closes.
- `console.cpp`: `pair`, `bonds`, `unpair`.
- `BLE_PROTOCOL.md` §5 "Security" for Miko.

### 17.7 Phase 4 bench test with nRF Connect, step by step (Christian)

Setup: upload `healthsync_box.ino`, Serial Monitor 115200 / Newline, press
**EN**. Expect `fw 0.4.0, Phase 4: secure Bluetooth` and `advertising as
"HealthSync-0001", 0 paired phone(s)`. The 6-digit code is in `secrets.h`
(`BLE_PASSKEY`).

| # | Do | Expect |
|---|---|---|
| T1 | Without pairing mode: nRF Connect → SCAN → CONNECT. Android shows a pairing request: type the real code (or cancel) | Fails: Serial `phone not paired: rejected (pairing mode is closed)`, disconnected. Even the right code fails outside pairing mode |
| T2 | With nothing lit, hold the button 5 s | LEDs fill up 1→6, one beep, then a running light; Serial `PAIRING MODE for 2 minutes` |
| T3 | CONNECT; in Android's pairing request type the code from `secrets.h` | Serial `NEW PHONE PAIRED`, two beeps, running light stops. Then Request MTU 247, notifications on, write `{"op":"hello"}` → reply |
| T4 | DISCONNECT, then CONNECT again | No code asked; Serial `paired phone, encrypted link`; `hello` works |
| T5 | `unpair` in the Serial Monitor; on the phone: Settings → Bluetooth → HealthSync-0001 → Forget. Hold 5 s, connect, type a wrong code (e.g. 111111) | `pairing failed (wrong code?)`, disconnected |
| T6 | `add 3 HH:MM` (now + 1 min); when LED 3 lights, hold the button 6 s | The dose is TAKEN (two beeps); pairing mode does **not** open |
| T7 | Short press with nothing lit | `nothing due` (long beep), no pairing |
| T8 | Open pairing mode and wait 2 minutes without connecting | Serial `Pairing mode closed`, running light stops |
| T9 | Finally pair the phone again (T2 + T3) for the next tests | `bonds` → 1 |

If Android shows the pairing request as a notification instead of a dialog,
tap the notification. If nRF Connect shows old characteristics, use ⋮ →
Refresh services after connecting.

**Phase 4 bench results (Oct 25):**

| Test | Result |
|---|---|
| T2 hold 5 s | ✅ `PAIRING MODE for 2 minutes` |
| T3 pair with the code | ✅ `NEW PHONE PAIRED (passkey accepted)`, `Phone paired: pairing mode closed` |
| T4 reconnect | ✅ `paired phone, encrypted link`, no code; `hello` → fw 0.4.0 |
| T6 hold 6 s with a dose lit | ✅ `Dose TAKEN: compartment 1, 01:47 … on time`, `logged #10`; no pairing |
| T8 timeout | ✅ `Pairing mode closed` |
| T1, T5, T7 | not in the screenshots |

Notes: `secrets.h` on disk has `BLE_PASSKEY` (line 10); Christian's editor tab
showed an older copy (close and reopen it; do not save the old tab). The 60 s
disconnect in nRF Connect is the idle drop (`BLE_IDLE_DISCONNECT_MS`), on
purpose for connect-on-demand; can be raised to 3 min for testing.

### 17.8 Change requests after Phase 4 (Oct 25), plan waiting for approval

Christian asked for: (1) no early take (a press before the alarm might be an
accident); (2) missed after 30 min, or an alarm every 5 min, or a better
suggestion; (3) a different, long (not short) beep for every buzzer event.

Proposed:
1. **No early take.** A press with nothing lit → "nothing due" beep only,
   nothing recorded. `EARLY_WINDOW_MIN` and the `early` timing go.
2. **Keep missed at 60 min** (same as the app, the Worker and the care partner
   alerts: late at 30, missed at 60; the paper says 60). **Alarm every 5 min**
   instead of every minute, until taken or missed (12 alarms); the LED stays on.
   Missed at 30 is possible but the box and the app would disagree between 30
   and 60 min.
3. **Beep patterns** (nothing shorter than 0.5 s): power on 1 × 1 s; dose alarm
   3 × 0.8 s every 5 min; taken 2 × 0.6 s; nothing due 1 × 2 s; pairing mode
   opened 4 × 0.5 s; phone paired 1 s + 0.5 s + 1 s. Missed stays silent.


**Phase 4: COMPLETE (Oct 25).** Christian ran every test (T1–T9), including
T1 (rejected outside pairing mode), T5 (wrong code) and T7 (short press).
The 60 s idle disconnect stays: nRF Connect is only a test tool; the
presentation uses the real app.

### 17.9 Changes after Phase 4, done (Oct 25, firmware 0.4.1)

Decided by Christian: missed stays at **60 min**; every buzzer event is **one
straight (continuous) tone**, lengths chosen by Claude; whether to keep the
early take left to Claude.

- **Early take removed.** A press only takes a dose that is lit; with nothing
  lit it takes nothing and plays the "nothing due" tone (a press before the
  alarm may be an accident). Early logging stays an app-only action.
- **Tones** (`config.h`, `TONE_*`), each a different length, none short:

| Event | Tone |
|---|---|
| Dose alarm | 5 s, repeated every 5 min until taken or missed (+60 min) |
| Phone paired | 3 s |
| Pairing mode opened | 2 s |
| Dose taken (button) | 1.5 s |
| Power on | 1 s |
| Nothing due / clock not set | 0.8 s |

  A missed dose stays silent (LED off; the phone reports it later).
- The tones no longer freeze the box: `buzzer_tone(ms)` plays in the
  background (over the alarm); only the power-on tone blocks.
- Files: `config.h`, `buzzer.cpp/h` (rewritten), `schedule.cpp/h`
  (`schedule_take(nowLocal)`, no early branch), `healthsync_box.ino`,
  `storage.h` (comment), `BLE_PROTOCOL.md` (timing `on_time`/`late` only, alarm
  rule, signals), `HARDWARE_ASSESSMENT.md` 1.6, `HARDWARE_ARCHITECTURE.md` open
  decision 4. Compiles with no errors or warnings, 55% flash.

**Quick bench check for 0.4.1:**
1. Upload, press EN → a 1 s tone at power on.
2. `add 2 HH:MM` (now + 1 min) → LED 2 + a 5 s tone; 5 min later the 5 s tone
   again.
3. Press and let go → TAKEN, 1.5 s tone.
4. `add 4 HH:MM` (now + 10 min) and press right away → `nothing due`, 0.8 s
   tone; `status` still shows it `upcoming`; `log` has no new line.
5. Hold 5 s with nothing lit → 2 s tone + running light. To hear the 3 s
   "paired" tone: `unpair`, forget the box on the phone, then pair again.
6. A dose left for 60 min (or a clock jump) → LED off, no sound.
