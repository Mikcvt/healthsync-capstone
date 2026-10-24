// healthsync_box.ino — HealthSync medicine box (Bluetooth design, Oct 22, 2026).
//
// Phase 1: offline alarm from a stored schedule. No phone needed.
// Phase 2: every taken/missed dose is logged on the microSD (storage.h).
// Phase 3: the phone syncs over Bluetooth (ble.h, protocol.h, BLE_PROTOCOL.md):
//          time, schedule, dose events + ack, "done in the app".
// Phase 4: only a paired phone can connect (passkey on the box label).
//   Boot     self-test (LEDs 1→6, 1 s tone), DS3231 clock, stored schedule
//   Each s   due compartments (from the clock + schedule) → LED on and a 5 s
//            tone every 5 min; 60 min after its time a dose is missed (LED off)
//   Button   press and let go (0.3–10 s): every lit dose is taken (1.5 s tone).
//            Nothing lit: nothing is taken, never early (0.8 s tone).
//            Nothing lit, held 5 s (LEDs fill up 1→6): pairing mode for
//            2 minutes (running light 1→6, 2 s tone); a phone pairs → 3 s tone
//   Tones    one straight tone per event, each a different length (config.h)
//   Serial   bench commands (console.h)
//
// Next phases (WORK_NOTES.md §12): 5 with the app + battery.
// No logic beyond wiring the modules together lives here.

#include "config.h"
#include "leds.h"
#include "buzzer.h"
#include "button.h"
#include "rtc_clock.h"
#include "schedule.h"
#include "storage.h"
#include "console.h"
#include "ble.h"
#include "protocol.h"
#include "secrets.h"

static_assert(BLE_PASSKEY >= 100000 && BLE_PASSKEY <= 999999, "BLE_PASSKEY needs 6 digits");

static uint8_t  _shownMask    = 0;      // dose compartments lit right now
static uint32_t _lastTick     = 0;
static uint32_t _lastHeld     = 0;      // button hold time in the previous loop
static uint32_t _lastSecond   = 0;      // for the "holding..." debug prints
static bool     _stuckWarned  = false;
static bool     _clockWarned  = false;
static bool     _holdEligible = false;  // this press began with nothing lit: it may open pairing
static bool     _holdPairing  = false;  // this press opened pairing; its release does nothing else
static bool     _overlayShown = false;  // the LEDs show the hold progress or the running light

// LEDs and buzzer follow the due compartments; a newly due dose starts a fresh
// burst of beeps.
static void showDoses(uint8_t lit) {
    leds_set(lit);
    bool newlyLit = (lit & ~_shownMask) != 0;
    if (lit) {
        if (newlyLit || !buzzer_running()) buzzer_start();
    } else {
        buzzer_stop();
    }
    _shownMask = lit;
}

// Once a second, and right after anything changes.
static void tick() {
    if (!rtc_time_valid()) {
        if (!_clockWarned) {
            Serial.println("Clock not set: no alarms. Type  time YYYY-MM-DD HH:MM  (Manila time)");
            _clockWarned = true;
        }
        showDoses(0);
        return;
    }
    _clockWarned = false;
    showDoses(schedule_update(rtc_now_local()));
}

static void openPairing() {
    ble_pairing_open(PAIRING_WINDOW_MS);
    buzzer_tone(TONE_PAIRING_MS);
    Serial.println("PAIRING MODE for 2 minutes: connect the phone and type the 6-digit code "
                   "from the box label");
}

// A deliberate press: held BUTTON_CONFIRM_MS to BUTTON_CONFIRM_MAX_MS, then let go.
static void onPress(uint32_t heldMs) {
    if (heldMs < BUTTON_CONFIRM_MS) {
        Serial.printf("Button: %lu ms is too short, ignored (press for at least %lu ms)\n",
                      (unsigned long)heldMs, (unsigned long)BUTTON_CONFIRM_MS);
        return;
    }
    if (heldMs > BUTTON_CONFIRM_MAX_MS) {
        Serial.println("Button: held too long, ignored");
        return;
    }
    if (!rtc_time_valid()) {
        Serial.println("Button: clock not set, nothing can be taken");
        buzzer_tone(TONE_NOTHING_MS);
        return;
    }

    uint8_t taken = schedule_take(rtc_now_local());   // only lit doses, never early
    tick();                                   // LEDs off and the alarm stops first
    if (taken) {
        buzzer_tone(TONE_TAKEN_MS);           // 1.5 s: taken
    } else {
        Serial.println("Button: nothing due (nothing is taken before its alarm)");
        buzzer_tone(TONE_NOTHING_MS);         // 0.8 s: nothing due
    }
}

