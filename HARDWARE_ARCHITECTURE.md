# HealthSync Smart Medicine Box — Hardware Architecture

> Status: **DRAFT for team review** (October 13, 2026; updated October 19, 2026
> for the 6-compartment build and the confirmed wiring)
> Scope: the ESP32 box, how it is wired, what its firmware does, and how it talks
> to the cloud. The Flutter app and the Worker are covered only where the box
> touches them.
>
> Read it in order. Each step builds on the one before it. Anything marked
> **DECIDE** is a choice the team has to make before writing firmware.
>
> The firmware is built in phases (Step 8.0): **Phase 1** LED + buzzer sync,
> **Phase 2** button confirms the dose, then Wi-Fi setup, offline and device
> key. `firmware/healthsync_box/FIRMWARE_ARCHITECTURE.md` has the detail.

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). The box now talks to
> the patient's phone over BLE, connect-on-demand: no Wi-Fi, no hotspot, no
> direct box-to-cloud link, no device secret. Every part of this file that
> describes the Wi-Fi/HTTPS link to the Worker (Steps 0, 2, 6, 7, 8, 9, 10
> and 12) is kept for the record and marked below. The wiring steps are not
> superseded by this decision, but see the hardware conflicts listed in
> BLE_CONNECT_ON_DEMAND.md §9.

---

## Step 0 — What the box is (and is not)

The box is a **display and a button**. It is not where dose logic lives.

| The box DOES | The box does NOT |
|---|---|
| Light the LED of the compartment whose dose is due | Decide on its own that a dose is due (except when offline, Step 9) |
| Beep the buzzer while a dose is due | Measure heart rate, SpO2, battery, or anything else |
| Let the patient press one button to confirm "I took it" | Send SMS, talk to a smartwatch, or scan QR codes |
| Keep time with the DS3231 when Wi-Fi is down | Hold the Firebase service account key |
| Queue button presses on the microSD card while offline, and send them later | Store medicine names, patient names, or any health data beyond the queue |

Hardware in this build, and nothing else: **ESP32, 6 LEDs (6 compartments), 1 push
button, 1 active buzzer, DS3231 RTC, microSD module.** (See "No phantom features"
in `CLAUDE.md`.)

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). The box now syncs
> with the patient's phone over BLE and has no Wi-Fi. The paragraph below is
> kept for the record.

The box does **not** connect to the phone and does not use the phone's
internet. The box and the app each talk to the cloud on their own, so the box
needs its own Wi-Fi (Step 10).

---

## Step 1 — Bill of materials

Check each line against what is on your bench. The "Why" column is what a
panelist will ask.

| # | Part | Qty | Notes / why |
|---|---|---|---|
| 1 | ESP32 dev board (ESP32-WROOM-32, 30 or 38 pin DevKit V1) | 1 | Wi-Fi + enough GPIO for 6 LEDs, I2C and SPI. **Must be WROOM: GPIO 16/17 are PSRAM on a WROVER (Step 3).** |
| 2 | 5 mm LEDs | 6 | Red, yellow, or green. Avoid blue/white: they need ~3.0 V and will be dim on a 3.3 V pin. |
| 3 | 220 Ω resistors | 6 | One per LED, current limit (~5–6 mA each). |
| 4 | Tactile push button (12 mm recommended, easy to press for elderly users) | 1 | Silences the box (Phase 1), confirms the dose (Phase 2). |
| 5 | ~~10 kΩ resistor~~ | 0 | Not needed: the button goes to GND and uses the ESP32's internal pull-up. |
| 6 | Active buzzer (5 V or 3.3 V type) | 1 | *Active* = beeps on DC, no PWM tone needed. |
| 7 | NPN transistor (2N2222, S8050, or BC547) + 1 kΩ resistor | 1 + 1 | Drives the buzzer. Most buzzers draw 25–30 mA, more than an ESP32 pin should supply. |
| 8 | 1N4148 diode | 1 | Optional, across the buzzer (protects the transistor from back-EMF). |
| 9 | DS3231 RTC module (usually "ZS-042") + coin cell | 1 | Keeps time with no Wi-Fi and no power. Read the battery warning in Step 6. |
| 10 | MicroSD card module (SPI) + microSD card ≤ 32 GB | 1 | Offline queue and schedule cache. Format FAT32. |
| 11 | 5 V 2 A USB power adapter + cable | 1 | Wi-Fi transmit spikes need the headroom. |
| 12 | Breadboard / perfboard, jumper wires, enclosure with 6 compartments | — | |

