// leds.cpp
#include "leds.h"
#include "config.h"
#include <Arduino.h>

// Sized by LED_COUNT so no slot is left as 0: an empty slot would make the
// loops below drive GPIO 0, a boot pin.
static const uint8_t LED_PINS[LED_COUNT] = {
    LED_PIN_1, LED_PIN_2, LED_PIN_3,
    LED_PIN_4, LED_PIN_5, LED_PIN_6,
};

void leds_init() {
    for (int i = 0; i < LED_COUNT; i++) {
        pinMode(LED_PINS[i], OUTPUT);
        digitalWrite(LED_PINS[i], LOW);
    }
}

void leds_set(uint8_t mask) {
    for (int i = 0; i < LED_COUNT; i++) {
        digitalWrite(LED_PINS[i], ((mask >> i) & 1) ? HIGH : LOW);
    }
}

void leds_all_off() { leds_set(0); }

void leds_self_test() {
    for (int i = 0; i < LED_COUNT; i++) {
        leds_set(1 << i);
        delay(150);
    }
    leds_all_off();
}
