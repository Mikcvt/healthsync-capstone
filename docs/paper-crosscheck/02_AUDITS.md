# Part 2: Specific audits

[Back to the index](REPORT.md)

Page numbers are PDF pages. Code is `release-without-google-terms` at `36995c8`.

## 4. Capability gaps: things the app does that the paper never mentions

| # | Capability | Where in the code | Where it belongs in the paper |
|---|---|---|---|
| G-01 | **Voice prompts on the box** (14 English clips: dose due with compartment numbers, "Dose confirmed.", pairing, power-on greeting). Tone first, then voice. Every round for 5 min, then every 3rd round, silent after 30 min. | `config.h:90-109`, `voice.cpp`, `VOICE_CLIPS.md` | Partly covered (pp.56-60) but missing from Ch 1 definitions, scope, Table 3, Figure 4, Table 1, IPO. The p.17 delimitation denies it. |
| G-02 | **Background box watch**: phone syncs every minute while a box dose is due, also in the background, with an ongoing notification; stops at the day's last box dose; swiping the app away stops it | `box_watch_service.dart`, `lib/utils/box_watch.dart`, `box_watch_test.dart` | pp.57 and 61 call it dev-only (F-26) |
| G-03 | **Undo** for 5 seconds after Done or Skip; the care partner push waits until Undo closes | `dose_timing.dart:63`, `dose_actions.dart:195` | Scope, FR, test cases |
| G-04 | **Early logging**: Done/Skip unlock 30 min before; a tap earlier asks "Logging early?" up to 3 h before, never more than half the gap to the previous dose | `dose_timing.dart:50-88` | Scope (dose timeline), FR |
| G-05 | **Missed-dose reason and "logged late" correction** by the patient until the end of the next day | `missed_dose_screen.dart` | Mentioned on p.12 only; add to FR and tests |
| G-06 | **Offline dose logging**: Done/Skip saved on the phone with no internet, synced later; "Waiting to sync" label; offline banner | CLAUDE.md "Offline-first dose logging"; `connectivity_plus` in `pubspec.yaml` | Offline delimitation (p.18) only covers reminders |
| G-07 | **Reminder health report to the care partner**: the patient's phone reports whether notifications, exact alarms and battery settings allow reminders, and when the app was last opened | `user_model.dart` (`reminders_*`, `app_last_opened_at`) | Not mentioned anywhere |
| G-08 | **Correction alerts**: a dose logged after it was marked missed (offline phone or late box press) sends "Dose update" to the care partner | `dose-copy.ts:110-121` | Not mentioned |
| G-09 | **"Dose taken" / "Dose skipped" pushes** to the care partner (also "taken early", "taken late") | `dose-copy.ts:103-140` | Paper says only late, missed, low stock |
| G-10 | **Mark treatment complete**: archives every active medicine as a finished course in one step | CLAUDE.md "Mark treatment complete"; `patient_detail_screen.dart` | Not mentioned |
| G-11 | **Archived medicines list and restore** | `archived_medicines_screen.dart` | Archiving is in scope (p.15) but restore is not |
| G-12 | **Patient self-deletion and care-partner restore** with "I understand" checkbox and password | `pending_deletion_screen.dart`, `account.ts` | Scope p.16 mentions deletion; UI safeguards not mentioned |
| G-13 | **Box pairing with a 6-digit passkey** on the box label, 5-second hold, 2-minute pairing window, LE Secure Connections | `config.h:77-81`, `ble.cpp:107-112` | Not described; only "pairing" |
| G-14 | **Box status in the app**: online/offline from last sync within 10 minutes, firmware version, "box last synced" warning | `device_model.dart:46`; `devices.firmware_version` | Use case mentions "checking device connectivity status" only |
| G-15 | **Shared pill count between box and app** (box press counts one pill off) | `recordBoxPress` (`patient_provider.dart:898`); CLAUDE.md firmware 0.4.2 | Not mentioned |
| G-16 | **Dose forms**: Tablet, Capsule, Liquid, Drops, Inhaler, Injection; only tablets and capsules go into a compartment by default | CLAUDE.md `patient_medications.dosage_form` | p.16 says "Liquid medications were not supported" in the box; does not say the app supports them without a compartment |
| G-17 | **Code sign-in rate limit** (a device that enters too many wrong codes is blocked for 10 minutes) | `healthsync-api/src/lib/http.ts`, `otp.ts` | Security NFR and tests |
| G-18 | **Firestore security rules**: dose logs can never be deleted by the app; patients may only write `led_active` and `pills_remaining` on schedules | `firestore.rules:194`, schedules block | Security NFR, Part C C5 |
| G-19 | **66 automated tests** (dose timing 26, input rules 19, box sync 12, box watch 7, auth flow 1, widget 1) | `test/` | 4.4.1 Unit Testing (supports Part C C10) |
| G-20 | **Two app variants** (HealthSync and HealthSync Dev) with separate Firebase projects and Workers | CLAUDE.md "Environments" | Test environment table in 4.4 |
| G-21 | **Medicine colour label and purpose** fields | `patient_medication_model.dart` (`color_label`, `purpose`) | Data dictionary Table 11 |

