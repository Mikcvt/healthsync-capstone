// healthsync_box.ino — Phase 1 (LED + buzzer sync) + Phase 3 (Wi-Fi setup).
//
//   Boot     self-test (LEDs 1→6, one chirp), then the saved Wi-Fi
//   Setup    hotspot "HealthSync-xxxx": LEDs 1 and 6 blink, one beep; after the
//            Wi-Fi is saved, two beeps. Opens by itself with no saved Wi-Fi,
//            or after 5 min without Wi-Fi
//   Button   press while LEDs are lit → silences them and the buzzer on the box
//            only (temporary: the dose is still confirmed in the app; Phase 2
//            changes this)
//            hold 5 s while nothing is lit → opens Wi-Fi setup (LEDs fill up
//            1→6 while held); the same hold in setup → closes it
//   Every 60 s   GET /device/{serial}/state → light the due compartments,
//                5 short beeps every minute while any is due
//
// No logic beyond wiring the modules together lives here.
// See FIRMWARE_ARCHITECTURE.md.

#include "config.h"
#include "leds.h"
#include "buzzer.h"
#include "button.h"
#include "net.h"

static uint8_t  _litMask      = 0;     // compartments the Worker says are due
static uint8_t  _silencedMask = 0;     // of those, the ones the button silenced
static uint8_t  _shownMask    = 0;     // what the LEDs show right now (doses)
static bool     _buzz         = true;  // false while every due dose is snoozed
static uint32_t _lastPoll     = 0;
static bool     _wasInSetup   = false;
static bool     _holdUsed     = false; // this hold already did something; wait for release
static bool     _holdShown    = false; // the LEDs are showing the hold progress
static bool     _seenReleased = false; // the button has been up at least once since boot
static bool     _stuckWarned  = false;

// True once when the button has been held SETUP_HOLD_MS. When `allowed`, the
// LEDs fill up 1→6 while it is held, so the user sees how long to keep going.
//
// Stuck-button safeguard: a button already down at boot never counts until
// it has been released once, and one held past BUTTON_STUCK_MS is reported
// and ignored until released. So a jammed or miswired button opens setup at
// most once (setup then closes by itself after SETUP_WINDOW_MS unused).
static bool holdCompleted(bool allowed, bool showProgress) {
    uint32_t held = button_down_ms();
    if (held == 0) {                          // released
        _holdUsed     = false;
        _seenReleased = true;
        _stuckWarned  = false;
        if (_holdShown) {
            _holdShown = false;
            leds_set(_shownMask);             // put the dose LEDs back
        }
        return false;
    }
    if (held >= BUTTON_STUCK_MS && !_stuckWarned) {
        _stuckWarned = true;
        Serial.println("WARNING: button held 30 s: jammed or miswired? Ignored until released.");
    }
    if (!_seenReleased || _holdUsed || !allowed) return false;

    if (held >= SETUP_HOLD_MS) {
        _holdUsed  = true;
        _holdShown = false;
        return true;
    }
    if (showProgress && held >= SETUP_HOLD_SHOW_MS) {
        int lit = held * LED_COUNT / SETUP_HOLD_MS;   // 0..5
        leds_set((1 << (lit + 1)) - 1);               // LED 1, then 1–2, … up to 1–6
        _holdShown = true;
    }
    return false;
}

// Bench testing (BUTTON_DEBUG): print what the button does, so a noisy button
// or a hold that was cut short shows up on the Serial Monitor.
static void debugButton() {
#if BUTTON_DEBUG
    static uint32_t lastHeld = 0;
    static uint32_t lastSecond = 0;
    uint32_t held = button_down_ms();
    if (held > 0 && lastHeld == 0) {
        Serial.println("Button down");
        lastSecond = 0;
    } else if (held > 0 && held / 1000 > lastSecond) {
        lastSecond = held / 1000;
        Serial.printf("  holding... %lu s\n", (unsigned long)lastSecond);
    } else if (held == 0 && lastHeld > 0) {
        Serial.printf("Button up after %.1f s\n", lastHeld / 1000.0);
    }
    lastHeld = held;
#endif
}

