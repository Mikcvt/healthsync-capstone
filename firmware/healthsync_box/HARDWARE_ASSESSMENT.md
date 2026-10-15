# Hardware Assessment Form — HealthSync Smart Medicine Box

> Prepared by: Christian  
> Date: _______________  
> Status: In Progress → Complete  

---

## 1. Component Photos

### 1.1 ESP32 DevKit V1 (ESP32-WROOM-32)
<!-- Paste your photo here or drag and drop the image into this section -->
![ESP32 DevKit](photos/esp32.jpg)

> The main microcontroller of the HealthSync Smart Medicine Box. Handles Wi-Fi connectivity, GPIO control for LEDs, button input, buzzer output, I2C communication with the DS3231 RTC, and SPI communication with the microSD module.

---

### 1.2 8 × LEDs (5mm)
<!-- Paste your photo here -->
![LEDs](photos/leds.jpg)

> One LED per compartment (8 total). Lights up to indicate which compartment has a dose due. Red, yellow, or green recommended — avoid blue/white as they require ~3.0V and will be dim on a 3.3V pin.

---

### 1.3 8 × 220Ω Resistors
<!-- Paste your photo here -->
![220 Ohm Resistors](photos/resistors_220.jpg)

> Current-limiting resistors for each LED. Limits current to ~6mA per LED to protect the ESP32 GPIO pins. Even with all 8 LEDs on, total draw is ~48mA — within the ESP32's budget.

---

### 1.4 Tactile Push Button (12mm)
<!-- Paste your photo here -->
![Push Button](photos/button.jpg)

> The physical confirmation button mounted on the medicine box. 12mm size chosen for ease of use by elderly patients. Requires a press of ≥300ms to confirm a dose, preventing accidental triggers from bumping the box.
>
> **Primary role:** The button is the primary physical way for a patient to confirm they took their medicine and to immediately turn off the LED(s) and buzzer. It is equal in authority to the "Taken" button in the app — whoever acts first wins.
>
> **Why this matters:** If the patient does not have their phone nearby, the LED and buzzer will continue alerting. The button gives them a way to stop the alert and log the dose without needing the app.
>
> **Button press behavior:**
> - Turns off all currently lit LEDs and silences the buzzer immediately
> - Posts a `taken` event to the Worker (online), or queues it to `queue.jsonl` on the SD card (offline)
> - If no LED is lit when pressed → one low beep ("nothing due")

**Known scenarios and how they are handled:**

| # | Scenario | Behavior |
|---|---|---|
| 1 | Patient has phone, taps "Taken" in app | Worker updates Firestore → next `/state` poll (≤60s) drops LED from `lit` → LED and buzzer turn off |
| 2 | Patient has no phone, presses button | Box posts `taken` → LED and buzzer turn off immediately → app reflects it when opened later |
| 3 | Patient presses button, then later taps "Taken" in app | First action wins — `event_id` makes the second call idempotent, no duplicate logs |
| 4 | Patient taps "Taken" in app, then presses button | LED already off → button press gives a low beep ("nothing due") |
| 5 | Patient accidentally bumps the box | ≥300ms press requirement prevents accidental triggers |
| 6 | Multiple LEDs lit, patient presses button once | ⚠️ OPEN DECISION: confirm all lit compartments at once (simpler for elderly) vs. one per press (more precise). Currently leaning toward all at once — needs team agreement. |
| 7 | Box is offline, patient presses button | Queued to `queue.jsonl` → LED and buzzer turn off immediately in RAM → replayed to Worker on reconnect |
| 8 | Box offline, dose window expires before reconnect | Worker sweep marks dose `missed`, but replayed `pressed_at` inside the window corrects it to `taken` |
| 9 | Patient presses button but did not actually take medicine | No sensor can detect this — known limitation. Care partner is notified either way and can follow up. |
| 10 | Patient never presses button or taps app | After 60 min past scheduled time → Worker sweep marks dose `missed` → LED and buzzer stop → care partner notified |
| 11 | Box loses power during active dose alert | On power return → box reboots → fetches `/state` → LED relights if dose still pending |

> ⚠️ **Pending team decisions:**
> - Scenario 6: one press = all lit compartments, or one press = one compartment?
> - Scenario 5: should the care partner app show a different notification when confirmation came from the button vs. the app?

---

### 1.5 10kΩ Resistor
<!-- Paste your photo here -->
![10k Ohm Resistor](photos/resistor_10k.jpg)

> Pull-down resistor for the push button. Keeps GPIO 5 at LOW when the button is not pressed, ensuring a clean signal read.

---

### 1.6 Active Buzzer
<!-- Paste your photo here -->
![Active Buzzer](photos/buzzer.jpg)

> Beeps while a dose is due to alert the patient. Active type (beeps on DC, no PWM needed). Driven through an NPN transistor since most buzzers draw 25–30mA, more than an ESP32 pin should supply directly. Silenced immediately when the button is pressed or when the app marks the dose as taken.

---

### 1.7 NPN Transistor + 1kΩ Resistor
<!-- Paste your photo here -->
![NPN Transistor](photos/transistor.jpg)

> Drives the buzzer safely. The 1kΩ resistor is placed between GPIO 18 and the transistor base. Allows a 5V buzzer to be controlled from a 3.3V GPIO pin without damaging the ESP32.

---

### 1.8 1N4148 Diode
<!-- Paste your photo here -->
![1N4148 Diode](photos/diode.jpg)

