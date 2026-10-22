# HealthSync Firmware Architecture
# firmware/healthsync_box/

> Status: Phase 1 written (Oct 19, 2026), waiting for the Firebase key to test;
> Phase 3 written (Oct 20, 2026), bench testing. See WORK_NOTES.md
> Branch: `feature/medbox-integration` (never `main` or `release`)
> Author: Christian
> Last updated: October 19, 2026

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). The box now
> talks to the patient's phone over BLE, connect-on-demand: no Wi-Fi, no
> hotspot, no direct box-to-cloud link, no device secret. This file describes
> the earlier Wi-Fi/Worker design (Worker polling, Phases 1–5 as written,
> WiFiManager setup, device key). It is kept for the record; the sections
> that depend on that link are marked below. The pin map and the hardware
> list are not changed by this decision.

---

## Overview

The app is finished. The care partner sets each medicine, its dose times and
its compartment in the app. The box does what the app's schedule says:

- at dose time, the **LED of that compartment turns on** and the **buzzer sounds**
- the **button** silences them (Phase 1) and later confirms the dose (Phase 2)

The box **never talks to Firestore directly** and **never talks to the phone**.
Both the box and the app talk to the cloud:

```
Box ──Wi-Fi──► Cloudflare Worker ──► Firestore ◄── App (phone)
```

So the box needs its own Wi-Fi connection. It does not use the phone's.

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). Proposed path
> now: care partner edits schedule → Firebase/Worker → patient's phone → BLE
> → box. The box has no Wi-Fi.

---

## Build phases (in order of importance)

One phase at a time. A phase is done only when its pass check works on the
real box.

| Phase | Goal | Pass check |
|---|---|---|
| **1 — LED + buzzer sync (MVP)** | Box polls the Worker every 60 s and lights the compartment(s) whose dose is due, with the buzzer. Button only silences the box locally (temporary). | A dose set in the app lights the right LED and beeps at dose time; tapping Done in the app turns it off within 60 s |
| **2 — Button confirms the dose** | Button press marks the dose taken (`confirmed_via: "button"`) and the care partner is notified | Press the button → app shows the dose taken, care partner gets the push |
| 3 — Wi-Fi setup hotspot | Replace the hardcoded Wi-Fi with a setup hotspot (WiFiManager) | A new Wi-Fi network can be set from a phone with no re-flash |
| 4 — Offline (RTC + SD card) | DS3231 keeps time; SD holds the schedule and queues button presses while offline | Router off → LED still lights on time; press is sent after reconnect, once |
| 5 — Device key | Each box sends a secret key; the Worker refuses unknown boxes | Wrong key → `401` |

Phases 3–5 can be reordered by the team. Phase 3 was built before Phase 2
(Oct 20) because it does not need the Firebase key.

**Since Phase 3** the home Wi-Fi is chosen on the box's setup page and saved
in the ESP32's flash. It is no longer typed into any file.

---

## Hardware in this build

6 compartments, so **6 LEDs**, one push button, one active buzzer, DS3231 RTC
and a microSD module. Nothing else.

### Pin map (frozen, matches the physical wiring)

| Function | GPIO | Notes |
|---|---|---|
| LED compartment 1 | 13 | |
| LED compartment 2 | 14 | Flickers briefly at boot. Harmless |
| LED compartment 3 | 25 | |
| LED compartment 4 | 26 | |
| LED compartment 5 | 32 | |
| LED compartment 6 | 33 | |
| Active buzzer | 17 | HIGH = sound |
| Push button | 16 | 6 mm **NC** panel button, GPIO 16 → button → GND, `INPUT_PULLUP`: idle LOW, **pressed HIGH** (`BUTTON_PRESSED_LEVEL`) |
| microSD SCK | 18 | |
| microSD MOSI | 19 | See SPI note |
| microSD MISO | 23 | See SPI note |
| microSD CS | 15 | Strapping pin; the SD module's pull-up keeps it high at boot. Fine |
| DS3231 SDA | 21 | Default I2C |
| DS3231 SCL | 22 | Default I2C |
| Built-in LED | 2 | Optional Wi-Fi status light |