---

## Step 2 — Block diagram

```
                         ┌────────────────────────────────────────────┐
   5 V USB adapter ─────►│               ESP32 DevKit                 │
                         │                                            │
                         │  GPIO 13,14,25,26,32,33 ──► 6 LEDs         │──► Compartments 1–6
                         │                                            │
   Push button ─────────►│  GPIO 16  (input, internal pull-up, to GND)│
                         │                                            │
                         │  GPIO 17  ──► NPN ──► Active buzzer        │
                         │                                            │
                         │  I2C  SDA 21 / SCL 22 ◄──► DS3231 RTC      │
                         │                                            │
                         │  SPI  SCK 18 / MISO 23 /                   │
                         │       MOSI 19 / CS 15 ◄──► microSD module  │
                         │                                            │
                         │  Wi-Fi ◄──────────────────────────────┐    │
                         └───────────────────────────────────────┼────┘
                                                                 │ HTTPS
                                                                 ▼
                                              ┌────────────────────────────┐
                                              │ Cloudflare Worker          │
                                              │ GET  /device/{serial}/...  │
                                              │ POST /device/{serial}/dose │
                                              └─────────────┬──────────────┘
                                                            │ service account
                                                            ▼
                                              ┌────────────────────────────┐
                                              │ Firestore                  │
                                              │ devices, schedules,        │
                                              │ dose_logs, notifications   │
                                              └─────────────┬──────────────┘
                                                            │ live streams
                                                            ▼
                                              Patient app  ·  Care Partner app
```

The box **never talks to Firestore directly.** It only talks to the Worker
(Step 7 explains why).

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). The Wi-Fi → HTTPS →
> Worker path in the diagram above is replaced by box ◄─BLE─► patient's
> phone → Firebase/Worker. The box still never talks to Firestore directly.

---

## Step 3 — Pin map (and pin cautions)

| Function | GPIO | Direction | Caution |
|---|---|---|---|
| LED compartment 1 | 13 | Output | — |
| LED compartment 2 | 14 | Output | Flickers briefly at boot (ESP32 outputs a PWM signal on 14). Harmless for an LED. |
| LED compartment 3 | 25 | Output | — |
| LED compartment 4 | 26 | Output | — |
| LED compartment 5 | 32 | Output | — |
| LED compartment 6 | 33 | Output | — |
| Push button | 16 | Input | Wired GPIO 16 → button → GND. `INPUT_PULLUP`, pressed = LOW. **On a WROVER board GPIO 16/17 belong to PSRAM — do not use.** On WROOM it is fine. |
| Active buzzer (via NPN) | 17 | Output | HIGH = sound. Same WROVER caution as GPIO 16. |
| DS3231 SDA | 21 | I2C | Default I2C pins. |
| DS3231 SCL | 22 | I2C | Default I2C pins. |
| microSD SCK | 18 | SPI | — |
| microSD MOSI | 19 | SPI | Swapped vs. the ESP32 default (see below). |
| microSD MISO | 23 | SPI | Swapped vs. the ESP32 default (see below). |
| microSD CS | 15 | SPI | **Strapping pin.** The SD module's pull-up keeps it high at boot, which is the normal state. Harmless. |
| (built-in LED) | 2 | Output | Optional Wi-Fi status light. Already on the board, not a new feature. |

Wiring confirmed against the bench box on October 19, 2026.

Pins deliberately **not** used: 0, 5 (strapping), 6–11 (flash), 12 (strapping —
pulled high at boot it bricks the boot), 34–39 (input-only).

