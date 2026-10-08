# HealthSync — Phase 4.5: Remediation before the dose loop

**Status:** implemented Oct 6, 2026 — **awaiting device testing.** See
*Implementation record* at the end of this file for what landed and what did not.
**Branch:** working tree on `dev`, not committed.
**Owner of this file:** update the status tables as you land each task.

> **One item is NOT done and needs your Firebase credentials:** Task 0.1, the
> `applicationId`. Everything else in this file is implemented. The decisions
> D1, D2 and D3 were resolved as recommended.

---

## Why this phase exists

`flutter analyze` reports **zero issues**. Every problem below is invisible to the
compiler: a button wired to `Navigator.pop()`, a percentage typed into a widget
tree, a notification call nobody invokes. The code builds and runs, and looks
finished on a phone, which is exactly why these survived to Phase 4.

An audit on Oct 6 found four separate classes of problem:

| Class | What it is | Count |
|---|---|---|
| **A** | Screens that accept input and silently discard it | 4 screens |
| **B** | Figma traces with invented data, no provider, no stream | 9 screens |
| **C** | UI showing sensor data the hardware cannot produce | 5 places |
| **D** | Dose-loop wiring that exists but is never called | 3 paths |

Class D matters most, because **Phase 5 assumes the dose loop needs wiring when
it actually needs a missing component** — see Decision D1. Starting Phase 5
without resolving it means building reminder UI on top of a collection that
never receives a `pending` document.

### We have the time for this

`DEVELOPMENT_WORKFLOW.md` schedules Phase 4 for Oct 27–Nov 2. Phase 4's screens
landed on Oct 6 — roughly **three weeks ahead of plan**. This phase spends eight
of those days and still opens Phase 5 on **Oct 19, two weeks earlier** than the
original Nov 3 slot. Nothing downstream slips. Do not skip it to bank the lead;
the lead is what makes it affordable.

---

## Decisions to make before writing code

### D1 — Where do `pending` dose logs come from? (blocks Phase 5)

Nothing in the system creates a dose log with `status: 'pending'`. Verified:
grepping for `'pending'` across `lib/` returns only model defaults and getters.
Logs are written only at the moment a user taps, already set to `taken`.

Consequences, all of which read as separate bugs but are one cause:

- `sweep.ts:34` queries `status == 'pending' AND scheduled_at < cutoff`. It will
  match zero documents forever, so the **30-minute missed rule cannot fire**.
- `reports_screen` counts a `Pending` metric that is always 0.
- Every Class B screen is a view over dose logs that do not exist yet.

Something must turn `schedules` (recurring intent) into `dose_logs` (dated
instances). `DEVELOPMENT_WORKFLOW.md` Phase 5 does not name this job.

**Options:**

| | Where | Cost | Risk |
|---|---|---|---|
| **1** | App, on open + on schedule change, idempotent | low | a patient who never opens the app generates no logs, so nothing is ever marked missed — defeats the purpose |
| **2** | Worker cron, materialize the next 24h each night | medium | one more cron path; needs a dedup key |
| **3** | Both — Worker owns it, app backfills today on open | highest | duplicate-write risk if the dedup key is wrong |

**Recommendation: option 2.** The missed-dose rule only means something if it
fires with every phone asleep, which is the same argument that put the sweep in
the Worker. Use a deterministic document id — `{schedule_id}_{YYYY-MM-DD}_{HH:mm}`
— so re-running the job is a no-op instead of a duplicate. That id also makes
the app's "backfill today" path safe to add later if needed.

**Decide and record the answer here before Task 3.** Initial and date:

> **D1 resolved: option 2 — Worker cron materializer.** Implemented in
> `healthsync-api/src/handlers/materialize.ts`, sharing the 5-minute cron and
> the access token with the sweep. Document ids are
> `{schedule_id}_{YYYY-MM-DD}_{HH:mm}`, so a re-run is a no-op.

### D2 — Do we keep the vitals UI? (blocks Task 4)

Five places display heart rate, SpO2 or battery:

- `patient_history_screen.dart` — `On time · HR 78 bpm · Normal`
- `patient_schedule_screen.dart` — `Col 1 · HR: 78 bpm · Normal`
- `missed_alert_screen.dart` — `Last vitals: HR 82 bpm · SpO2 98%`
- `caregiver_alerts_screen.dart` — `Elevated heart rate`, `140 bpm`
- `medicine_box_status_screen.dart` — `Battery: 84%`

The GPIO map in `CLAUDE.md` has 8 LEDs, a push button, a buzzer, a DS3231 and a
microSD. **There is no heart-rate sensor, no pulse oximeter and no battery
monitoring in this build.** `DeviceModel.batteryLevel` is hardcoded to `100` in
`pairDevice()`.

A panelist who reads "SpO2 98%" will ask which sensor produced it.

**Recommendation: cut all vitals from the UI.** Adding a MAX30102 in Phase 7
means new hardware, new firmware, new schema fields and a new privacy story for
cardiac data, on a project that already has no slack week. Adherence is the
claim; vitals are scope creep that arrived through a mockup.

> **D2 resolved: cut all vitals.** Removed `HR … bpm`, `SpO2 98%`,
> `Battery 84%`, `WearOS · Connected` and the welcome screen's "Smartwatch
> vibration reminders" claim. Also removed `DeviceModel.batteryLevel`,
> `CaregiverPatientLinkModel.canViewVitals`, and the `alert_pref_vitals`
> preference — renamed to `alert_pref_low_stock`, which is what `CLAUDE.md`
> specified all along. `grep -ri "bpm\|spo2\|wearos" lib/` is now clean.

### D3 — Delete the duplicate screens, or wire them?

Two Class B screens already have correct, data-driven twins:

| Static (fake data) | Working twin | Verdict |
|---|---|---|
| `caregiver/patient_analytics_screen.dart` (372 ln, `87%` hardcoded) | `caregiver/reports_screen.dart` — live adherence from dose logs | delete the static one |
| `patient/intake_history_screen.dart` (87 ln, `Aug 7` hardcoded) | `patient/analytics_screen.dart` — reads the provider | delete the static one |

**Recommendation: delete both.** Repoint their one entry point each at the twin.
This removes ~460 lines and two future maintenance sites. Note
`patient/analytics_screen.dart` is currently imported by nobody and needs an
entry point regardless — give it the one `intake_history` vacates.

> **D3 resolved: deleted the duplicates.** `patient_analytics_screen.dart` and
> `intake_history_screen.dart` are gone, their entry points repointed at
> `reports_screen` and `analytics_screen`. Two more were deleted on the same
> reasoning: `missed_alert_screen.dart` (orphaned, all invented, and its
> "Send Reminder to Patient" button had no backend endpoint) and
> `scan_qr_screen.dart` (a stub whose only button was `onPressed: () {}`).

---

## Task 0 — Stop the bleeding (Oct 6, half a day)

Two of these are permanent if we get them wrong, so they go first.

### 0.1 — Change the Android application id

`android/app/build.gradle.kts:28` reads:

```kotlin
applicationId = "com.example.healthsync"
```

Google Play **rejects** any `com.example.*` package, and the id is **immutable
after the first upload**. Change it now, while nothing is published:

```kotlin
applicationId = "ph.edu.ntc.healthsync"   // or your chosen reverse domain
```

Then rename the Kotlin source directory to match, and re-run
`flutterfire configure --project=healthsync-b8394` so `google-services.json` and
`firebase_options.dart` carry the new id. A mismatch here breaks FCM silently.

**Done when:** a release build installs and receives a test FCM push.

### 0.2 — Bundle the fonts

`fonts/Plus_Jakarta_Sans/` holds the TTFs, but `pubspec.yaml` has no `fonts:`
section — the whole block is still commented-out boilerplate. The app uses
`google_fonts`, which fetches over the network on first launch and falls back to
Roboto offline. That breaks `CLAUDE.md` coding standard 7.

Declare the family in `pubspec.yaml`, drop the `google_fonts` dependency, and set
`fontFamily: 'PlusJakartaSans'` in the `ThemeData` in `main.dart:48`.