**SPI note:** the ESP32's standard SPI pins are MISO 19 and MOSI 23. Our wiring
has them the other way round. The ESP32 can route SPI to any pins, so the
firmware follows the wiring:

```cpp
SPI.begin(/*SCK*/ 18, /*MISO*/ 23, /*MOSI*/ 19, /*CS*/ 15);
SD.begin(15, SPI);
```

If the card will not start, swap MISO and MOSI in `config.h` before checking
anything else.

**GPIO 16 and 17** are free on an ESP32-WROOM board. On a WROVER board they
belong to PSRAM and cannot be used.

### Compartments 7 and 8

The app lets the care partner pick compartments 1–8; this box has 6. A
medicine set to 7 or 8 still gets phone reminders, but no LED lights. The
firmware ignores 7 and 8. Tell care partners to use 1–6.

---

## File responsibilities

| File | What it does | Phase |
|---|---|---|
| `healthsync_box.ino` | `setup()` and `loop()` only, calls the modules, no logic | 1 |
| `config.h` | Pins, poll interval, Worker URL | 1 |
| `secrets.h` | `DEVICE_SERIAL`, `SETUP_AP_PASSWORD` (later `DEVICE_KEY`). Git-ignored, flashed per box | 1, 3 |
| `config.example.h` | Safe-to-commit template for `secrets.h`, **placeholders only** | 1, 3 |
| `net.cpp/h` | Wi-Fi (saved network + setup hotspot via WiFiManager), `GET /state`, later `POST /dose` | 1, 2, 3 |
| `leds.cpp/h` | `leds_init()`, `leds_set(mask)`, `leds_all_off()`, `leds_self_test()` | 1 |
| `buzzer.cpp/h` | Non-blocking beep pattern while a dose is due | 1 |
| `button.cpp/h` | Debounced press detection | 1, 2 |
| `rtc_clock.cpp/h` | DS3231 read/write, NTP sync | 4 |
| `storage.cpp/h` | SD: `schedule.json`, `queue.jsonl` | 4 |
| `schedule.cpp/h` | Offline "what is due now" | 4 |

---

## Phase 1 — LED + buzzer sync (MVP)

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). Polling
> `GET /device/{serial}/state` over Wi-Fi is replaced by alarms from the
> stored schedule and the DS3231 (proposed). Kept for the record.

### What it does

1. Boot self-test: each LED 1→6 lights for 150 ms, one buzzer chirp
2. Connect to the saved Wi-Fi (set through the Phase 3 setup hotspot)
3. Every 60 s: `GET /device/{serial}/state`
4. Light exactly the compartments in `lit`, all others off
5. Buzzer beeps while a lit dose is not silenced
6. Button press: LEDs and buzzer off **on the box only** (temporary, see below)

### Worker endpoint: `GET /device/{serial}/state`

Response:
```json
{
  "server_time": "2026-10-19T00:02:11Z",
  "lit": [3, 5],
  "buzz": true
}
```

- `lit` = compartments that have a dose `pending` or `snoozed` whose
  `scheduled_at` is between 60 minutes ago and now, and whose schedule has a
  `mat_box_column`. The Worker works this out from `dose_logs`, which the
  materializer already creates every 5 minutes.
- `buzz` = false when every lit dose is snoozed in the app and its
  `snoozed_until` has not passed yet; otherwise true.
- When the patient taps Done or Skip in the app, the dose stops being pending,
  so the next poll drops it from `lit` and the LED turns off within 60 s.
- At +60 min the Worker's sweep marks the dose missed, which also drops it.
- Every call also updates the device doc: `status: "online"`, `last_sync`.

