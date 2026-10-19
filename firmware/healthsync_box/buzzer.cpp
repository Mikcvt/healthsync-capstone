// buzzer.cpp
#include "buzzer.h"
#include "config.h"
#include <Arduino.h>

static bool     _running    = false;
static bool     _pinHigh    = false;
static uint32_t _burstStart = 0;   // millis() when the current burst began

static void writePin(bool high) {
    if (high == _pinHigh) return;
    _pinHigh = high;
    digitalWrite(BUZZER_PIN, high ? HIGH : LOW);
}

void buzzer_init() {
    pinMode(BUZZER_PIN, OUTPUT);
    digitalWrite(BUZZER_PIN, LOW);
    _pinHigh = false;
}

void buzzer_start() {
    _running    = true;
    _burstStart = millis();
    buzzer_update();
}

void buzzer_stop() {
    _running = false;
    writePin(false);
}

bool buzzer_running() { return _running; }

void buzzer_update() {
    if (!_running) return;

    uint32_t elapsed = millis() - _burstStart;
    if (elapsed >= BEEP_REPEAT_MS) {          // time for the next burst
        _burstStart += BEEP_REPEAT_MS * (elapsed / BEEP_REPEAT_MS);
        elapsed = millis() - _burstStart;
    }

    const uint32_t period = BEEP_ON_MS + BEEP_OFF_MS;
    const uint32_t beep   = elapsed / period;   // which beep of the burst
    writePin(beep < BEEP_COUNT && (elapsed % period) < BEEP_ON_MS);
}

void buzzer_chirp() {
    writePin(true);
    delay(BEEP_ON_MS);
    writePin(false);
}
