# HealthSync paper vs. project: cross-check report

## 1. Header

| Item | Value |
|---|---|
| Paper | `DRAFT_HEALTHSYNC_CAPSTONE DOCUMENTATION[Nov4].pdf` (DOCUMENTATION folder), 103 pages with text plus 1 empty page. Ends at the reference list. |
| Audited branch | `release-without-google-terms`, commit `36995c86cb6723b47d4f680137ecdc42c965dd66` (Nov 3, 2026, 21:22 +08:00) |
| Compared branch | `fixing-bugs-and-ble`, commit `fff59b090031eb246b36502578c65e85d2af0a0f` (same commit as `dev`). The audited branch is 2 commits ahead: version `1.0.0+3`, and the background box watch moved from dev-only to every build (14 files). |
| Play build | `release`, commit `fdbe0f9` (Oct 13), version `1.0.0+2`. **It has no Bluetooth or box features** (Bluetooth arrived Oct 27 in `88aa746`). |
| Audit date | November 4, 2026 |
| Page numbers | PDF page numbers (the printed page numbers could not be read from the text layer) |
| Guides available | Capstone Documentation Template; Discussion Guide – Whole Documentation (June 2026); Format Conversion Guide (NEWEST); Discussion: Software and Integration Testing 4.4 / UAT 4.5; Discussion: ISO/IEC 25010 Metrics for Evaluation |
| Other documents read | HealthSync UAT Evaluation Tool (Version 2); respondent request letter; Capstone 1 Revision Matrix; Capstone 1 final submission (context only); Chapter 2 LRM/CAM draft (.docx); `MISC/healthsync-current-state.md` |
| Not available | `claude/latest-updates.md` and `claude/uat-and-medbox-testing-plan.md` (not found on this computer); the figures as images (no renderer in this session, so only their captions and descriptions were checked); Play Console; the physical box |
| Secrets | `firmware/healthsync_box/secrets.h` present, not read. No keys, passwords or tokens appear in this report. |
| Changes made | Only the files in `docs/paper-crosscheck/`. Nothing else in the repo, the paper, Firebase, the Worker or Play Console was touched. |

## Report parts

| Part | Contents |
|---|---|
| [01_FINDINGS.md](01_FINDINGS.md) | Section 3: findings table F-01 to F-100, grouped A to I |
| [02_AUDITS.md](02_AUDITS.md) | Sections 4 to 12: capability gaps, scope and delimitations, numbers, internal consistency, data dictionary, test cases, UAT/4.5 change list, guide compliance, proofreading |
| [03_QUESTIONS_AND_COVERAGE.md](03_QUESTIONS_AND_COVERAGE.md) | Sections 13 to 15: questions for people, unverifiable claims, coverage log |
| [04_UNFINISHED_AND_HOW_TO_WRITE.md](04_UNFINISHED_AND_HOW_TO_WRITE.md) | Extra (asked for): every unfinished section and how to write it from what the project already has |

## 2. Executive summary

**100 findings** in the main table, plus 21 capability gaps, 21 guide-compliance items and 31 proofreading items in Part 2.

| Severity | Count |
|---|---|
| Must fix before defense | 50 |
| Should fix | 28 |
| Nice to have | 11 |
| No action (recorded matches) | 11 |

| Verdict | Count |
|---|---|
| Contradicts | 54 |
| Matches | 20 |
| Partly true | 15 |
| Unfinished | 6 |
| Cannot verify | 2 |
| Not implemented | 2 |
| Code mismatch (the paper states a team decision the app does not do yet) | 1 |

Counts updated on Nov 4 after the team's answers (see "Team answers" below).

### Team answers (Nov 4) that changed the report

- **Button: a confirmation button in the defended build.** This matches firmware 0.4.3. Part 1, section A now gives one wording to use everywhere (F-01 to F-13).
- **Limits of 3 patients and 6 medicines: dropped from the paper** (F-32, F-33). Unused fields `max_patients` and `alert_pref_daily` are removed (F-36, F-48).
- **Missed-dose reason: required.** The app does not ask for it yet, so this is now a code change for Miko (F-38).
- **Hosted APK 1.0.0+3 is the UAT and defense build** (F-26).
- **Deployment: the hosted APK is final; the Google Play closed test was only an attempt.** Facts for the attempt: Oct 14 (first install Oct 15) to the evening of Oct 29, 25 registered testers, closed test and production-access application approved, production release rejected because an organization account is needed. Objective 6, the p.16 scope bullet and Stage 4 change to the hosted APK; the attempt is mentioned only as history (F-27 to F-30).
- **Title confirmed** as on page 1; **school year 2026-2027** (F-45, F-89).
- **Hardware:** battery 2200 mAh (Table 3 says 3000); all LED resistors 220 Ω; buzzer rated 12 V DC (works 3–24 V); microSD on 5 V; no brownout on the battery, the earlier resets were low battery; Mona updates the schematic.
- **Adviser:** adult respondents first, at least 3 IT experts, questionnaire approved, ISO/IEC 25010:2023.
- **4.3.3 and 4.3.4:** Part 4 now has a proposed DFD Level 1 and 2, and how to present an ERD for Firestore (NoSQL).

