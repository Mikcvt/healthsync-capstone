# Hardware Assessment Form — HealthSync Smart Medicine Box

> Prepared by: Christian  
> Date: _______________  
> Status: In Progress → Complete  
> Build: **6 compartments** (6 LEDs)  
> Last updated: October 19, 2026

---

## 1. Component Photos

### 1.1 ESP32 DevKit V1 (ESP32-WROOM-32)
<!-- Paste your photo here or drag and drop the image into this section -->
![ESP32 DevKit](photos/esp32.jpg)

> The main microcontroller of the HealthSync Smart Medicine Box. Handles Wi-Fi connectivity, GPIO control for LEDs, button input, buzzer output, I2C communication with the DS3231 RTC, and SPI communication with the microSD module.  
> ⚠️ Must be a **WROOM** board: the buzzer (GPIO 17) and button (GPIO 16) use pins that a WROVER board reserves for PSRAM.

---

### 1.2 6 × LEDs (5mm)
<!-- Paste your photo here -->
![LEDs](photos/leds.jpg)

> One LED per compartment (6 total). Lights up to indicate which compartment has a dose due. Red, yellow, or green recommended — avoid blue/white as they require ~3.0V and will be dim on a 3.3V pin.

---

### 1.3 6 × 220Ω Resistors
<!-- Paste your photo here -->
![220 Ohm Resistors](photos/resistors_220.jpg)

> Current-limiting resistors for each LED. Limits current to ~6mA per LED to protect the ESP32 GPIO pins. Even with all 6 LEDs on, total draw is ~36mA — within the ESP32's budget.

---

### 1.4 Push Button (6 mm normally-closed panel button)
<!-- Paste your photo here -->
![Push Button](photos/button.jpg)

> The physical button mounted on the front of the medicine box: a 6 mm **normally-closed (NC)** panel button in a 7.2 mm hole. Normally closed means it connects while idle and opens when pressed, so the pin reads LOW idle and HIGH pressed (`BUTTON_PRESSED_LEVEL HIGH` in `config.h`). Wired from **GPIO 16 to GND**; the ESP32's internal pull-up keeps the pin HIGH until it is pressed (pressed = LOW).
>
> **The button's job grows by phase:**
> - **Phase 1 (now, temporary):** turns off the lit LED(s) and the buzzer on the box only. The dose must still be confirmed in the app.
> - **Phase 2:** confirms the dose. Equal in authority to the "Taken" button in the app — whoever acts first wins. Requires a press of ≥300ms so bumping the box does not confirm a dose.
>
> - **Wi-Fi setup (Phase 3):** holding it for 5 seconds while no LED is lit opens the box's Wi-Fi setup hotspot (the LEDs fill up 1→6 while it is held); the same hold closes setup. A short press never does this.
>
> **Why this matters:** If the patient does not have their phone nearby, the LED and buzzer will continue alerting. The button gives them a way to stop the alert and (from Phase 2) log the dose without needing the app.

**Phase 1 behavior (temporary):**

| Condition | Behavior |
|---|---|
| Pressed while LEDs are lit | LEDs and buzzer off at once; those compartments stay off until their dose is no longer due |
| Pressed with nothing lit | Ignored |
| Patient taps "Taken" in the app | Next poll (≤60s) drops the LED → LED and buzzer off, no button needed |

**Phase 2 scenarios and how they will be handled:**

