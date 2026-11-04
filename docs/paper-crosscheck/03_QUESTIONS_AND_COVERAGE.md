# Part 3: Questions for people, unverifiable claims, coverage log

[Back to the index](REPORT.md)

## 13. Questions that need a human answer

### Status after the team's answers (Nov 4)

| ID | Answer | Still open |
|---|---|---|
| Q-LD1, Q-LD2 | The button is a **confirmation button** in the defended build (matches firmware 0.4.3) | — |
| Q-LD3 | **Drop both limits from the paper** | — |
| Q-LD4 | A reason for a missed dose is **required** | The app does not ask for it today (F-38): Miko to change the app, or the paper must say "optional" |
| Q-LD5 | The hosted APK `1.0.0+3` is the UAT and defense build | — |
| Q-LD6 | **Remove** `alert_pref_daily` and `max_patients` | Miko removes `alert_pref_daily` from the code |
| Q-LD7 | — | Still open |
| Q-PL1 | Closed test: first tester added Oct 14, first install Oct 15, ended evening of Oct 29; 25 testers registered; closed test and production-access application approved; production release rejected (organization account needed) | — |
| Q-PL2 | Reword to publishing / publicly hosting the APK (GitHub Releases) | Adviser approval of the final wording |
| Q-PL3 | Title confirmed: "A Mobile-Based Medication Reminder System with an IoT-Assisted LED-Guided Medicine Box for Care Partner-Supported Medication Adherence" | Month/year on the title page |
| Q-PL4 | School year 2026-2027 | — |
| Q-PL5 | — | Still open |
| Q-HW1, Q-HW2 | Battery 2200 mAh; all LED resistors 220 Ω | — |
| Q-HW3 | microSD on 5 V; buzzer rated 12 V DC (works 3–24 V) | Which rail the buzzer is wired to (5 V expected) |
| Q-HW4 | — | Still open |
| Q-HW5 | Mona will update the schematic | — |
| Q-HW6 | No brownout on the battery; the earlier resets were low battery | Charge the box before UAT and the defense |
| Q-AD1 | Adult respondents first | Whether minors are added later (then ethics, consent, assent) |
| Q-AD2 | IT experts: at least 3 | Number of box testers not set |
| Q-AD3 | — | Measured targets still to approve |
| Q-AD4 | Questionnaire approved; ISO/IEC 25010:2023 | — |
| Q-AD5 | See the note in Part 4 ("Approval Sheet") | Ask the capstone teacher for the final-defense form |
| Q-AD6 | Conversion guide: 4.3.3 = DFD Level 1 and 2 | Part 4 has a proposed DFD and the ERD approach for Firestore |
| Q-AD7 | — | Still open |
| Q-DOC1 | Questionnaire approved | Count Part B in the approved form (8 or 9) |

### Lead developer (Miko)

| ID | Question | Why it matters |
|---|---|---|
| Q-LD1 | **What is the push button's final job in the defended build?** The audit briefing says the box "no longer confirms doses (Oct 29, Nov 3)" and the button's function is undecided. But on `release-without-google-terms` (`36995c8`, Nov 3 21:22) the firmware 0.4.3 records a press during a lit dose as taken, the app writes it as `confirmed_via: "button"`, and the background watch that collects presses was turned on for every build in that same commit. Which is current? | 14 places in the paper, UAT statement B9, test cases and the scope depend on it (Part 1, section A). The panel will press the button. |
| Q-LD2 | Will the box firmware be changed before UAT/defense to match the decision (for example, a press only silences)? If so, which version will be flashed on the demo box? | The paper must describe the firmware actually on the box. |
| Q-LD3 | Should a care partner be limited to three patients and a patient to six medicines? Neither limit exists in the code. Add them, or should the paper drop them? | Delimitations p.16; a panelist can test it in a minute. |
| Q-LD4 | Is a reason for a missed dose meant to be optional (current code: the patient may add one later) or required? Who enters it, and when? | p.12 and p.14 say required; briefing lists this as an open question. |
| Q-LD5 | Is the hosted APK `1.0.0+3` (with the background watch) the exact build used in UAT and at the defense? | Background-watch text (F-26), tested-build statements, Part C C14. |
| Q-LD6 | Should `alert_pref_daily` and `max_patients` be removed from the data model, or will a daily summary be built? | Data dictionary Tables 8 (F-36, F-48). |
| Q-LD7 | Are `updated_at` fields meant to exist on users, patient_profile, dose_logs, notifications and devices (the paper lists them; the code does not)? | Data dictionary accuracy. |

