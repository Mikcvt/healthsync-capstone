# UAT Part C: resources for the IT experts

For: the HealthSync team, preparing the IT-expert evaluation (Part C, 25 statements, UAT Evaluation Tool v2).
Checked on Nov 6, 2026 against `release-without-google-terms` at `36995c8` (app 1.0.0+3), which is still the latest commit on GitHub.

## Decisions already made

| Item | Decision |
|---|---|
| Repo | **Public** (Miko). Experts read code in the browser; no collaborator invites needed. |
| C19 scalability | Rated on design grounds only (no load test). |
| C14 box ↔ app | In scope: the tested APK has the Bluetooth link. A sync video is the proof. |
| Signing key (PS-21) | Exists. The APK checked on Nov 3 is signed by Miko's release key (see section 2). |
| Adviser | At least 3 IT experts; questionnaire approved. |

## 1. Status of each resource

| # | Resource | Status | Owner | Notes |
|---|---|---|---|---|
| R1 | Hosted APK link (GitHub Release) | **Not yet**: the repo has no releases or tags | Miko | Upload the final APK as a release asset; see section 2 |
| R2 | APK SHA-256 next to the link | Ready for the Nov 3 file (section 2) | Siemonne | Recompute if Miko rebuilds with his small fixes |
| R3 | Tag for the evaluated build | **Not yet** | Miko | Tag `36995c8` (or the rebuilt commit) as `v1.0.0-build3`; give experts the tag link, not a branch |
| R4 | Test accounts, one set per expert | **To create** | Miko or Siemonne | See section 3: one care partner + one patient per expert |
| R5 | Note on what the test accounts can and cannot do | Draft in section 3 | Siemonne | Send with the accounts |
| R6 | Automated test run | **64 passed, 2 failed** (Nov 6) | Miko | The 2 failures are stale UI smoke tests (section 4). Fix or remove them before experts run `flutter test` |
| R7 | README on the repo homepage | **Still the Flutter template** ("A new Flutter project") | Miko / documentation | The first thing an expert sees on a public repo; affects C8. Section 5 has a suggested outline |
| R8 | `CLAUDE.md` and architecture notes | Exist, but `CLAUDE.md` has stale lines | Miko | Section 5 lists what is out of date; give experts a note or fix it |
| R9 | Firebase security rules | In repo: `firestore.rules` | Miko | "As deployed" can only be confirmed in the Firebase console for the live project; Miko confirms it matches the file |
| R10 | Worker code (codes, alerts, deletion) | In repo: `healthsync-api/src/` | — | Paths in section 6 |
| R11 | Section 4.4 security test results | **Not yet** (paper tables still say "Pass / Fail") | Adi | Needed for C1–C5 evidence |
| R12 | Data-flow diagram | **Not yet** (DFD Level 1 planned for 4.3.3) | Mona / documentation | `docs/paper-crosscheck/04_UNFINISHED_AND_HOW_TO_WRITE.md` has the proposed Level 1 |
| R13 | User manual (MAN-01) | **Not yet** (Appendix B unwritten) | Documentation | Needed for C8 and the walkthrough |
| R14 | Box sync video | **To record** | Christian / Miko | For C14; see section 6 |
| R15 | `BLE_PROTOCOL.md`, firmware version | In repo | Christian | **Confirm which firmware is on the demo box**: release branch is 0.4.3, Christian's `feature/medbox-integration` has 0.5.0 (Oct 29) |
| R16 | Test phones: models and Android versions | To record | Adi | At least one Android 12+ and one Android 11-or-older (C17, and the Bluetooth/location permission difference) |
| R17 | QA regression results (QA-11), pilot bug log (PIL-02), known limitations (DOC-18) | Tracker items | Adi | Status not checked here |
| R18 | Walkthrough (DEF-01 script) | Tracker item | Team | Experts should see the system before rating |
| R19 | Respondent codes E01, E02, E03 and personal links | After adviser approval (ADV-11) | Siemonne | Never share the code-to-name list |

## 2. The APK

| Item | Value |
|---|---|
| File checked | `app-arm64-v8a-prod-release.apk` (24,155,539 bytes, Nov 3) |
| SHA-256 of the file | `9330845fd1b7ba3d84670998f2d0ec848f16b0a33e993c1a1e613d99dbde4c91` |
| Package / version | `com.healthsyncteam.app`, 1.0.0, versionCode 2003 (build 3, arm64) |
| Minimum Android | 7.0 (API 24) |
| Signed by | CN=Miko Cervantes, O=HealthSync Team; certificate SHA-256 `61e4f18e4b13ad2507af0055e50bea347124cdd2f4268fa968ee6e70db183fba` |
| Servers | Live Firebase project and live Worker (not dev) |

