// config.h — pins, timings, Worker URL. Safe to commit (no secrets here).
// Wi-Fi and the box serial live in secrets.h.
#pragma once

// ── Worker ────────────────────────────────────────────────────────────────────
// Phase 1 testing: `npx wrangler dev --ip 0.0.0.0` on the PC, reached over the
// same Wi-Fi. If the PC's IP changes (router restart), run `ipconfig` and
// update it here, then re-upload.
// Production: https://healthsync-api.healthsync12.workers.dev — only once the
// lead software developer has deployed the box endpoint.
#define WORKER_BASE_URL "http://192.168.1.11:8787"

#define POLL_INTERVAL_MS        60000UL  // ask the Worker every 60 s
#define HTTP_TIMEOUT_MS          8000    // give up on one request after 8 s
#define WIFI_CONNECT_TIMEOUT_MS 15000UL  // connect at boot, and when trying a Wi-Fi typed in setup

// ── Wi-Fi setup hotspot (Phase 3) ─────────────────────────────────────────────
// Hotspot name: "HealthSync-" + the serial without "HS-" (HS-0001 → HealthSync-0001).
// Its password is SETUP_AP_PASSWORD in secrets.h, printed on the box label.
#define SETUP_HOLD_MS          5000UL    // hold the button this long, with no LED lit → setup opens;
                                         // the same hold in setup → setup closes
#define SETUP_HOLD_SHOW_MS      300UL    // after this much holding, LEDs start filling up 1→6
#define SETUP_AFTER_NO_WIFI_MS 300000UL  // 5 min without Wi-Fi → setup opens by itself
#define SETUP_WINDOW_MS        300000UL  // setup nobody uses closes after 5 min to retry the saved Wi-Fi
#define SETUP_BLINK_MS         1000UL    // compartment LEDs 1 and 6 blink at this rate in setup

// ── LEDs — one per compartment, compartments 1–6 ─────────────────────────────
#define LED_COUNT 6
#define LED_PIN_1 13
#define LED_PIN_2 14
#define LED_PIN_3 25
#define LED_PIN_4 26
#define LED_PIN_5 32
#define LED_PIN_6 33

#define STATUS_LED_PIN 2   // built-in LED: on while Wi-Fi is connected

// ── Buzzer (active, through an NPN transistor; HIGH = sound) ─────────────────
#define BUZZER_PIN 17
#define BEEP_COUNT       5        // short beeps per burst
#define BEEP_ON_MS       200
#define BEEP_OFF_MS      150
#define BEEP_REPEAT_MS   60000UL  // one burst every minute while a dose is due

// ── Push button (GPIO 16 → button → GND, internal pull-up, pressed = LOW) ────
#define BUTTON_PIN 16
#define BUTTON_DEBOUNCE_MS 80   // was 50; raised Oct 20 because the bench button picks up noise
#define BUTTON_DEBUG 1          // 1 = print button down/hold/up on Serial (bench testing); 0 = off
#define BUTTON_STUCK_MS 30000UL // held longer than this = jammed or miswired: ignored until released

// ── microSD (Phase 4) ─────────────────────────────────────────────────────────
// MOSI and MISO are SWAPPED compared with the ESP32 default (MISO 19, MOSI 23).
// This matches our wiring. If the card will not start, swap these two first.
#define SD_SCK_PIN  18
#define SD_MISO_PIN 23
#define SD_MOSI_PIN 19
#define SD_CS_PIN   15

// ── DS3231 RTC (Phase 4) ──────────────────────────────────────────────────────
#define RTC_SDA_PIN 21
#define RTC_SCL_PIN 22
