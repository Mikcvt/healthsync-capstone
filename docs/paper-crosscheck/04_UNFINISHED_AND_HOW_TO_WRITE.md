# Part 4: Unfinished parts, and how to write them

[Back to the index](REPORT.md)

The Nov 4 draft stops at the reference list (PDF p.103). This part lists every section that is missing or still a placeholder, in the order of the template. For each one it gives what the school guides ask for and what HealthSync material already exists. **Do not copy numbers into the paper that were not measured.** Where a result is needed, this part says where it will come from.

## Status at a glance

| Section | Status in the Nov 4 draft | Blocking? |
|---|---|---|
| Approval Sheet (ii) | Heading only | Yes, needs the adviser's form |
| Abstract (iii) | Heading only | Yes, write last |
| Acknowledgment (iv) | Heading only | No, short |
| TOC, List of Tables, List of Figures | Present but wrong numbers and pages | Update last |
| 4.2 How requirements were gathered | Missing | Short paragraph |
| 4.3 Screen / navigation map | Missing | Guide asks for "the connection based on the user interface" |
| 4.3.3 Level 1 DFD | Missing (flowcharts only) | Ask the adviser (Q-AD6) |
| 4.4 Test environment, testers, schedule, defect handling, results | Missing | Yes |
| Tables 16-18 results | "Pass / Fail" placeholders | Yes |
| 4.5 UAT | Old plan | Yes, rewrite |
| Chapter 5 Results and Discussion | Missing | Yes, after UAT (Nov 7 consolidation) |
| Conclusions and Recommendations (6.1-6.3) | Missing | Yes |
| Appendices A-D | Missing | Yes |
| Curriculum Vitae | Missing | Yes |
| Figures 8, 9 and the context, use case and ERD figures | Present but describe the old design | Yes (Part 1) |

## Approval Sheet

Page 2 of the draft is headed "APPROVAL SHEET FOR TITLE DEFENSE", copied from the template. The Whole Documentation guide describes page ii as the "Approval Sheet for **Final** Defense: the signed approval of the panel and adviser for your Final Defense. Use the form provided by your respective Capstone Teachers." So the question is only: **ask the capstone teacher for the final-defense approval form and paste it on page ii** instead of the title-defense heading. The panel and adviser sign it after the defense. Names to include: the proponents, adviser and panel. The respondent letter lists Jasper Kutz Ebedo as Capstone Project Adviser and John Paulo I. Perminola as Capstone Project Coordinator. The Capstone 1 revision matrix lists Marvic Stephen B. Tifora as adviser. Confirm which names belong on the Capstone 2 sheet.

## Abstract (one page, write it last)

The guide asks for the problem, the system built, the methods, and the main results. Suggested order (about 250 words), using only facts that will be true when you finish:

1. **Problem** (2 sentences): unintentional non-adherence; care partners do not know when a dose is missed (from 1.1).
2. **System** (3-4 sentences): HealthSync, a Flutter Android app for care partners and managed patients, Firebase (Spark) and a Cloudflare Worker, plus an optional ESP32 LED-guided medicine box connected to the patient's phone over Bluetooth Low Energy, with LEDs, buzzer, voice prompts, DS3231 RTC and microSD log.
3. **Rules** (1-2 sentences): reminders at the dose time; late at 30 minutes and missed at 60 minutes, with care partner alerts.
4. **Method** (2 sentences): Agile; unit, integration and system testing; UAT with patients, care partners and IT experts using ISO/IEC 25010:2023 and a 5-point scale.
5. **Results** (2-3 sentences): the overall weighted mean and its interpretation, per group; the test pass rate; the main measured values. **Fill in only after the Nov 7 consolidation.**
6. **Conclusion** (1 sentence).
7. Keywords: medication adherence, IoT, Bluetooth Low Energy, care partner, Flutter, Firebase, ISO/IEC 25010.

## Acknowledgment

Short thank-you to the adviser, the panel (Meneses, Apelado, Perminola were the Capstone 1 panel), the client Mr. Mark Noah V. Sunga and Mr. Dionisio M. Sunga, the respondents and IT experts, the closed-test testers, and families.

## 4.2: add how the requirements were gathered

The guide asks for this, and the paper skips it. You already have the material: the client interview (1.1), the Capstone 1 panel recommendations (revision matrix: login, dashboard, add medication, schedule calendar, adherence report, device status, settings, registration, offline with DS3231 and microSD), and the Capstone 2 requirements validation activity in `REQUIREMENTS/`. One paragraph is enough: who you interviewed, what you observed, and that the panel's recommendations were added as requirements.