| # | Scenario | Behavior |
|---|---|---|
| 1 | Patient has phone, taps "Taken" in app | Worker updates Firestore → next `/state` poll (≤60s) drops LED from `lit` → LED and buzzer turn off |
| 2 | Patient has no phone, presses button | Box posts `taken` → LED and buzzer turn off immediately → app reflects it when opened later |
| 3 | Patient presses button, then later taps "Taken" in app | First action wins — no duplicate logs |
| 4 | Patient taps "Taken" in app, then presses button | LED already off → button press gives a low beep ("nothing due") |
| 5 | Patient accidentally bumps the box | ≥300ms press requirement prevents accidental triggers |
| 6 | Multiple LEDs lit, patient presses button once | ⚠️ OPEN DECISION: confirm all lit compartments at once (simpler for elderly) vs. one per press (more precise). Currently leaning toward all at once — needs team agreement. |
| 7 | Box is offline, patient presses button | (Phase 4) Queued to `queue.jsonl` → LED and buzzer turn off immediately → replayed to Worker on reconnect |
| 8 | Box offline, dose window expires before reconnect | (Phase 4) Worker sweep marks dose `missed`, but replayed `pressed_at` inside the window corrects it to `taken` |
| 9 | Patient presses button but did not actually take medicine | No sensor can detect this — known limitation. Care partner is notified either way and can follow up. |
| 10 | Patient never presses button or taps app | After 60 min past scheduled time → Worker sweep marks dose `missed` → LED and buzzer stop → care partner notified |
| 11 | Box loses power during active dose alert | On power return → box reboots → fetches `/state` → LED relights if dose still pending |

> ⚠️ **Pending team decisions:**
> - Scenario 6: one press = all lit compartments, or one press = one compartment?
> - Should the care partner app show a different notification when confirmation came from the button vs. the app?

---

### 1.5 10kΩ Resistor — not used
<!-- Paste your photo here -->
![10k Ohm Resistor](photos/resistor_10k.jpg)

> No longer needed. The button is wired from GPIO 16 to GND and uses the ESP32's internal pull-up resistor instead of an external pull-down.

---

### 1.6 Active Buzzer
<!-- Paste your photo here -->
![Active Buzzer](photos/buzzer.jpg)

> Beeps while a dose is due to alert the patient: 5 short beeps every minute. Active type (beeps on DC, no PWM needed). Controlled from GPIO 17. Driven through an NPN transistor since most buzzers draw 25–30mA, more than an ESP32 pin should supply directly. Silenced immediately when the button is pressed or when the app marks the dose as taken.

---

### 1.7 NPN Transistor + 1kΩ Resistor
<!-- Paste your photo here -->
![NPN Transistor](photos/transistor.jpg)

> Drives the buzzer safely. The 1kΩ resistor is placed between GPIO 17 and the transistor base. Allows a 5V buzzer to be controlled from a 3.3V GPIO pin without damaging the ESP32.

---

### 1.8 1N4148 Diode
<!-- Paste your photo here -->
![1N4148 Diode](photos/diode.jpg)

> Optional flyback/protection diode placed across the buzzer. Protects the NPN transistor from back-EMF voltage spikes when the buzzer turns off.

---

### 1.9 DS3231 RTC Module (ZS-042) + Coin Cell
<!-- Paste your photo here -->
![DS3231 RTC](photos/ds3231.jpg)

> Real-time clock module. Keeps accurate time even when Wi-Fi is down or the ESP32 is restarting. Communicates via I2C (SDA: GPIO 21, SCL: GPIO 22). Drift is ~±1 minute per year; corrected by NTP every 6 hours when online. Used from Phase 4 (offline).  
> ⚠️ **Note:** ZS-042 boards have a charging circuit for LIR2032. If using a standard CR2032, desolder the charging resistor to prevent battery damage.

---

### 1.10 MicroSD Card Module (SPI) + MicroSD Card (≤32GB, FAT32)
<!-- Paste your photo here -->
![MicroSD Module](photos/microsd.jpg)

> Used for offline queue storage (`queue.jsonl`) and schedule cache (`schedule.json`) from Phase 4. Communicates via SPI (SCK: GPIO 18, MOSI: GPIO 19, MISO: GPIO 23, CS: GPIO 15).  
> ⚠️ **Wiring note:** the ESP32's standard SPI pins are MISO 19 / MOSI 23 — ours are the other way round. The firmware follows our wiring, but if the card will not start, try swapping MOSI and MISO first.  
> ⚠️ **Power note:** The common blue module with AMS1117 regulator requires **5V on VCC** (from ESP32 `VIN`). Feeding it 3.3V causes random initialization failures.

---

### 1.11 Full Assembly / Breadboard Setup
<!-- Paste your photo here -->
![Full Assembly](photos/full_assembly.jpg)

