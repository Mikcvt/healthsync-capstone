// hw_test.ino — bench check for the 6 LEDs, the buzzer and the button.
//
// Upload, open the Serial Monitor at 115200, press EN (reset), then watch the
// box and the Serial Monitor together.
//
//   Part 1  LEDs: compartments 1→6 light one at a time, slowly. Check each one
//           is in the right compartment.
//   Part 2  Buzzer: the dose alarm, 5 short beeps.
//   Part 3  Button: every press lights the NEXT compartment and chirps once.
//
// Pins are the same as config.h in the main firmware.

const int LED_PINS[6] = {13, 14, 25, 26, 32, 33};   // compartments 1–6
const int BUZZER_PIN  = 17;                          // HIGH = sound
const int BUTTON_PIN  = 16;                          // to GND, pressed = LOW

static void allOff() {
    for (int pin : LED_PINS) digitalWrite(pin, LOW);
}

static void beep(int ms) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(ms);
    digitalWrite(BUZZER_PIN, LOW);
}

void setup() {
    Serial.begin(115200);
    delay(2000);   // give the Serial Monitor time to connect after an upload
    Serial.println("\n=== HealthSync LEDs / buzzer / button test ===");

    for (int pin : LED_PINS) pinMode(pin, OUTPUT);
    pinMode(BUZZER_PIN, OUTPUT);
    pinMode(BUTTON_PIN, INPUT_PULLUP);
    allOff();
    digitalWrite(BUZZER_PIN, LOW);

    // ── Part 1: LEDs ─────────────────────────────────────────────────────────
    Serial.println("\nPart 1: LEDs, one at a time");
    for (int i = 0; i < 6; i++) {
        Serial.printf("  Compartment %d (GPIO %d) ON\n", i + 1, LED_PINS[i]);
        digitalWrite(LED_PINS[i], HIGH);
        delay(800);
        digitalWrite(LED_PINS[i], LOW);
        delay(200);
    }
    Serial.println("  All 6 ON for 2 s");
    for (int pin : LED_PINS) digitalWrite(pin, HIGH);
    delay(2000);
    allOff();

    // ── Part 2: buzzer ───────────────────────────────────────────────────────
    Serial.println("\nPart 2: buzzer, the dose alarm (5 short beeps)");
    for (int i = 0; i < 5; i++) {
        beep(200);
        delay(150);
    }

    // ── Part 3: button ───────────────────────────────────────────────────────
    Serial.println("\nPart 3: button");
    if (digitalRead(BUTTON_PIN) == LOW) {
        Serial.println("  WARNING: the button reads PRESSED while nobody presses it.");
        Serial.println("  Check that it goes from GPIO 16 to GND, not to 3.3 V,");
        Serial.println("  and that the two legs used are not always connected.");
    }
    Serial.println("  Press the button: each press lights the next compartment and chirps.");
}

void loop() {
    static int lastRaw = HIGH, stable = HIGH;
    static uint32_t lastChange = 0;
    static int presses = 0, compartment = 0;

    int raw = digitalRead(BUTTON_PIN);
    if (raw != lastRaw) {
        lastRaw = raw;
        lastChange = millis();
    }
    if (raw != stable && millis() - lastChange >= 50) {   // 50 ms debounce
        stable = raw;
        if (stable == LOW) {
            presses++;
            compartment = compartment % 6 + 1;
            allOff();
            digitalWrite(LED_PINS[compartment - 1], HIGH);
            beep(80);
            Serial.printf("  Press #%d -> compartment %d\n", presses, compartment);
        } else {
            Serial.println("  released");
        }
    }
}
