# healthsync_box firmware

ESP32 firmware for the HealthSync medicine box: 6 compartment LEDs, an NC push
button, a buzzer, a DS3231 clock, a microSD dose log, Bluetooth LE to the
patient's phone, and voice prompts from a DFPlayer Mini (firmware 0.4.3,
Nov 3, 2026).

Read first:

| File | What it holds |
|---|---|
| `WORK_NOTES.md` | Status ("Start here"), decisions and bench results, phase by phase |
| `BLE_PROTOCOL.md` | Phone ↔ box protocol |
| `VOICE_CLIPS.md` | The voice clips, the alarm rounds, recording and the DFPlayer bench notes |
| `config.h` | Every pin and timing |

Build: Arduino ESP32 core 3.3.12, board `esp32:esp32:esp32` with
`PartitionScheme=huge_app`. Libraries: NimBLE-Arduino 2.5.1, ArduinoJson 7.4.3,
RTClib, DFRobotDFPlayerMini 1.0.6. `secrets.h` (serial and pairing code) is
git-ignored; copy `config.example.h`.

Bench sketches: `hw_test/`, `rtc_test/`, `sd_test/`, `dfplayer_test/`.