### Project lead / Play Console owner (Siemonne)

| ID | Question | Why it matters |
|---|---|---|
| Q-PL1 | What are the exact closed-test start and end dates, track name, version and number of opted-in testers, as shown in Play Console? (Paper: Oct 15 to Oct 28; notes: published Oct 14.) | p.16 is the only evidence of the Google Play objective. |
| Q-PL2 | How should Objective 6 be worded now that production was refused twice and the app is a hosted APK? | Conclusions must answer each objective one-to-one. |
| Q-PL3 | What is the approved final title (with or without "HealthSync:")? What month goes on the title page? | Title page, approval sheet, letters and UAT forms disagree (F-89). |
| Q-PL4 | Which academic year(s) does the study cover? | p.15 says 2026-2027; Capstone 1 was AY 2025-2026. |
| Q-PL5 | Will the paper mention the hosted APK and the project website (download link) in 3.3 and in the deployment plan? | Distribution facts in F-27, F-30. |

### Hardware (Christian)

| ID | Question | Why it matters |
|---|---|---|
| Q-HW1 | What is printed on the 18650 cell (brand, capacity)? | Table 3 says PKCELL 3000 mAh; repo notes say 2,500–3,000 mAh. |
| Q-HW2 | Is every LED resistor 220 Ω? | Table 3 says 220–330 Ω, schematic text says 220 Ω. |
| Q-HW3 | What voltage are the microSD module and the buzzer wired to on the final box? | Table 3 lists "5 V or 3.3 V". |
| Q-HW4 | Is the external 10 kΩ pull-up on GPIO 16 fitted on the final box? | Schematic must match the build (`WORK_NOTES.md` suggests it). |
| Q-HW5 | Can you supply an updated schematic (Figure 4) with the DFPlayer Mini, speaker, 470 µF capacitor and the 1 kΩ on DFPlayer RX? | F-54. |
| Q-HW6 | Will the demo box run on the 18650 battery? (On laptop USB, voice at volume 30 browns the ESP32 out.) | Part B B7 and the demo. |

### Adviser

| ID | Question | Why it matters |
|---|---|---|
| Q-AD1 | Minimum respondent age: 18+ only, or 13-17 with guardian consent? If minors: ethics approval, consent and assent forms? | UAT tool allows 13-17; paper says 18+; app delimitation says 13+. |
| Q-AD2 | How many IT experts (at least 3?) and box testers? | 4.5 respondents table. |
| Q-AD3 | Approve the measured targets (task completion, on-time reminders, install success, BLE sync)? | Testing guide wants measurable targets. |
| Q-AD4 | Does the department follow ISO/IEC 25010:2023 for this paper? (Tool v2 says final per the GCR announcement.) | Edition must be consistent. |
| Q-AD5 | Approval sheet: Title Defense form or Final Defense form? | Template and guide differ. |
| Q-AD6 | Is a flowchart acceptable for 4.3.3, or is a Level 1 DFD required? | Conversion guide mentions DFD Level 1 and 2. |
| Q-AD7 | Should the Implementation and Deployment Plan stay inside 4.5? | Template's 4.5 is UAT only. |

### Testing / documentation (Adi and the documentation lead)

| ID | Question | Why it matters |
|---|---|---|
| Q-DOC1 | Part B: 8 statements (briefing) or 9 (UAT tool v2 in the folder)? | Paper and Appendix C must match the form used. |
| Q-DOC2 | Which QA workbook results go into Tables 16-18, and who ran them on which phones? | Tables have only "Pass / Fail". |
| Q-DOC3 | Is the "On my own" participation mode in the UAT form counted in the results? | Adviser wants observers. |