## 5. Scope and Delimitations audit (Chapter 1, pp.13-18)

### 5.1 Scope bullets

| Scope bullet (page) | Does the app/firmware behave this way? | Evidence | Action |
|---|---|---|---|
| Phone-Only Operation (p.14) | Yes | "The box is optional" (CLAUDE.md); `hasBox` derived from a devices doc | Keep |
| Mobile Application Functionality (p.14) | Yes, but incomplete | Undo, early logging, offline logging, missed reasons missing | Add a short list or refer to 4.2 |
| LED-Guided Medication Management (p.14) | Yes for LEDs | `leds.cpp`, `schedule.cpp` | Add voice and buzzer; add the button once Q-LD1 is answered |
| Low-stock alerts (p.14) | Yes | `stock_counted`; threshold default 5 | Fix the missed-reason sentence (F-38); it is also in the wrong bullet |
| Snooze rule (p.14) | Yes | `patient_provider.dart:999-1040` | Add the 4th-tap rule |
| Rule-Based Notification System (p.15) | Yes | Phone reminders + Worker sweep | Fine |
| Remote Care Partner Monitoring (p.15) | Yes | `sweep.ts`, 5-min cron | List all alert kinds (F-39) |
| Accessible Interface Design (p.15) | Cannot verify by code alone | No accessibility test exists | Back it with a UAT result (A11) later |
| Study Duration and Evaluation (p.15) | Cannot verify | — | Confirm AY (F-45); add IT experts |
| User Roles and Account Access (p.15) | Yes | `otp_code_model.dart`, `POST /patients` | Fine |
| Medication Dose Timeline (p.15) | Yes | `dose_timing.dart` | Fine |
| Medication Archiving (p.15-16) | Yes | `archived_medicines_screen.dart` | Add restore |
| Account Deletion (p.16) | Yes | `account.ts:42` | Fine |
| Google Play Release (p.16) | No longer the release method | Hosted APK is final; Play was an attempt (F-27) | Replace with a Distribution bullet (hosted APK) |

### 5.2 Delimitations

| Delimitation (page) | True? | Evidence | Action |
|---|---|---|---|
| Automated Medication Dispensing (p.16) | True | No motors | Keep |
| Dose Confirmation on the box (p.16) | **False for the code** | F-01 | Decide (Q-LD1) |
| Dosage Form (p.16) | Partly | Only tablet/capsule default into a compartment; liquids are tracked in the app | Say the app tracks other forms without a compartment |
| Patient Limit per Care Partner, 3 (p.16) | **False** | No limit (F-32) | Add the limit or remove |
| Medicine Limit per Patient, 6 (p.16) | **False** | No limit (F-33) | Rewrite or add the limit |
| Advanced Health Analytics (p.16-17) | True | Only adherence counts | Keep |
| AI-Driven Adaptive Reminders (p.17) | True | Fixed rules | Keep |
| Pharmacy and Prescription Integration (p.17) | True | Manual entry | Keep |
| Voice Interaction (p.17) | **False** | DFPlayer voice (F-35) | Rewrite |
| Medical Diagnosis (p.17) | True | — | Keep |
| User Registration (p.17) | True | Caregiver-only sign-up | Keep |
| SMS Gateway (p.17) | True | — | Keep |
| Vital-Sign Monitoring and Smartwatch (p.17) | True | — | Keep |
| Platform Compatibility (p.17) | True | Android only | Add minimum Android 7.0 (API 24) |
| Time Zone Support (p.18) | True | `Asia/Manila` | Keep |
| Battery-Level Monitoring (p.18) | True | — | Keep |
| Offline Operation Limitations (p.18) | True | — | Add offline dose logging in the app |
| Bluetooth Connection (p.18) | True, with one change | Background watch syncs every minute while a box dose is due (F-26) | Add that sentence |
| Minimum User Age, 13+ (p.18) | **Conflicts** | F-34 | Decide |
| Solo Use (p.18) | True | Solo role removed Oct 2026 (CLAUDE.md) | Keep |

### 5.3 Missing delimitations (features a panelist may ask about)

- Languages: the app and the voice prompts are **English only** (no localisation in `lib/`; `VOICE_FOLDER 1 /01/ = English`, `config.h:93`).
- **No export or printing of reports** (no PDF/CSV code in `lib/`).
- **One care partner per patient** (F-40).
- **No pill detection**: the box cannot tell whether a compartment was opened or emptied (no sensor on any pin, `config.h`).
- **The box needs the phone** to get schedule changes and to send presses; a change made by the care partner reaches the box only at the next sync.
- **Distribution**: hosted APK, not the Play Store; updates are installed by hand.
- **Patients' phones must allow notifications and exact alarms**; battery savers can delay reminders (the app reports this to the care partner, G-07).