// Setup mode on the box: compartment LEDs 1 and 6 blink together.
static void showSetupBlink() {
    bool on = (millis() / SETUP_BLINK_MS) % 2 == 0;
    leds_set(on ? (0x01 | (1 << (LED_COUNT - 1))) : 0);
}

// Drive the LEDs and buzzer from the current state.
static void refreshOutputs() {
    uint8_t show = _litMask & ~_silencedMask;
    leds_set(show);

    bool newlyLit = (show & ~_shownMask) != 0;
    if (show && _buzz) {
        if (newlyLit || !buzzer_running()) buzzer_start();   // fresh burst for a new dose
    } else {
        buzzer_stop();
    }
    _shownMask = show;
}

static void poll() {
    net_maintain();

    BoxState state;
    if (!net_get_state(state)) {
        Serial.println("Poll failed, keeping the last state.");
        return;
    }

    _litMask = state.litMask;
    _buzz    = state.buzz;
    // A compartment that is no longer due stops being silenced, so its next
    // dose lights normally.
    _silencedMask &= _litMask;
    refreshOutputs();

    Serial.printf("Poll: lit=0x%02X silenced=0x%02X buzz=%d\n",
                  _litMask, _silencedMask, _buzz);
}

void setup() {
    Serial.begin(115200);
    delay(300);
    Serial.println("\n=== HealthSync Box booting (Phase 1 + 3) ===");

    leds_init();
    buzzer_init();
    button_init();

    Serial.println("Self-test: LEDs 1-6 and buzzer");
    leds_self_test();
    buzzer_chirp();

    net_begin();
    if (!net_in_setup()) poll();
    _lastPoll = millis();
}

void loop() {
    bool joined  = net_process();
    bool pressed = button_pressed();   // every loop, so the hold timing stays right
    debugButton();

    // ── Setup mode ───────────────────────────────────────────────────────────
    if (net_in_setup()) {
        if (!_wasInSetup) {            // just entered setup
            _wasInSetup = true;
            buzzer_stop();
            _shownMask = 0;
            buzzer_chirp();
        }
        if (holdCompleted(true, true)) {   // LEDs fill up 1→6 while held, here too
            if (net_close_setup()) buzzer_chirp();
            else Serial.println("No Wi-Fi saved yet: setup stays open.");
        }
        if (net_in_setup()) {
            if (!_holdShown) showSetupBlink();   // the fill-up replaces the blink while held
            return;                    // no polling while in setup
        }
    }

    if (_wasInSetup) {                 // just left setup
        _wasInSetup = false;
        leds_all_off();
        _shownMask = 0;
        if (joined) {                  // new Wi-Fi saved: two beeps
            buzzer_chirp();
            delay(150);
            buzzer_chirp();
        }
        _lastPoll = millis() - POLL_INTERVAL_MS;   // poll right away
    }

    // ── Button ───────────────────────────────────────────────────────────────
    if (pressed && !_seenReleased) {
        Serial.println("Button: was already down at start-up, ignored until released");
        pressed = false;
    }
    if (pressed) {
        if (_shownMask) {
            Serial.printf("Button: silenced 0x%02X\n", _shownMask);
            _silencedMask |= _shownMask;
            refreshOutputs();
            _holdUsed = true;          // this press silenced; holding on does not open setup
        } else {
            Serial.println("Button: nothing to silence (hold 5 s for Wi-Fi setup)");
        }
    }

    // The setup hold works only while no dose LED is lit.
    if (holdCompleted(_shownMask == 0, true)) {
        Serial.println("Button held 5 s: opening Wi-Fi setup.");
        net_open_setup();
        return;                        // the next loop shows setup mode
    }

    buzzer_update();

    if (millis() - _lastPoll >= POLL_INTERVAL_MS) {
        _lastPoll = millis();
        poll();
    }
}