## 14. Claims that could not be verified

| Claim (page) | What would settle it | Who has it |
|---|---|---|
| Closed-test dates Oct 15 to Oct 28 (p.16) | Play Console release history | Siemonne |
| Testers recruited through a consent form (p.16) | The form and responses | Siemonne |
| Client details: father's stroke, family reminders, two wrong-time doses (p.9) | Interview notes with Mr. Mark Noah V. Sunga | Project lead |
| LED forward voltage about 2.0 V, about 6 mA (p.49) | Multimeter reading | Christian |
| Battery 3000 mAh PKCELL (p.50) | Cell label | Christian |
| Development workstation minimum and recommended specs (p.48) | Flutter/Android Studio official requirements at the versions used | Miko |
| "Tested on 4 GB RAM class" (p.48) | Test log naming the phone | Adi |
| Accessible interface, readable text (p.15, p.67) | UAT A11 results, task-completion data | Adi |
| "Encryption and cloud security services" (p.67) | Firebase documentation (Google encrypts data at rest and in transit) | Documentation lead |
| Table layouts (Tables 6-15) are correct visually | Open the source file | Documentation lead |
| Figures 1, 2, 3, 5, 6, 7, 8, 9, 10 drawings | The figures were not available as images in this audit (text layer only); their captions and descriptions were checked | Documentation lead (send the images for a second pass) |
| Fonts, margins, page numbers | The source document | Documentation lead |
| Chapter 2 literature claims about each source | The sources (not part of this audit) | Documentation lead |

## 15. Coverage log

### Paper pages

All 103 text pages were read in order from the text layer (pdftotext -layout). Page 104 is empty. Figures were **not** viewed as images (no image renderer was available in this session); their text descriptions were checked. "Findings" counts the findings anchored on that page (some findings cover several pages).

