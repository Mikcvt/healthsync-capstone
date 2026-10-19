// leds.h
#pragma once
#include <stdint.h>

void leds_init();

// Light exactly the compartments in the bitmask (bit 0 = compartment 1 …
// bit 5 = compartment 6). Higher bits are ignored.
void leds_set(uint8_t mask);

void leds_all_off();

// Boot self-test: lights compartments 1→6 one after another, 150 ms each.
// Blocking — call from setup() only.
void leds_self_test();