**Only 6 compartments.** The app lets the care partner pick compartments 1–8.
A medicine set to 7 or 8 still gets phone reminders, but no LED lights; the
firmware ignores those numbers. Care partners should use 1–6. (The app is
final, so this is a usage rule, not an app change.)

**SPI pins.** The ESP32's standard SPI pins are MISO 19 and MOSI 23; our wiring
has them the other way round. The ESP32 can route SPI to any pins, so the
firmware follows the wiring and starts SPI explicitly:

```cpp
SPI.begin(/*SCK*/ 18, /*MISO*/ 23, /*MOSI*/ 19, /*CS*/ 15);
SD.begin(15, SPI);
```

If the card will not start, swap MISO and MOSI before checking anything else.

---

## Step 4 — Wiring each part

Wire and test **one subsystem at a time** (Step 11 has the test for each).
All grounds join: ESP32 GND, LED cathodes, button, transistor emitter,
DS3231 GND, SD GND.

### 4.1 LEDs (×6)

```
GPIO ──[220 Ω]──►|── GND
              anode  cathode (short leg, flat side)
```

- HIGH = on, LOW = off.
- Current per LED ≈ (3.3 V − 2.0 V) / 220 Ω ≈ 6 mA. Even all 6 on is ~36 mA,
  well inside the ESP32's total budget.

### 4.2 Push button

```
GPIO 16 ──[button]── GND        (internal pull-up enabled in firmware)
```

- Not pressed = HIGH, pressed = LOW (active-low). `pinMode(16, INPUT_PULLUP)`.
- No external resistor needed. Never connect the button to 5 V.
- Debounce in firmware (50 ms). From Phase 2, require a **press of ≥ 300 ms**
  so a bump of the box does not confirm a dose.

### 4.3 Active buzzer

```
            5 V (or 3.3 V for a 3.3 V buzzer)
              │
          [buzzer +]
          [buzzer −]──┬──────┐
                      │      ┴ 1N4148 (optional, cathode to +)
                      C
GPIO 17 ──[1 kΩ]──── B   NPN (2N2222 / S8050)
                      E
                      │
                     GND
```

- GPIO 17 HIGH = beep.
- The transistor lets a 5 V buzzer run from a 3.3 V pin and keeps the
  current off the ESP32.

### 4.4 DS3231 RTC

| DS3231 pin | ESP32 |
|---|---|
| VCC | 3.3 V |
| GND | GND |
| SDA | GPIO 21 |
| SCL | GPIO 22 |
| SQW, 32K | not connected |

- I2C address `0x68` (the ZS-042 board also has an EEPROM at `0x57`; ignore it).
- The module already has pull-up resistors on SDA/SCL. Do not add more.

### 4.5 microSD module

| SD module pin | ESP32 |
|---|---|
| VCC | **see note** |
| GND | GND |
| SCK | GPIO 18 |
| MOSI | GPIO 19 |
| MISO | GPIO 23 |
| CS | GPIO 15 |

**Power note — the most common SD failure:** the usual blue module has a 3.3 V
regulator (AMS1117) and level shifter on it, so it needs **5 V on VCC** (from
the ESP32 `VIN`/`5V` pin). Fed 3.3 V it initialises randomly or not at all. A
bare breakout with no regulator takes **3.3 V**. Look at your board before wiring.

### 4.6 Power

- USB 5 V 2 A adapter into the ESP32's USB port, or 5 V into `VIN`.
- The ESP32's onboard regulator supplies 3.3 V to the LEDs, button and DS3231.
- The SD module (if 5 V type) and a 5 V buzzer take from `VIN`/`5V`.

---

## Step 5 — Power budget

| Load | Typical | Peak |
|---|---|---|
| ESP32 with Wi-Fi | 80–120 mA | ~350 mA (transmit burst) |
| LEDs (usually 1–2 lit, max 6) | 6–12 mA | 36 mA |
| Buzzer | 0 | 30 mA |
| DS3231 | < 1 mA | — |
| microSD (write) | 1 mA idle | ~100 mA |
| **Total** | **~150 mA** | **~520 mA** |