// Button state every loop: debug prints, the stuck warning, the 5-second hold
// for pairing, and a press is handled when the button is let go.
static void watchButton() {
    button_pressed();                         // keeps the debounced state current
    uint32_t held = button_down_ms();

#if BUTTON_DEBUG
    if (held > 0 && _lastHeld == 0) {
        Serial.println("Button down");
        _lastSecond = 0;
    } else if (held > 0 && held / 1000 > _lastSecond) {
        _lastSecond = held / 1000;
        Serial.printf("  holding... %lu s\n", (unsigned long)_lastSecond);
    } else if (held == 0 && _lastHeld > 0) {
        Serial.printf("Button up after %.1f s\n", _lastHeld / 1000.0);
    }
#endif

    // A press that starts with a dose lit always takes the dose: it never opens
    // pairing, however long it is held.
    if (held > 0 && _lastHeld == 0) {
        _holdEligible = (_shownMask == 0);
        _holdPairing  = false;
    }
    if (held > 0 && _holdEligible && !_holdPairing && held < BUTTON_STUCK_MS) {
        if (held >= PAIRING_HOLD_MS) {
            _holdPairing = true;
            openPairing();
        } else if (held >= PAIRING_HOLD_SHOW_MS) {
            int n = held * LED_COUNT / PAIRING_HOLD_MS;   // 1..5 while holding
            leds_set((1 << n) - 1);                     // LEDs fill up 1→6
            _overlayShown = true;
        }
    }

    if (held >= BUTTON_STUCK_MS && !_stuckWarned) {
        _stuckWarned = true;
        Serial.println("WARNING: button held 30 s: jammed or miswired? Ignored until released.");
    }
    if (held == 0 && _lastHeld > 0) {
        _stuckWarned = false;
        if (!_holdPairing) onPress(_lastHeld);   // a 5 s hold only opened pairing
        _holdPairing = false;
    }
    _lastHeld = held;
}

// Pairing mode shows a running light 1→6 (never mistaken for a dose, which
// lights one steady LED). A due dose always has priority on the LEDs.
static void showOverlay() {
    bool holding = button_down_ms() >= PAIRING_HOLD_SHOW_MS && _holdEligible && !_holdPairing;
    if (holding) return;                                      // watchButton draws the fill-up
    if (ble_pairing_active() && _shownMask == 0) {
        leds_set(1 << ((millis() / PAIRING_CHASE_MS) % LED_COUNT));
        _overlayShown = true;
    } else if (_overlayShown) {
        _overlayShown = false;
        leds_set(_shownMask);                                 // back to the dose LEDs
    }
}

void setup() {
    Serial.begin(115200);
    delay(300);
    Serial.println("\n=== HealthSync Box booting (fw " FIRMWARE_VERSION ", Phase 4: secure Bluetooth) ===");

    leds_init();
    buzzer_init();
    button_init();

    Serial.println("Self-test: LEDs 1-6 and buzzer");
    leds_self_test();
    buzzer_beep_ms(TONE_POWER_ON_MS);         // 1 s: power on

    if (!rtc_begin()) Serial.println("WARNING: DS3231 clock not found (check SDA 21 / SCL 22)");
    else if (rtc_lost_power()) Serial.println("WARNING: the clock lost power: set the time again");
    storage_begin();                          // before the schedule: a dose missed while the
    schedule_begin();                         // box was off is logged on the first tick
    console_begin();

    // Bluetooth name: "HealthSync-" + the serial without "HS-" (HS-0001 → HealthSync-0001).
    String name = DEVICE_SERIAL;
    if (name.startsWith("HS-")) name = name.substring(3);
    ble_begin(("HealthSync-" + name).c_str(), BLE_PASSKEY);

    tick();
    _lastTick = millis();
}

void loop() {
    if (console_update()) tick();

    char cmd[BLE_COMMAND_MAX];
    while (ble_next_command(cmd, sizeof(cmd))) {
        Serial.printf("BLE > %s\n", cmd);
        if (protocol_handle(cmd)) tick();
    }
    ble_update();
    if (ble_take_paired_event()) {
        ble_pairing_close();
        Serial.println("Phone paired: pairing mode closed");
        buzzer_tone(TONE_PAIRED_MS);          // 3 s: paired
    }
    watchButton();

    if (millis() - _lastTick >= 1000) {
        _lastTick = millis();
        tick();
    }
    showOverlay();
    buzzer_update();
}