> ⚠️ **The current `healthsync-api/src/handlers/device.ts` does not do this.**
> It lights LEDs from `schedules.led_active`, and nothing in the app or the
> Worker ever sets `led_active` to true (checked Oct 19: `setColumnLedStatus`
> has no callers). With it, no LED would ever light. It also returns
> `compartments` instead of `lit` and uses the UTC date instead of Manila's.
> Phase 1 needs the Worker changed to the contract above.

### Buzzer pattern (proposed)

- From dose time: 3 short beeps every 1 minute for the first 10 minutes
- Then 3 short beeps every 5 minutes
- Stops when the compartment leaves `lit` (taken or skipped in the app, or
  missed at +60) or when the button is pressed

Non-blocking (`millis()`), never `delay()`, so the button and polling keep
working while it beeps.

> OPEN: quiet hours (for example no buzzer 10 PM–7 AM)? Default: always beep.

### Button in Phase 1 (temporary)

| Condition | Action |
|---|---|
| Press while LEDs are lit | All LEDs and buzzer off at once. The box remembers those compartments as **silenced** and does not relight them on the next polls |
| A compartment leaves `lit` | It is no longer silenced (nothing to remember) |
| A new compartment appears in `lit` | It lights and beeps as normal |
| Press with nothing lit | Ignored |

Nothing is sent to the Worker. The dose still has to be confirmed in the app.
Phase 2 replaces this.

### Main loop (Phase 1)

```
setup():
  Serial 115200
  leds_init(), buzzer_init(), button_init()
  leds_self_test()            → 1→6, 150 ms each, one chirp
  net_begin()                 → saved Wi-Fi, 15 s timeout (or setup, Phase 3)
  poll once

loop() — non-blocking, no delay():
  every loop   → button_update(); on press → silence lit compartments
  every loop   → buzzer_update()  (runs the beep pattern)
  every 60 s   → if Wi-Fi down: try to reconnect
                 GET /state → leds_set(lit − silenced), buzzer on/off
                 on failure: keep the last state
```

### LED behaviour

| Condition | LEDs | Buzzer |
|---|---|---|
| Dose due | Compartment LED on | Beep pattern |
| Dose due, silenced by button | Off | Silent |
| No dose due | All off | Silent |
| Worker unreachable | Keep last state | Keep last state |
| Self-test on boot | 1→6, 150 ms each | One chirp |

---

## Phase 2 — Button confirms the dose

### What it does

1. Patient presses the button for ≥300 ms (a bump of the box does not count)
2. All lit LEDs and the buzzer turn off at once
3. Box sends `POST /device/{serial}/dose`
4. The Worker marks those doses taken, `confirmed_via: "button"`, the same way
   the app's Done button does (timing, pill count −1)
5. The care partner gets the push

### Worker endpoint: `POST /device/{serial}/dose`

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). The box no
> longer posts to the Worker. A press becomes a timestamped dose event on the
> microSD that the phone pulls on the next connect (proposed). How "dose
> taken" is recorded is an open question (Christian, C5). Kept for the record.

Request body:
```json
{
  "event_id": "HS-0001-1760313731",
  "pressed_at": "2026-10-19T00:02:11Z",
  "columns": [3, 5]
}
```

- `event_id` = `{serial}-{unix time}`. Sending the same one twice does
  nothing, so a retry after a timeout is safe.
- `columns` = every compartment lit at the moment of the press.

Response: `{ "confirmed": [3, 5], "ignored": [] }`. A column is ignored when
the dose was already taken in the app or nothing was due.

### Button behaviour (Phase 2)

| Condition | Action |
|---|---|
| ≥300 ms press, LEDs lit | LEDs + buzzer off → `POST /dose` |
| ≥300 ms press, nothing lit | One low beep ("nothing due") |
| Press < 300 ms | Ignored |
| Press, then Done in the app | First wins; the second does nothing |