A 5 V 1 A adapter would work; 2 A gives margin for a cheap cable's voltage
drop. There is **no battery in this build**, so if the box is unplugged it does
nothing until power returns (the DS3231 keeps the time meanwhile).

---

## Step 6 — Timekeeping

> **SUPERSEDED in part by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). There is no Wi-Fi, so
> no NTP: the proposed design has the phone set the DS3231 time on each BLE
> connect. Items 1 and 4 below are kept for the record.

The box must know the time to light LEDs when Wi-Fi is down.

1. **On boot / every 6 hours while online:** get the time by NTP
   (`pool.ntp.org`) and write it into the DS3231.
2. **Always:** read the time from the DS3231, never from `millis()`.
3. **Store UTC** in the DS3231. Convert to Manila time (UTC+8, no daylight
   saving) only for comparison with `scheduled_time`.
4. DS3231 drift is about ±1 minute per year; NTP corrects it anyway.

**Coin cell warning (ZS-042 boards):** the board has a charging circuit
(a 200 Ω resistor and a diode near the battery holder) meant for a
*rechargeable* LIR2032. With a normal CR2032 it slowly charges a
non-rechargeable cell, which can swell or leak. Either use an LIR2032, or
desolder/cut that resistor and keep the CR2032.

---

## Step 7 — How the box talks to the cloud

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). The box no longer
> talks to the cloud. The device key (7.2), the `/device/{serial}/…`
> endpoints (7.3) and the polling cost (7.4) are not planned any more. All of
> Step 7 is kept for the record. The point in 7.1 still holds: the box must
> never hold the Firebase service account key.

### 7.1 Through the Worker, not Firestore

`CLAUDE.md` currently says *"Auth: ESP32 uses Firebase service account API key."*
**This must change.** The service account key is full admin over the whole
Firebase project. Anyone who owns a box can read the ESP32 flash with a USB
cable and `esptool`, take the key, and read or delete every patient's data.
`CLAUDE.md` itself says the key goes "NEVER in the repo or the APK" — the box is
the same case.

The box talks only to the Worker, which already holds the key:

```
Box ──HTTPS──► Worker (checks device key) ──service account──► Firestore
```

### 7.2 Device identity

Each box gets two values, flashed into it once (ESP32 NVS / `Preferences`)
and printed on a label under the box:

| Value | Example | Who sees it |
|---|---|---|
| `serial` | `HS-0001` | Printed on the label; typed into the app on `device_pairing_screen` |
| `device_key` | 32 random characters | Flashed into the box; **only a hash** is stored server-side |

Every request sends `X-Device-Key: <device_key>`. The Worker hashes it and
compares it with the stored hash for that serial. A wrong key gets `401`.

**DECIDE:** where the Worker keeps serial → key hash. Recommended: a new
`device_registry` collection written only by the Worker (rules: no client
access), seeded by a small script when you flash each box. It must not live
in `devices`, because the patient's app can write that collection.

### 7.3 Endpoints

`CLAUDE.md` lists `GET /device/{serial}/schedule` and `POST /device/{serial}/dose`,
but **neither exists in `healthsync-api/src/index.ts` yet.** This is the
proposed contract; the light `/state` call is new and is explained in 7.4.

#### `GET /device/{serial}/state` — every 60 s

Which LEDs should be on right now.

```json
{
  "server_time": "2026-10-13T00:02:11Z",
  "lit": [3, 5],
  "buzz": true,
  "schedule_version": "2026-10-12T09:41:00Z"
}
```

- `lit` = compartments that have a dose `pending` or `snoozed` whose
  `scheduled_at` is between 60 minutes ago and now (the "Due now" and "Late"
  windows from `DOSE_LOGIC_PROPOSAL.md`), and whose schedule has a
  `mat_box_column`. The box ignores anything outside 1–6.
- `buzz` = false while every lit dose is snoozed in the app and its
  `snoozed_until` has not passed, so the box does not beep through a snooze.
- `schedule_version` is only needed from Phase 4 (offline). Phase 1 can leave
  it out.