> Complete wiring of all components on the breadboard. All grounds are joined: ESP32 GND, LED cathodes, button, transistor emitter, DS3231 GND, and SD GND.

---

## 2. Actual Pin List

| Function | GPIO | Direction | Notes |
|---|---|---|---|
| LED — Compartment 1 | 13 | Output | — |
| LED — Compartment 2 | 14 | Output | Brief flicker at boot (PWM signal on GPIO 14). Harmless. |
| LED — Compartment 3 | 25 | Output | — |
| LED — Compartment 4 | 26 | Output | — |
| LED — Compartment 5 | 32 | Output | — |
| LED — Compartment 6 | 33 | Output | — |
| Push Button | 16 | Input | Wired to GND. Internal pull-up (`INPUT_PULLUP`). NC button: idle LOW, pressed HIGH. ⚠️ WROOM only (PSRAM pin on WROVER). |
| Active Buzzer (via NPN) | 17 | Output | HIGH = sound. ⚠️ WROOM only (PSRAM pin on WROVER). |
| MicroSD SCK | 18 | SPI | — |
| MicroSD MOSI | 19 | SPI | Swapped vs. the ESP32 default (see 1.10). |
| MicroSD MISO | 23 | SPI | Swapped vs. the ESP32 default (see 1.10). |
| MicroSD CS | 15 | SPI | Strapping pin. The SD module's pull-up keeps it high at boot. Harmless. |
| DS3231 SDA | 21 | I2C | Default I2C. Module has onboard pull-ups — do not add more. |
| DS3231 SCL | 22 | I2C | Default I2C. |
| Built-in LED (Wi-Fi status) | 2 | Output | Already on the board. On while Wi-Fi is connected. |

**Pins deliberately NOT used:**  
`0` (strapping, boot button), `5` (strapping), `6–11` (flash memory), `12` (strapping — HIGH at boot bricks the boot), `34–39` (input-only).

**Compartments 7 and 8:** the app lets the care partner choose compartments 1–8, but this box has 6. A medicine set to 7 or 8 gets phone reminders only; no LED lights. Care partners should use 1–6.

---

## 3. Firmware Location

| Item | Details |
|---|---|
| Repository | `healthsync-capstone` |
| Branch | `feature/medbox-integration` (never `main` or `release`) |
| Firmware path | `firmware/healthsync_box/` |
| Main entry point | `firmware/healthsync_box/healthsync_box.ino` |
| IDE | Arduino IDE (ESP32 board support) |
| Committed | ✅ Folder and docs — commit `4739071`. Phase 1 code not yet committed. |

### Firmware File Structure

```
firmware/healthsync_box/
├── healthsync_box.ino     — setup() and loop() only, calls all modules
├── config.h               — pins, poll interval, Worker URL
├── config.example.h       — safe-to-commit template (copy → secrets.h), placeholders only
├── secrets.h              — serial + setup hotspot password (git-ignored, flashed per box)
├── leds.cpp / leds.h      — leds_set(), leds_all_off(), leds_self_test()
├── button.cpp / button.h  — debounced press detection
├── buzzer.cpp / buzzer.h  — non-blocking beep pattern
├── net.cpp / net.h        — Wi-Fi, HTTPS to Worker
├── rtc_clock.cpp / rtc_clock.h — DS3231 read/write, NTP sync (Phase 4)
├── storage.cpp / storage.h    — SD: schedule.json, queue.jsonl (Phase 4)
├── schedule.cpp / schedule.h  — offline "what is due now" logic (Phase 4)
├── .gitignore             — excludes secrets.h
└── README.md
```

See `FIRMWARE_ARCHITECTURE.md` for the phases and what each file does.

---

## 4. Sign-off

| Item | Status |
|---|---|
| Component photos attached | ☐ |
| Actual pin list verified against physical wiring | ✅ Pins confirmed Oct 19, 2026 (re-check against photo 1.11) |
| Firmware committed and pushed to repo | ☐ Phase 1 pending |
| Form reviewed by team | ☐ |