> OPEN (decide before Phase 2): one press with several LEDs lit confirms
> **all** of them (recommended, simplest for elderly users) or one per press?

---

## Phase 3 — Wi-Fi setup hotspot (written Oct 20, 2026)

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). No Wi-Fi and no
> hotspot. The code for this phase is still in `net.cpp` on this branch; this
> doc update does not change code. Kept for the record.

| When | What the box does |
|---|---|
| No Wi-Fi saved | Opens its hotspot `HealthSync-0001` at once and keeps it open |
| Button held **5 s at any time while no LED is lit** (LEDs fill up 1→6 while held) | Opens the hotspot, one beep. The saved Wi-Fi is kept until a new one is saved. Holding 5 s again **in setup closes it** and rejoins the saved Wi-Fi |
| Saved Wi-Fi missing for **5 min** (new router, new password, moved house) | Opens the hotspot by itself. If nobody joins within 5 min it closes it and retries the saved Wi-Fi for 5 min, and so on, so a Wi-Fi that comes back is rejoined |
| Short outage (router restart) | No hotspot; reconnects by itself |

In setup mode: compartment **LEDs 1 and 6 blink** together (1 s), one beep on
entering; no polling. The hotspot needs `SETUP_AP_PASSWORD` (8+ characters,
on the label). The setup page (WiFiManager, at `192.168.4.1`, opens by itself
on most phones) is titled "HealthSync box setup" and shows only "Configure
WiFi". After **Save** the box joins that Wi-Fi, gives **two beeps**, closes
the hotspot and polls at once. A wrong password keeps it in setup.

The Wi-Fi is saved in the ESP32's flash: it survives power cuts and firmware
uploads. A phone's mobile hotspot works as the network, but then the box only
works while that hotspot is on. The ESP32 supports **2.4 GHz only**.

Library: `WiFiManager` 2.0.17 (tzapu). No app or Worker change.
Flash use: 87% of the default 1.3 MB app partition. Phase 4 will likely need
Tools → Partition Scheme → **Huge APP (3MB No OTA/1MB SPIFFS)**.

---

## Phase 4 — Offline (later)

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). Proposed: the
> phone sets the DS3231 time and pushes the schedule over BLE; the box logs
> dose events on the microSD and the phone pulls them on the next connect.
> No NTP, no `GET /schedule`, no replay to the Worker. Kept for the record.

1. **Time:** NTP on boot and every 6 h, written to the DS3231 (stored as UTC,
   compared in Manila time, UTC+8)
2. **Schedule:** `GET /device/{serial}/schedule` on boot and when it changes,
   saved to `schedule.json` on the SD card (6 columns, 24-hour times, no
   medicine or patient names)
3. **LEDs offline:** lit from `schedule.json` + DS3231, same window as `/state`
4. **Button offline:** one line appended to `queue.jsonl`, LEDs off in RAM
5. **Reconnect:** replay `queue.jsonl` oldest first; delete a line only after
   a `200`. A press inside the window corrects a dose the sweep marked missed

---

## Phase 5 — Device key (later)

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). The device-key
> endpoints are not planned. How the box refuses writes from other phones
> (bonding with a passkey, or an app-level secret) is undecided (Christian,
> C3). Kept for the record.

- Each box gets a `DEVICE_KEY` (32 random characters) in `secrets.h`
- Every request sends `X-Device-Key`; the Worker compares its hash with a
  `device_registry` collection that no client can read or write
- Wrong key → `401`

---

## Device states

```
power on
   │
   ▼
┌─────────┐
│  BOOT   │ self-test
└────┬────┘
     ▼
┌─────────┐   connected   ┌──────────┐
│ CONNECT │ ────────────► │  ONLINE  │ ◄─┐
└────┬────┘               └────┬─────┘   │ reconnect
     │ 15 s timeout            │ Wi-Fi / │
     ▼                         │ Worker  │
┌─────────┐ ◄──────────────────┘  down   │
│ OFFLINE │ ─────────────────────────────┘
└─────────┘  (retry every 60 s)
```

