// sd_test.ino — bench check for the microSD module (B1), using OUR wiring.
//
// Upload, open the Serial Monitor at 115200, and read the result. Press the
// ESP32's EN (reset) button to run it again.
//
// Our MOSI and MISO are SWAPPED compared with the ESP32 default
// (default: MISO 19, MOSI 23). This sketch uses our wiring, the same as
// config.h in the main firmware.

#include <SPI.h>
#include <SD.h>

const int SD_SCK  = 18;
const int SD_MISO = 23;
const int SD_MOSI = 19;
const int SD_CS   = 15;

const char *TEST_FILE = "/healthsync_test.txt";

// Try a normal speed first, then a slow one: long breadboard wires sometimes
// only work slowly.
const uint32_t SPEEDS_HZ[] = {4000000, 1000000};

static bool mountCard() {
    for (uint32_t hz : SPEEDS_HZ) {
        Serial.printf("Starting the card at %lu kHz... ", (unsigned long)(hz / 1000));
        if (SD.begin(SD_CS, SPI, hz)) {
            Serial.println("OK");
            return true;
        }
        Serial.println("failed");
        SD.end();
        delay(200);
    }
    return false;
}

static void printHints() {
    Serial.println();
    Serial.println("The card did not start. Try these, in this order:");
    Serial.println("  1. Swap the MOSI and MISO wires (GPIO 19 and 23), then press EN.");
    Serial.println("  2. Power the module from 5 V (ESP32 VIN pin), not 3.3 V,");
    Serial.println("     if it is the blue module with a regulator on it.");
    Serial.println("  3. Check SCK -> 18 and CS -> 15, and that GND is shared.");
    Serial.println("  4. Card formatted FAT32, 32 GB or smaller, pushed fully in.");
}

static const char *cardTypeName(uint8_t type) {
    switch (type) {
        case CARD_MMC:  return "MMC";
        case CARD_SD:   return "SD";
        case CARD_SDHC: return "SDHC";
        default:        return "unknown";
    }
}

void setup() {
    Serial.begin(115200);
    delay(500);
    Serial.println("\n=== HealthSync SD card test ===");
    Serial.printf("Pins: SCK %d, MISO %d, MOSI %d, CS %d\n", SD_SCK, SD_MISO, SD_MOSI, SD_CS);

    SPI.begin(SD_SCK, SD_MISO, SD_MOSI, SD_CS);

    if (!mountCard()) {
        printHints();
        return;
    }

    uint8_t type = SD.cardType();
    if (type == CARD_NONE) {
        Serial.println("No card detected.");
        printHints();
        return;
    }
    Serial.printf("Card type: %s\n", cardTypeName(type));
    Serial.printf("Card size: %llu MB\n", SD.cardSize() / (1024ULL * 1024ULL));
    Serial.printf("Free space: %llu MB\n",
                  (SD.totalBytes() - SD.usedBytes()) / (1024ULL * 1024ULL));

    // Write a line (replacing the file), then read it back.
    String line = "HealthSync SD test OK, uptime " + String(millis()) + " ms";

    File f = SD.open(TEST_FILE, FILE_WRITE);
    if (!f) {
        Serial.println("Could not create the test file (card may be read-only or full).");
        return;
    }
    f.println(line);
    f.close();
    Serial.printf("Wrote:  %s\n", line.c_str());

    f = SD.open(TEST_FILE, FILE_READ);
    if (!f) {
        Serial.println("Could not open the test file again.");
        return;
    }
    String readBack = f.readStringUntil('\n');
    f.close();
    readBack.trim();
    Serial.printf("Read:   %s\n", readBack.c_str());

    Serial.println();
    if (readBack == line) {
        Serial.println("PASS: the SD card works with our wiring.");
        Serial.printf("Check it on the PC: the card should have %s\n", TEST_FILE);
    } else {
        Serial.println("FAIL: what was read back does not match what was written.");
        printHints();
    }

    SD.end();
}

void loop() {}
