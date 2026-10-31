// buzzer.cpp
#include "buzzer.h"
#include "config.h"
#include <Arduino.h>

static bool     _running    = false;   // the dose alarm is on
static bool     _pinHigh    = false;
static uint32_t _alarmStart = 0;       // millis() when the current alarm tone began
static uint32_t _toneUntil  = 0;       // millis() when the one-off tone ends; 0 = none

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
    _alarmStart = millis();
    buzzer_update();
}

void buzzer_stop() {
    _running = false;
    buzzer_update();
}

bool buzzer_running() { return _running; }

void buzzer_tone(uint32_t ms) {
    uint32_t until = millis() + ms;
    _toneUntil = until ? until : 1;
    buzzer_update();
}

void buzzer_update() {
    uint32_t now = millis();
    bool on = false;

    if (_toneUntil != 0) {
        if ((int32_t)(_toneUntil - now) > 0) on = true;
        else _toneUntil = 0;
    }
    if (!on && _running) {
        // 5 s tone, 2 s pause, repeated (Oct 31). How long it keeps going is
        // decided by showDoses(): it stops the alarm 30 min after the dose time.
        const uint32_t cycle = TONE_ALARM_MS + ALARM_PAUSE_MS;
        uint32_t elapsed = now - _alarmStart;
        if (elapsed >= cycle) {
            _alarmStart += cycle * (elapsed / cycle);
            elapsed = now - _alarmStart;
        }
        on = elapsed < TONE_ALARM_MS;
    }
    writePin(on);
}

void buzzer_beep_ms(uint32_t ms) {
    writePin(true);
    delay(ms);
    writePin(false);
}