Phase 3 adds a SETUP state (hotspot): entered when no Wi-Fi is saved, by the
5-second button hold (nothing lit), or from OFFLINE after 5 minutes without
Wi-Fi. Left by saving a Wi-Fi, by the same hold, or after 5 unused minutes
when a Wi-Fi is saved.

The box always tries the saved Wi-Fi first at boot and only then asks whether
one is saved: asked earlier, the ESP32 can wrongly answer "no" (bench, Oct 20).

---

## Security

- The box **never holds the Firebase service account key**
- `secrets.h` is git-ignored. `config.example.h` holds placeholders only:
  **never commit a real Wi-Fi name or password** (since Phase 3 the home
  Wi-Fi is not in any file at all)
- The setup hotspot is password-protected, so a neighbour cannot change the
  box's Wi-Fi
- Until Phase 5 the Worker trusts the serial alone. Acceptable for bench
  testing and the demo, not for real use

---

## Libraries (Arduino IDE)

| Library | Install from | Used for | Phase |
|---|---|---|---|
| `WiFi`, `HTTPClient`, `WiFiClientSecure` | ESP32 core (built-in) | Wi-Fi and HTTPS | 1 |
| `ArduinoJson` v7 | Library Manager | Parse `/state` | 1 |
| `WiFiManager` by tzapu | Library Manager | Setup hotspot | 3 |
| `RTClib` by Adafruit | Library Manager | DS3231 | 4 |
| `SD`, `SPI` | ESP32 core (built-in) | microSD | 4 |
| `Preferences` | ESP32 core (built-in) | Device key in flash | 5 |

---

## Work needed outside the box (Worker side)

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](../../BLE_CONNECT_ON_DEMAND.md). No Worker
> device endpoints are planned. The work outside the box moves to the app
> (owner Miko). Kept for the record.

| Phase | File | Work |
|---|---|---|
| 1 | `healthsync-api/src/handlers/device.ts` | Rewrite `GET /state` to the Phase 1 contract (`lit` from `dose_logs`, Manila time, `buzz`, heartbeat) |
| 1 | `healthsync-api/src/index.ts` | Route `/device/{serial}/*` (prefix match). Already added, uncommitted |
| 1 | `firestore.indexes.json` | `dose_logs` index for the `/state` query, if not already there |
| 2 | `device.ts` | `POST /dose` per the Phase 2 contract, with care partner push |
| 4 | `device.ts` | `GET /schedule` for the offline cache |
| 5 | `firestore.rules`, `tool/` | `device_registry`, key generator script |

---

## Open decisions

| # | Decision | Recommendation | Needed by |
|---|---|---|---|
| 1 | LED source: `lit` from `dose_logs` (Worker) vs. something setting `led_active: true` | `lit` from `dose_logs` | Phase 1 |
| 2 | Buzzer quiet hours | Discuss with team; default always beep | Phase 1 |
| 3 | LED from dose time, or 30 min before (app unlock) | From dose time | Phase 1 |
| 4 | Worker URL for the box | The deployed Worker, not a temporary `trycloudflare.com` tunnel | Phase 1 |
| 5 | One press with several LEDs lit | Confirm all | Phase 2 |
| 6 | Different care partner wording for a button confirmation | Yes, "confirmed on the medicine box" | Phase 2 |

---

## Known differences from the app (not changed: the app is final)

1. **Compartments 1–8 in the app, 6 on the box.** See "Compartments 7 and 8".
2. **`pairDevice` writes `status: "online"`** the moment the serial is typed,
   before the box has connected. The box's first `/state` call sets it
   properly afterwards.
3. **`device_type`** is `"esp32_smart_box"` in the app's model (CLAUDE.md says
   `"medicine_box"`). The box never sends it, so it does not matter here.
