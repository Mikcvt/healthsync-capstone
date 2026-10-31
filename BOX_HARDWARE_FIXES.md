# Medicine box: power, alarm, pairing and battery plan

> **Status:** decided Oct 31, 2026 (see "Decided"). Nothing is built yet.
> From Miko's bench test of box HS-0001 (firmware 0.4.1).
> Firmware changes need Christian's agreement (he owns the firmware and
> `BLE_PROTOCOL.md`); app changes go on `fixing-bugs-and-ble` and are tested
> on dev only.

Six requests, one section each:

| # | Request | Kind of fix | New parts |
|---|---|---|---|
| 1 | Box will not start on battery until USB-C is plugged in once | Hardware | A small switch or button (≈ ₱20–120) |
| 2 | Alarm: 5 s on, 2 s off, repeated for 30 min | Firmware | None |
| 3 | Pairing mode keeps running after the phone connects | Firmware bug | None |
| 4 | One press confirms every lit compartment | **Already built** | None (test only) |
| 5 | Battery percentage in the app | Hardware + firmware + app | 2 resistors (≈ ₱5) |
| 6 | Low-battery and fully-charged signals on the box | Firmware | None beyond #5 |

---

## 1. The box does not turn on from the battery

### What happens
1. The 18650 is in, but the box stays dark.
2. USB-C is plugged into the 134N3P: the box starts.
3. USB-C is pulled out: the box keeps running on the battery.

### Why
This is how many single-cell "charge + 5 V boost" modules work. When the
battery is connected, the module starts in **standby with its 5 V output
off**. It switches the output on only when it is woken: by a charger being
plugged in, or by a press on its **KEY** input. Once on, it stays on while
the load draws enough current.

Two things to check on the module before choosing a fix:

- **The chip's marking** (the largest chip on the module, often IP5306,
  FM5324, HT4928 or similar). Send a clear photo or the text on it.
- **A pad or pin labelled `KEY`, `K` or `SW`.** Many of these modules have one.

Also watch for the second habit of these modules: **switching off by itself
when the load is light** (often below about 45–50 mA, after 30 s or so). The
ESP32 with Bluetooth draws about 40–60 mA, so it is close to that line. Leave
the box on battery for a night: if it is dark in the morning, this is happening.

### Options

| | Option | How it works | Parts | Verdict |
|---|---|---|---|---|
| **A** | **Power button on the module's KEY pad** | A small push button from `KEY` to `GND` on the module. Press once: on. Most of these chips turn off with a double press or a long press (check the datasheet once the chip is known). | 1 tactile push button (≈ ₱5–20), 2 wires | **Recommended if the module has a KEY pad and does not switch off by itself.** Exactly "press a button to turn on and off" |
| **B** | **Replace the module: TP4056 + MT3608 + slide switch** | TP4056 (the version with the DW01 protection chip) charges the 18650; an MT3608 boost set to 5.1 V feeds the ESP32's VIN; a slide switch between them is a plain on/off. No standby, no auto-off. | TP4056 board, MT3608 board, 1 slide switch (≈ ₱80–120 in total) | **Recommended if the 134N3P has no KEY pad, or switches off by itself.** Most reliable |
| C | Slide switch on the battery wire | Cuts the battery. | 1 switch | **Not recommended.** Reconnecting the battery puts the module back in standby, so the box still will not start |
| D | Use the dose button to switch off (ESP32 deep sleep) | Hold the dose button 10 s to sleep. | None | **Not recommended.** GPIO 16 cannot wake the ESP32 from deep sleep; the module may cut its output when the load drops; and a patient could switch the box off by accident while confirming a dose, and then no alarm rings |

### Keep the dose button separate from the power button
The dose button is pressed every day, often in a hurry. If holding it could
turn the box off, sooner or later it will, and the next dose will not ring.
A separate power button, preferably recessed or on the side, avoids that.