- The file checksum proves the download was not altered. It changes with every rebuild, so publish the checksum of the exact file uploaded to the release.
- The certificate fingerprint stays the same for every build signed with Miko's key. Experts can check it with `apksigner verify --print-certs`.
- The arm64 APK does not install on 32-bit-only phones. If a respondent's phone refuses it, offer the armeabi-v7a APK from the same build.

## 3. Test accounts

**The APK talks to the live Firebase project**, so the test accounts are real accounts there. That is fine for UAT, but:
- create **new accounts only for UAT**, named clearly (for example "UAT Expert E01"), never the closed-test testers' accounts;
- use made-up medicines and names, no real health data.

**Give each expert their own pair** (care partner + managed patient), not one shared set:
- A sign-in code works **once** and expires after **48 hours**, so a shared patient code would only work for the first expert.
- A care partner can delete their patients; with one shared set, one expert could delete the others' test data.
- Better still: give each expert only the care partner login and let them add their own patient and create the code. That also shows them C3 (one-time code) and C18 (setup) in practice.

**Note to send with the accounts (draft):**

> These are test accounts for the HealthSync evaluation. Use only made-up information. You may add, edit and archive medicines, log doses, and delete your own test patient. Please do not delete the care partner account itself until you have finished all statements, because deletion signs you out and closes the account for 30 days. Sign-in codes work once and expire after 48 hours; generate a new one from the care partner account if needed.

Send passwords and codes privately (direct message or a one-time secret link), never in the shared folder.

## 4. Automated tests (C10)

Run on Nov 6 on `36995c8` with `flutter test --reporter expanded` (Flutter 3.47.7): **64 passed, 2 failed.** Full output: `test-run-2026-11-06.txt` in this folder.

| Test file | Tests | Result |
|---|---|---|
| `test/dose_timing_test.dart` | 26 | Pass |
| `test/input_rules_test.dart` | 19 | Pass |
| `test/box_sync_test.dart` | 12 | Pass |
| `test/box_watch_test.dart` | 7 | Pass |
| `test/auth_flow_test.dart` | 1 | **Fail**: builds the whole app without starting Firebase (`[core/no-app] No Firebase App '[DEFAULT]' has been created`), so the welcome screen never appears |
| `test/widget_test.dart` | 1 | **Fail**: Flutter's starter "counter" test; HealthSync has no counter |

For Miko: delete `widget_test.dart`, and either set up a Firebase test double in `auth_flow_test.dart` or test `WelcomeScreen` on its own instead of the whole app. Then rerun and give experts the clean output.

## 5. Documentation the experts will read (C8)

**README.md** is the Flutter template. A public repo shows it first. Suggested outline (about one page):
1. What HealthSync is (2 sentences) and the two roles.
2. Components: Flutter app (`lib/`), Cloudflare Worker (`healthsync-api/`), Firestore rules (`firestore.rules`), box firmware (`firmware/healthsync_box/`).
3. Folder layout of `lib/` (screens, providers, services, models, utils, widgets).
4. How to run the tests (`flutter test`).
5. Where the deeper docs are (list below).
6. Download link to the APK release.

