// dfplayer_test.ino — bench check for the DFPlayer Mini voice module.
//
// Upload, open the Serial Monitor at 115200, then press EN (reset).
//
// Wiring (HealthSync Box Wiring page):
//   ESP32 GPIO 27 → 1 kΩ → DFPlayer pin 2 RX   (commands to the player)
//   DFPlayer pin 3 TX    → ESP32 GPIO 34       (replies)
//   DFPlayer pin 16 BUSY → ESP32 GPIO 35       (LOW while a clip plays)
//   DFPlayer pin 1 VCC → 5 V, pin 7 GND → GND, 470 µF across them
//   DFPlayer pin 6 SPK1 / pin 8 SPK2 → speaker
//
// Card: the DFPlayer's own microSD, FAT32, clips in /01/001.mp3 … /01/063.mp3
// (VOICE_CLIPS.md).
//
//  1. Starts the player and counts the files in folder 01. Expect 13.
//  2. Plays 001 ("Please take your medicine.") on its own.
//  3. Plays a full sentence: 001 002 011 012 003 013.
//  4. Then waits for Serial commands:
//       a number   play that clip, e.g. 1, 2, 11, 51, 63
//       s          the sentence again
//       a          every clip, one after the other
//       + / -      volume up / down (0–30)
//
// Pass: clip 001 is clear, BUSY reads LOW while it plays, and the ESP32 does
// not reset. If it resets during a clip, the speaker pulled the 5 V line down:
// lower the volume or check the 470 µF capacitor.

#include <DFRobotDFPlayerMini.h>
#include <esp_system.h>

const int DF_TX_PIN = 27;     // ESP32 → DFPlayer RX (through 1 kΩ)
const int DF_RX_PIN = 34;     // DFPlayer TX → ESP32
const int DF_BUSY_PIN = 35;   // LOW while playing
const int FOLDER = 1;         // /01/ = English
const int START_VOLUME = 30;  // of 30; chosen by ear on the bench, no brownout on laptop USB (Nov 2)

HardwareSerial dfSerial(2);
DFRobotDFPlayerMini player;
int volume = START_VOLUME;
bool busySeen = false;        // BUSY went LOW at least once

struct Clip { int number; const char *text; };
const Clip CLIPS[] = {
    {1, "Please take your medicine."}, {2, "Compartment"}, {3, "and"},
    {11, "one"}, {12, "two"}, {13, "three"}, {14, "four"}, {15, "five"}, {16, "six"},
    {51, "Dose confirmed."}, {61, "Pairing mode."}, {62, "Phone connected."},
    {63, "Pairing cancelled."},
};
const int CLIP_COUNT = sizeof(CLIPS) / sizeof(CLIPS[0]);

static const char *clipText(int n) {
    for (int i = 0; i < CLIP_COUNT; i++) if (CLIPS[i].number == n) return CLIPS[i].text;
    return "(not a HealthSync clip)";
}

static void printMessage(uint8_t type, int value) {
    switch (type) {
        case DFPlayerCardRemoved:  Serial.println("  player: card removed"); break;
        case DFPlayerCardInserted: Serial.println("  player: card inserted"); break;
        case DFPlayerCardOnline:   Serial.println("  player: card online"); break;
        case DFPlayerPlayFinished: break;   // BUSY already tells us
        case DFPlayerError:
            Serial.print("  player error: ");
            switch (value) {
                case Busy:             Serial.println("card not found (not FAT32, or not pushed in)"); break;
                case Sleeping:         Serial.println("sleeping"); break;
                case SerialWrongStack: Serial.println("garbled command (check the 1 kΩ / RX wire)"); break;
                case CheckSumNotMatch: Serial.println("checksum mismatch (noise on the RX wire)"); break;
                case FileIndexOut:     Serial.println("file number out of range"); break;
                case FileMismatch:     Serial.println("file not found (check the name and the 01 folder)"); break;
                case Advertise:        Serial.println("advertise"); break;
                default:               Serial.printf("code %d\n", value); break;
            }
            break;
        default: break;
    }
}

static void drainMessages() {
    while (player.available()) printMessage(player.readType(), player.read());
}