Also add the functional requirements that exist in the app but not in 4.2 (Part 2, section 4: undo, early logging, missed reason and logged late, offline logging, pairing, Sync button, background watch, self-deletion, reminder health warnings, archive and treatment complete, voice prompts).

## 4.3: add a screen map

The Whole Documentation guide asks for "the connection based on the user interface". A simple figure is enough: two trees from the Welcome screen.
- **Care partner**: Register → Verify email → Home / Patients / Alerts / Reports / Profile; Patients → Add patient → Add medicines → Share code; Patient detail → Schedule, History, Smart box, Archived medicines, Delete/Restore.
- **Patient**: Enter code → Home / Schedule / Box / Alerts / Profile; Reminder → Alarm screen (Done, Skip, Snooze); Missed dose → Reason; Box → Pair, Sync.

(Tab names from CLAUDE.md "Bottom navigation"; check the final labels in the app.)

## 4.3.3: Data Flow Diagram, Level 1 and Level 2

The Conversion guide (§5) places "Data Flow Diagram (Level 1 & 2)" in 4.3.3, and the context diagram in 4.3.1 is already the Level 0. A DFD shows **data**, not decisions, so it does not care whether the database is SQL or NoSQL: each Firestore collection is simply a data store (D1, D2 ...).

**Level 1 (proposed, built from the code):**

| Process | Inputs | Outputs | Data stores |
|---|---|---|---|
| 1.0 Manage accounts | Care partner: registration, login; patient: one-time code | Account, code shown to care partner, signed-in session | D1 users, D2 patient_profile, D3 caregiver_profile, D4 caregiver_patient_links, D11 otp_codes |
| 2.0 Manage medicines and schedules | Care partner: medicine, dose times, days, compartment, stock | Saved schedule; schedule to the phone's reminders | D5 medications, D6 patient_medications, D7 schedules |
| 3.0 Remind and record doses | Patient: Done, Skip + reason, Snooze, missed reason; box: button presses (through 5.0) | Phone reminders, dose status, low-stock notice | D7 schedules, D8 dose_logs, D9 notifications |
| 4.0 Monitor and alert (Cloudflare Worker) | Dose logs and their times | Late at 30 min, missed at 60 min, alerts to the care partner (FCM) | D8 dose_logs, D9 notifications, D3 caregiver_profile |
| 5.0 Sync with the medicine box | Box events (taken, missed) and status over BLE | Clock time, schedule, "done in app" to the box; box presses to 3.0 | D7 schedules, D10 devices |
| 6.0 View reports and history | Care partner and patient requests | History, adherence summaries | D8 dose_logs |

