// buzzer.h
#pragma once

void buzzer_init();

// Alarm pattern: BEEP_COUNT short beeps now, then again every BEEP_REPEAT_MS.
// Non-blocking — buzzer_update() must run every loop().
void buzzer_start();     // (re)starts the pattern with a burst right now
void buzzer_stop();      // silence at once
bool buzzer_running();
void buzzer_update();

// One short beep, blocking. For the boot self-test only.
void buzzer_chirp();
