# Tracker review: Christian's tasks (October 22, 2026)

Source: HealthSync tracker, Tasks tab filtered to owner Christian or All,
plus the Risks & Decisions, Key Dates, Requirements and Hardware tabs (read
Oct 22). Compared with the repo (`feature/medbox-integration`, commit
`286c33b`, Oct 20) and the bench results in `WORK_NOTES.md`.

The agent can only read the sheet. Christian edits it by hand (see "How to
apply" at the end).

## Evidence links

| What | Link |
|---|---|
| Firmware folder | https://github.com/Mikcvt/healthsync-capstone/tree/feature/medbox-integration/firmware/healthsync_box |
| Commit of Oct 20 | https://github.com/Mikcvt/healthsync-capstone/commit/286c33b9a42c548ae351bbf26345668ce0d47183 |
| Work notes (bench results) | https://github.com/Mikcvt/healthsync-capstone/blob/feature/medbox-integration/firmware/healthsync_box/WORK_NOTES.md |
| Hardware assessment (pin list) | https://github.com/Mikcvt/healthsync-capstone/blob/feature/medbox-integration/firmware/healthsync_box/HARDWARE_ASSESSMENT.md |
| Test sketches | `…/firmware/healthsync_box/hw_test`, `…/sd_test`, `…/rtc_test` |
| Serial Monitor screenshots | Not online yet: upload the Oct 20 `sd_test` and `rtc_test` screenshots (and a short `hw_test` video) to the team Drive and use that folder link |

## Two findings to resolve first

1. **Bluetooth replaced Wi-Fi on Oct 21** (HW-08, HW-09, HW-10, HW-13,
   DEV-27). The firmware built Oct 19–20 uses Wi-Fi: Phase 1 asks the Worker
   which LEDs to light; Phase 3 is the Wi-Fi setup hotspot. If Bluetooth is
   final, both are shelved (kept in git history), the box no longer needs the
   Worker or the Firebase key, and the next firmware work is the Bluetooth
   server from Miko's spec (DEV-27). The LED, buzzer, button, RTC and SD
   parts carry over. **Risks & Decisions still says DEC-3 "ESP32 reaches the
   cloud through Worker device endpoints"**: a new decision row is needed.
2. **The Hardware tab lists the button as a "6 mm NC panel" button.** NC =
   normally closed: connected while idle, open while pressed. That matches the
   Oct 20 bench symptom exactly ("held" when untouched, "up" when pressed). If
   that is the button on the breadboard, the wiring is fine and the firmware
   must read pressed = HIGH.

## Christian's answers (Oct 22)

| Question | Answer | Effect |
|---|---|---|
| Is Bluetooth final? | **Yes** | Wi-Fi Phase 1/3 shelved; next firmware = Bluetooth server per DEV-27 |
| Which button is on the board? | **6 mm NC panel button** | Not a wiring fault. Firmware must read pressed = HIGH (HW-26) |
| HW-01 photos / review | Photos and video were sent to the team, just not put in the document | HW-01 stays **Complete**; optionally link the chat/Drive photos |
| HW-05 sent to Mona? | **Yes** | HW-05 **Complete** after the notes are corrected |
| HW-23, HW-24, HW-25 | **Done** | All three → **Complete**; paste a photo or chat link as evidence |

## Tasks

Categories: **Done** (proof exists) · **Not done** (what is missing) ·
**Outdated** (date or wording to fix) · **Irrelevant** (none found) · **Ask**.

| ID | Status now | Suggested | Category | Exact change |
|---|---|---|---|---|
| PS-02 | Complete | Complete | Done (not verifiable here) | No change. Proof is Siemonne's tester list |
| HW-01 | Complete | Complete (answered Oct 22) | Done | The form is in the repo (updated Oct 20), but its 11 photo slots are empty and "Form reviewed by team" is unticked. Add the photos and Siemonne's review, then Evidence = HARDWARE_ASSESSMENT.md link. If Siemonne reviewed a version with photos elsewhere, keep Complete and link that |
| HW-02 | Complete | Complete | Done (not verifiable here) | No change if you have the receipts |
| HW-03 | Complete | Complete | Done | Evidence Link = firmware folder link. Notes: "Latest: commit 286c33b (Oct 20): firmware, test sketches, docs" |
| HW-04 | For Review | **Complete once the evidence is uploaded** | Done (links missing) | Proof: `sd_test` PASS and `rtc_test` PASS (Serial screenshots, Oct 20); `hw_test` Oct 20: LEDs 1–6 in order, buzzer, button. Upload the screenshots + a 20 s `hw_test` video to Drive, paste the folder link. Notes: replace "reported all parts working on Oct 8" with "Bench-tested Oct 20 with hw_test, sd_test, rtc_test (in the repo). Button reads inverted: NC type, firmware fix pending" |
| HW-05 | Complete | Complete (sent to Mona, Oct 22 answer) | **Outdated** | Notes are wrong ("Button GPIO 5, buzzer GPIO 18"). Replace with: "Frozen Oct 19 from the bench wiring: LEDs 13, 14, 25, 26, 32, 33; button 16 (to GND, internal pull-up); buzzer 17 (via NPN); SD SCK 18, MOSI 19, MISO 23, CS 15 (MOSI/MISO swapped vs the ESP32 default, verified Oct 20); RTC SDA 21, SCL 22." Evidence = HARDWARE_ASSESSMENT.md (section 2). **Ask:** was it sent to Mona and Miko? If not, send it today |
| HW-06 | Complete | Complete | **Outdated** | Notes: "Superseded Oct 21 by HW-15: one protected 18650 cell through the 134N3P module. DEC-8 on Risks & Decisions must be updated" |
| HW-07 | Not Started, Wed Oct 14 | Not Started, **Mon Oct 26** | **Outdated** (date passed) | Most facts exist in HARDWARE_ARCHITECTURE.md (parts, pins, power budget) but need the 18650 and Bluetooth changes. New date after DEV-27 and the HW-24 measurements |
| HW-08 | Not Started | Not Started | Not done | Missing: Miko's Bluetooth spec (DEV-27, due Oct 22). Notes: "Oct 19–20 firmware used Wi-Fi + Worker and a Wi-Fi setup hotspot; Bluetooth replaces both. LEDs, buzzer, button, RTC and SD carry over." Oct 27 holds only if the spec arrives by Oct 23 |
| HW-09 | Not Started | **In Progress** | Not done | LED, 5-beep buzzer pattern and button silence are written and bench-run (commit 286c33b), but they follow the Worker, not a stored schedule, and the button does not mark taken yet. Notes: "Partly built; needs the stored schedule from Bluetooth (HW-08) and the local trigger" |
| HW-10 | Not Started | Not Started | **Outdated** (Done When) | Done When says "Wi-Fi off". Change to: "Video: phone away / Bluetooth off, the dose is taken on the box, and after reconnecting it appears in the app with its original time." Notes: "RTC and SD hardware verified Oct 20; rtc_clock, storage, schedule modules are still empty" |
| HW-11 | Not Started | Not Started | Not done | No change |
| HW-12 | Not Started | Not Started | Not done | Notes: "Bench results so far: WORK_NOTES.md (Oct 20)" |
| HW-13 | Not Started | Not Started | Not done | No change. (The box needs no hotspot, but the phone still needs internet for the app) |
| HW-14 | Complete | Complete | Done | Evidence = the `sd_test` screenshot. Notes: "16 GB card; write/read test passed Oct 20 with our wiring (sd_test)" |
| HW-15 | Not Started | **Complete once logged** | **Outdated** | Decided Oct 21 (one protected 18650, single-cell holder), but Done When is "Decision logged" and DEC-8 still says "USB power; battery optional". Update DEC-8 (or add a new decision), then Complete. Notes: delete "Deferred per DEC-8. Revisit only if the panel expects battery power." Docs saying "no battery in this build" must be updated later |
| HW-16 | In Progress | In Progress | Not done | Partly: LED order 1–6 confirmed on the bench (hw_test); wire plan = HW-05 pins. Heights wait for HW-24. No status change |
| HW-17 | Not Started | Not Started | Not done | No change |
| HW-18 | Complete | Complete | **Outdated** (Done When) | Done When: "Print plan decided: a student prints, we buy the filament (Oct 21)" |
| HW-19 | Not Started | Not Started | Not done | No change |
| HW-20 | Not Started | Not Started | Not done | No change |
| HW-21 | Not Started | Not Started | Not done | Notes: "Breadboard wiring with the current pins is in HARDWARE_ARCHITECTURE.md Step 4; the 18650 + 134N3P power part is missing." (The agent can draft it) |
| HW-22 | Not Started | Not Started | Not done | No change |
| HW-23 | Not Started, Thu Oct 22 | **Complete** | Done (Christian, Oct 22) | Status = Complete; paste a photo or chat link as evidence |
| HW-24 | Not Started | **Complete** | Done (Christian, Oct 22) | Status = Complete; paste the measurements message as evidence |
| HW-25 | Not Started | **Complete** | Done (Christian, Oct 22) | Status = Complete; paste a photo/receipt as evidence. Then HW-15 can be Complete too once DEC-8 is updated |
| DEF-03 | Not Started | Not Started | Not done | No change. Your answers: hardware, offline, ESP32 security |
| DEF-04 | Not Started | Not Started | Not done | No change |
| DEF-05 | Not Started | Not Started | Not done | No change |
| DEF-06 | Not Started | Not Started | Not done | No change |

**Irrelevant:** none of these tasks. What becomes irrelevant if Bluetooth is
final is the Oct 19–20 Wi-Fi work (Worker `/state`, Wi-Fi setup hotspot), which
has no task row.

## New rows to add

| Where | New row |
|---|---|
| Tasks | `HW-26` · Hardware · "Button is a 6 mm NC panel button: firmware reads pressed = HIGH; re-test" · Christian · P0 · Fri Oct 23 · Depends on: — · Done When: "Serial shows one Button down/up per press, none for 1 min untouched" (confirmed Oct 22: the NC button is the one in use) |
| Risks & Decisions | New decision: "Box ↔ phone over Bluetooth (BLE); the phone relays to Firestore. Supersedes DEC-3." · Owner Miko/Team · Date Oct 21 · Affected: HW-08, HW-09, HW-10, DEV-15, DEV-17, DEV-27 |
| Risks & Decisions | Update DEC-8: "Battery: one protected 18650 through the 134N3P module (Oct 21)" · Affected: HW-06, HW-15, HW-25 |

## Hardware tab corrections (Christian keeps this tab)

| Row | Change |
|---|---|
| 3 Push button | Notes: "GPIO 16 to GND, internal pull-up. NC type: pressed = HIGH (firmware fix HW-26)." Score stays 3 once the evidence link is added |
| 4 Active buzzer | Notes: "GPIO 17 via NPN." Add the evidence link (hw_test) |
| 6 microSD module + card | Add the evidence link (sd_test PASS, Oct 20) |
| 5 DS3231 | Add the evidence link (rtc_test PASS, Oct 20) |
| 10 Firmware: Wi-Fi + HTTPS to Worker | Rename to "Firmware: Bluetooth (BLE) link"; score **0**. Note: "Wi-Fi version built and bench-run Oct 20, replaced by Bluetooth Oct 21" |
| 11 LED + buzzer control | Score **3**, evidence = hw_test video. Note: "LEDs 1–6, 5-beep pattern" |
| 12 Button read + debounce | Score **2**: written; NC polarity to fix |
| 13 RTC read/set; local alarm | Score **2**: read/set tested with rtc_test; the rtc_clock module and the local alarm are not written |
| 14 microSD log | Score **1**: card works (sd_test); the storage module is still empty (the current note "Source in repo" is wrong) |
| 15–17 Integration | Note: "Waits on DEV-27 (Bluetooth spec) and HW-08" instead of DEV-15 |
| Pin table | LED 5 = **32**, LED 6 = **33**, button = **16**, buzzer = **17**, SD MOSI = **19**, MISO = **23**, SCK = **18**, CS = **15**. Delete the line "Button 5 and buzzer 18 come from the Oct 19 hardware notes" |
| Rows 1–6 "Score 3 without an evidence link" | Fixed by the Drive links above |

## Daily Log entry (Oct 22, Christian)

| Done since last update | Doing next | Blocked? | Blocker |
|---|---|---|---|
| HW-03 commit 286c33b (Oct 20); HW-04 bench tests passed (hw_test, sd_test, rtc_test, Oct 20); HW-05 pins frozen; HW-14 SD write/read passed | HW-26 button fix; HW-08 once the spec arrives; HW-16; HW-21 | Y | Waiting for DEV-27 Bluetooth spec (Miko). The new decision (Bluetooth replaces DEC-3) is not logged yet |

## How to apply (from the tracker guide)

- Done → Status = Complete and paste the proof in Evidence Link.
- Outdated → fix Target Date / Notes. Orange dates are proposals: confirm or
  correct them.
- Irrelevant → do NOT delete the row; Status = Deferred, reason in Notes.
- New task → next empty row, new ID.
- Log the day in the Daily Log tab.