### 5.4 Objectives against scope and tests

| Objective (p.13) | Matching scope item | Matching test / result | Gap |
|---|---|---|---|
| 1. Design app for both roles (confirm, skip, snooze, history) | Mobile App Functionality, Snooze, User Roles | ST "Medication Schedule Creation", "Care Partner Monitoring"; no Skip or Snooze test case | Add Skip and Snooze test cases |
| 2. App works without the box | Phone-Only Operation | None | Add a phone-only system test |
| 3. Rule-based reminders and late/missed alerts | Rule-Based Notification, Dose Timeline | IT "Missed dose escalation" | Add a "Running late" test |
| 4. Integrate app, cloud and box (sync, status, records) | LED-Guided, Bluetooth delimitation | IT cases still describe Wi-Fi (F-17, F-18) | Rewrite IT cases for BLE |
| 5. Box with alarms and BLE to guide to the right compartment | LED-Guided | UT LED (wrong count), ST LED activation | Fix UT; add voice and pairing tests |
| 6. Publish on Google Play | Google Play Release (to become Distribution) | None | Reword to the hosted APK (F-29); test case: install the APK from the download link on a clean phone |
| 7. Evaluate with ISO/IEC 25010 through UAT | Study Duration and Evaluation | 4.5 (old plan) | Rewrite 4.5; results go in Ch 5 |

## 6. Numbers and constants

| Number in the paper (page) | Value in the paper | Value in code/hardware files (path:line) | Verdict |
|---|---|---|---|
| Late after (pp.12, 15, 21, 47) | 30 min | 30 min (`dose_timing.dart:54`; `config.h:51`) | Matches |
| Missed after (same) | 60 min | 60 min (`dose_timing.dart:57`; `config.h:50`) | Matches |
| Worker check interval (pp.12, 15, 21, 41, 61) | every 5 min | `*/5 * * * *` (`wrangler.jsonc` triggers); a second `*/15` cron purges deleted accounts | Matches; second cron not mentioned |
| Snooze length / cap (pp.14, 66) | 10 min, max 3 | 10 min, 3 (`patient_provider.dart:33,1034`) | Matches |
| Code length / validity (pp.11, 15, 25) | 8 chars, 48 h, one use | 8 chars (`otp_entry_screen.dart:26`; `otp_code_model.dart:15-19`), 48 h (`otp_code_model.dart:22`) | Matches |
| Missed retry (p.41) | 6 h | 6 h (`sweep.ts:45`) | Matches |
| Deletion grace (p.16) | 30 days | 30 days (`account.ts:42`) | Matches |
| Correction window (p.12) | end of next day | end of next day (`missed_dose_screen.dart:15`) | Matches |
| Compartments / LEDs (pp.26, 49, 60, 62) | 6 | 6 (`config.h:10`) | Matches |
| Compartments in unit test (p.88) | 8 | 6 | **Contradicts** |
| LED pins (pp.49, 62) | 13, 14, 25, 26, 32, 33 | same (`config.h:11-16`) | Matches |
| Buzzer pin (pp.50, 62) | 17 | 17 (`config.h:19`) | Matches |
| Buzzer pin in unit test (p.88) | 12 | 17 | **Contradicts** |
| Button pin (pp.50, 62) | 16, NC, internal pull-up | 16, NC to GND, `INPUT_PULLUP`, pressed = HIGH (`config.h:37-38`; `HARDWARE_ARCHITECTURE.md`) | Matches |
| RTC I2C (pp.50, 62) | SDA 21, SCL 22 | 21, 22 (`config.h:112-113`) | Matches |
| microSD SPI (pp.50, 62) | SCK 18, MOSI 19, MISO 23, CS 15 | same (`config.h:57-60`) | Matches |
| DFPlayer pins | not given | TX 27 (1 kΩ), RX 34, BUSY 35 (`config.h:90-92`) | **Missing** |
| LED resistor (pp.49, 62) | 220-330 Ω / 220 Ω | 220 Ω, all six (Christian, Nov 4) | Partly (use 220) |
| Buzzer base resistor (pp.50, 62) | 1 kΩ | 1 kΩ (`HARDWARE_ARCHITECTURE.md` §1.7) | Matches |
| LED current (p.49) | about 2.0 V, about 6 mA | not in repo | Cannot verify |
| Battery (p.50) | 3.7 V, 3000 mAh, 4.2 V full, about 3.0 V empty | 2200 mAh (Christian, Nov 4) | **Contradicts** |
| Boost output (pp.50, 58, 62) | 5 V | 5 V to VIN (`WORK_NOTES.md`; CLAUDE.md) | Matches |
| Pairing hold (p.60) | 5 s | 5 s, only with no LED lit (`config.h:77`) | Matches (add the condition) |
| Alarm tone pattern | not given | 5 s tone, prompt, 5 s pause; tone stops after 30 min, LED stays until 60 min (`config.h:21-23`) | **Missing** |
| Box schedule capacity | not given | 24 dose times (`config.h:52`) | **Missing** (useful for the 6-medicine discussion) |
| BLE idle drop | not given | 60 s (`config.h:69`) | Missing (optional) |
| Bluetooth version (pp.49, 54) | 4.0 LE / 4.2 | 4.2 needed for LE Secure Connections (`ble.cpp:107-112`) | **Contradicts** in Table 2 |
| Minimum Android (pp.48, 52) | 7.0, API 24 | APK `sdkVersion:'24'`, target 36 (aapt check of APK 1.0.0+3) | Matches |
| RAM (p.48) | 4 GB min | none in code | Tested fact, not a requirement |
| Patients per care partner (p.16) | 3 | no limit | **Contradicts** |
| Medicines per patient (p.16) | 6 | no limit | **Contradicts** |
| Minimum age (pp.12, 18) | 13 | no check; website Terms/Privacy 18+; respondents 18+ | **Conflicts** |
| Background sync (pp.57, 61) | about every minute | 60 s tick (`box_watch_service.dart:25` `_tickMs = 60 * 1000`) | Matches (but now every build) |
| Low-stock threshold | "minimum stock" | default 5 (`schedule_model.dart:39`) | Missing number |
| Unlock before dose / early cap | not given | 30 min / 3 h (`dose_timing.dart:50,60`) | Missing |
| Undo window | not given | 5 s (`dose_timing.dart:63`) | Missing |
| Sample sizes (p.94) | 15 patients, 5-10 care partners | 15 patients, 5 care partners approved; IT experts open, at least 3 (UAT tool v2; briefing) | **Contradicts** |
| UAT statements | not given | A 19, B 9 (tool v2) or 8 (briefing), C 25 | Missing; B count to confirm |
| Likert ranges (p.96) | 4.20–5.00 ... | 4.21–5.00 ... (NTC) | **Contradicts** |
| App version | not given | 1.0.0+3 hosted APK (`pubspec.yaml:19`); Play closed test 1.0.0+2 | Missing |
| Firmware version | not given | 0.4.3 (`config.h:63`) | Missing |