**Deeper docs already in the repo:**
- `CLAUDE.md`: data model, dose rules, offline logging, Worker endpoints. **Stale lines an expert may notice:**
  - "Deadline: November 30, 2026 (Google Play Store publication)" (now a hosted APK);
  - "Support Android API level 21 and above" (the build's minimum is API 24);
  - the project path `C:\Users\User\healthsync\`;
  - `medicine_box_status_screen.dart` "live 8-column view" (the box has 6);
  - the OTP example `"HS47XQ"` (6 characters; real codes have 8);
  - "Generates a one-time OTP code and sends it via email or SMS" (shared through the phone's share sheet);
  - "Receives FCM alerts for ... adherence reports" (no such alert);
  - the "Live app safety (closed beta on Play)" section.
- `DOSE_LOGIC_PROPOSAL.md`: dose timeline and rules.
- `BLE_CONNECT_ON_DEMAND.md`, `firmware/healthsync_box/BLE_PROTOCOL.md`, `firmware/healthsync_box/FIRMWARE_ARCHITECTURE.md`, `HARDWARE_ARCHITECTURE.md`: box and Bluetooth.
- `MEDICATION_DATA_MAP.md`: medicine data fields.

## 6. Evidence for each Part C statement

| No. | Statement (short) | Where to look | How to show it |
|---|---|---|---|
| C1 | Patient data seen only by the patient and their care partner | `firestore.rules` (users, patient_profile, dose_logs blocks) | Expert E01 tries to view E02's patient: nothing appears |
| C2 | Users cannot change data they are not allowed to | `firestore.rules` schedules block (patients may write only `led_active` and `pills_remaining`) | Patient app has no add/edit/delete medicine controls |
| C3 | Code works once and expires after 48 h | `lib/models/otp_code_model.dart:22`; `healthsync-api/src/handlers/otp.ts` | Redeem a code, then try it again on a second phone |
| C4 | Each dose record shows who recorded it and when | Dose log fields `confirmed_via` (app/button), `logged_at`, `taken_at`, `recorded_by` (`lib/models/dose_log_model.dart`) | History screens; check in the app which of these are visible to users |
| C5 | Recorded doses cannot be deleted | `firestore.rules:194` (`allow delete: if false` on dose_logs) | No delete action anywhere in history |
| C6 | Separate layers | `lib/screens`, `lib/providers`, `lib/services`, `lib/models` | Folder view on GitHub |
| C7 | Shared parts reused | `lib/widgets/shared`, `lib/services`, `lib/constants`, `lib/utils` | — |
| C8 | Comments and docs help find problems | Section 5 | README fix first |
| C9 | A new feature (e.g. a notification type) without rewriting | `healthsync-api/src/lib/dose-copy.ts` (alert kinds in one switch); `lib/models/notification_model.dart` | — |
| C10 | Key logic tested on its own | `test/dose_timing_test.dart` and the others | Clean test run (section 4) |
| C11 | Does not interfere with other apps | Test phones | Use with other apps open |
| C12 | Firebase sign-in, database, push | `lib/services/auth_service.dart`, `lib/services/firestore_service.dart`, `lib/services/notification_service.dart` | Log in, add a medicine, receive a care partner alert |
| C13 | Cloudflare Worker (accounts, codes, alerts, deletion) | `lib/services/api_service.dart` (the only caller); `healthsync-api/src/index.ts` routes; `handlers/patients.ts`, `otp.ts`, `dose-events.ts`, `sweep.ts`, `account.ts` | Add patient, redeem code, get a "Running late" alert |
| C14 | Box and app exchange schedule and time | `firmware/healthsync_box/BLE_PROTOCOL.md`; `test/box_sync_test.dart` (12 tests) | **Video**: pair, sync, a dose lights at its time, press the button, the dose shows as taken in the app |
| C15 | Notifications and alarms work with phone settings | `lib/services/dose_reminder_scheduler.dart`; manifest permissions (notifications, exact alarms, boot) | Turn notifications off: the care partner sees the reminder warning |
| C16 | Screens fit different sizes | Commit `4cc55e0` (text no longer cut off at large font size) | Two phones of different size; large system font |
| C17 | Runs on supported Android versions (7.0+) | APK minimum API 24 | Record each phone's model and version |
| C18 | Installs without technical steps | Release link + SHA-256 (section 2) | Install from the link on a clean phone |
| C19 | Can serve more users (design grounds) | One care partner, many patients; no fixed limit in the code. Per-run caps in the Worker: 200 schedules (`materialize.ts:36`), 40 dose writes and 5 alerts per run (`materialize.ts:38`, `sweep.ts:59`); Firebase free plan quotas | State these honestly: the design scales by role, the free-plan caps limit volume |
| C20 | Can replace a paper log or phone alarm | — | Walkthrough |
| C21 | No crashes in normal use | QA-11 regression results | — |
| C22 | Reminders appear when the app is closed | Exact alarms scheduled on the phone (`dose_reminder_scheduler.dart`) | Close the app; wait for a dose time |
| C23 | Records doses offline, sends later | Offline-first logging (`CLAUDE.md` section "Offline-first dose logging") | Airplane mode, tap Done, reconnect, check the care partner side |
| C24 | Nothing lost after a restart or failed sync | Firestore offline persistence | Log offline, restart the phone, reconnect |
| C25 | Failed alerts are retried | `healthsync-api/src/handlers/sweep.ts` backstop; `MISSED_RETRY_HOURS = 6` (`sweep.ts:45`) | Code review only |

## 7. Corrections to the earlier draft list

- "A test account on a **test Firebase project**": the hosted APK uses the **live** project. Use dedicated UAT accounts there (section 3), or the experts would be testing a different build.
- "**The production build has no background box sync**, so C22 must be answered for the current build": no longer true. Since `36995c8` the background box watch is in every build, including the APK. C22 is about phone reminders with the app closed, which works in any case.
- Tests: there are **six** test files, not four, and the current run has **2 failures** (section 4).
- "Read-only access to the repo **at the tagged build**": there are **no tags** yet (R3).
- "**Public or private repo**" decision: settled, public. Invites are not needed. Checked on Nov 6: no private key, keystore, `key.properties` or box passkey (`secrets.h`) has ever been committed. The two `google-services.json` files and `firebase_options*.dart` are public by design (Firebase client config); the data is protected by the security rules, and Google recommends restricting the API key to the app's package and signing certificate (tracker REL-03) before the link is widely shared.

## 8. Follow-ups, and where each item goes

The experts should need only **three links** plus their private login:
1. the **GitHub tag** (code and technical docs),
2. the **GitHub Release** (the APK and its checksum),
3. one **view-only Google Drive folder** with a "Start here" document that links to everything else.

Do **not** give the experts the paper-audit page or `docs/paper-crosscheck/`: it lists the paper's open problems and team decisions, not evidence about the system.

| # | Follow-up | Owner | Where it goes |
|---|---|---|---|
| F1 | Fix or remove the two failing tests; rerun `flutter test` and save the output | Miko | Repo (`docs/uat-it-experts/`), copy in Drive |
| F2 | Replace the template `README.md` (outline in section 5) | Miko (draft can be prepared) | Repo homepage |
| F3 | Remove the unused `alert_pref_daily` field and fix the box-press correction wording, if they go into the evaluated build | Miko | Code; then rebuild |
| F4 | Merge `healthsync-docs-help` (updated `CLAUDE.md`, this pack) into the release branch | Miko | Repo |
| F5 | Tag the evaluated commit (e.g. `v1.0.0-build3`, or build 4 if Miko rebuilds) | Miko | GitHub tag |
| F6 | Create the GitHub Release: arm64 and armeabi-v7a APKs, SHA-256 of each, short install steps | Miko | GitHub Releases (link it from the website too) |
| F7 | Restrict the Firebase API key to the package and signing certificate (REL-03) | Miko | Google Cloud console |
| F8 | Create one care partner login per expert (E01, E02, E03), made-up data | Miko or Siemonne | Live app; send logins privately |
| F9 | Write the account note (draft in section 3) | Siemonne | Drive, and with each login |
| F10 | Record the box sync video (pair, sync, dose lights, button press, dose taken in the app) | Christian, Miko | Drive (unlisted YouTube link also works) |
| F11 | Confirm the firmware on the demo box (0.4.3 or 0.5.0) and charge the box | Christian | Note in the Start-here document |
| F12 | Record test phones: model, Android version, screen size (one Android 12+ and one Android 11 or older) | Adi | Drive |
| F13 | Fill in the 4.4 security test results (C1–C5) with pass/fail and dates | Adi | Drive (PDF) |
| F14 | Export QA-11 regression results, the PIL-02 pilot bug log and DOC-18 known limitations | Adi | Drive (PDF) |
| F15 | Draw the data-flow diagram (DFD Level 1 from the paper plan) | Mona | Drive (image or PDF) |
| F16 | User manual, at least the care partner and patient quick steps (MAN-01) | Documentation | Drive (PDF) |
| F17 | Walkthrough script (DEF-01) and a time for the session | Team | Live call or in person; slides in Drive |
| F18 | Adviser: may IT experts also answer Part A? Approve respondent codes (ADV-11) | Siemonne | — |
| F19 | Personal Google Form links with E01–E03 pre-filled | Siemonne | Private message, after F18 |
| F20 | "Start here" document: the three links, what to install, how to sign in, which statements need which item (section 6), deadline | Siemonne | Top of the Drive folder |

**Drive folder layout (view-only, experts' emails added):**

```
HealthSync – IT expert evaluation/
  00 Start here (Google Doc)
  01 User manual.pdf
  02 Architecture notes.pdf        (README + CLAUDE.md export, or links)
  03 Data-flow diagram.png
  04 Security test results.pdf     (Section 4.4)
  05 Automated test run.txt
  06 QA results and known limitations.pdf
  07 Test phones.pdf
  08 Box sync video.mp4            (or a link)
```

## 9. Channels (unchanged from the draft, adjusted for the public repo)

| Resource | Channel |
|---|---|
| Manual, architecture notes, test results, rules, data-flow diagram | Shared Google Drive folder, view-only, experts' emails added |
| Source code | The public repo at the tag (no invite needed) |
| APK | GitHub Release link with the SHA-256 next to it |
| Logins and codes | Private message or a one-time secret link |
| Walkthrough | Live call or in person, DEF-01 script |
| Respondent list | Not shared |
