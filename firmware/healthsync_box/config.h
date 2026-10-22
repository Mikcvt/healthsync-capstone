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
#define BEEP_COUNT       5        // short beeps per burst
#define BEEP_ON_MS       200
#define BEEP_OFF_MS      150
#define BEEP_REPEAT_MS   60000UL  // one burst every minute while a dose is due

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
#define BEEP_NOTHING_MS         600UL   // one long beep: nothing is due

// ── Schedule and dose timing (Phase 1) ────────────────────────────────────────
// Times follow lib/utils/dose_timing.dart and DOSE_LOGIC_PROPOSAL.md.
#define TZ_OFFSET_MIN    480   // Manila, UTC+8, no daylight saving. The DS3231 holds UTC
#define DUE_WINDOW_MIN    60   // a dose stays lit this long after its time, then it is missed
#define LATE_AFTER_MIN    30   // taken this long after its time or later = "late"
#define EARLY_WINDOW_MIN  30   // a press up to this long before a dose takes it early
#define MAX_SCHEDULES     24   // dose times the box can hold

// ── microSD ───────────────────────────────────────────────────────────────────
// MOSI and MISO are SWAPPED compared with the ESP32 default (MISO 19, MOSI 23).
// This matches our wiring (verified with sd_test, Oct 20).
#define SD_SCK_PIN  18
#define SD_MISO_PIN 23
#define SD_MOSI_PIN 19
#define SD_CS_PIN   15

// ── Bluetooth (Phase 3) — the protocol is in BLE_PROTOCOL.md ─────────────────
#define FIRMWARE_VERSION       "0.3.0"
#define BLE_SERVICE_UUID       "908a611a-cdae-4717-843a-8929f91d551b"
#define BLE_COMMAND_UUID       "a8672cae-3524-49a5-9a57-696fd57e7b72"   // phone → box (write)
#define BLE_REPLY_UUID         "c7b37ff8-2e2b-4156-8130-34df10d433e5"   // box → phone (notify)
#define BLE_MTU                247      // packet size asked for; every message fits in one
#define BLE_COMMAND_MAX        512      // longest command accepted
#define BLE_IDLE_DISCONNECT_MS 60000UL  // connect-on-demand: drop a phone silent for 60 s
#define BLE_EVENTS_MAX         20       // events sent per "events" request
#define STATUS_LED_PIN         2        // built-in LED: on while a phone is connected (bench aid)

// ── Dose log (Phase 2) ────────────────────────────────────────────────────────
#define LOG_FILE         "/doselog.jsonl"   // one JSON line per taken/missed dose
#define LOG_FALLBACK_MAX 32                 // events kept in flash while there is no SD card

// ── DS3231 RTC ────────────────────────────────────────────────────────────────
#define RTC_SDA_PIN 21
#define RTC_SCL_PIN 22