## 7. Internal consistency

| Fact | Every place it appears | Which version the evidence supports |
|---|---|---|
| Button function | p.16 "no confirmation button"; p.47, 51, 62, 66 "turns off LED and buzzer"; p.57, 60, 64, 73, 84, 88, 89, 92, 93, 96 "confirms" | Code: confirms (F-01). Decision pending (Q-LD1). |
| Box ↔ cloud | p.18, 22, 23, 54, 57, 59 "no cloud link, through the phone"; p.64, 72-73, 89-90, 92 Wi-Fi / Firestore / FCM from ESP32 | No cloud link |
| Voice | p.56-60 voice prompts; p.17 "no voice feedback"; absent from Table 3, Fig. 4, definitions | Voice exists |
| Background sync | p.57, 61 "development build" | Every build since `36995c8` |
| Bluetooth version | p.49 4.0; p.54 4.2 | 4.2 |
| Minimum user age | p.12, 18: 13+; p.94: respondents 18+; UAT tool: 13-17 allowed with consent; website Terms and Privacy: 18+ | 18+ recommended (F-34) |
| Patient limit | p.16: 3; data dictionary p.80 `max_patients`; ERD p.77 "multiple patients" | No limit in code |
| Care partners per patient | p.77 "multiple care partners"; p.79 "primary care partner" | One |
| Who edits medicines | p.11, 14, 22 care partner; p.69, 71 patient | Care partner only |
| Who receives FCM | p.22, 24 care partner; p.53, 61 patients and care partners | Care partners only |
| Alert kinds | p.22, 24 late/missed/low stock; p.41 confirm/skip reported to Worker | Seven kinds (F-39) |
| Name of the box | "LED-guided medicine box" everywhere except p.21, 22 "smart medicine box", p.28 "smart box" | LED-guided medicine box |
| Layer names | p.56 Hardware/Cloud/User; p.59-61 Hardware/Network/Cloud/Client | Pick one |
| Release method | p.16 published on closed test; p.13 objective "to publish on Google Play"; p.97 "will be published" | Hosted APK is final; the Play closed test was an attempt |
| Survey method | p.65, 94-95 Google Forms online after video, SUS; UAT tool v2 observed sessions, no SUS | UAT tool v2 |
| Likert scale | p.96 own ranges; UAT tool and NTC guides 4.21-5.00 ... | NTC scale |
| Dose statuses | p.21-22 phases + Taken/Skipped/Cancelled; p.76, 84 taken/missed/snoozed | Six stored statuses (pending, snoozed, taken, skipped, missed, cancelled) |
| Missed reason required | p.12, 14 required; code optional | Optional (confirm) |
| Tense | Ch 1-3 mostly past; p.14 "The app was written ... is"; p.64 "allows", "uses"; p.97 "will" | One tense (past, as most of the paper) |
| Data logging on box | p.21 "while it was not connected to the phone"; firmware logs every taken/missed event whether or not a phone is near (`healthsync_box.ino:4`) | Every event is logged |