- When the patient taps Done in the app, the dose stops being pending, so the
  next poll drops it from `lit` and the LED turns off within a minute.
- `schedule_version` changes when a Care Partner edits a schedule
  (the latest `updated_at`). If it differs from the box's copy, the box fetches
  the full schedule.

#### `GET /device/{serial}/schedule` — on boot, and when `schedule_version` changes

Only what the box needs to run offline. No medicine names, no patient names.

```json
{
  "schedule_version": "2026-10-12T09:41:00Z",
  "timezone_offset_min": 480,
  "columns": [
    { "column": 3, "schedule_id": "abc", "time": "08:00", "days": ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"] },
    { "column": 3, "schedule_id": "def", "time": "20:00", "days": ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"] },
    { "column": 5, "schedule_id": "ghi", "time": "12:30", "days": ["Mon","Wed","Fri"] }
  ]
}
```

Times are 24-hour here so the ESP32 does not have to parse `"08:00 PM"`.

#### `POST /device/{serial}/dose` — when the button is pressed

```json
{
  "event_id": "HS-0001-1760313731",
  "pressed_at": "2026-10-13T00:02:11Z",
  "columns": [3, 5],
  "offline": false
}
```

The Worker, for each column:
1. Finds that column's dose that is pending/snoozed and inside its window.
2. Writes it the same way the app's Done button does: `status: "taken"`,
   `timing` (from the same rules as `lib/utils/dose_timing.dart`),
   `confirmed_via: "button"`, `taken_at: pressed_at`, pill count −1,
   `led_active: false`.
3. Sends the Care Partner push (same path as `POST /dose-events`).

`event_id` makes the call idempotent: if the box retries after a timeout, the
Worker sees the same id and does nothing twice.

Response: `{ "confirmed": [3, 5], "ignored": [] }`. A column is ignored when the
dose was already taken in the app, or nothing was due.

### 7.4 Why a light `/state` call and a rare `/schedule` call

The Spark plan allows **50,000 Firestore reads per day for the whole project.**

| Design | Reads per poll | Polls/day (60 s) | Reads/day per box |
|---|---|---|---|
| Fetch the full schedule + today's dose logs every poll | ~25 | 1,440 | **~36,000** — one box would use most of the free quota |
| `/state` (1 device lookup + 1 small dose_logs query) | ~2–3 | 1,440 | **~4,000** |
| plus `/schedule` only when it changes | ~9 | a few | ~50 |

With the light design, about **10 boxes** fit in the free plan alongside the
app — plenty for the capstone demo.

`/state` needs one composite index on `dose_logs`
(`patient_ref`, `status`, `scheduled_at`). Check `firestore.indexes.json` first;
the sweep may already have a close match.

### 7.5 What currently turns an LED on (gap found)

`CLAUDE.md` says "the APP (or the Worker) sets `led_active: true`". In the
current code, **nothing sets it to true** — only to false (`sweep.ts`,
`firestore_service.dart`, `device_service.dart`). If the box polled
`led_active`, no LED would ever light.

The `/state` design above avoids the problem: the Worker works out `lit` from
`dose_logs`, which the materializer already creates. That keeps "the box is a
display, the server knows the time" without adding another writer.

**DECIDE:** adopt `lit` from dose logs (recommended), or add code that sets
`led_active: true` at dose time. The second needs the phone to be awake at the
right minute, or a Worker write every 5 minutes per due dose.

**Re-checked October 19, 2026:** still true. `DeviceService.setColumnLedStatus`
has no callers. The uncommitted `healthsync-api/src/handlers/device.ts` builds
`/state` from `led_active`, so with it no LED would ever light. It also returns
`compartments` instead of `lit` and uses the UTC date instead of Manila's. It
has to change before Phase 1 can pass.

---

## Step 8 — Firmware structure

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). The phases, file list,
> main loop, states and libraries below assume Wi-Fi, HTTPS polling,
> WiFiManager and a device key. The proposed firmware is a BLE GATT service,
> schedule and event storage, and an RTC set from the phone, with no Wi-Fi
> code. Kept for the record.

