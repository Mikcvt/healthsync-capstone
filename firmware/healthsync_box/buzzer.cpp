// buzzer.cpp
#include "buzzer.h"
#include "config.h"
#include "voice.h"
#include <Arduino.h>

// One alarm round (Nov 3, Miko): tone, then the spoken prompt, then a pause.
enum Phase : uint8_t { PHASE_TONE, PHASE_VOICE, PHASE_PAUSE };

static bool     _running      = false;   // the dose alarm is on
static bool     _pinHigh      = false;
static uint8_t  _lit          = 0;       // compartments the prompt names
static Phase    _phase        = PHASE_TONE;
static uint32_t _phaseStart   = 0;       // millis() when the current phase began
static uint32_t _alarmBegin   = 0;       // millis() when this alarm started
static uint8_t  _silentRounds = 0;       // rounds without the voice since it last spoke
static uint32_t _toneUntil    = 0;       // millis() when the one-off tone ends; 0 = none

static void writePin(bool high) {
    if (high == _pinHigh) return;
    _pinHigh = high;
    digitalWrite(BUZZER_PIN, high ? HIGH : LOW);
}

// The voice speaks every round for the first VOICE_EVERY_ROUND_MS of an
// alarm, then every VOICE_EVERY_NTH_ROUND-th round.
static bool roundSpeaks(uint32_t now) {
    if (!voice_available()) return false;
    if (now - _alarmBegin < VOICE_EVERY_ROUND_MS) return true;
    if (++_silentRounds < VOICE_EVERY_NTH_ROUND) return false;
    _silentRounds = 0;
    return true;
}

void buzzer_init() {
    pinMode(BUZZER_PIN, OUTPUT);
    digitalWrite(BUZZER_PIN, LOW);
    _pinHigh = false;
}

void buzzer_start(uint8_t lit) {
    if (_running && _phase == PHASE_VOICE) voice_stop();
    _running      = true;
    _lit          = lit;
    _phase        = PHASE_TONE;
    _phaseStart   = _alarmBegin = millis();
    _silentRounds = 0;
    buzzer_update();
}

void buzzer_set_lit(uint8_t lit) { _lit = lit; }

void buzzer_stop() {
    if (_running && _phase == PHASE_VOICE) voice_stop();
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
    if (_running) {
        // 5 s tone, the prompt, 5 s pause, repeated. How long it keeps going is
        // decided by showDoses(): it stops the alarm 30 min after the dose time.
        // The tone and the voice never play together (the speaker's current
        // on top of the buzzer's could brown the ESP32 out).
        uint32_t inPhase = now - _phaseStart;
        switch (_phase) {
            case PHASE_TONE:
                if (inPhase >= TONE_ALARM_MS) {
                    _phaseStart = now;
                    if (roundSpeaks(now)) {
                        voice_say_dose(_lit);
                        _phase = PHASE_VOICE;
                    } else {
                        _phase = PHASE_PAUSE;
                    }
                }
                break;
            case PHASE_VOICE:
                if (!voice_busy() || inPhase > VOICE_ROUND_MAX_MS) {
                    _phase      = PHASE_PAUSE;
                    _phaseStart = now;
                }
                break;
            case PHASE_PAUSE:
                if (inPhase >= ALARM_PAUSE_MS) {
                    _phase      = PHASE_TONE;
                    _phaseStart = now;
                }
                break;
        }
        if (_phase == PHASE_TONE) on = true;
    }
    writePin(on);
}

void buzzer_beep_ms(uint32_t ms) {
    writePin(true);
    delay(ms);
    writePin(false);
}
