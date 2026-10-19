// rtc_test.ino — bench check for the DS3231 clock (B1).
//
// Upload, open the Serial Monitor at 115200, then press EN (reset).
//
//  1. Scans the I2C wires (SDA 21, SCL 22). Expect 0x68 (DS3231) and, on the
//     usual ZS-042 board, 0x57 (its memory chip).
//  2. The FIRST boot after an upload sets the clock to the PC's time at
//     compile time. Later resets do NOT set it again, so you can test that the
//     coin cell keeps the time.
//  3. Prints the time every second.
//
// Test: note the time, unplug the USB for 1 minute, plug it back, open the
// Serial Monitor, press EN. The time must have kept running (not jumped back).
//
// Phase 4 will store UTC from the internet (NTP). This test uses the PC's
// local time, which is fine for checking the hardware.

#include <Wire.h>
#include <RTClib.h>
#include <Preferences.h>

const int RTC_SDA = 21;
const int RTC_SCL = 22;

RTC_DS3231 rtc;
Preferences prefs;

static void scanI2C() {
    Serial.println("Scanning I2C (SDA 21, SCL 22)...");
    int found = 0;
    for (uint8_t addr = 1; addr < 127; addr++) {
        Wire.beginTransmission(addr);
        if (Wire.endTransmission() == 0) {
            const char *what = addr == 0x68 ? "DS3231 clock"
                             : addr == 0x57 ? "memory chip on the clock board (ignore)"
                             : "unknown device";
            Serial.printf("  found 0x%02X  %s\n", addr, what);
            found++;
        }
    }
    if (found == 0) Serial.println("  nothing found");
}

static void printHints() {
    Serial.println();
    Serial.println("The clock was not found. Check:");
    Serial.println("  1. SDA -> GPIO 21 and SCL -> GPIO 22 (not swapped)");
    Serial.println("  2. VCC -> 3.3 V and GND -> GND");
    Serial.println("  3. Wires pushed fully into the breadboard");
}

void setup() {
    Serial.begin(115200);
    delay(2000);   // give the Serial Monitor time to connect after an upload
    Serial.println("\n=== HealthSync DS3231 clock test ===");

    Wire.begin(RTC_SDA, RTC_SCL);
    scanI2C();

    if (!rtc.begin(&Wire)) {
        printHints();
        while (true) delay(1000);
    }
    Serial.println("DS3231 started.");

    if (rtc.lostPower()) {
        Serial.println("NOTE: the clock says it lost power (normal the very first time,");
        Serial.println("      or after the coin cell was removed or is flat).");
    }

    // Set the clock once per upload: the build stamp changes with every upload.
    const String build = String(__DATE__) + " " + __TIME__;
    prefs.begin("rtc_test", false);
    if (prefs.getString("build", "") != build || rtc.lostPower()) {
        rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
        prefs.putString("build", build);
        Serial.printf("Clock SET to the upload time: %s\n", build.c_str());
    } else {
        Serial.println("Clock NOT set this boot: it is running on its own.");
    }
    prefs.end();
    Serial.println();
}

void loop() {
    static uint32_t last = 0;
    if (millis() - last < 1000) return;
    last = millis();

    DateTime now = rtc.now();
    Serial.printf("%04d-%02d-%02d %02d:%02d:%02d\n",
                  now.year(), now.month(), now.day(),
                  now.hour(), now.minute(), now.second());
}