**Done when:** the app renders in Plus Jakarta Sans with networking disabled.

### 0.3 — Correct the screen checklist in `CLAUDE.md`

The checklist marks `device_pairing_screen.dart` and
`patient_profile_setup_screen.dart` as **DONE**. Neither saves anything. That
inaccuracy is how these shipped to Phase 4 unnoticed.

Replace the checklist with the status table at the bottom of this file, and adopt
this rule going forward:

> A screen is DONE when it reads its data from a provider or stream, its write
> path reaches Firestore, and its failure path shows a message. Rendering
> correctly is not done.

**Done when:** no screen is marked DONE that has no provider and no write path.

---

## Task 1 — Screens that discard input (Oct 7–8, 1.5 days)

The worst class: the user sees a success state and loses their data.

### 1.1 — `patient/edit_profile_screen.dart`

Two defects in one file:

1. **Save does nothing.** Line 61 is `onPressed: () => Navigator.of(context).pop()`.
2. **It leaks a teammate's data.** Fields are pre-filled through
   `initialValue: hint` with `Christian`, `San Luis`,
   `sanluis12345@gmail.com`, blood type `A-`, allergies `Dust`. Every
   patient opens their own profile and sees those values already in it.

Rebuild it against `AuthProvider.updateProfile()` (which exists and works — see
`caregiver_settings_screen.dart:65` for the correct usage) plus
`PatientProvider.saveProfile()` for the clinical fields. Prefill from the real
`UserModel` and `PatientProfileModel`; a hint is a hint, never a value.

Drop `date of birth` and `blood type` — neither field exists in the Firestore
schema, so there is nowhere to put them.

### 1.2 — `patient/patient_profile_setup_screen.dart`

The Continue button (line 110) and the secondary skip button (line 139) are
**identical** — both push `DevicePairingScreen`. The conditions, allergies and
emergency contact the patient entered are dropped.

Wire Continue to `PatientProvider.saveProfile()`, which has **zero callers**
today. Keep skip as a genuine skip.

### 1.3 — The device pairing dead end

`device_pairing_screen` → both buttons push `scan_qr_screen` →
`scan_qr_screen.dart:91` is `onPressed: () {}`. `PatientProvider.pairSmartBox()`
has **zero callers**, so no `devices` document is ever created.

For this phase, make manual serial entry work: validate the serial, call
`pairSmartBox()`, show success or failure. Leave real QR scanning for Phase 7 —
it needs a camera dependency and a permission flow — but the button must say what
it does rather than doing nothing.

**This unblocks Task 4:** `medicine_box_status_screen` cannot show a real device
until pairing creates one.

### 1.4 — `patient/settings_screen.dart`

Lines 96 and 102 are `onTap: () {}`. Either route them or remove the rows. A
tappable row that does nothing reads as a crash to a non-technical user.

**Task 1 done when:** on a real device, every form in the patient flow either
persists to Firestore and survives an app restart, or is visibly absent. No
button pops without saving.

---

## Task 2 — Dose-loop integrity (Oct 9–10, 2 days)

Three independent breaks that currently hide each other.

### 2.1 — `reportDoseEvent` has zero callers

`lib/services/api_service.dart:160` is fully implemented against the Worker's
`POST /dose-events`. Nothing in `lib/` calls it. **The caregiver never receives
the dose-taken push.**

Call it from `PatientProvider._confirmDoseTaken()`, *after* the Firestore write
and fire-and-forget, per the design note in `DEVELOPMENT_WORKFLOW.md` 2b.4: a
failed Worker call must never cost the patient their confirmation.

### 2.2 — `caregiver_notified` is hardcoded true

`patient_provider.dart:189`, `:201` and `:231` all write
`caregiverNotified: true` as a literal, when no notification was sent.

`sweep.ts:69` skips any log with `caregiver_notified === true`. So the one
mechanism designed to catch a dropped notification is told to ignore it — the
backstop is disarmed by the bug it exists to cover.

Write `false` on creation. Let the Worker set it `true` when a push actually
leaves, which `dose-events.ts:53` already does.

### 2.3 — Snooze is cosmetic

