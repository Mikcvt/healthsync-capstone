# CLAUDE.md history (moved out on Nov 7, 2026)

These sections were in `CLAUDE.md` until Nov 7, 2026. They record what was
fixed or replaced, so nobody repeats an old mistake. None of it describes
the current build; for that, read `CLAUDE.md`.

---

## Superseded box design (before the Oct 22, 2026 BLE decision)

The box used to be planned as a Wi-Fi device talking to Firebase directly.
This was replaced by Bluetooth to the patient's phone, connect-on-demand
(`BLE_CONNECT_ON_DEMAND.md`). Kept for the record:

```
ESP32 ↔ Firebase communication:
  - Schedule fetch:  HTTP GET → Firestore REST API
  - Dose log write:  HTTP POST → Firestore REST API
  - LED control:     ESP32 polls led_active field in schedules collection
  - Offline:         DS3231 RTC triggers locally, logs to microSD
  - Reconnect sync:  Push all microSD logs to Firestore, clear local queue
  - Auth:            ESP32 uses Firebase service account API key
```

Old notification flow:

```
Dose time reached
    → the APP (or the Worker) sets led_active: true in Firestore
    → ESP32 polls led_active and lights the LED on the box
    → FCM push notification sent to patient

  NOTE: the phone knows the real time and the schedule; the box is a display.
  Earlier drafts of this file said both "ESP32 sets led_active" and "ESP32
  polls led_active" — it is the second. The ESP32 never decides a dose is due.
```

Old Worker endpoints for the box (never used by the BLE build; the handler
`healthsync-api/src/handlers/device.ts` is switched off):

```
GET  /device/{serial}/schedule   ESP32 polls this instead of Firestore
POST /device/{serial}/dose       ESP32 button press
```

The tech-stack row read: "Hardware: ESP32 microcontroller via HTTP REST API".

---

## Deleted and never-built screens

```
DELETED — a static duplicate of a working screen:
  intake_history_screen.dart   → use analytics_screen.dart
  scan_qr_screen.dart          → QR scanning belongs with Phase 7 hardware
  patient_analytics_screen.dart  → use reports_screen.dart
  missed_alert_screen.dart       → use caregiver_alerts_screen.dart

DELETED — unreachable once the solo role was removed:
  patient_profile_setup_screen.dart → only a self-registering patient reached
                                      it; the caregiver now enters medical
                                      details in add_patient_screen

SOLO USER screens — removed
  The solo role was removed in October 2026 before either screen was built.
  Neither solo_dashboard_screen.dart nor solo_analytics_screen.dart ever
  existed as files. Nothing to build here.
```

`caregiver_profile_screen.dart` was listed as done in the checklist but no
such file exists; the care partner's profile and settings live in
`caregiver_settings_screen.dart`.

---

## Google Play era (Oct 13 – Oct 29, 2026)

- The Play closed test ran version 1.0.0+2, built from the `release` branch
  (no Bluetooth, no box features). First tester added Oct 14, first install
  Oct 15, ended the evening of Oct 29; 25 registered testers. The closed test
  and the production-access application were approved; the production
  release was rejected because health apps need an organisation developer
  account. The app is now distributed as a hosted APK.
- The old rule "every server change must keep working for 1.0.0+2" was
  dropped on Nov 7, 2026: Play testers were asked to uninstall the Play copy.

---

## Known issues fixed

