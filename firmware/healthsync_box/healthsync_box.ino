// healthsync_box.ino — HealthSync medicine box (Bluetooth design, Oct 22, 2026).
//
// Phase 1: offline alarm from a stored schedule. No phone needed.
// Phase 2: every taken/missed dose is logged on the microSD (storage.h).
// Phase 3: the phone syncs over Bluetooth (ble.h, protocol.h, BLE_PROTOCOL.md):
//          time, schedule, dose events + ack, "done in the app".
//   Boot     self-test (LEDs 1→6, one chirp), DS3231 clock, stored schedule
//   Each s   due compartments (from the clock + schedule) → LED on, 5 beeps
//            every minute; 60 min after its time a dose is missed (LED off)
//   Button   press and let go (0.3–10 s): every lit dose is taken, two beeps.
//            Nothing lit: a dose due within 30 min is taken early; otherwise
//            one long beep ("nothing due")
//   Serial   bench commands (console.h) until Bluetooth arrives in Phase 3
//
// Next phases (WORK_NOTES.md §12): 4 security, 5 with the app + battery.
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

static uint8_t  _shownMask   = 0;      // compartments lit right now
static uint32_t _lastTick    = 0;
static uint32_t _lastHeld    = 0;      // button hold time in the previous loop
static uint32_t _lastSecond  = 0;      // for the "holding..." debug prints
static bool     _stuckWarned = false;
static bool     _clockWarned = false;

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
        buzzer_beep_ms(BEEP_NOTHING_MS);
        return;
    }

    bool early = false;
    uint8_t taken = schedule_take(rtc_now_local(), early);
    tick();                                   // LEDs off and buzzer quiet first
    if (taken) {
        buzzer_chirp();                       // two short beeps: taken
        delay(120);
        buzzer_chirp();
    } else {
        Serial.println("Button: nothing due");
        buzzer_beep_ms(BEEP_NOTHING_MS);      // one long beep
    }
}

// Button state every loop: debug prints, the stuck warning, and a press is
// handled when the button is let go.
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

    if (held >= BUTTON_STUCK_MS && !_stuckWarned) {
        _stuckWarned = true;
        Serial.println("WARNING: button held 30 s: jammed or miswired? Ignored until released.");
    }
    if (held == 0 && _lastHeld > 0) {
        _stuckWarned = false;
        onPress(_lastHeld);
    }
    _lastHeld = held;
}

void setup() {
    Serial.begin(115200);
    delay(300);
    Serial.println("\n=== HealthSync Box booting (fw " FIRMWARE_VERSION ", Phase 3: Bluetooth) ===");

    leds_init();
    buzzer_init();
    button_init();

    Serial.println("Self-test: LEDs 1-6 and buzzer");
    leds_self_test();
    buzzer_chirp();

    if (!rtc_begin()) Serial.println("WARNING: DS3231 clock not found (check SDA 21 / SCL 22)");
    else if (rtc_lost_power()) Serial.println("WARNING: the clock lost power: set the time again");
    storage_begin();                          // before the schedule: a dose missed while the
    schedule_begin();                         // box was off is logged on the first tick
    console_begin();

    // Bluetooth name: "HealthSync-" + the serial without "HS-" (HS-0001 → HealthSync-0001).
    String name = DEVICE_SERIAL;
    if (name.startsWith("HS-")) name = name.substring(3);
    ble_begin(("HealthSync-" + name).c_str());

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
    watchButton();

    if (millis() - _lastTick >= 1000) {
        _lastTick = millis();
        tick();
    }
    buzzer_update();
}
