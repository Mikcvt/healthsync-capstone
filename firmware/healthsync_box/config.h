// config.h — pins and timings. Safe to commit (no secrets here).
// The box serial lives in secrets.h.
//
// Oct 22, 2026: the box talks to the patient's phone over Bluetooth
// (BLE_CONNECT_ON_DEMAND.md). The Wi-Fi / Worker settings of the earlier
// design were removed in Phase 0 (still in git history, commit 286c33b).
#pragma once

// ── LEDs — one per compartment, compartments 1–6 ─────────────────────────────
#define LED_COUNT 6
#define LED_PIN_1 13
#define LED_PIN_2 14
#define LED_PIN_3 25
#define LED_PIN_4 26
#define LED_PIN_5 32
#define LED_PIN_6 33

// ── Buzzer (active, through an NPN transistor; HIGH = sound) ─────────────────
#define BUZZER_PIN 17
// One straight (continuous) tone per event, each a different length (Oct 25):
#define TONE_ALARM_MS        5000UL   // a dose is due: 5 s tone ...
#define ALARM_REPEAT_MS    300000UL   // ... repeated every 5 min until taken or missed (+60 min)
#define TONE_PAIRED_MS       3000UL   // a phone paired
#define TONE_PAIRING_MS      2000UL   // pairing mode opened
#define TONE_TAKEN_MS        1500UL   // dose taken with the button
#define TONE_POWER_ON_MS     1000UL   // power on (self-test)
#define TONE_NOTHING_MS       800UL   // press with no dose due, or the clock not set

// ── Push button (GPIO 16 → button → GND, internal pull-up) ────────────────────
// The box uses a 6 mm NORMALLY CLOSED (NC) panel button: closed while idle, so
// the pin reads LOW; pressing opens it and the pull-up makes it HIGH.
// For a normal (normally open) button, set BUTTON_PRESSED_LEVEL to LOW.
// A broken wire reads as "held forever": the stuck-button safeguard covers it.
#define BUTTON_PIN 16
#define BUTTON_PRESSED_LEVEL HIGH
#define BUTTON_DEBOUNCE_MS 80   // was 50; raised Oct 20 because the bench button picks up noise
#define BUTTON_DEBUG 1          // 1 = print button down/hold/up on Serial (bench testing); 0 = off
#define BUTTON_STUCK_MS 30000UL // held longer than this = jammed or miswired: ignored until released
// A press counts only when the button is let go after being held this long:
// a bump, or a wire losing contact for a moment, never marks a dose taken.
#define BUTTON_CONFIRM_MS       300UL
#define BUTTON_CONFIRM_MAX_MS 10000UL   // held longer than this: not a deliberate press, ignored

// ── Schedule and dose timing (Phase 1) ────────────────────────────────────────
// Times follow lib/utils/dose_timing.dart and DOSE_LOGIC_PROPOSAL.md.
#define TZ_OFFSET_MIN    480   // Manila, UTC+8, no daylight saving. The DS3231 holds UTC
#define DUE_WINDOW_MIN    60   // a dose stays lit this long after its time, then it is missed
#define LATE_AFTER_MIN    30   // taken this long after its time or later = "late"
#define MAX_SCHEDULES     24   // dose times the box can hold

// ── microSD ───────────────────────────────────────────────────────────────────
// MOSI and MISO are SWAPPED compared with the ESP32 default (MISO 19, MOSI 23).
// This matches our wiring (verified with sd_test, Oct 20).
#define SD_SCK_PIN  18
#define SD_MISO_PIN 23
#define SD_MOSI_PIN 19
#define SD_CS_PIN   15

// ── Bluetooth (Phase 3) — the protocol is in BLE_PROTOCOL.md ─────────────────
#define FIRMWARE_VERSION       "0.5.0"
#define BLE_SERVICE_UUID       "908a611a-cdae-4717-843a-8929f91d551b"
#define BLE_COMMAND_UUID       "a8672cae-3524-49a5-9a57-696fd57e7b72"   // phone → box (write)
#define BLE_REPLY_UUID         "c7b37ff8-2e2b-4156-8130-34df10d433e5"   // box → phone (notify)
#define BLE_MTU                247      // packet size asked for; every message fits in one
#define BLE_COMMAND_MAX        512      // longest command accepted
#define BLE_IDLE_DISCONNECT_MS 60000UL  // connect-on-demand: drop a phone silent for 60 s
#define BLE_EVENTS_MAX         20       // events sent per "events" request
#define STATUS_LED_PIN         2        // built-in LED: on while a phone is connected (bench aid)

// ── Bluetooth security (Phase 4) ──────────────────────────────────────────────
// Pairing uses the 6-digit BLE_PASSKEY from secrets.h (printed on the box label).
// A new phone can pair only while pairing mode is open; paired phones reconnect
// encrypted with no code.
#define PAIRING_HOLD_MS        5000UL   // hold the button this long, with no LED lit → pairing mode
#define PAIRING_HOLD_SHOW_MS   1000UL   // after this much holding the LEDs start filling up 1→6
#define PAIRING_WINDOW_MS    120000UL   // pairing mode lasts 2 minutes (running light 1→6)
#define PAIRING_CHASE_MS        150UL   // running-light step
#define BLE_UNSECURED_DROP_MS 30000UL   // a phone not paired/encrypted within 30 s is dropped

// ── Power saving (Phase 5, Oct 29) ────────────────────────────────────────────
// This ESP32 core has no automatic light sleep (CONFIG_PM_ENABLE is off) and
// already lets the Bluetooth radio sleep between packets (modem sleep), so the
// savings come from a slower CPU, letting it rest between loops, and slower
// advertising. Set POWER_SAVE to 0 for the "before" current measurement.
#define POWER_SAVE 1
#if POWER_SAVE
#define CPU_MHZ            80     // was 240; 80 MHz is the lowest Bluetooth allows
#define LOOP_IDLE_MS       10     // loop() rests this long when nothing happened
#define BLE_ADV_MIN_UNITS 800     // advertise every 500–550 ms (units of 0.625 ms). The app
#define BLE_ADV_MAX_UNITS 880     // scans 8–12 s, so it still finds the box in about a second
#else
#define CPU_MHZ           240
#define LOOP_IDLE_MS        0
#define BLE_ADV_MIN_UNITS   0     // 0 = NimBLE's default (fast)
#define BLE_ADV_MAX_UNITS   0
#endif

// ── Status signals without a laptop (Phase 5, Oct 29) ─────────────────────────
// With no dose lit and no pairing mode, a problem flashes ALL six LEDs every
// 10 s (never mistaken for a dose, which lights one steady LED). No sound.
//   1 flash  = clock not set or not found: the box cannot alarm. Ends when the
//              phone syncs (set_time) or the time is typed on the console.
//   2 flashes = no SD card: doses are kept in flash (up to 32) until the phone
//              collects them.
#define STATUS_WARN_EVERY_MS 10000UL
#define STATUS_FLASH_ON_MS     150UL
#define STATUS_FLASH_OFF_MS    250UL

// ── Dose log (Phase 2) ────────────────────────────────────────────────────────
#define LOG_FILE         "/doselog.jsonl"   // one JSON line per taken/missed dose
#define LOG_FALLBACK_MAX 32                 // events kept in flash while there is no SD card

// ── DS3231 RTC ────────────────────────────────────────────────────────────────
#define RTC_SDA_PIN 21
#define RTC_SCL_PIN 22