`dose_alert_screen.dart:170` shows a SnackBar reading *"Dose snoozed for 10
minutes."* and writes nothing. No `snooze_count`, no re-trigger, no state change.
`PatientProvider.snoozeDose()` and `markDoseMissed()` both have **zero callers
from any screen**, so the 3-snooze cap lives only in a method nobody invokes.

Wire both buttons to the provider. Actual re-trigger scheduling is Phase 5 work
(it needs `flutter_local_notifications`), but the **state** must be real now, or
Phase 5 builds on a lie.

### 2.4 — Two smaller correctness bugs in the same file

- **Double-tap drifts stock.** `confirmDoseTaken` decrements `pills_remaining`
  (`:181`) with no already-taken guard. Check status before writing.
- **Ad-hoc logs have no `scheduled_at`.** The log created at `:191` omits it, so
  it is invisible to the sweep and unsortable in history. Always populate it.

**Task 2 done when:** confirming a dose on device A produces a push on the
caregiver's device B, and a dose log whose `caregiver_notified` reflects whether
that push actually sent.

---

## Task 3 — The dose-log materializer (Oct 13–14, 2 days)

**Do not start until D1 is recorded above.** Assuming option 2:

1. Add a Worker job that materializes the next 24 hours of `dose_logs` from
   active `schedules`, honouring `days_of_week`, `start_date` and `end_date`.
2. Use the deterministic id `{schedule_id}_{YYYY-MM-DD}_{HH:mm}` so re-runs are
   no-ops. Set `status: 'pending'`, `scheduled_at` as a real timestamp, and
   `caregiver_notified: false`.
3. Respect the free-plan limits the existing code already respects: one
   `:runQuery`, batched `:commit`, 40 writes per run at most (`sweep.ts` is the
   model to copy).
4. Keep it in the same cron handler as the sweep rather than adding a second
   schedule — `DEVELOPMENT_WORKFLOW.md` Phase 8 makes the same point about low
   stock.

**Task 3 done when:** a schedule created through the caregiver flow produces
`pending` logs for tomorrow, the sweep flips an unconfirmed one to `missed` after
30 minutes, and the caregiver gets the alert — with no app open on any phone.

That is the capstone's graded claim, demonstrable two weeks before Phase 5 was
due to start.

---

## Task 4 — Wire or delete the Figma traces (Oct 15–16, 2 days)

Nine screens, roughly 2,000 lines, no provider and no stream. Apply D2 (strip
vitals) and D3 (delete duplicates) as you go.

| Screen | Lines | Hardcoded today | Action |
|---|---|---|---|
| `caregiver/patient_analytics_screen.dart` | 372 | `87%`, `18/21`, 7 bar values, 3 fake medicines | **delete** (D3) |
| `caregiver/patient_schedule_screen.dart` | 245 | Tue 21–Fri 23, 3 doses all "Taken" | wire to `schedules` |
| `caregiver/caregiver_alerts_screen.dart` | 233 | `3 unread`, 5 invented alerts | wire to `notifications` |
| `caregiver/patient_history_screen.dart` | 227 | two days of fake intake rows | wire to `dose_logs` |
| `caregiver/missed_alert_screen.dart` | 193 | Metformin / 8:00 PM / Column 3 | wire to the `dose_logs` row |
| `patient/missed_dose_screen.dart` | 180 | same, patient side | wire, **and give it a route** |
| `patient/notifications_screen.dart` | 121 | 2 invented alerts | wire to `notifications` |
| `patient/medicine_box_status_screen.dart` | 98 | `Online`, `84%`, `4 minutes ago` | wire to `devices` (needs 1.3) |
| `patient/intake_history_screen.dart` | 87 | `Aug 7`, `Aug 6`, `Aug 5` | **delete** (D3) |

Three notes while you work:

- `patient_schedule_screen.dart` ships a mockup annotation as UI:
  `Col 3 · LED should light at 8:00` on a dose marked **Taken**. Remove it.
- The `notifications` collection is currently written only by the Worker and read
  by nobody: `streamUserNotifications`, `createNotification` and
  `markNotificationAsRead` all have **zero callers**. Wiring the two alerts
  screens is what makes that collection real.