> Optional flyback/protection diode placed across the buzzer. Protects the NPN transistor from back-EMF voltage spikes when the buzzer turns off.

---

### 1.9 DS3231 RTC Module (ZS-042) + Coin Cell
<!-- Paste your photo here -->
![DS3231 RTC](photos/ds3231.jpg)

> Real-time clock module. Keeps accurate time even when Wi-Fi is down or the ESP32 is restarting. Communicates via I2C (SDA: GPIO 21, SCL: GPIO 22). Drift is ~±1 minute per year; corrected by NTP every 6 hours when online.  
> ⚠️ **Note:** ZS-042 boards have a charging circuit for LIR2032. If using a standard CR2032, desolder the charging resistor to prevent battery damage.

---

### 1.10 MicroSD Card Module (SPI) + MicroSD Card (≤32GB, FAT32)
<!-- Paste your photo here -->
![MicroSD Module](photos/microsd.jpg)

> Used for offline queue storage (`queue.jsonl`) and schedule cache (`schedule.json`). Communicates via SPI on custom pins (SCK: GPIO 15, MISO: GPIO 19, MOSI: GPIO 23, CS: GPIO 17).  
> ⚠️ **Power note:** The common blue module with AMS1117 regulator requires **5V on VCC** (from ESP32 `VIN`). Feeding it 3.3V causes random initialization failures.

---

### 1.11 Full Assembly / Breadboard Setup
<!-- Paste your photo here -->
![Full Assembly](photos/full_assembly.jpg)

> Complete wiring of all components on the breadboard. All grounds are joined: ESP32 GND, LED cathodes, button resistor, transistor emitter, DS3231 GND, and SD GND.

---

## 2. Actual Pin List

| Function | GPIO | Direction | Notes |
|---|---|---|---|
| LED — Compartment 1 | 13 | Output | — |
| LED — Compartment 2 | 14 | Output | Brief flicker at boot (PWM signal on GPIO 14). Harmless. |
| LED — Compartment 3 | 25 | Output | — |
| LED — Compartment 4 | 26 | Output | — |
| LED — Compartment 5 | 27 | Output | — |
| LED — Compartment 6 | 32 | Output | — |
| LED — Compartment 7 | 33 | Output | — |
| LED — Compartment 8 | 4  | Output | — |
| Push Button | 5 | Input | Strapping pin. External 10kΩ pull-down keeps boot stable. Move to GPIO 34/35 if boot loops occur. Primary physical confirmation — turns off all lit LEDs and buzzer immediately on ≥300ms press. Equal in authority to the app's "Taken" button. |
| Active Buzzer (via NPN) | 18 | Output | Default SPI clock reassigned; SD uses custom SPI pins instead. Silenced immediately on button press or when app marks dose taken. |
| DS3231 SDA | 21 | I2C | Default I2C. Module has onboard pull-ups — do not add more. |
| DS3231 SCL | 22 | I2C | Default I2C. |
| MicroSD MOSI | 23 | SPI | Custom SPI bus. |
| MicroSD MISO | 19 | SPI | Custom SPI bus. |
| MicroSD SCK | 15 | SPI | Strapping pin. Low at boot only silences Serial boot log. Harmless. |
| MicroSD CS | 17 | SPI | ⚠️ Do NOT use on WROVER boards (GPIO 16/17 = PSRAM). Fine on WROOM. |
| Built-in LED (Wi-Fi status) | 2 | Output | Already on the board. Used as Wi-Fi/provisioning indicator. |

**Pins deliberately NOT used:**  
`0, 2` (strapping), `6–11` (flash memory), `12` (strapping — HIGH at boot bricks the board), `34–39` (input-only, reserved as button fallback).

---

## 3. Firmware Location

| Item | Details |
|---|---|
| Repository | `healthsync-capstone` |
| Branch | `feature/medicine-box-firebase` |
| Firmware path | `firmware/healthsync_box/` |
| Main entry point | `firmware/healthsync_box/healthsync_box.ino` |
| IDE | Arduino IDE (ESP32 board support) |
| Committed | ✅ Yes — commit `2cdfe55` |

### Firmware File Structure

```
firmware/healthsync_box/
├── healthsync_box.ino     — setup() and loop() only, calls all modules
├── config.h               — pins, poll intervals, Worker URL
├── config.example.h       — safe-to-commit template (copy → secrets.h)
├── secrets.h              — serial + device_key (git-ignored, flashed per box)
├── leds.cpp / leds.h      — ledsSet(), ledsAllOff(), ledsSelfTest()
├── button.cpp / button.h  — debounced long-press → onButtonPressed()
├── buzzer.cpp / buzzer.h  — beep pattern, quiet hours
├── rtc_clock.cpp / rtc_clock.h — DS3231 read/write, NTP sync
├── storage.cpp / storage.h    — SD: schedule.json, queue.jsonl
├── net.cpp / net.h            — Wi-Fi, provisioning portal, HTTPS to Worker
├── schedule.cpp / schedule.h  — offline "what is due now" logic
├── .gitignore             — excludes secrets.h
└── README.md
```

---

## 4. Sign-off

| Item | Status |
|---|---|
| Component photos attached | ☐ |
| Actual pin list verified against physical wiring | ☐ |
| Firmware committed and pushed to repo | ✅ |
| Form reviewed by team | ☐ |