### What "off" means for the patient
A box that is off does not light or ring. The phone still reminds as normal,
and the app keeps working without the box. The app should say so: see 5.4,
"Box last seen".

---

## 2. Alarm: 5 s tone, 2 s pause, for 30 minutes

### Now (firmware 0.4.1)
A 5 s tone, then silence until the next tone 5 minutes later, repeated until
the dose is taken or missed at +60 min.

### Wanted
- **Tone 5 s → pause 2 s → tone 5 s → …** for **30 minutes** from the dose time.
- **After 30 min** the buzzer stops; the **LED stays lit** until the dose is
  confirmed, skipped in the app, or missed at +60 min (as now).
- The button, or Done/Skip in the app (`app_done`), stops both at once (as now).

### Change
`config.h`:

```c
#define TONE_ALARM_MS     5000UL   // tone
#define ALARM_PAUSE_MS    2000UL   // pause between tones (was ALARM_REPEAT_MS 300000)
#define ALARM_BEEP_FOR_MS 1800000UL // beep for 30 min, then LED only
```

`buzzer.cpp`: the alarm cycle becomes 7 s (5 on, 2 off) and stops after
`ALARM_BEEP_FOR_MS`. Measured from when the dose first lit; a second dose
that lights later starts its own 30 minutes.

### Notes
- 30 min matches the app: at +30 min the care partner gets "Running late".
- Battery cost: about 30 mA for 5 s in every 7 s, for at most 30 min, about
  11 mAh per dose. Small next to the 2,500 mAh cell.

---

## 3. Pairing mode does not stop after connecting

### Why
Pairing mode closes when a **new** phone finishes pairing with the code
(`ble_take_paired_event`). A phone that is **already paired** reconnects with
no code, so that event never fires and the running light keeps going for the
full 2 minutes.

### Fix (firmware)
- Close pairing mode as soon as **any paired phone connects over an encrypted
  link** (already detected in `ble.cpp` as `_evSecure`), not only a newly
  paired one. Tone: the 3 s "paired" tone only for a new phone; a short 0.5 s
  tone for a returning one.
- Add a way out: a **short press while the lights are running cancels pairing
  mode** (1 tone, lights off).

---

## 4. One press confirms every lit compartment: already built

When several compartments are lit, one press of the button marks **all of
them** taken (`schedule_take` in `schedule.cpp`). Each becomes its own event on
the SD card, and the app saves each as its own dose log, counting one pill off
each medicine.

The bench test so far had only one lit dose at a time, so this still needs a
test:

1. In the dev app, give three medicines the same dose time, each in its own
   compartment (for example 1, 2 and 3).
2. Sync. At the dose time LEDs 1, 2 and 3 light together.
3. One press: all three go dark, a 1.5 s tone, and the log shows three
   `Dose TAKEN` lines.
4. Sync: three doses show taken in the app, and each medicine's pill count
   drops by one.

A dose that is not lit yet is never taken by a press (kept on purpose: a press
before the alarm may be an accident).

---

## 5. Battery percentage in the app

### Why it needs new parts
The ESP32 only ever sees the 134N3P's steady 5 V, whatever the battery holds.
To know the battery level it must measure the battery itself. **Today the box
cannot**, which is why `CLAUDE.md` ("No phantom features") forbids showing a
battery level. Adding the reading below makes it real; until a box reports it,
the app shows nothing.

### 5.1 Hardware: a voltage divider (2 resistors)

```
18650 + (B+ on the module) ──[100 kΩ]──┬──[100 kΩ]── GND
                                       │
                                       └── GPIO 34 (ADC, input only)
                                       (optional 0.1 µF from GPIO 34 to GND
                                        steadies the reading)
```

