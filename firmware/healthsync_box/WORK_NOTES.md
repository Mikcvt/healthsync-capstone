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

## ⚠️ Oct 22: read this first

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

Full task-by-task review: `TRACKER_REVIEW_2026-10-22.md`.

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

## 0. Start here — status at the end of October 20, 2026

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). The Wi-Fi,
> Worker (`/state`), Firebase-key and setup-hotspot items and the "next
> steps" in this section belong to the old link. The bench results for the
> LEDs, buzzer, SD card and DS3231 still stand. Kept for the record.

| Item | Status |
|---|---|
| Phase 1 firmware (LED + buzzer sync) | ✅ Written, compiles. ⏳ Not yet tested against real Firebase data |
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
> The new firmware tasks are in ACTION_PLAN.md Step 7. Kept for the record.

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