### 8.0 Build phases (in order of importance)

| Phase | Goal | Button does |
|---|---|---|
| **1 — LED + buzzer sync (MVP)** | Poll `/state` every 60 s, light the due compartments, beep | Silences LEDs + buzzer on the box only (temporary) |
| **2 — Button confirms the dose** | `POST /dose`, dose taken with `confirmed_via: "button"`, care partner push | Confirms the dose |
| 3 — Wi-Fi setup hotspot | WiFiManager replaces hardcoded Wi-Fi (Step 10) | — |
| 4 — Offline | DS3231 + SD: offline schedule and queued presses (Steps 6, 9) | Queues the press when offline |
| 5 — Device key | `X-Device-Key` + `device_registry` (Step 7.2) | — |

Since Phase 3 (written October 20, 2026) the home Wi-Fi is chosen on the
box's setup page and saved in the ESP32's flash, not typed into any file. Until Phase 5 the Worker trusts the serial
alone.

One Arduino (or PlatformIO) project, one file per module:

```
firmware/healthsync_box/
├── healthsync_box.ino   setup() and loop() only — calls the modules
├── config.h             pins, poll intervals, Worker URL
├── leds.cpp/.h          leds_set(mask), leds_all_off(), leds_self_test()   (1)
├── button.cpp/.h        debounced press; long press from Phase 2          (1, 2)
├── buzzer.cpp/.h        non-blocking beep pattern while a dose is due      (1)
├── net.cpp/.h           Wi-Fi, HTTPS to the Worker; setup portal in Phase 3 (1, 3)
├── rtc_clock.cpp/.h     DS3231 read/write, NTP sync                        (4)
├── storage.cpp/.h       SD: schedule.json, queue.jsonl                     (4)
├── schedule.cpp/.h      offline "what is due now" from schedule.json + RTC (4)
└── secrets.h            serial, setup hotspot password, device_key (Phase 5); git-ignored
```

### 8.1 Main loop (non-blocking, no `delay()`)

Phase 1:

```
every loop     read button → if LEDs lit: turn them and the buzzer off, and
                              remember those compartments as silenced
every loop     update buzzer pattern
every 60 s     if Wi-Fi down → reconnect
               GET /state → LEDs on for lit minus silenced, buzzer per `buzz`
               a compartment that leaves `lit` is no longer silenced
               on failure → keep the last state
```

Added by later phases:

```
Phase 2  on button    if any LED lit → POST /dose, LEDs off, short confirm beep
                      if no LED lit  → one low beep ("nothing due")
Phase 4  every 60 s   if schedule_version changed → GET /schedule → save to SD
                      if queue.jsonl not empty → replay it (Step 9)
                      if offline → lit columns from schedule.json + RTC
         every 6 h    NTP → DS3231
         on button    offline → append to queue.jsonl
```

### 8.2 States

```
          power on
             │
             ▼
        ┌─────────┐   no Wi-Fi saved    ┌──────────────┐
        │  BOOT   │ ──────────────────► │ PROVISIONING │ (AP "HealthSync-0001")
        │ self-   │                     └──────┬───────┘
        │ test    │ ◄──── Wi-Fi saved ─────────┘
        └────┬────┘
             ▼
        ┌─────────┐   connected    ┌──────────┐
        │ CONNECT │ ─────────────► │  ONLINE  │ ◄─┐
        └────┬────┘                └────┬─────┘   │ reconnect
             │ 30 s timeout             │ Wi-Fi / │ + replay queue
             ▼                          │ Worker  │
        ┌─────────┐ ◄───────────────────┘ down    │
        │ OFFLINE │ ──────────────────────────────┘
        └─────────┘   (retry every 60 s)
```

Boot self-test: each LED lights for 150 ms in order 1→6 and the buzzer chirps
once. It shows at a glance that every LED and the buzzer work (useful at the
defense).

### 8.3 Libraries