- 4.2 V full → 2.1 V at the pin; 3.0 V empty → 1.5 V. Safe for the ESP32.
- GPIO 34 is free, input-only, and on ADC1, which works while Bluetooth runs.
- 100 kΩ + 100 kΩ draws about 0.02 mA: nothing.
- **Bench fallback** with parts already on hand: two **1 kΩ** resistors (as used
  for the buzzer transistor). Works, but drains about 2 mA all the time
  (roughly 3% of the box's use). Swap to 100 kΩ for the final build.
- **Optional, for "charging" and "full":** a second divider (100 kΩ + 100 kΩ)
  from the module's **USB 5 V input** pad to **GPIO 35**. The ESP32 then knows
  when a charger is plugged in. Without it the box can only guess charging
  from a rising voltage.

### 5.2 Firmware
- Read the battery every minute (average 16 samples with
  `analogReadMilliVolts`, times 2 for the divider).
- Percent from an approximate Li-ion curve, rounded to 5%:

  | Volts | 4.20 | 4.10 | 4.00 | 3.90 | 3.80 | 3.70 | 3.60 | 3.50 | 3.40 | ≤ 3.30 |
  |---|---|---|---|---|---|---|---|---|---|---|
  | % | 100 | 90 | 80 | 65 | 50 | 35 | 20 | 10 | 5 | 0 |

- While charging, the voltage reads high, so the box reports "charging"
  rather than a percent that jumps around.
- **Protocol (BLE_PROTOCOL.md, needs Christian's agreement):** `hello` gains
  three optional fields:

  ```json
  {"op":"hello", ..., "batt_mv":3920, "batt_pct":65, "charging":false}
  ```

  A box without the divider leaves them out; the app then shows nothing.

### 5.3 App
- **Box tab:** a battery row, for example `Battery 65% · checked 3 min ago`,
  or `Charging`. Red below 20%.
- **Saved on the `devices` document** at every sync: `battery_percent`,
  `battery_charging`, `battery_checked_at` (new optional fields; the live
  build ignores them, so this is safe for the Play beta). The care partner's
  Smart box screen shows the same row.
- **"As of" always shown.** The phone connects only now and then, so the
  reading is from the last sync, never live. "65%" alone would be read as live.
- Later, optional: a "box battery low" alert to the care partner. That is a
  Worker change: dev first, then prod with a release.

### 5.4 Also worth adding: "Box last seen"
If the battery runs flat, or the box is switched off, the app cannot know the
battery level any more. But it does know when it last synced. Show
`Box last synced 2 days ago: is it switched on and charged?` when the last
sync is older than a day. Costs nothing, and covers a flat battery even before
the divider exists.

---

## 6. Low battery and fully charged, shown on the box

Uses only what the box already has: 6 LEDs, the buzzer, the button. Needs the
divider from 5.1 to know the level at all; "charging" and "full" need the
optional USB sense wire.

Each signal must look different from the ones already in use:

| Already used | Looks like |
|---|---|
| Dose due | One or more compartment LEDs **steady**, 5 s tone / 2 s pause |
| Pairing | LEDs fill 1→6 while holding, then a **running light** |
| Power on | All LEDs and buzzer briefly (self-test) |

### Proposed signals

| When | LEDs | Sound | Notes |
|---|---|---|---|
| **Press with nothing due** (check the battery) | **Battery bar**: LEDs 1→N steady for 3 s, N = level in sixths (6 = full, 1 = under 17%) | The existing 0.8 s "nothing due" tone | Like a phone's battery icon. Today this press only beeps |
| **Low battery** (≤ 15%) | **All 6 LEDs flash 3 times quickly**, every 2 minutes | Two short beeps, once when it first drops to 15% and once at 5%; no repeated beeping, so it never wakes anyone at night | Paused while a dose is lit: the dose always wins |
| **Charger plugged in** | Battery bar for 5 s, with the next LED **blinking** (filling up) | One short beep | Needs the USB sense wire |
| **Fully charged** | **All 6 LEDs steady 3 s**, once | One 1 s tone | Needs the USB sense wire; "full" = charging and ≥ 4.15 V for 5 min |
| **Power on** | Self-test, then the battery bar for 2 s | As now | Shows the level each time the box starts |

### Without the divider (today)
The box itself cannot tell. The only honest options:
- Use the **134N3P's own charge LEDs**, if it has any, and cut a small window
  or light pipe in the enclosure so they can be seen.
- "Box last seen" in the app (5.4).

---

## Order of work (suggested)

| Step | What | Who | Needs |
|---|---|---|---|
| 1 | Identify the 134N3P chip and KEY pad; overnight auto-off test | Miko / Christian | Photo of the module |
| 2 | Pairing fix (#3) and alarm pattern (#2) | Firmware | Nothing new; flash and test |
| 3 | Multi-dose test (#4) | Miko | Dev app, 3 medicines |
| 4 | Power button (#1, option A or B) | Hardware | Parts from step 1's answer |
| 5 | Battery divider (#5.1), firmware reading, `hello` fields | Hardware + firmware | 2 resistors (+2 for charging) |
| 6 | App battery row, devices fields, "Box last seen" (#5.3–5.4) | App | Step 5 for the reading; 5.4 can go first |
| 7 | Box battery signals (#6) | Firmware | Step 5 |
| 8 | Update `CLAUDE.md` ("No phantom features", `devices` model) and `BLE_PROTOCOL.md` once the reading is real | Docs | Step 5 |

## Decided (Miko, Oct 31, 2026)

| # | Topic | Decision |
|---|---|---|
| D1 | Power | **No switch: the box is always on, like AirPods.** Keep the **134N3P**: after the battery goes in, plug USB-C once and the box runs from then on. Options A–D in section 1 are dropped, and so is the one-button soft-power latch discussed in chat. **Condition:** it must pass the overnight test (still on in the morning, on battery). If it switches itself off at low load, move to the TP4056 + MT3608 supply (option B without its switch) |
| D2 | Alarm | 5 s tone / 2 s pause for 30 min, then **LED only, silent**, until confirmed, skipped or missed at +60 min |
| D3 | Battery reading | **Not now.** No divider, no battery % in the app, no battery signals on the box (sections 5.1–5.3 and 6 wait). The "No phantom features" rule stays as it is |
| D4 | Charging sense wire | Not now (follows D3) |
| D5 | Care partner low-battery alert | Not now (follows D3) |
| D6 | "Box last synced" warning in the app | **Yes, now** (section 5.4): the one way to notice a flat or dead box without a battery reading |

### Defaults taken (no choice needed)
- **Pairing fix (#3):** pairing mode closes when any paired phone connects;
  a short press while the lights run cancels it.
- **Multi-dose press (#4):** already built; run the 3-medicine test.
- **Power saving (Phase 5, Christian's C2):** needed for an always-on box to
  last more than about a day. Must be re-checked against D1's condition: lower
  current makes a light-load cut-out more likely.

### Work list after these decisions

| Step | What | Where | Parts |
|---|---|---|---|
| 1 | Overnight test of the 134N3P on battery | Bench | None |
| 2 | Alarm 5 s / 2 s for 30 min, then LED only (#2) | Firmware | **Done, fw 0.4.2 (Oct 31).** Flashed to HS-0001; the 30-min silence still to be heard on the bench |
| 3 | Pairing closes for a returning phone; short press cancels (#3) | Firmware | **Done, fw 0.4.2, tested Oct 31:** "Paired phone connected: pairing mode closed" and "Button: pairing mode cancelled" in the box log |
| 4 | 3-medicine one-press test (#4) | Bench + dev app | None |
| 5 | "Box last synced" warning (#5.4) | App | **Built Oct 31** (patient Box tab and care partner's Smart box screen, after 24 h without a sync); not yet installed on the phone |
| 6 | Power saving, then repeat the overnight test | Firmware (Christian) | None |
