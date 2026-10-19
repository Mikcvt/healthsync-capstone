// button.h
#pragma once
#include <stdint.h>

void button_init();

// Call every loop() — it also updates the state button_down_ms() reads.
// Returns true exactly once per press, after the signal has been stable for
// BUTTON_DEBOUNCE_MS. Holding the button does not repeat.
bool button_pressed();

// How long the button has been held down (debounced), in ms; 0 when released.
// Used for the 5-second hold that opens or closes Wi-Fi setup.
uint32_t button_down_ms();