```
✅ patient_profile_setup_screen.dart — _ToggleGroup widget was missing,
   now defined as StatefulWidget at bottom of file

✅ Flutter project created inside C:\flutter by mistake — moved to
   C:\Users\User\Desktop\Projects\healthsync (correct location)

✅ Firebase project not showing in flutterfire configure — fixed by
   logging out and back in with correct Google account, then running:
   flutterfire configure --project=healthsync-b8394
   (now healthsyncapp-b546b — see below)

── Phase 4.5 (Oct 2026) ──────────────────────────────────────────────

✅ No pending dose logs existed at all, so the Worker's 30-minute missed-dose
   sweep had nothing to find and could never fire. Added the materializer:
   healthsync-api/src/handlers/materialize.ts, on the same 5-minute cron.

✅ reportDoseEvent() had zero callers — the caregiver never got a dose-taken
   push. Now called from PatientProvider after the Firestore write.

✅ caregiver_notified was hardcoded true on every write, which told the sweep
   to skip the very doses whose notification had been dropped.

✅ Snooze showed "Dose snoozed for 10 minutes" and wrote nothing. Now writes
   snooze_count; the third snooze marks the dose missed.

✅ patient_profile.medical_conditions: the Worker wrote a string, the Dart model
   parsed it with List<String>.from() — which throws. Every managed patient's
   profile stream died. Both sides now use arrays.

✅ edit_profile_screen's Save button only called Navigator.pop(), and its fields
   were prefilled with a teammate's real name, email and blood type.

✅ Device pairing was a dead end: pairSmartBox() had no callers, so no devices
   document was ever created.

✅ AuthGate showed WelcomeScreen while the profile loaded, so the login screen
   flashed on every launch and a signed-in user was stranded there when offline.
   AuthStatus now has checking / loadingProfile / profileMissing / ready.

✅ Fonts were fetched at runtime through google_fonts despite the TTFs sitting
   in fonts/. Now bundled, per coding standard 7.

✅ Solo user role removed (Oct 2026). It was scaffolded only: an AccountType
   constant, an isSolo getter, one role card on role_select_screen, and a
   fallback in auth_service that turned any non-caregiver signup into a solo
   account. Self-registration is now caregiver-only and rejects any other role
   rather than defaulting. A users document still carrying account_type 'solo'
   resolves to 'managed' — read-only, the safe direction.
   Follow-up sweep: patient screens no longer show Add / Edit / Delete medicine
   controls (canEditMedications is always false for a patient), the orphaned
   patient_profile_setup_screen was deleted, email verification always routes
   to the caregiver welcome screen, and firestore.rules mayAuthorFor() no longer
   lets a user author medications for their own record — caregiver only.

✅ Dose logic (Oct 2026, DOSE_LOGIC_PROPOSAL.md): status timeline with Late at
   30 and Missed at 60 min, skipped and cancelled statuses, timing tags,
   early-logging prompt with a cap, Undo with a delayed caregiver push, Snooze
   only on the alarm screen, tap-to-open reminders, missed-dose reasons with
   retro logging, and no dose-log deletes anywhere ("Delete for good" removed;
   archive cancels future doses, restore revives them). The app also now
   creates a missing dose log under the Worker's own deterministic id, which
   stopped a duplicate pending copy from being swept as missed.

✅ Caregiver alerts (Oct 2026, docs/archive/CAREGIVER_ALERTS_FIX.md): a missed dose whose
   alert failed or overflowed the per-run cap was never retried; a lost Done
   report never reached the caregiver; runs could exceed 50 subrequests; the
   push channel did not exist on the caregiver phone; tokens were not
   refreshed or cleared on sign-out (shared test phones got each other's
   alerts); sweep alerts said "their medication". Needs the two new dose_logs
   indexes deployed before the Worker.

✅ Account deletion cascade (Oct 2026): deleting a caregiver only set their
   users.is_active false and deleted their own Auth login. Their patients'
   schedules stayed active, so the 5-minute cron kept materialising doses,
   marking them missed and pushing to the deleted caregiver's still-stored FCM
   token, burning Firestore quota. Now POST /account/delete deletes the
   caregiver, every managed patient, and all of their data and Auth accounts;
   the settings dialog lists the patients and asks for the password. Signing
   out (or an account vanishing) now cancels the phone's local reminders.

✅ OTP takeover closed (Oct 2026): any caregiver could write an otp_codes doc
   naming any uid and redeem it to sign in as that account. Now the rules only
   allow a code for isCaregiverOf(patient_ref), and otp.ts refuses a code unless
   the patient's profile names the code's caregiver and the account is an
   active managed patient. The patient's experience is unchanged.

✅ Removing a patient is a real delete (Oct 2026): "Remove" calls
   POST /patients/delete, behind a dialog with the consequences, the password
   and an "I understand" box. deactivatePatient() is gone.

✅ 30-day restore and patient self-delete (Oct 2026): Play requires that
   whoever asks for deletion gets it, but a care partner could decline a
   patient's request. Now a patient deletes their own account (confirm +
   "I understand", no approval) and the care partner is notified. Every
   deletion pauses the accounts for 30 days and then purges them. A care
   partner signing in to their own deleted account gets
   pending_deletion_screen.dart (Restore / Sign out); a deleted patient shows
   "Restore" on their My Patients card. Patient phones sign themselves out
   when their users doc gets deletion_scheduled_for. Restored patients need a
   new code. Website wording: WEBSITE_DELETION_UPDATE.md.

✅ Mark treatment complete (Oct 2026): patient_detail_screen archives every
   active medicine as a finished course in one step (schedules inactive, LEDs
   off, future doses cancelled, history and adherence kept) and stamps
   patient_profile.treatment_completed_at. Screens show "Treatment complete"
   only while that is set AND no medicine is active.

✅ Moved to a new Firebase project (Oct 2026): healthsyncapp-b546b, package
   com.healthsyncteam.app (com.example.* is rejected by Play). MainActivity
   moved to kotlin/com/healthsyncteam/app. The Worker's token cache is now
   keyed by service account, so swapping FIREBASE_SA_KEY takes effect at once.
```