| Library | For |
|---|---|
| `WiFi`, `HTTPClient`, `WiFiClientSecure` (ESP32 core) | Wi-Fi and HTTPS (Phase 1) |
| `ArduinoJson` v7 | Parsing `/state` (Phase 1) and `/schedule` (Phase 4) |
| `WiFiManager` (tzapu) | First-time Wi-Fi setup portal (Phase 3) |
| `RTClib` (Adafruit) | DS3231 (Phase 4) |
| `SD`, `SPI` (ESP32 core) | microSD (Phase 4) |
| `Preferences` (ESP32 core) | Serial + device key in flash (Phase 5) |

---

## Step 9 — Offline behaviour

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). With BLE
> connect-on-demand the box always runs from its stored schedule and the
> DS3231, and the phone pulls its logged dose events on the next connect.
> The Wi-Fi/Worker replay below is kept for the record.

When Wi-Fi or the Worker is unreachable:

1. **LEDs:** the box lights a compartment from `schedule.json` + the DS3231,
   using the same window as `/state` (from the dose time until 60 minutes
   after). This is the only time the box decides a dose is due — and only
   because the server cannot tell it.
2. **Button press:** append one line to `/queue.jsonl` on the SD card:
   ```json
   {"event_id":"HS-0001-1760313731","pressed_at":"2026-10-13T00:02:11Z","columns":[3]}
   ```
   Turn those LEDs off and remember (in RAM) that those doses are done, so they
   do not relight before the next poll.
3. **Reconnect:** send each queued line, oldest first, as `POST /dose` with
   `"offline": true`. Delete a line only after a `200`. Because of `event_id`
   a retry is harmless.
4. **What the Worker does with a late press:** if the sweep has already marked
   the dose `missed`, a press with `pressed_at` inside the window corrects it to
   taken — the same rule the app uses (`logged_at` before `missed_at`), and the
   Care Partner gets a "correction" notice.

Limits to state in the paper: the offline schedule is only as fresh as the last
sync; with no power at all the box does nothing; doses confirmed in the app
while the box is offline relight on the box until it reconnects.

---

## Step 10 — Setup and pairing (first use)

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). There is no Wi-Fi
> setup hotspot and no device key. Pairing becomes a BLE pairing flow in the
> app (proposed; owner Miko). Kept for the record.

1. **Flash** the firmware with that box's `serial` and `device_key`.
   Register the key hash in `device_registry` (Step 7.2).
2. **Wi-Fi (Phase 3):** on first power-up the box opens its own hotspot
   `HealthSync-0001` (compartment LEDs 1 and 6 blink, one beep). The Care
   Partner joins it from the phone's Wi-Fi settings with the password on the
   label, and a setup page opens by itself (or go to `192.168.4.1`). They pick
   the home Wi-Fi and enter its password; the box joins it, beeps twice, and
   rejoins it on every boot after.
   - Holding the button for 5 s while no LED is lit reopens setup (LEDs fill
     up 1→6 while held); the same hold in setup closes it.
   - After 5 minutes without its saved Wi-Fi, the box opens setup by itself.
   - The box uses its **own** Wi-Fi, never the phone's internet. Pairing in
     step 3 does not give it a connection.
   - A phone's mobile hotspot can be the network chosen here, but the box then
     works only while that hotspot is on.
   - The ESP32 supports **2.4 GHz Wi-Fi only**, not 5 GHz.
3. **Pair:** in the app, open the Smart box screen and type the serial from the
   label. The app creates the `devices` doc (already built:
   `FirestoreService.pairDevice`).
4. **Assign compartments** per medicine on `patient_box_screen.dart` (already built).
5. The box's next `/state` poll finds the `devices` doc by serial and starts
   lighting LEDs.

**Gaps found in the current pairing code:**

- `pairDevice` writes `status: "online"` the moment the serial is typed, before
  the box has ever connected. Better: write `"pairing"` (already a value in
  `DeviceModel`), and let the Worker set `"online"` and `last_sync` on the box's
  first `/state` call.
- Anyone can type any serial. Acceptable for the capstone; for real use, show a
  4-digit code on first boot (blinked on the LEDs or printed on the label) and
  ask for it in the app.
