// button.cpp — GPIO 16 → button → GND, internal pull-up, so pressed = LOW.
#include "button.h"
#include "config.h"
#include <Arduino.h>

static int      _lastRaw    = HIGH;   // last reading, may still be bouncing
static int      _stable     = HIGH;   // debounced state
static uint32_t _lastChange = 0;
static uint32_t _downSince  = 0;      // when the debounced state went down

void button_init() {
    pinMode(BUTTON_PIN, INPUT_PULLUP);
}

bool button_pressed() {
    int raw = digitalRead(BUTTON_PIN);
    uint32_t now = millis();

    if (raw != _lastRaw) {
        _lastRaw    = raw;
        _lastChange = now;
    }

    if (raw != _stable && (now - _lastChange) >= BUTTON_DEBOUNCE_MS) {
        _stable = raw;
        if (_stable == LOW) {
            _downSince = now;
            return true;         // report the press, not the release
        }
    }
    return false;
}

uint32_t button_down_ms() {
    return _stable == LOW ? millis() - _downSince : 0;
}