### The 15 most dangerous problems for the defense

1. **The button is described four ways**: no button (p.16), silence only (pp.47, 51, 62, 66), confirms (pp.57, 60, 64, 73, 84, 88-96). The team decided it confirms doses, so pp.16, 47, 51, 62 and 66 must change. F-01 to F-05.
2. **Figure 8 and its text (pp.72-73) show the ESP32 using Wi-Fi, sending FCM and writing Firestore**, which the paper itself says the box cannot do. F-14, F-15.
3. **The limits of 3 patients per care partner and 6 medicines per patient (p.16) do not exist in the app**; the team will remove them from the paper. **A missed-dose reason is "required" but the app does not ask for one yet.** F-32, F-33, F-38.
4. **The "no voice feedback" delimitation (p.17) is false**: the box speaks. Voice is also missing from Table 3, the schematic and the definitions. F-35, F-54.
5. **The paper still presents Google Play as the release** (p.16 scope bullet, Objective 6, p.97 "will be published"). The final method is the hosted APK; the closed test was an attempt, and its build (1.0.0+2) has no Bluetooth or box features. F-27 to F-30.
6. **Minimum age is 13+ in Chapter 1, but 18+ in the website Terms and Privacy Policy and for the respondents, and 13-17 is allowed in the UAT tool; the app checks nothing.** F-34.
7. **4.5 describes the old online Google Forms + demo video + SUS plan**, not the Nov 3 observed UAT with Parts A, B and C. F-77, F-80.
8. **The Likert ranges in Table 19 differ from the NTC scale** used in the UAT tool. F-78.
9. **The use case diagram makes the patient the one who adds and edits medicines and registers with a password.** Patients do neither. F-42, F-43.
10. **The context diagram says the box sends snooze and receives "which LED to light"**: the box never snoozes, and it decides from its own schedule. F-21, F-22.
11. **The data dictionary lists fields that do not exist** (`password_hash`, `date_of_birth` in users, `max_patients`), uses wrong types (allergies boolean, conditions string), lists only 3 of 6 dose statuses, and has field names broken by a find-and-replace (`care partner_ref`). F-46 to F-53.
12. **The ERD text claims many care partners per patient**; the app allows one. F-40.
13. **Test tables have only "Pass / Fail" placeholders**, test the old Wi-Fi design, use 8 compartments and buzzer GPIO 12. F-17 to F-20, F-60, F-61, F-75.
14. **Background sync is called "development build" only (pp.57, 61)**; since Nov 3 it is in every build, including the hosted APK. F-26.
15. **Abstract, acknowledgment, approval sheet, Chapter 5, Conclusions, Appendices and CVs are missing**, and the TOC numbers 2.2.1 three times. F-86, F-87, F-91.

### Known issues from the manual check: result

| # | Known issue | Result |
|---|---|---|
| 1 | Button described three ways | **Confirmed and extended**: four ways; the code confirms doses (F-01 to F-13) |
| 2 | Figures 8 and 9 show ESP32 Wi-Fi, FCM, Firestore | **Confirmed** for Figure 8 (F-14); Figure 9 has no ESP32 steps but shows "manage patient links", which does not exist (F-41) |
| 3 | "Development build" background service | **Refined**: exists; dev-only on `fixing-bugs-and-ble`, every build on the audited branch (`36995c8`); in the hosted APK 1.0.0+3; not in the Play build (F-26, F-27) |
| 4 | Voice missing from Table 3, Figure 4, Ch 1; p.17 says no voice | **Confirmed** (F-35, F-54) |
| 5 | 4.5 still old Google Forms plan | **Confirmed** (F-77) |
| 6 | Bluetooth 4.0 vs 4.2 | **Confirmed**; 4.2 is right (F-55) |
| 7 | Abstract and acknowledgment empty | **Confirmed**; approval sheet too (F-86) |
| 8 | Closed test Oct 15-28 vs Oct 14 | **Cannot verify**: needs Play Console (F-28) |
| 9 | "smart medicine box" on p.21 | **Confirmed**, plus p.22 and p.28 (F-100) |
| 10 | TOC 2.2.1 three times | **Confirmed** (F-91) |
| 11 | 13+ vs 18+ | **Confirmed**, plus the UAT tool allows 13-17 and the app has no age check (F-34) |
| 12 | Maaño year, Ko Ko, "notificatison" | **Confirmed**, plus Leung 2024 vs 2023 and an uncited Pornillos reference (F-93 to F-96, P-01) |

## Before-you-finish checks done

- Spot-checked these findings against the code a second time: F-24, F-26, F-27, F-32, F-36, F-38, F-55, F-60, F-61, F-62, F-68 and F-71. F-49 was corrected (`paused_for_deletion` is written by the Worker, not read by the model). F-94 was trimmed to what the paper shows.
- No secret values appear in the report (BLE UUIDs are listed only in the code, not here; no passkey, keys or KV ids).
- The only files created are the five files in `docs/paper-crosscheck/`.