// Plays one clip and returns once it has finished.
static void playClip(int n) {
    Serial.printf("Playing %03d  \"%s\"\n", n, clipText(n));
    player.playFolder(FOLDER, n);

    unsigned long start = millis();
    while (digitalRead(DF_BUSY_PIN) == HIGH && millis() - start < 1000) delay(5);
    if (digitalRead(DF_BUSY_PIN) == HIGH) {
        Serial.println("  BUSY never went LOW: no clip started, or the BUSY wire (pin 16 → GPIO 35) is off");
        drainMessages();
        delay(2500);   // give a clip that did start time to finish
        return;
    }
    busySeen = true;
    unsigned long began = millis();
    while (digitalRead(DF_BUSY_PIN) == LOW && millis() - began < 15000) delay(5);
    Serial.printf("  played for %lu ms\n", millis() - began);
    delay(30);   // the player needs a moment before the next command
    drainMessages();
}

static void playSentence() {
    Serial.println("Sentence: \"Please take your medicine. Compartment one, two and three.\"");
    const int parts[] = {1, 2, 11, 12, 3, 13};
    for (int n : parts) playClip(n);
}

static void printResetReason() {
    esp_reset_reason_t r = esp_reset_reason();
    if (r == ESP_RST_BROWNOUT) {
        Serial.println("!! The last reset was a BROWNOUT: the 5 V line dipped, most likely");
        Serial.println("!! while the speaker played. Lower the volume or check the 470 uF capacitor.");
    }
}

void setup() {
    Serial.begin(115200);
    delay(2000);   // give the Serial Monitor time to connect after an upload
    Serial.println("\n=== HealthSync DFPlayer test ===");
    printResetReason();

    pinMode(DF_BUSY_PIN, INPUT);   // GPIO 35 has no internal pull-up; the DFPlayer drives it
    Serial.printf("BUSY before start: %s\n",
                  digitalRead(DF_BUSY_PIN) == HIGH ? "HIGH (idle, good)" : "LOW (check the BUSY wire and the player's 5 V)");

    dfSerial.begin(9600, SERIAL_8N1, DF_RX_PIN, DF_TX_PIN);
    // No reset command: restarting the player switches its amplifier on with a
    // current surge that browned out the ESP32 on laptop USB power (Nov 2).
    // The player is already started from power-on, so ask for its volume instead.
    Serial.println("Starting the player...");
    delay(1500);   // the player reads its card for about 1 s after power-on
    player.begin(dfSerial, true, false);
    player.setTimeOut(500);
    if (player.readVolume() >= 0) {
        Serial.println("  player answered");
    } else {
        Serial.println("  NO answer from the player. Check:");
        Serial.println("    1. VCC (pin 1) on 5 V and GND (pin 7) on GND: the beep test");
        Serial.println("    2. DFPlayer TX (pin 3) -> GPIO 34, and GPIO 27 -> 1 kOhm -> RX (pin 2)");
        Serial.println("    3. The card is FAT32 and pushed fully in");
        Serial.println("  Trying to play anyway: if you hear clip 001, only the TX -> GPIO 34 wire is off.");
        player.begin(dfSerial, false, false);
    }
    player.setTimeOut(500);
    player.volume(volume);
    delay(100);

    int files = player.readFileCountsInFolder(FOLDER);
    if (files < 0) Serial.println("Files in folder 01: no answer (some clone players do not report this)");
    else Serial.printf("Files in folder 01: %d %s\n", files, files == CLIP_COUNT ? "(all 13, good)" : "(expected 13)");
    Serial.printf("Volume: %d of 30\n\n", volume);

    playClip(1);
    delay(800);
    playSentence();

    Serial.println();
    if (busySeen) Serial.println("BUSY works.");
    Serial.println("Commands: a clip number (1, 2, 3, 11-16, 51, 61-63), s = sentence, a = all clips, + / - = volume");
}

void loop() {
    drainMessages();
    if (!Serial.available()) { delay(20); return; }

    String line = Serial.readStringUntil('\n');
    line.trim();
    if (line.length() == 0) return;

    if (line == "s") {
        playSentence();
    } else if (line == "a") {
        for (int i = 0; i < CLIP_COUNT; i++) { playClip(CLIPS[i].number); delay(300); }
    } else if (line == "+" || line == "-") {
        volume = constrain(volume + (line == "+" ? 2 : -2), 0, 30);
        player.volume(volume);
        Serial.printf("Volume: %d of 30\n", volume);
    } else if (line.toInt() > 0 && line.toInt() < 256) {
        playClip(line.toInt());
    } else {
        Serial.println("Commands: a clip number, s, a, + or -");
    }
}