## 8. Data dictionary comparison (Tables 6-15 against the models and rules)

Sources: `lib/models/*.dart` (fields read), `lib/services/firestore_service.dart` (fields written), CLAUDE.md data model, `firestore.rules`.

| Collection (table) | In the paper but not in the code | In the code but not in the paper | Wrong type or meaning in the paper |
|---|---|---|---|
| users (T6) | `password_hash`, `date_of_birth`, `updated_at` | `account_type`, `can_edit_medications`, `deletion_requested_at`, `deletion_requested_by`, `deletion_scheduled_for`, `reminders_notifications_ok`, `reminders_exact_alarms_ok`, `reminders_battery_ok`, `app_last_opened_at` | `role` description fine; rows appear shifted (F-53) |
| patient_profile (T7) | `updated_at` (not read by the model) | `date_of_birth`, `gender`, `treatment_completed_at` | `medical_conditions` array (not string); `allergies` array of strings (not boolean); `caregiver_ref` spelled `care partner_ref` |
| caregiver_profile (T8) | `max_patients`, `updated_at` | `alert_pref_low_stock` | `alert_pref_daily` exists but nothing uses it |
| caregiver_patient_links (T9) | `updated_at` | `can_edit_medications` (CLAUDE.md) | `status` values are `active`, `pending`, `removed` (paper: "active or unlinked"); `caregiver_ref` spelled `care partner_ref` |
| medications (T10) | `updated_at` | — | Fine |
| patient_medications (T11) | — | `medication_name`, `dosage_form` (6 values), `purpose`, `color_label`, `start_date`, `end_date`, `archived_reason`, `created_by`, `updated_at` (written, `firestore_service.dart:271,429`) | Fine for the listed fields |
| schedules (T12) | — | `pat_med_ref`, `led_active`, `pills_remaining`, `low_stock_threshold`, `paused_for_deletion` | `mat_box_column` number 1–6 or null; `days_of_week` array; types shifted |
| dose_logs (T13) | `updated_at` (not in model) | `scheduled_at` (required by the sweep), `timing`, `logged_at`, `synced_at`, `missed_at`, `undone_at`, `stock_counted`, `snoozed_until`, `acknowledged_at`, `cancelled_reason`, `excluded_from_adherence`, `late_notified` | `status` has six values, not three; `caregiver_notified` spelled `care partner_notified`; add "never deleted" |
| notifications (T14) | `updated_at` | `patient_ref` | `notification_type` values: reminder, confirmed, late, missed, skipped, correction, low_stock, streak, account_deletion (CLAUDE.md) |
| devices (T15) | `updated_at` | `firmware_version` | `status` is derived: online if synced within 10 min (`device_model.dart:46`); `last_sync` is the last sync with the phone, not "with Firestore" |
| otp_codes | Missing table | `code`, `patient_ref`, `caregiver_ref`, `created_at`, `expires_at`, `used` | Add a table |

The guide asks for "name, data type, size, description, and keys". The tables have no Size column. For Firestore, write "variable" or the real limit (for example code = 8 characters, `mat_box_column` = 1–6), or explain once that Firestore has no fixed field sizes.

## 9. Test case comparison (Tables 16-18)

| Test case (page) | Behaviour implemented? | Automated or documented test? | Expected result matches current behaviour? | Action |
|---|---|---|---|---|
| UT Navigation (p.87) | Yes | Manual | Yes | Give screen names per role |
| UT Authentication (p.88) | Yes for care partners | `test/auth_flow_test.dart` (1) | Partly: patients use codes | Add code cases |
| UT Schedule form validation (p.88) | Yes | `test/input_rules_test.dart` (19) | Yes | Cite the automated tests |
| UT LED indicator (p.88) | Yes | Bench sketch `firmware/healthsync_box/hw_test` | No: 8 compartments; "deactivates on confirmation" depends on Q-LD1 | Fix count |
| UT Buzzer (p.88) | Yes | Bench | No: GPIO 12 | GPIO 17 |
| UT Push button (p.88) | Yes | Bench | No: interrupt | Polling + debounce |
| UT DS3231 (p.88) | Yes | `firmware/healthsync_box/rtc_test` | Wi-Fi wording wrong | Fix |
| UT microSD (p.88) | Yes | `firmware/healthsync_box/sd_test` | Yes | Fine |
| IT ESP32 to Firestore (p.89) | **No** (no direct link) | — | No | Replace with phone ↔ box BLE sync and Firestore write through the phone (`test/box_sync_test.dart`, 12) |
| IT Schedule delivery to hardware (p.89) | Yes, over BLE | `box_sync_test.dart` | "ESP32 fetch cycle" wrong | Phone pushes over BLE |
| IT Push button to app log (p.89) | Yes | Manual | Yes (decision pending) | Keep or drop after Q-LD1 |
| IT Missed dose escalation (p.89) | Yes | Manual | Yes | Add the 30-min "Running late" case |
| IT Offline to online (p.90) | Yes, but via BLE | — | No (Wi-Fi) | Rewrite |
| IT Care partner–patient linking (p.90) | Different | — | "Link" is "add patient + code" | Rewrite |
| ST User Registration (p.91) | Yes (care partners) | Manual | Yes | Say "care partner" |
| ST User Login (p.91) | Yes | Manual | Yes | Add patient code sign-in |
| ST Medication Schedule Creation (p.91) | Yes (care partner) | Manual | Yes | Say who does it |
| ST Notification and Alert Delivery (p.91-92) | Yes | Manual | Mixed phone + box | Split |
| ST Medication Adherence Logging (p.92) | Yes | Manual | Decision pending | Add an app Done case |
| ST Care Partner Monitoring (p.92) | Yes | Manual | Yes | Fine |
| ST LED Indicator Activation (p.92) | Yes | Manual | Yes | Fine |
| ST Offline Operation (p.92) | Yes | Manual | No (Wi-Fi) | Rewrite |
| ST Security (p.93) | Yes | Rules | Yes | Add patient-edits-medicine (rules refuse) and code reuse |