External entities stay the same as Level 0: Patient, Care Partner, Medicine Box, and Firebase Cloud Messaging (or show FCM as the Worker's outlet).

**Level 2:** expand the process the panel cares about most. Recommended: **3.0 Remind and record doses** (3.1 schedule phone reminder, 3.2 show alarm screen, 3.3 record Done/Skip/Snooze, 3.4 undo within 5 s, 3.5 record box press, 3.6 update pill count and low-stock notice, 3.7 record missed reason or logged-late correction). A second Level 2 for **4.0 Monitor and alert** is optional (4.1 create dose records, 4.2 late check, 4.3 missed check, 4.4 send alert, 4.5 retry backstop).

**Figures 8 and 9 (flowcharts):** after the redraw (F-14), keep them only if the adviser wants them, as activity diagrams after the DFDs. The template's heading is "Data Flow Diagram (DFD) or Activity Diagram", so they fit there too.

## 4.3.4: ERD for a NoSQL database (Firestore)

The concern is fair: Firestore has no tables, joins or enforced foreign keys. An ERD is still the right figure and stays in **4.3.4**, because the guide only asks that it "match your actual database". How to make that honest:

1. **Entities = collections** (users, patient_profile, caregiver_profile, caregiver_patient_links, medications, patient_medications, schedules, dose_logs, notifications, devices, otp_codes). Attributes = the document fields from the data dictionary.
2. **Keys**: the document ID is the key (for example `dose_log_id` = `{schedule_id}_{date}_{time}`). Reference fields such as `patient_ref` or `schedule_ref` hold another document's ID; draw them as relationships and mark them "(ref)" or FK.
3. **Cardinality** from the code: one care partner to many patients; one patient to one patient_profile; one patient to many patient_medications; one patient_medication to many schedules (one per dose time); one schedule to many dose_logs; one dose_log to zero or more notifications; one patient to zero or one active device; one patient to many otp_codes.
4. **Caption and one paragraph** in the text: "Figure 10. Firestore Data Model (Entity Relationship Diagram). Cloud Firestore is a NoSQL document database. Each entity is a collection of documents. Relationships are stored as document-ID reference fields and are enforced by the application and the Firestore security rules, not by the database."
5. Drop "foreign key relationships ... guaranteeing data consistency" (p.77) unless you add that sentence: Firestore itself does not guarantee it.

The data dictionary (4.3.5) then lists the same collections in the same order.

## 4.4: what to add (Testing guide template)

1. **Purpose and approach** (2-3 sentences).
2. **Levels of testing table**: level, what was tested, tested by, schedule.
3. **Test environment table** with real items, for example: development laptop; the Android phones actually used (model and Android version, from the QA workbook); the prototype box with firmware 0.4.3; Firebase dev project and prod project; the two Worker environments; tools (Flutter test runner for the 66 automated tests, Serial monitor and bench sketches `hw_test`, `rtc_test`, `sd_test`, `dfplayer_test`).
4. **Pass/fail criteria and defect handling**: a failed case is fixed and retested; testing moves to the next level when all cases pass.
5. **Test case tables** with the guide's columns: ID (UT-01 ...), function/module, description, test data, expected, actual, status. Fill from `TESTING/HealthSync QA Testing Workbook_ Phase 4 _ Pre-Phase 5.xlsx` and the `test/` suite. **Show at least the failed-then-fixed cases**: the guide lists "Listing only test cases that pass" as a mistake.
6. **Add the missing cases** listed in Part 2, section 9.
7. **Results summary** after each table: number of cases, number passed on the first run, what was fixed.
8. **Measurable targets** for the system tests (performance, reliability, compatibility), matching the UAT measured-value table.

Automated tests you can cite for 4.4.1: `test/dose_timing_test.dart` (26 tests), `test/input_rules_test.dart` (19), `test/box_sync_test.dart` (12), `test/box_watch_test.dart` (7), `test/auth_flow_test.dart` (1), `test/widget_test.dart` (1). Run `flutter test` once on the final commit and quote the real count and result.

## 4.5: rewrite outline (from UAT tool v2 and the 4.5 guide)

1. **Purpose** (UAT plus ISO/IEC 25010:2023 evaluation).
2. **Respondents table**: group, number, percentage. Patients 15, care partners 5, IT experts (adviser), box testers (Part B, subset). Purposive sampling and why each group qualifies. Age rule (Q-AD1).
3. **Instrument**: profile and consent; Part A (19 statements, 4 characteristics), Part B (box, 9 or 8, reported separately), Part C (25, 5 characteristics); open questions; validation by the adviser and at least two experts; pilot and Cronbach's alpha if required. Full form in Appendix C.
4. **Rating scale**: NTC table (4.21-5.00 ... 1.00-1.80).
5. **Procedure**: task script, observers, in-person or screen-shared online sessions, the box station, the IT-expert walkthrough with test account, user manual, test results and code review.
6. **Statistical treatment**: weighted mean formula; characteristic and overall means; per group and overall; Part B separately; thematic analysis; measured values next to survey means.
7. **Ethics and consent**: consent page; guardian consent and assent if minors are included.
8. **UAT sign-off form** for the client.
9. Results do **not** go here (they go in 5.2).

## Chapter 5: Results and Discussion

### 5.1 System Implementation
Short intro: the final build (app 1.0.0+3, firmware 0.4.3, Worker, Firebase), how it is distributed (APK), and what the box looks like (photo of the prototype).

### 5.1.1 Main Interface / Dashboard
One clear screenshot each of the patient dashboard and the care partner dashboard, with a short explanation. The `ASSETS/play-ready/` folder has real screenshots from Oct 12; retake them from the 1.0.0+3 build, because the wording and the Box tab changed since.

### 5.1.2 Core Modules Features
One screenshot plus 2-4 sentences per module. Suggested modules (all exist in the code):
1. Care partner sign-up and adding a patient (code shown and shared)
2. Patient sign-in with the code
3. Adding a medicine (3 steps, compartment choice)
4. Dose reminder and alarm screen (Done, Skip with reason, Snooze, Undo)
5. Missed dose and "logged late" correction
6. Care partner alerts (running late, missed, skipped, taken, low stock)
7. Reports and history (adherence from dose logs)
8. Medicine box: pairing, Box tab, sync, LED and voice (photos of the box)
9. Low stock and zero stock
10. Archive, treatment complete, account deletion and restore
11. Offline logging ("Waiting to sync")

### 5.2 Evaluation Results (ISO/IEC 25010)
Tables of weighted means per characteristic with verbal interpretation, for each group and overall; Part B separately; the measured-value table (target vs actual). Discuss each table right after it. Use only collected data and keep the raw responses.

### 5.3 Discussion of Findings
Highest and lowest characteristics and why; link to the test results in 4.4, to each objective, and to Chapter 2 (for example: Leung et al. on alarm reliability vs your Reliability score; Moon and Walsh on older users vs your Interaction Capability score). Report low scores honestly and say what you would improve.

## Conclusions and Recommendations

### 6.1 Summary of Findings
Restate the problem, the system and the main results (from 5.2) in a few paragraphs.

### 6.2 Conclusions
**One conclusion per specific objective, same order** (guide). Map:

| Objective | Conclusion must state | Evidence source |
|---|---|---|
| 1 Design the app for both roles | Whether the app supported scheduling, Done/Skip/Snooze and history | System tests, Part A A1-A4 |
| 2 App works without the box | Whether phone-only mode worked | Phone-only system test (to add) |
| 3 Rule-based reminders and alerts | Whether late/missed alerts fired at 30/60 minutes | Integration test, A14, A17, on-time rate |
| 4 Integration app–cloud–box | Whether schedule sync and box events reached Firestore | Box sync tests, B4, B6, C12-C14 |
| 5 Box with alarms and BLE | Whether the LED, tone and voice guided the patient at the right time | Part B, unit tests |
| 6 Deploy the app (as reworded, F-29) | That the APK was hosted publicly and installed by respondents; optionally, one sentence on the Play attempt | Download link, installation success rate from UAT |
| 7 ISO/IEC 25010 evaluation | The overall mean and interpretation per group | 5.2 |

### 6.3 Recommendations
Should follow from the findings and the delimitations (guide). Candidates already in the paper or code: a solo user mode; iOS; pill detection in the box; battery-level reading; languages other than English (app and voice); adaptive reminders; pharmacy integration; a Google Play production release under an organization account; an organization account and Play foreground-service declaration for the background watch; daily summary alerts. Add the panel's suggestions after the defense.

## Appendices

| Appendix | What to include | Where it is |
|---|---|---|
| Divider page | "APPENDICES" | — |
| A: Relevant Source Code Snippets | Key portions only, each with 2-3 lines of explanation. Good candidates: the dose timing rules (`lib/utils/dose_timing.dart`), the late and missed sweep (`healthsync-api/src/handlers/sweep.ts`), code redemption (`healthsync-api/src/handlers/otp.ts`), a Firestore rule that blocks dose-log deletes (`firestore.rules`), the firmware button handler (`firmware/healthsync_box/healthsync_box.ino`), and the BLE schedule message (`firmware/healthsync_box/BLE_PROTOCOL.md`). **Never include `secrets.h`, `google-services.json`, keystores or service-account keys.** | Repo |
| B: User Manual | Step by step for each user type with screenshots: care partner (register, add patient, add medicine, share code, alerts, delete/restore); patient (install APK, enter code, reminders, Done/Skip/Snooze, missed reason); box (charge, pair with the label code, fill compartments, LED and voice, sync). The website's install steps can be reused. | To write |
| C: Survey Instruments | The final UAT form (Version 2 or later) exactly as used, the consent page, and the requirements-gathering questionnaire if one was used | DOCUMENTATION folder |
| D: Grammarian's Certificate / Plagiarism Report | Signed certificate and report | To obtain |
| Curriculum Vitae | One page per proponent | To write |

## Order of work suggested

1. Most blocking questions were answered on Nov 4 (button, limits, Play facts, title, school year). Still needed: Miko's app change for the required missed-dose reason (F-38), the age decision for Chapter 1 (F-34), and the adviser's OK on the Objective 6 wording.
2. Fix Chapter 1 scope and delimitations, then the definitions.
3. Redraw Figures 6, 7, 8, 9 and the ERD; fix Tables 3 and 6-15.
4. Rewrite 4.4 tables with real results and 4.5 from the UAT tool.
5. After UAT consolidation (Nov 7): Chapter 5, then Conclusions, then Abstract.
6. Appendices and CVs.
7. Last: TOC, lists, page numbers, references check, grammarian.
