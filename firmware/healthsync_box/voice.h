// voice.h — spoken prompts from the DFPlayer Mini (VOICE_CLIPS.md, Nov 2026).
// Clips are /01/NNN.mp3 on the DFPlayer's own card. Every prompt follows its
// tone: callers pass the tone length as the delay. Nothing here blocks the
// loop except voice_begin(). Without a DFPlayer the box keeps its tones and
// every call here does nothing.
#pragma once
#include <stdint.h>

// At boot, at least VOICE_READY_MS after power-on. Never resets the player
// (the reset browned the ESP32 out, Nov 2). Returns whether it answered.
bool voice_begin();
bool voice_available();

// Plays `count` clips one after another, starting `delayMs` from now.
// Replaces whatever was playing or waiting.
void voice_say(const uint8_t *clips, uint8_t count, uint32_t delayMs = 0);
void voice_say_one(uint8_t clip, uint32_t delayMs = 0);

// "Please take your medicine. Compartment one, two and three." for the
// compartments in `mask` (bit 0 = compartment 1), lowest first.
void voice_say_dose(uint8_t mask);

void voice_stop();
bool voice_busy();       // something is playing or waiting to play

// Call every loop(): starts the next clip when the previous one has ended.
void voice_update();