- `missed_dose_screen.dart` (180 lines) and `patient/analytics_screen.dart` (258
  lines, already correct) are reachable from nowhere. Both need an entry point.

**Task 4 done when:** no screen in `lib/screens/` renders a number, name, date or
status that was typed by a developer. Spot-check with a patient who has **zero**
medications — every one of these screens must show an empty state, not a blank
or a crash.

---

## Task 5 — Architecture and security cleanups (fold into Tasks 1–4)

Do these inside the tasks above rather than as a separate pass.

### 5.1 — Five screens call Firebase directly

Breaks `CLAUDE.md` coding standard 2:

`auth/otp_success_screen.dart` · `caregiver/my_patients_screen.dart` ·
`caregiver/setup_medications_screen.dart` · `patient/edit_medicine_screen.dart` ·
`patient/delete_medicine_screen.dart`

The last two do write real data, but construct `FirestoreService()` inside the
widget with **no try/catch** — a failed write leaves `_isSaving` stuck `true` and
shows the success SnackBar anyway. Route them through `PatientProvider`.

While you are in `delete_medicine_screen.dart`: it deactivates only the
**schedule**, never the `patient_medication`, so the medicine stays in the list
with its schedule gone. `deletePatientMedication()` and
`updatePatientMedication()` both have zero callers.

### 5.2 — Adopt `SnackbarHelper` (standard 4)

`lib/utils/snackbar_helper.dart` exists and is good — `showError`, `showSuccess`,
`showInfo`, `showWarning`. **14 screens build raw SnackBars; only 3 use it.**
Convert as you touch each file.

### 5.3 — Three security fixes

| Where | Problem | Fix |
|---|---|---|
| `firestore.rules:158` | `caregiver_patient_links` is readable by **any** signed-in user — anyone can enumerate every caregiver-patient relationship | scope reads to the two parties |
| `firestore.rules:84` | any solo user can write the shared `medications` catalogue; `canEditMedications()` was meant to scope a user to their own regimen | restrict writes, or make it read-only from the client |
| `dose-events.ts:53` | sets `caregiver_notified: true` on whatever `dose_log_id` it is handed, with no ownership check — any authenticated user can suppress another patient's missed-dose alert | verify the log's `patient_ref` matches the caller |

Also `dose-events.ts:47` passes `callerUid` as the patient, so a **caregiver**
confirming a dose on a patient's behalf notifies nobody. Take the patient uid
from the dose log.

### 5.4 — Dead weight to remove

- `lib/constants/app_strings.dart`, `lib/utils/date_formatter.dart`,
  `lib/utils/validators.dart` and all nine files in `lib/widgets/` are **0 bytes**.
  Either fill them or delete them — Phase 8 assumes the shared widgets exist.
- `CaregiverPatientLinkModel.inviteCode` and `PatientProvider.inviteCode` are
  leftovers from the pre-OTP flow (`DEVELOPMENT_WORKFLOW.md` Phase 9.1).
- `searchMedications()` has zero callers and the `medications` catalogue is
  unused — `medicationRef` is always written as an empty string. Decide whether
  the catalogue is part of the capstone or not.

### 5.5 — Four provider bugs worth fixing while nearby

- **Welcome screen flashes on every launch.** `auth_provider.dart:24` requires
  both a Firebase user *and* a loaded profile, so cold start renders
  `WelcomeScreen` for one frame before jumping. Offline, a signed-in user is
  **stuck** there. `AuthGate` (`main.dart:66`) needs a third loading state.
- **"Next dose" is arbitrary.** `patient_provider.dart:70` returns
  `_schedules.first` from an unsorted stream.
- **Loading spinners never show.** `_isLoading` is set true then false
  synchronously (`patient_provider.dart:80`–`:138`) before any stream emits.
- **Today's logs go stale at midnight** — `todayStr` is captured once at init
  (`:83`).

---

## Exit gate — Phase 5 may begin when all of these are true

Run through this on a **real Android device**, not the emulator, with two phones
and a patient who has zero medications as well as one who has three.