**Behaviours with no test case:** Skip with reason; Snooze (incl. 4th tap = missed); Undo; early logging; missed-dose reason and logged late; low stock and zero stock; Running late alert; correction alert; archive and restore; mark treatment complete; account deletion and restore; code expiry and reuse; box pairing (passkey); voice prompts; background box watch; phone-only mode; offline dose logging in the app; reminders with the app closed (Part C C22).

**Tests of removed behaviour:** IT "ESP32 to Firestore"; IT/ST "disconnect the box from Wi-Fi"; UT "eight compartments"; UT "GPIO 12".

## 10. UAT and 4.5 change list

Against UAT tool v2 (DOCUMENTATION folder), the briefing's Nov 3 plan, and the school's 4.4/4.5 guide.

| # | Paper now (pp.93-96) | Change to |
|---|---|---|
| U-01 | Online Google Forms after a demo video | Observed sessions with a task script: in person, or online with screen sharing; "on my own" option exists in the tool, decide whether it counts |
| U-02 | Four sections incl. SUS | Profile + consent, Part A (19), Part B (9 or 8, box testers only, reported separately), Part C (25, IT experts), three open questions; no SUS (remove "SUS" everywhere, p.95-96) |
| U-03 | "ISO 25010 ... usability and functional suitability" | ISO/IEC 25010:2023; Part A: Functional Suitability, Interaction Capability, Performance Efficiency, Safety; Part B: Interaction Capability, Functional Suitability, Compatibility, Reliability; Part C: Security, Maintainability, Compatibility, Flexibility, Reliability. Cite: International Organization for Standardization. (2023). ISO/IEC 25010:2023. |
| U-04 | 15 patients, 5-10 care partners | 15 patients and 5 care partners (approved), IT experts (adviser wants at least 3), box testers (minimum open); add a respondents table (guide) |
| U-05 | Respondents 18+ | Decide with the adviser: the tool allows 13-17 with guardian consent; minors need ethics approval, consent and assent (APPROVE) |
| U-06 | Patients register, verify email, set schedules | Patient tasks: install APK, enter code, get reminder, Done/Skip (reason)/Snooze, view history; care partner tasks: register, add patient, add medicine, share code, see alerts, delete/restore; box tasks: pair, see LED and hear voice, (button per Q-LD1), sync |
| U-07 | "linked to the patient's account" | "added the patient and shared the code" |
| U-08 | Statistical treatment: weighted mean, SUS scoring, thematic analysis | Weighted mean WM = Σ(f·w)/N per statement, N = respondents who answered it; characteristic mean = average of statement means; overall mean; per group (patients, care partners, IT experts) and overall; Part B separately; thematic analysis for open answers; measured values next to survey scores |
| U-09 | Table 19 ranges | NTC scale (F-78) |
| U-10 | No instrument validation | Adviser + at least two experts review; pilot; Cronbach's alpha about 0.70 (ISO guide §5) |
| U-11 | No measured values | Add the measured-value table (task completion ≥ 90%, on-time reminders ≥ 95%, install success ≥ 95%, phones passed 100%, critical actions confirmed 100%, security tests 100%, BLE sync 4 of 5) once the adviser finalises the targets |
| U-12 | No observers | Add the observer role and checklist (adviser wants observers) |
| U-13 | No evidence review for Part C | Add the IT-expert walkthrough with test account, user manual, test results and code review (adviser) |
| U-14 | No UAT sign-off | Add the sign-off form (guide), signed by the client (Mr. Mark Noah V. Sunga) |
| U-15 | Statements that depend on undecided behaviour | B9 "whether a dose was confirmed" (depends on Q-LD1); C14 "schedule updates and the clock time" applies only if the tested build has the box link (the hosted APK does; the Play build does not) |
| U-16 | Features with no statement | Voice prompts are in B9 only; offline logging (C23 covers it); Undo (A10 covers it); account deletion (A18 partly); **reminder health warnings to the care partner and box pairing have no statement** |
| U-17 | Results in 4.5 | Results go to 5.2 and discussion to 5.3 (guide) |
| U-18 | Implementation and Deployment Plan (pp.96-97) in 4.5 | Rewrite to the APK reality (F-30, F-31); consider moving it out of 4.5, since the template's 4.5 is UAT and Evaluation |