- `device_type` is `"medicine_box"` in `CLAUDE.md` but `"esp32_smart_box"` in
  `device_model.dart`. Pick one.
- `status` should go back to `"offline"` when the box stops polling. The Worker
  cron can mark a box offline if `last_sync` is older than 5 minutes.

---

## Step 11 — Build and test, step by step

Do these in order. Do not move on until the pass check is true. Each is a
small throwaway sketch except 11.8.

| Step | Build | Pass check |
|---|---|---|
| 11.1 | ESP32 alone: upload Blink to GPIO 2 | Built-in LED blinks; Serial Monitor shows output at 115200 |
| 11.2 | Wire 6 LEDs (4.1). Sketch lights 1→6 in turn | Every LED lights, in the right compartment order |
| 11.3 | Wire button (4.2). Sketch prints on press | One print per press, none from tapping the table, none at idle |
| 11.4 | Wire buzzer (4.3). Sketch beeps on button press | Clear beep; ESP32 does not reset when it beeps |
| 11.5 | Wire DS3231 (4.4). I2C scanner, then set + read time | Scanner finds `0x68`; time survives unplugging USB for 1 minute |
| 11.6 | Wire SD (4.5). Write a line, read it back | File readable on a PC afterwards |
| 11.7 | Wi-Fi + NTP + call the Worker's existing `GET /health` over HTTPS | Prints `{"status":"ok",...}` |
| 11.8a | **Phase 1:** full firmware against a Worker with the new `/state` | Due dose lights the right LED and beeps; button silences it; tapping Done in the app turns it off within 60 s |
| 11.8b | **Phase 2:** button confirms | Button marks the dose taken in the app within a minute; Care Partner gets the push |
| 11.9 | **Phase 4:** offline test: turn router off, press button, turn router on | Dose appears as taken (via button) after reconnect, once, not twice |
| 11.10 | Conflict test: tap Done in the app while the LED is lit | LED turns off within 60 s without pressing the button |

---

## Step 12 — Work this creates outside the box

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). The Worker device
> endpoints, `device_registry` and key script below are not planned. The
> work outside the box is now in the app (Bluetooth permissions, pairing,
> sync service, box events to Firebase). Kept for the record.

| Where | Work |
|---|---|
| `healthsync-api/src/handlers/device.ts` (new) | `/device/{serial}/state`, `/schedule`, `/dose`; device-key check |
| `healthsync-api/src/index.ts` | Route the three endpoints (path has a `{serial}`, so the current exact-match `switch` needs a prefix match) |
| `firestore.rules` | `device_registry`: no client read/write |
| `firestore.indexes.json` | `dose_logs` index for `/state` if not already there |
| `lib/services/firestore_service.dart` | `pairDevice` writes `status: "pairing"` |
| `CLAUDE.md` | Replace "ESP32 uses Firebase service account API key" with the device-key design; fix `device_type`; add `/state` |
| `tool/` (new script) | Generate a serial + device key, store the hash, print the label |

---

## Open decisions (summary)

1. **LED source:** compute `lit` from `dose_logs` in the Worker (recommended) vs.
   something setting `led_active: true` at dose time. (Step 7.5)
2. **One button, several lit LEDs:** confirm *all* lit compartments with one
   press (proposed above — simplest for an elderly user), or confirm only the
   lowest-numbered one per press?
3. **Early window on the box:** light the LED only from the dose time
   (proposed), or from 30 minutes before, to match the app's unlock time?
4. **Buzzer:** how long to beep (proposed: 3 short beeps every minute for the
   first 10 minutes, then every 5 minutes until +60) and whether to add quiet
   hours.
5. **Device registry location** for the key hashes. (Step 7.2)
6. ~~**Button pin:** keep GPIO 5, or move to GPIO 34.~~ **Decided Oct 19,
   2026:** GPIO 16 to GND with the internal pull-up, matching the wiring.
7. **Worker URL** for the box: the deployed Worker, not a temporary
   `trycloudflare.com` tunnel (which changes on every restart).