- [ ] D1, D2 and D3 are recorded in this file with a name and a date
- [ ] `applicationId` is not `com.example.*`, and FCM still arrives after the change
- [ ] The app renders in Plus Jakarta Sans with networking disabled
- [ ] No `onPressed: () {}` or `onTap: () {}` remains anywhere in `lib/screens/`
- [ ] Every patient-facing form persists and survives an app restart
- [ ] Confirming a dose on phone A pushes to the caregiver on phone B
- [ ] A `pending` dose log left alone for 30 minutes becomes `missed`, with the
      caregiver alerted, **with both apps closed**
- [ ] Snooze writes `snooze_count`; the third snooze marks the dose `missed`
- [ ] No screen renders a developer-typed number, name, date or status
- [ ] A zero-medication patient sees an empty state on every patient screen
- [ ] No vitals appear anywhere in the UI (per D2), or the sensor exists (per D2)
- [ ] `lib/screens/` contains no direct `FirebaseFirestore` / `FirebaseAuth` use
- [ ] `firestore.rules` no longer exposes `caregiver_patient_links` to all users
- [ ] `flutter analyze` is clean, and the `CLAUDE.md` checklist matches reality
- [ ] A returning user never sees the welcome screen on launch, online or off

---

## Working rules for this phase

1. **One task per commit**, named for the task number: `fix(4.5.1): ...`.
2. `flutter analyze` before every commit. It is clean today — keep it clean, and
   remember it will not catch anything in this document.
3. Verify by **restarting the app and re-reading Firestore**, never by trusting a
   success SnackBar. Several of the bugs here *are* success SnackBars.
4. Test the empty case first. Most Class B screens have never been seen with no
   data.
5. When you finish a screen, update the status table below **and** the checklist
   in `CLAUDE.md` in the same commit.
6. If a task reveals more than it promised, log it here rather than widening the
   commit.

---

## Corrected screen status

Replaces the checklist in `CLAUDE.md`, which marks screens DONE that save
nothing. `data` = reads from a provider or stream. `write` = its write path
reaches Firestore. `errors` = failure path shows a message.

