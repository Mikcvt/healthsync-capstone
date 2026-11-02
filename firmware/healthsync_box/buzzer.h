// buzzer.h — one straight (continuous) tone per event, each a different length
// (config.h, TONE_*). Nothing blocks except buzzer_beep_ms().
#pragma once
#include <stdint.h>

void buzzer_init();

// The dose alarm, in rounds: TONE_ALARM_MS on, the spoken prompt for the lit
// compartments (voice.h), ALARM_PAUSE_MS off, repeated until stopped.
void buzzer_start(uint8_t lit);   // (re)starts the alarm with a tone right now
void buzzer_set_lit(uint8_t lit); // the compartments changed; the alarm goes on
void buzzer_stop();               // stops the alarm (a confirmation tone keeps playing)
bool buzzer_running();

// One tone of `ms` milliseconds (taken, nothing due, pairing...). It plays
// over the alarm and does not stop the box from working meanwhile.
void buzzer_tone(uint32_t ms);

// Call every loop(): plays the alarm and the tones.
void buzzer_update();

// One tone of `ms` milliseconds, blocking. For the boot self-test only.
void buzzer_beep_ms(uint32_t ms);