### Part A statements against the app (audited branch)

| Statement | Can the app do it? | Note |
|---|---|---|
| A1 functions | Yes | — |
| A2 reminder shows correct medicine and time | Yes | Local notifications |
| A3 Done/Skip records correct status | Yes | — |
| A4 history taken/skipped/missed with date/time/status | Yes | `analytics_screen.dart`, `patient_history_screen.dart` |
| A5 easier to take on time | Opinion | — |
| A6-A9 | Opinion | — |
| A10 undo / fix mistakes | Yes | Undo 5 s; care partner can edit dose times |
| A11 large clear text | Opinion | — |
| A12-A13 speed | Opinion; measure too | — |
| A14 reminders on time | Yes | Measure on-time rate |
| A15 smooth | Opinion | — |
| A16 warns when running low | Yes | Patient in-app notice |
| A17 care partner alert late/missed | Yes | Worker sweep |
| A18 confirm before delete | Yes | CLAUDE.md "Every delete ... explicit confirm" |
| A19 can record at zero stock | Yes | `stock_counted` |

### Part B statements against the box (audited branch)

| Statement | Can the box do it? | Note |
|---|---|---|
| B1 lit LED shows compartment | Yes | — |
| B2 buzzer loud enough | Opinion | — |
| B3 LED and buzzer at dose time | Yes | RTC schedule |
| B4 app connected without repeated attempts | Yes | Measure BLE sync success |
| B5 putting medicine in is easy | Opinion | — |
| B6 box compartment/time match app | Yes | Same schedule |
| B7 no freeze/reset/missed alert | Yes | Note brownout on laptop USB (CLAUDE.md "Box sounds") – test on battery |
| B8 size and shape | Opinion | — |
| B9 voice says compartment and "confirmed" | Yes in code | Depends on Q-LD1 |

## 11. Guide compliance deviations

Guides available: Capstone Documentation Template; Whole Documentation guide (June 2026); Conversion Guide (newest); 4.4/4.5 Testing and UAT guide; ISO/IEC 25010 Metrics guide. The Revision Matrix and the Capstone 1 final submission were used only for context; per the briefing, the removed Chapter 1-3 lab sheets were not used (none are in the folder).

| # | Deviation | Guide and section |
|---|---|---|
| D-01 | Abstract, acknowledgment and approval sheet empty | Whole Documentation guide, Preliminary Pages |
| D-02 | Approval sheet titled "for Title Defense" | Whole Documentation guide: "Approval Sheet for Final Defense (ii)" (the template itself says Title Defense: ask the adviser) |
| D-03 | Chapter 5, Conclusions and Recommendations, Appendices A-D, CVs missing | Template TOC; Whole Documentation guide, Final Checklist |
| D-04 | TOC numbering and page numbers wrong (F-91); Lists of Tables/Figures without numbers and with wrong pages (F-92) | Whole Documentation guide: "Headings and page numbers must match ... Update these pages last" |
| D-05 | Page numbering cannot be checked in the text layer (no printed numbers found); preliminary pages should be i-vii, chapters from 1 | Whole Documentation guide, "How the Documentation Is Organized" |
| D-06 | Definition of Terms not alphabetical: "LED-guided Medicine Box" sits after "Rule-Based System" (p.26); common terms ("Cloud Computing", "Mobile Application") included; terms used but not defined (DFPlayer Mini, voice prompt, push button, snooze, skipped, logged late, low stock, Workers KV, Spark plan, APK, ISO/IEC 25010, UAT, pairing passkey, foreground service, archiving) | Whole Documentation guide 1.6 "Define technical and key terms ... Do not add common terms"; Conversion guide "Keep alphabetical ordering" |
| D-07 | Specific objectives should follow "design, develop, evaluate" and map one-to-one to conclusions; Objective 6 (Play) will not have a matching achieved result as written | Conversion guide 1.3; Whole Documentation guide Tip |
| D-08 | 4.2 does not say how requirements were gathered (interviews, observation) | Whole Documentation guide 4.2 |
| D-09 | 4.3 lacks "the connection based on the user interface" (a screen map / navigation diagram) | Whole Documentation guide 4.3 |
| D-10 | 4.3.3 uses system flowcharts; the guide accepts DFD or Activity Diagram, the Conversion guide lists DFD Level 1 and 2. Context diagram is called "Level 0 DFD" but there is no Level 1 DFD | Conversion guide §5; Whole Documentation guide 4.3.3 |
| D-11 | Data dictionary has no Size column | Whole Documentation guide 4.3.5 "name, data type, size, description, and keys" |
| D-12 | ERD must match the actual database (F-40, F-46 to F-51) | Template Ch 4 "Your ERD must match your actual database tables" |
| D-13 | 4.4 missing test environment, testers and schedule, defect handling, ID/test data/actual result columns, results summary, failed cases | Testing guide 4.4 template |
| D-14 | No measurable performance targets | Testing guide 4.4.3; ISO guide §10 |
| D-15 | 4.5 missing respondents table, instrument validation, procedure, UAT sign-off; scale differs from NTC | Testing guide 4.5; ISO guide §5-6 |
| D-16 | ISO/IEC 25010 edition not stated; 2011 term "usability" used (p.95) while the tool uses 2023 "Interaction Capability" | ISO guide §1 and §10 "Mixing the 2011 and 2023 characteristic names" |
| D-17 | Reference list: uncited source (Pornillos), year mismatches (Maaño, Leung), name mismatch (Ko) | Whole Documentation guide, References |
| D-18 | Font (Times New Roman 12) and red template notes cannot be checked from text; no red "Font:" notes appear in the text layer | Whole Documentation guide, General format rules |
| D-19 | Every page has the college header | Matches |
| D-20 | Synthesis follows the 3-part structure (themes, gap, positioning) | Matches (Conversion guide blueprint) |
| D-21 | 3.3 specification tables have Minimum and Recommended columns | Matches (Whole Documentation guide 3.3 Tip) |