| Pages | Content | Read | Findings anchored |
|---|---|---|---|
| 1 | Title page | Yes | F-89 |
| 2 | Approval sheet (empty) | Yes | F-86, F-90 |
| 3 | Abstract (empty) | Yes | F-86 |
| 4 | Acknowledgment (empty) | Yes | F-86 |
| 5-6 | Table of contents | Yes | F-91 |
| 7 | Lists of tables and figures | Yes | F-92, P-31 |
| 8 | Blank | Yes | F-88 |
| 9-10 | 1.1 Project Context | Yes | F-99 |
| 10-12 | 1.2 Purpose and Description | Yes | F-34, F-38, F-69 |
| 12-13 | 1.3 Objectives | Yes | F-29, F-39, F-79 |
| 13-16 | 1.4 Scope | Yes | F-27, F-28, F-38, F-45, F-66, F-67, F-70 |
| 16-18 | 1.4 Delimitations | Yes | F-01, F-32, F-33, F-34, F-35, F-72, F-73, F-74 |
| 19-20 | 1.5 Significance | Yes | — |
| 20-26 | 1.6 Definitions | Yes | F-39, F-54, F-100, D-06 |
| 27-31 | 2.1.1 Foreign Literature | Yes | F-95, F-100 |
| 31-32 | 2.1.2 Local Literature | Yes | — |
| 32-35 | 2.2.1 Foreign Studies | Yes | — |
| 35-36 | 2.2.2 Local Studies | Yes | F-93, F-94 |
| 36-39 | 2.3 Synthesis | Yes | F-93, F-95, F-99 |
| 40-43 | 3.1 Technologies | Yes | F-63, F-71 |
| 43-45 | 3.2 Existing system, Table 1 | Yes | F-12, F-98 |
| 45-47 | 3.3 Feasibility, Figure 1 IPO | Yes | F-03, F-54 |
| 47-51 | 3.3.1 Hardware, Tables 2-3 | Yes | F-02, F-54, F-55, F-56, F-57, F-58, F-59 |
| 51-53 | 3.3.2 Software, Table 4 | Yes | F-25 |
| 54-55 | 3.3.3 Network, Table 5 | Yes | F-55 |
| 56-57 | Figure 2 System Architecture | Yes (text) | F-06, F-26, F-64 |
| 58-61 | Figure 3 Block Diagram | Yes (text) | F-07, F-24, F-26, F-64 |
| 62 | Figure 4 Schematic | Yes (text) | F-04, F-54, F-57 |
| 63-65 | 4.1 SDLC, Figure 5 | Yes | F-08, F-16, F-82 |
| 65-67 | 4.2 Requirements | Yes | F-05, F-36, F-37, F-83 |
| 68-69 | 4.3.1 Context Diagram (Figure 6) | Yes (text) | F-21, F-22, F-23 |
| 70-71 | 4.3.2 Use Case (Figure 7) | Yes (text) | F-41, F-42, F-43, F-52 |
| 71-75 | 4.3.3 Flowcharts (Figures 8, 9) | Yes (text) | F-14, F-15, F-41, P-01 |
| 75-77 | 4.3.4 ERD (Figure 10) | Yes (text) | F-40, F-50, F-51 |
| 77-87 | 4.3.5 Data Dictionary, Tables 6-15 | Yes | F-09, F-46 to F-53 |
| 87-88 | 4.4.1 Unit Testing, Table 16 | Yes | F-10, F-20, F-60, F-61, F-62, F-75, F-85 |
| 89-90 | 4.4.2 Integration Testing, Table 17 | Yes | F-11, F-17, F-18, F-75 |
| 90-93 | 4.4.3 System Testing, Table 18 | Yes | F-11, F-19, F-75, F-84 |
| 93-96 | 4.5 UAT, Table 19 | Yes | F-44, F-77, F-78, F-80 |
| 96-97 | Implementation and Deployment Plan, Support | Yes | F-30, F-31 |
| 98-103 | References | Yes | F-93 to F-97 |
| 104 | Empty | Yes | — |

### Repo areas reviewed (read-only)

| Area | Reviewed | Notes |
|---|---|---|
| `lib/models/` (all 13 models) | Field lists | For the data dictionary |
| `lib/providers/patient_provider.dart` | Snooze, box press, missed, stock | Targeted, not every line |
| `lib/providers/box_provider.dart`, `lib/services/box_watch_service.dart`, `lib/utils/box_watch.dart` | Box sync and background watch | Targeted |
| `lib/utils/dose_timing.dart` | Constants | Full constants section |
| `lib/services/firestore_service.dart` | OTP creation, `updated_at` writes | Targeted |
| `lib/services/dose_reminder_scheduler.dart` | Time zone, reminders | Targeted |
| `lib/screens/` | File list; register, OTP entry, missed dose, caregiver settings | Targeted; not every screen read |
| `firestore.rules` | Collection blocks, delete rules | Structure only |
| `healthsync-api/` (Worker) | Routes, crons, constants, alert copy, patients, account | Targeted |
| `firmware/healthsync_box/` | `config.h`, `healthsync_box.ino` button logic, `ble.cpp` security, `button.cpp`, `BLE_PROTOCOL.md`, hardware notes | `secrets.h` present, not read |
| `android/app/build.gradle.kts`, `pubspec.yaml` | SDK levels, packages, version | Full |
| Hosted APK `1.0.0+3` | aapt/apksigner check from Nov 3 | Results reused from that check |
| `test/` | Counted tests per file | Not read in detail |
| Branch comparison | `fixing-bugs-and-ble` = `dev` = `fff59b0`; `release-without-google-terms` = `36995c8` (2 commits ahead); `release` = `fdbe0f9` (Play build 1.0.0+2, no Bluetooth) | `git diff --stat`, `git log` |

**Not fully reviewed:** every individual screen's UI text; all 66 automated tests line by line; the Worker's account-deletion purge; every Firestore rule condition; the figures as images.
