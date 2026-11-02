// voice.cpp
#include "voice.h"
#include "config.h"
#include <Arduino.h>
#include <DFRobotDFPlayerMini.h>

static HardwareSerial      _serial(2);
static DFRobotDFPlayerMini _player;
static bool     _available = false;

static uint8_t  _queue[2 + LED_COUNT * 2];   // the longest prompt: a dose with all 6 lit
static uint8_t  _count     = 0;
static uint8_t  _next      = 0;              // next clip in _queue to play
static uint32_t _startAt   = 0;              // millis() when the next clip may start
static bool     _playing   = false;
static bool     _busySeen  = false;          // BUSY went LOW for the current clip
static uint32_t _clipStart = 0;

bool voice_begin() {
    pinMode(DF_BUSY_PIN, INPUT);              // GPIO 35: no pull-up; the player drives it
    _serial.begin(9600, SERIAL_8N1, DF_RX_PIN, DF_TX_PIN);
    // No acknowledgements: with them every command waits for the player's
    // reply, which would stall the button and Bluetooth.
    _player.begin(_serial, false, false);
    _player.setTimeOut(500);
    _available = _player.readVolume() >= 0;   // up to 0.5 s, at boot only
    if (_available) _player.volume(VOICE_VOLUME);
    Serial.println(_available ? "Voice: DFPlayer ready"
                              : "Voice: no DFPlayer answer, tones only (check pins 27 / 34 / 35 and 5 V)");
    return _available;
}

bool voice_available() { return _available; }

void voice_stop() {
    if (_playing) _player.stop();
    _count = _next = 0;
    _playing = false;
}

void voice_say(const uint8_t *clips, uint8_t count, uint32_t delayMs) {
    if (!_available) return;
    voice_stop();
    if (count > sizeof(_queue)) count = sizeof(_queue);
    memcpy(_queue, clips, count);
    _count   = count;
    _startAt = millis() + delayMs;
}

void voice_say_one(uint8_t clip, uint32_t delayMs) { voice_say(&clip, 1, delayMs); }

void voice_say_dose(uint8_t mask) {
    uint8_t clips[sizeof(_queue)];
    uint8_t n = 0, lit = 0;
    for (int i = 0; i < LED_COUNT; i++) if ((mask >> i) & 1) lit++;
    if (lit == 0) return;
    clips[n++] = CLIP_TAKE_MEDICINE;
    clips[n++] = CLIP_COMPARTMENT;
    uint8_t said = 0;
    for (int i = 0; i < LED_COUNT; i++) {
        if (!((mask >> i) & 1)) continue;
        if (lit > 1 && ++said == lit) clips[n++] = CLIP_AND;   // "and" before the last
        clips[n++] = CLIP_NUMBER_BASE + i + 1;                 // 011 = "one" ... 016 = "six"
    }
    voice_say(clips, n);
}

bool voice_busy() { return _available && (_playing || _next < _count); }

void voice_update() {
    if (!_available) return;
    while (_player.available()) _player.read();   // drop "finished" replies

    uint32_t now = millis();
    if (_playing) {
        bool low = digitalRead(DF_BUSY_PIN) == LOW;
        if (low) _busySeen = true;
        uint32_t ran = now - _clipStart;
        // Ended: BUSY back HIGH, or it never went LOW (missing file), or too long.
        if ((_busySeen && !low) || (!_busySeen && ran > 1000) || ran > VOICE_CLIP_MAX_MS) {
            _playing = false;
            _startAt = now + 30;                  // the player needs a moment between clips
        }
        return;
    }
    if (_next < _count && (int32_t)(now - _startAt) >= 0) {
        _player.playFolder(VOICE_FOLDER, _queue[_next++]);
        _playing   = true;
        _busySeen  = false;
        _clipStart = now;
    } else if (_next >= _count) {
        _count = _next = 0;
    }
}