| Screen | data | write | errors | Status |
|---|---|---|---|---|
| **AUTH** | | | | |
| `welcome_screen` | n/a | n/a | n/a | OK — three-way split done |
| `role_select_screen` | n/a | n/a | n/a | OK |
| `register_screen` | yes | yes | yes | OK — solid rollback path |
| `login_screen` | yes | yes | yes | OK |
| `forgot_password_screen` | yes | yes | yes | OK |
| `email_verification_screen` | yes | yes | yes | OK |
| `otp_entry_screen` | yes | yes | yes | OK — three failure modes handled |
| `otp_success_screen` | yes | yes | yes | FIX — direct Firebase call (5.1) |
| **PATIENT** | | | | |
| `patient_main_screen` | n/a | n/a | n/a | OK |
| `patient_dashboard_screen` | yes | yes | yes | OK |
| `schedule_screen` | yes | — | yes | OK |
| `add_medicine_step1/2/3` | yes | yes | yes | OK |
| `add_medicine_success_screen` | n/a | n/a | n/a | OK |
| `medicine_detail_screen` | yes | yes | yes | OK |
| `edit_medicine_screen` | yes | yes | **no** | FIX — direct Firebase, no try/catch (5.1) |
| `delete_medicine_screen` | yes | yes | **no** | FIX — orphans the medication (5.1) |
| `dose_alert_screen` | yes | partial | **no** | **BROKEN** — snooze is cosmetic (2.3) |
| `dose_confirmed_screen` | n/a | n/a | n/a | OK |
| `analytics_screen` | yes | n/a | yes | FIX — correct but unreachable (Task 4) |
| `settings_screen` | **no** | **no** | **no** | **BROKEN** — two dead rows (1.4) |
| `change_password_screen` | yes | yes | yes | OK |
| `patient_profile_screen` | yes | yes | yes | OK |
| `edit_profile_screen` | **no** | **no** | **no** | **BROKEN** — discards input, leaks a teammate's data (1.1) |
| `patient_profile_setup_screen` | **no** | **no** | **no** | **BROKEN** — saves nothing; was marked DONE (1.2). *Later deleted: unreachable after the solo role was removed.* |
| `device_pairing_screen` | **no** | **no** | **no** | **BROKEN** — dead end; was marked DONE (1.3) |
| `scan_qr_screen` | **no** | **no** | **no** | **BROKEN** — button is `() {}` (1.3) |
| `medicine_box_status_screen` | **no** | n/a | **no** | **BROKEN** — hardcoded, needs 1.3 (Task 4) |
| `intake_history_screen` | **no** | n/a | **no** | **DELETE** per D3 |
| `missed_dose_screen` | **no** | **no** | **no** | **BROKEN** — hardcoded + unreachable (Task 4) |
| `notifications_screen` | **no** | **no** | **no** | **BROKEN** — hardcoded (Task 4) |
| **CAREGIVER** | | | | |
| `caregiver_main_screen` | n/a | n/a | n/a | OK |
| `caregiver_welcome_screen` | yes | — | yes | OK |
| `caregiver_dashboard_screen` | yes | yes | yes | OK |
| `my_patients_screen` | yes | yes | yes | FIX — direct Firebase call (5.1) |
| `add_patient_screen` | yes | yes | yes | OK — calls the Worker |
| `setup_medications_screen` | yes | yes | yes | FIX — direct Firebase call (5.1) |
| `generate_otp_screen` | yes | yes | yes | OK |
| `patient_detail_screen` | yes | yes | yes | OK |
| `reports_screen` | yes | n/a | yes | OK — live adherence |
| `caregiver_profile_screen` | yes | yes | yes | OK |
| `caregiver_settings_screen` | yes | yes | yes | OK |
| `patient_schedule_screen` | **no** | n/a | **no** | **BROKEN** — hardcoded (Task 4) |
| `patient_history_screen` | **no** | n/a | **no** | **BROKEN** — hardcoded (Task 4) |
| `patient_analytics_screen` | **no** | n/a | **no** | **DELETE** per D3 |
| `caregiver_alerts_screen` | **no** | **no** | **no** | **BROKEN** — hardcoded (Task 4) |
| `missed_alert_screen` | **no** | **no** | **no** | **BROKEN** — hardcoded (Task 4) |
| **SOLO** (Phase 6) | | | | |
| `solo_dashboard_screen` | — | — | — | role removed Oct 2026; never built |
| `solo_analytics_screen` | — | — | — | role removed Oct 2026; never built |

**Totals:** 25 OK · 6 FIX · 14 BROKEN or DELETE

---

*Audit performed Oct 6, 2026. Supersedes the screen checklist in `CLAUDE.md`.*
*Phase order and all other guidance remain as set in `DEVELOPMENT_WORKFLOW.md`.*


---

# Implementation record — Oct 6, 2026

`flutter analyze`: **0 issues.** Worker `tsc --noEmit`: **clean.**
Nothing is committed; the working tree is on `dev` for review.

## Not done — needs your credentials

**Task 0.1, the `applicationId`.** Still `com.example.healthsync` in
`android/app/build.gradle.kts:28`. Changing it is not just the one line: the new
package has to be registered in the Firebase console and
`flutterfire configure --project=healthsync-b8394` re-run, or
`google-services.json` stops matching and FCM breaks silently. Applying the
Gradle change alone would have left you with a build that does not run, so it is
yours to do. **It is still a hard Play Store blocker and the id cannot be
changed after the first upload.**

## Landed beyond the original plan

Things the audit had not found, discovered while fixing the listed items:

| What | Where | Why it mattered |
|---|---|---|
| **`patient_profile` schema mismatch** | `patient_profile_model.dart`, `patients.ts` | The Worker wrote `medical_conditions` as a **string**; the Dart model read it with `List<String>.from()`, which **throws** on a string. Every managed patient created with a non-empty conditions field had an unparseable profile, taking the whole `patient_profile` stream down. Both sides now use arrays, and the reader tolerates either shape. |
| **Phantom smartwatch** | `welcome_screen.dart`, `patient_profile_screen.dart` | The welcome screen advertised "Smartwatch vibration reminders" as a feature and the profile showed `WearOS · Connected` hardcoded `true`. There is no smartwatch in this project. |
| **`medicine_detail_screen` always claimed success** | `medicine_detail_screen.dart:249` | It ignored the result of `confirmDoseTaken` and showed "marked as taken!" even when the write failed. |
| **Streams rebuilt inside `build()`** | `otp_success_screen`, `my_patients_screen`, `setup_medications_screen` | A stream created in `build` is a *new* stream each rebuild, so the `StreamBuilder` re-subscribed and re-read every document it covered — real quota against the Spark plan's 50k reads/day. Now created once. |
| **Unbounded dose-log history** | `firestore_service.dart` | `streamPatientDoseLogs` had no limit and no date bound, re-reading a patient's entire history on every write. Now bounded to 90 days and 500 docs, with the index to match. |
| **`dose_logs` identity was client-mutable** | `firestore.rules` | A patient could rewrite `scheduled_at` on their own log — the exact field the sweep queries — or reassign `patient_ref`. Those three fields are now immutable after creation. |
| **Three more `Color(0xFF…)`-only screens** | `welcome_screen.dart` | 15 hex literals and no `AppColors` import at all, against coding standard 9. `grep -rn "Color(0xFF" lib/screens/` is now empty. |
| **Exact-alarm permissions and boot receivers** | `AndroidManifest.xml` | `RECEIVE_BOOT_COMPLETED` was declared with no receiver consuming it, so a scheduled reminder would have died on reboot. Added `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM` and both `flutter_local_notifications` receivers, ahead of Phase 5. |

## Corrections to this document

Two things it got wrong, for the record:

1. **`snackbar_helper.dart` is not empty.** It is 81 lines and well built. The
   real problem was adoption: 14 screens built raw `SnackBar`s and 3 used the
   helper. All 14 are converted; `grep -rn showSnackBar lib/screens/` is empty.
2. **Task 5.1 overstated three of the five screens.** `otp_success_screen`,
   `my_patients_screen` and `setup_medications_screen` read through
   `FirestoreService`, not Firebase directly, so they already satisfied coding
   standard 2 as written. They had a different, real bug — the rebuilt streams
   above. Only `edit_medicine_screen` and `delete_medicine_screen` were genuine
   violations, and both now go through `PatientProvider` with error handling.

## New files

```
lib/utils/date_formatter.dart          was 0 bytes — schedule-time parsing,
                                       relative dates, minutesOfDay sorting
lib/utils/validators.dart              was 0 bytes — form validators
lib/constants/app_strings.dart         was 0 bytes — shared copy + every empty state
lib/services/preferences_service.dart  new — device-local reminder prefs
healthsync-api/src/handlers/materialize.ts  new — the D1 materializer
```

**Deleted:** the nine 0-byte files under `lib/widgets/` (and the directory).
An empty file implies something exists; nothing imported them, and every screen
inlines its own presentational widgets. Phase 8's shared-widget extraction
should come from the real screen code, where the repeated patterns now are: the
empty-state block and the status-badge tuple each appear in roughly six screens.

## What still needs a human

- [ ] **Task 0.1** — the `applicationId`, above. Do this first.
- [ ] Deploy the Worker (`npx wrangler deploy`) so the materializer and the
      fixed `/dose-events` are live. **Nothing in the dose loop works until
      this is deployed** — the app writes logs, but only the Worker creates
      pending ones and sends caregiver pushes.
- [ ] `firebase deploy --only firestore:rules,firestore:indexes`. The new
      indexes are required by the bounded history query; without them those
      streams fail with a console link.
- [ ] Walk the exit gate on a real device with two phones.
- [ ] Confirm the Manila timezone assumption in `materialize.ts`
      (`MANILA_UTC_OFFSET_HOURS = 8`). Workers run in UTC and schedules store
      wall-clock time, so this constant decides which calendar day a dose lands
      on. It is correct for a single-region deployment and wrong the moment a
      patient travels.