## 12. Proofreading list

| # | Page | Text | Fix |
|---|---|---|---|
| P-01 | 74 | "notificatison" | notification |
| P-02 | 49 | "Function in the Syste," | System |
| P-03 | 49-51 | Table 3 header row split ("Componen t") and the component cells wrap mid-word | Widen the first column |
| P-04 | 48 | "Componen t", "Developme nt device" | Widen column |
| P-05 | 60 | "Compartment one. (no closing quotation mark) | add ” |
| P-06 | 60 | "the box used beeps only" (no full stop) | add . |
| P-07 | 25 | "once internet connectivity was restored" (no full stop) | add . |
| P-08 | 29 | "connected to Firebase cloud services" (no full stop) | add . |
| P-09 | 14 | "required ... for a missed dose" (no full stop) | add . |
| P-10 | 59 | "commanded the DFPlayer Mini through a UART connection read input from the push button" | add a comma or "and" |
| P-11 | 23 | "Cloudflare Worker, to help" | remove comma |
| P-12 | 71, 79-80, 84 | "care partner_profile", "care partner_ref", "care partner_notified" | real identifiers (F-52) |
| P-13 | 41 | "one-time code for sign-in" in a list of tasks | "redeeming the one-time sign-in code" |
| P-14 | 42 | "The application also records adherence events, such as recorded dose actions, such as taken, skipped" | one "such as"; past tense |
| P-15 | 64-65 | "The HealthSync application allows ... The system uses ... ensuring users can still view" | past tense |
| P-16 | 14 | "The app was written in Flutter/Dart and available" | "was available" |
| P-17 | 65 | "Care Partners" / "Care partners" / "care partner" mixed | Title Case only in headings and labels, "care partner" in sentences (project wording rule) |
| P-18 | 66-67 | "Care Partners could ..." in sentences | care partners |
| P-19 | 26 | "LED-guided Medicine Box" vs "LED-Guided Medicine Box" vs "LED-guided medicine box" | one capitalisation |
| P-20 | 37 | "Ko Ko et al." | see F-95 |
| P-21 | 20 | "School of Arts, Science and Technology" (p.1, p.20) vs header "Sciences" | Template title page uses "Science" in the body text; keep as template, but be consistent in 1.5 |
| P-22 | 65 | "one-time-code" | one-time code |
| P-23 | 73 | "LED column" | compartment |
| P-24 | 71 | "Assigning a medicine box column" | compartment |
| P-25 | 76 | "LED column assigned for each dose" | compartment, assigned per medicine (all dose times share one compartment) |
| P-26 | 96 | "Implementation and Deployment Plan" uses "will" | past tense after deployment |
| P-27 | 22 | "Firebase Firestore" (p.22, 24, 46) vs "Cloud Firestore" (p.41) | "Cloud Firestore" |
| P-28 | 61 | "Firestore DB", "Firebase Auth" | full names, as elsewhere |
| P-29 | 22, 52 | "user authentication" lowercase in a list of product names | Firebase Authentication |
| P-30 | 47 | "the phone of the managed patient" | the managed patient's phone |
| P-31 | 7 | "System Flowchart (Care Partner Monitoring and Alert Management" (missing closing parenthesis) | add ) |
