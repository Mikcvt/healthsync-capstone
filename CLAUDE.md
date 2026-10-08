# HealthSync — Claude Code Context File
# Auto-read by Claude Code every session. Do not delete.
# Last updated: October 2026

---

## Project overview

**HealthSync: An IoT-Based LED-Guided Smart Medicine Box with Mobile Integration for Medication Adherence**

- Institution: National Teachers College, Quiapo, Manila
- Course: BSIT Capstone Project 2025–2026
- Deadline: November 30, 2026 (Google Play Store publication)
- Team: Martin Merry Siemonne O. · Cervantes Miko D. · Fernandez Adia Charlotte · General Feonna Anne D. · San Luis Christian D.

---

## What this system does

HealthSync helps patients take their medications on time using two components:

1. **Smart medicine box (hardware)** — ESP32 microcontroller with 8 LED indicators. Each LED corresponds to one medicine compartment (column 1–8). At the scheduled dose time, the correct LED lights up to guide the patient. A push button on the box lets the patient confirm intake. DS3231 RTC handles offline scheduling. MicroSD card logs doses locally when offline and syncs to Firebase on reconnect.

2. **Flutter mobile app (software)** — Android app for patients and caregivers. Handles medication scheduling, dose reminders via FCM push notifications, adherence tracking, caregiver monitoring, and real-time sync with the medicine box via Firebase.

---

## Tech stack

| Layer | Technology |
|-------|-----------|
| Mobile app | Flutter / Dart (Android only) |
| Backend | Firebase **Spark (free) plan** — Firestore, Auth, FCM |
| Server-side jobs | **Cloudflare Worker** (free plan) — OTP redemption, custom tokens, FCM fan-out, missed-dose cron. Cloud Functions are NOT used: they cannot deploy on Spark. |
| Hardware | ESP32 microcontroller via HTTP REST API |
| State management | Provider |
| Font | Plus Jakarta Sans — **bundled** in `fonts/`, declared in `pubspec.yaml` (not `google_fonts`) |
| Design source | Figma |
| Version control | Git / GitHub — branch: `dev` |

---

## Project path

```
C:\Users\User\healthsync\
├── lib\
│   ├── constants\        app_colors.dart, app_strings.dart, app_styles.dart
│   ├── models\           10 model files
│   ├── services\         auth_service, firestore_service, notification_service, device_service
│   ├── providers\        auth_provider, patient_provider, caregiver_provider, schedule_provider
│   ├── utils\            date_formatter, validators, snackbar_helper
│   ├── screens\
│   │   ├── auth\         welcome, login, register, forgot_password, email_verification,
│   │   │                 role_select, otp_entry, otp_success
│   │   ├── patient\      24 screens
│   │   └── caregiver\    14 screens
│   ├── widgets\
│   │   ├── shared\       8 widgets
│   │   ├── patient\      bottom_nav_patient
│   │   └── caregiver\    bottom_nav_caregiver
│   ├── firebase_options.dart
│   └── main.dart
├── android\app\google-services.json
├── fonts\                Plus Jakarta Sans TTF files
└── CLAUDE.md             ← this file
```

---

## Two user types

### 1. Caregiver / Care partner
- Registers and logs in with email and password
- Creates patient accounts from their dashboard
- Inputs all medication names, dosages, times, and assigns box columns
- Generates a one-time OTP code and sends it via email or SMS to the patient
- **Only caregiver can add, edit, or delete medications**
- Receives FCM alerts for missed doses, low stock, and adherence reports
- Can monitor multiple patients

### 2. Managed patient (linked via OTP)
- Receives OTP code from caregiver via email or SMS
- Installs app → sees blank code entry screen on first launch
- Enters the OTP code → account opens automatically
- **No signup, no login, no form to fill** — account and schedule pre-loaded
- Can only confirm doses and view their own history
- Cannot edit medications — read-only access

> **A third "solo user" role was removed in October 2026.** It was scaffolded
> but never documented in the capstone paper and never fully built. Caregiver is
> now the only self-registering account; a patient always arrives with a code.
> Do not reintroduce it.

---

## OTP code rules

```
- One-time use only
- Mark used: true in Firestore immediately after first login
- Expires 48 hours after generation
- Patient auth via OTP token — no password required
- account_type field: "managed" (patient) or "caregiver"
- can_edit_medications: true for caregiver only, false for managed patient
```

**Firestore OTP collection — `otp_codes`:**
```
code            string   (e.g. "HS47XQ")
patient_ref     string   (Firestore user document reference)
caregiver_ref   string
created_at      timestamp
expires_at      timestamp  (created_at + 48 hours)
used            bool       (set to true on first use)
```

---

## Design system

### Colors

```dart
// Patient
patientBlue:    Color(0xFF1B5FD4)
blueLight:      Color(0xFFEBF1FF)
blueDark:       Color(0xFF0F3E9E)

// Caregiver
caregiverGreen: Color(0xFF0D9B6B)
greenLight:     Color(0xFFE4F7F0)
greenDark:      Color(0xFF066845)

// Streak accent (streak notifications only, not a role colour)
streakPurple:   Color(0xFF7C3AED)

// Gradient (headers and primary buttons)
gradient: LinearGradient(
  colors: [Color(0xFF1B5FD4), Color(0xFF0D9B6B)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)

// Status
takenGreen:     Color(0xFF3B6D11)   bg: Color(0xFFEAF3DE)
pendingAmber:   Color(0xFF854F0B)   bg: Color(0xFFFAEEDA)
missedRed:      Color(0xFF791F1F)   bg: Color(0xFFFCEBEB)
upcomingBlue:   Color(0xFF0F3E9E)   bg: Color(0xFFEBF1FF)

// Neutral
background:     Color(0xFFF5F7FB)
cardWhite:      Color(0xFFFFFFFF)
borderGray:     Color(0xFFE2E8F0)
textPrimary:    Color(0xFF0F172A)
textSecondary:  Color(0xFF64748B)
textMuted:      Color(0xFF94A3B8)

// LED column status
ledActive:      Color(0xFFF59E0B)   bg: Color(0xFFFEF3C7)
ledDone:        Color(0xFF0D9B6B)
ledOff:         Color(0xFFE2E8F0)
```

### Typography
- Font family: Plus Jakarta Sans (all weights 400–800)
- Files in: `fonts/` folder, declared in `pubspec.yaml`

### Cards
- Background: #FFFFFF
- Border: 1px solid #E2E8F0
- Border radius: 16px
- Shadow: 0 2px 8px rgba(15,23,42,0.05)

### Bottom navigation
- Patient: 5 tabs — Home, Schedule, Box, Alerts, Profile
- Caregiver: 5 tabs — Home, Patients, Alerts, Reports, Profile
- Active color: patient=blue, caregiver=green

---

## Firestore data model (10 collections)

### users
```
uid             string (Firebase Auth UID)
role            string ("patient" | "caregiver")
account_type    string ("managed" | "caregiver")
first_name      string
last_name       string
email           string
phone           string
can_edit_medications  bool
created_at      timestamp
is_active       bool
```

### patient_profile
```
profile_id         string
user_ref           string (→ users)
caregiver_ref      string (→ users)
medical_conditions array  of string  ← NOT a string. The Dart model parses with
allergies          array  of string     a list reader; the Worker writes arrays
                                        to match. A plain string here threw a
                                        TypeError and took down the whole
                                        patient_profile stream.
emergency_contact  string
emergency_phone    string
created_at         timestamp
```

### caregiver_profile
```
profile_id         string
user_ref           string (→ users)
alert_pref_missed  bool
alert_pref_low_stock bool   (NOT alert_pref_vitals — see below)
alert_pref_daily   bool
created_at         timestamp
```

### medications
```
medication_id   string
medication_name string
generic_name    string
dosage_form     string ("tablet" | "capsule" | "liquid")
common_dosages  string
category        string
created_at      timestamp
```

### patient_medications
```
pat_med_id          string
patient_ref         string (→ users)
medication_ref      string (→ medications)
prescribed_dosage   string
quantity_per_dose   number
dosage_form         string ("Tablet" | "Capsule" | "Liquid" | "Drops" |
                            "Inhaler" | "Injection"). Only Tablet and Capsule
                            default into a box compartment.
instructions        string
prescribing_doctor  string
date_prescribed     date
start_date          date
end_date            date
is_active           bool
created_by          string (caregiver uid)
updated_at          timestamp
```

### schedules
```
schedule_id     string
pat_med_ref     string (→ patient_medications)
patient_ref     string (→ users)
scheduled_time  string ("08:00 PM")
days_of_week    array  (["Mon","Tue","Wed","Thu","Fri","Sat","Sun"])
mat_box_column  number (1–8) or null
                null = not in the box: no box paired yet, or a liquid,
                inhaler or ninth medicine. Every dose time of one medicine
                shares one compartment. Never display null as a compartment.
start_date      date
end_date        date
is_active       bool
led_active      bool   (ESP32 polls this to activate/deactivate LED)
created_at      timestamp
```

### dose_logs
```
dose_log_id         string   (deterministic: {schedule_id}_{YYYY-MM-DD}_{HH:mm})
schedule_ref        string   (→ schedules)
patient_ref         string   (→ users)
scheduled_date      date     ("YYYY-MM-DD", for same-day lookups)
scheduled_time      string   ("08:00 PM", display form)
scheduled_at        timestamp  ← date + time as one instant.
                               REQUIRED: the Worker's sweep queries
                               `scheduled_at < cutoff`, and a range query
                               cannot be built from two strings. Sorting history
                               by the "08:00 AM" string also puts 10 AM first.
status              string ("pending" | "snoozed" | "taken" | "skipped" |
                            "missed" | "cancelled")
                    taken/skipped/missed/cancelled are final. skipped = the
                    patient chose not to take it (with a reason); cancelled =
                    medicine archived or dose time moved before it came due —
                    kept, never shown, never counted.
timing              string ("early" | "on_time" | "late" | "logged_late"),
                    set when taken. logged_late = was missed, then corrected
                    with "I took it but forgot to log it".
taken_at            timestamp  (for logged_late: when the patient says)
logged_at           timestamp  (when the patient last acted; the rules allow
                               Undo for 2 minutes after it)
snooze_count        number
snoozed_until       timestamp  (when the current snooze ends; another snooze
                               is refused before then)
confirmed_via       string ("app" | "button" | "" while pending)
caregiver_notified  bool       (the caregiver has the alert, pushed or in-app)
late_notified       bool       (the 30-minute running-late alert went out)
skipped_reason      string     (reason for a skipped or missed dose)
acknowledged_at     timestamp  (a reason was given)
cancelled_reason    string ("archived" | "rescheduled")
excluded_from_adherence bool   (medicine archived as "entered by mistake")
recorded_by         string
created_at          timestamp
is_active           bool

NEVER DELETED. firestore.rules has `allow delete: if false` on dose_logs.
Archiving cancels future pending doses; restoring revives them.
```

### notifications
```
notif_id            string
user_ref            string (→ users)
dose_log_ref        string (→ dose_logs)
notification_type   string ("reminder" | "confirmed" | "late" | "missed" |
                            "skipped" | "correction" | "low_stock" | "streak")
title               string
message             string
sent_at             timestamp
read_at             timestamp
channel             string ("fcm" | "in_app")
is_active           bool
```

### caregiver_patient_links
```
link_id              string
caregiver_ref        string (→ users)
patient_ref          string (→ users)
linked_since         timestamp
linked_by            string
status               string ("active" | "pending" | "removed")
can_view_schedule    bool
can_receive_alerts   bool
can_edit_medications bool  (always true for caregiver)
created_at           timestamp
is_active            bool
```

### devices
```
device_id       string
device_type     string ("medicine_box")
device_name     string
serial_number   string
patient_ref     string (→ users)
status          string ("online" | "offline")
last_sync       timestamp
columns_active  number
                NOTE: there is no battery_level field. This build has no
                battery monitoring on any GPIO pin.
created_at      timestamp
is_active       bool
```

### otp_codes
```
code            string
patient_ref     string (→ users, pre-created document)
caregiver_ref   string (→ users)
created_at      timestamp
expires_at      timestamp
used            bool
```

---

## Rule-based notification logic

```
Dose time reached
    → the APP (or the Worker) sets led_active: true in Firestore
    → ESP32 polls led_active and lights the LED on the box
    → FCM push notification sent to patient

  NOTE: the phone knows the real time and the schedule; the box is a display.
  Earlier drafts of this file said both "ESP32 sets led_active" and "ESP32
  polls led_active" — it is the second. The ESP32 never decides a dose is due.

Dose timeline (DOSE_LOGIC_PROPOSAL.md; one implementation in
lib/utils/dose_timing.dart, unit-tested in test/dose_timing_test.dart)

         −30 min           0          +30 min        +60 min
  ───────────┼─────────────┼──────────────┼──────────────┼────────►
   Upcoming  │  Upcoming   │   Due now    │    Late      │  Missed
   (locked)  │  (unlocked) │  (on time)   │              │

    → Done/Skip unlock 30 min before. Before that they look locked but a tap
      asks "Logging early?" — allowed up to 3 hrs before, never more than half
      the gap to the previous dose of the same medicine.
    → +30 min, nothing recorded: caregiver gets "Running late" (once, Worker)
    → +60 min, nothing recorded: status "missed", caregiver alerted (Worker)

Patient taps Done or Skip (dashboard, alarm screen, medicine detail)
    → written to Firestore at once; Skip asks for a reason first
    → 5-second Undo toast; the caregiver push (POST /dose-events) waits until
      it closes, so an undone tap never notifies anyone
    → led_active: false; Done counts one pill off
    → the Worker backstops a skip whose call never arrived (2–30 min later)

Missed dose → tap → reason (missed_dose_screen.dart)
    → "I took it but forgot to log it" (until the end of the next day): asks
      the time, status "taken", timing "logged_late", one pill off, caregiver
      gets a correction notice
    → any other reason: stays "missed" with the reason

Snooze — on the alarm screen only (opened by tapping a reminder)
    → Re-trigger after 10 minutes, while the dose is due or late
    → One snooze at a time: refused until snoozed_until has passed
    → After 3 snoozes the next Snooze tap marks it MISSED
    → Snoozed and then ignored: the sweep marks it MISSED once it is 60 min
      past scheduled_at AND 10 min past snoozed_until

Low stock (a confirmed dose brings pills_remaining to the threshold, or to 0)
    → in-app notification for the patient (written by the app)
    → FCM + notification for the caregiver (Worker, POST /dose-events),
      unless caregiver_profile.alert_pref_low_stock is false
    → at 0 pills, "Mark as taken" is disabled until the caregiver refills
```

---

## The box is optional (phone-only mode)

```
A patient may have no medicine box yet. Everything works without one:
reminders, confirming doses, snooze, missed-dose alerts, stock, reports.

Box mode is not a setting. It is derived:
  hasBox                = a devices doc exists for the patient (is_active)
  showsCompartment(s)   = hasBox AND s.mat_box_column != null
Only when showsCompartment is true may a screen or notification name a
compartment or an LED. An unpaired box keeps its compartment numbers.

Add medicine, step 3 ("Storage & stock"):
  no box  → no grid; banner says reminders are phone-only
  box     → grid of 8, taken compartments locked, plus "Not in the box";
            defaults to the first free compartment, or none for a non-pill
Compartments are moved per medicine on the caregiver's Smart box screen
(patient_box_screen.dart), never per dose time. Edit-medicine shows the
compartment read-only. Patients can pair a box but cannot assign
compartments: the rules let them write only led_active and pills_remaining.
```

## Medicine box integration

```
ESP32 ↔ Firebase communication:
  - Schedule fetch:  HTTP GET → Firestore REST API
  - Dose log write:  HTTP POST → Firestore REST API
  - LED control:     ESP32 polls led_active field in schedules collection
  - Offline:         DS3231 RTC triggers locally, logs to microSD
  - Reconnect sync:  Push all microSD logs to Firestore, clear local queue
  - Auth:            ESP32 uses Firebase service account API key

GPIO pin assignments:
  LED Column 1  → GPIO 13
  LED Column 2  → GPIO 14
  LED Column 3  → GPIO 25
  LED Column 4  → GPIO 26
  LED Column 5  → GPIO 27
  LED Column 6  → GPIO 32
  LED Column 7  → GPIO 33
  LED Column 8  → GPIO 4
  Push button   → GPIO 5  (10kΩ pull-down to GND)
  Active buzzer → GPIO 18
  DS3231 SDA    → GPIO 21
  DS3231 SCL    → GPIO 22
  MicroSD MOSI  → GPIO 23
  MicroSD MISO  → GPIO 19
  MicroSD SCK   → GPIO 15
  MicroSD CS    → GPIO 17
```

---

## Screens — current status

**A screen is DONE when** it reads its data from a provider or stream, its write
path reaches Firestore, and its failure path shows a message through
`SnackbarHelper`. Rendering correctly is not done.

That rule exists because the previous checklist marked `device_pairing_screen`
and `patient_profile_setup_screen` as done when neither saved anything, which is
how they reached Phase 4 unnoticed. See `PHASE_4.5_REMEDIATION.md`.

### AUTH screens
```
[x] welcome_screen.dart               caregiver sign-up / patient code / log in
[x] role_select_screen.dart
[x] register_screen.dart              caregiver only
[x] login_screen.dart
[x] forgot_password_screen.dart
[x] email_verification_screen.dart    skipped for managed patients
[x] otp_entry_screen.dart             8-char code → Worker → custom token
[x] otp_success_screen.dart           shows the pre-loaded schedule
```

### PATIENT screens
```
[x] patient_main_screen.dart          bottom nav wrapper
[x] patient_dashboard_screen.dart
[x] schedule_screen.dart
[x] add_medicine_step1_screen.dart    opened by the caregiver only
[x] add_medicine_step2_screen.dart    (from setup_medications_screen)
[x] add_medicine_step3_screen.dart
[x] add_medicine_success_screen.dart
[x] medicine_detail_screen.dart       read-only: no edit / delete actions
[x] edit_medicine_screen.dart         caregiver only, via PatientProvider
[x] delete_medicine_screen.dart       caregiver only; retires the medication AND its schedules
[x] medicine_box_status_screen.dart   live 8-column view off devices + schedules
[x] dose_alert_screen.dart            alarm screen, opened by tapping a reminder
                                      (also from a closed app); the only Snooze
[x] dose_confirmed_screen.dart
[x] missed_dose_screen.dart           reason, or "took it but forgot" → logged late
[x] analytics_screen.dart
[x] notifications_screen.dart         reads the notifications collection
[x] patient_profile_screen.dart
[x] edit_profile_screen.dart          saves to users + patient_profile
[x] change_password_screen.dart
[x] settings_screen.dart              device-local prefs via PreferencesService
[x] device_pairing_screen.dart        serial entry → creates a devices doc

DELETED — a static duplicate of a working screen:
  intake_history_screen.dart   → use analytics_screen.dart
  scan_qr_screen.dart          → QR scanning belongs with Phase 7 hardware

DELETED — unreachable once the solo role was removed:
  patient_profile_setup_screen.dart → only a self-registering patient reached
                                      it; the caregiver now enters medical
                                      details in add_patient_screen
```

### CAREGIVER screens
```
[x] caregiver_main_screen.dart        bottom nav wrapper
[x] caregiver_welcome_screen.dart
[x] caregiver_dashboard_screen.dart
[x] my_patients_screen.dart
[x] add_patient_screen.dart           calls the Worker's POST /patients
[x] setup_medications_screen.dart     authors to the patient's uid
[x] generate_otp_screen.dart          48-hour countdown, share sheet
[x] patient_detail_screen.dart
[x] patient_schedule_screen.dart      real day strip + materialised doses
[x] patient_history_screen.dart       real dose_logs, grouped by day
[x] caregiver_alerts_screen.dart      reads the notifications collection
[x] reports_screen.dart               live adherence from dose logs
[x] patient_box_screen.dart           pair a box, assign compartments per medicine
[x] caregiver_profile_screen.dart
[x] caregiver_settings_screen.dart

DELETED — a static duplicate of a working screen:
  patient_analytics_screen.dart  → use reports_screen.dart
  missed_alert_screen.dart       → use caregiver_alerts_screen.dart
```

### SOLO USER screens — removed
```
The solo role was removed in October 2026 before either screen was built.
Neither solo_dashboard_screen.dart nor solo_analytics_screen.dart ever
existed as files. Nothing to build here.
```

---

## No phantom features

This build has **8 LEDs, a push button, a buzzer, a DS3231 RTC and a microSD
card**. It has no heart-rate sensor, no pulse oximeter, no battery monitoring,
no smartwatch and no SMS gateway.

Earlier screens displayed `HR 78 bpm`, `SpO2 98%`, `Battery 84%`,
`WearOS · Connected` and an "SMS fallback" toggle. All of it was traced from
mockups, and all of it is now removed. **Do not reintroduce a reading the
hardware cannot produce** — a panelist who sees "SpO2 98%" will ask which sensor
produced it.

---

## Coding standards (follow every time)

```
1. Clean architecture always:
   /screens  /widgets  /models  /services  /providers

2. NEVER call Firebase directly from UI widgets
   All Firebase calls go inside service classes:
   - auth_service.dart
   - firestore_service.dart
   - notification_service.dart
   - device_service.dart

3. Use StreamBuilder for real-time Firestore data
   Use FutureBuilder for one-time data fetches

4. Handle all errors with SnackBar messages
   Use snackbar_helper.dart

5. Every screen file uses snake_case naming
   e.g. patient_dashboard_screen.dart

6. Support Android API level 21 and above

7. Use Plus Jakarta Sans everywhere — fontFamily: 'PlusJakartaSans'

8. State management: Provider
   Import providers from /providers folder

9. AppColors class for all colors — never hardcode hex in screens
   AppStyles class for reusable decorations and input styles
```

---

## When I send you a Figma screenshot

1. Analyze the design carefully — colors, layout, spacing, components
2. Tell me the exact file path to create
3. Give me the **complete** Dart code — no partial snippets
4. Tell me what to run in the terminal after
5. Tell me exactly what I should see on screen to confirm it worked
6. If it needs navigation, use Navigator.push or named routes
7. If it needs Firebase, use the service class — never call Firebase directly in the screen

---

## Firebase project

```
Project ID:     healthsync-b8394
Plan:           Spark (free) — do NOT upgrade to Blaze
Auth:           Email/Password + Custom Token (for managed patients)
Firestore:      Test mode, asia-southeast1 region (lock rules before release)
FCM:            Enabled — sent only from the Cloudflare Worker, never from the app
Flutter config: lib/firebase_options.dart (auto-generated by FlutterFire CLI)
```

## Cloudflare Worker (server-side)

```
Why:     Cloud Functions cannot deploy on the Spark plan. The Worker holds the
         Firebase service account key and does the four things a client cannot:
         mint custom tokens, create Auth accounts, send FCM to another user,
         and run the late (30 min) and missed (60 min) sweep on a cron.

Secrets: FIREBASE_SA_KEY via `wrangler secret put` — NEVER in the repo or the APK
Cache:   KV namespace TOKEN_CACHE holds the OAuth access token for 55 min
Limits:  free plan = 10ms CPU per invocation, 50 external subrequests, 100k req/day

Endpoints:
  POST /patients              caregiver creates a managed patient account
  POST /otp/redeem            code in → Firebase custom token out (rate-limited)
  POST /dose-events           dose confirmed/missed → caregiver FCM
  cron */5 * * * *            materialise doses, running-late alerts, missed sweep, skip backstop
  GET  /device/{serial}/schedule   ESP32 polls this instead of Firestore
  POST /device/{serial}/dose       ESP32 button press

App side: lib/services/api_service.dart is the ONLY place that calls the Worker.
          Base URL comes from --dart-define, never hardcoded.
```

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

⚠️ STILL OPEN: applicationId is "com.example.healthsync". Google Play REJECTS
   com.example.* and the id cannot be changed after the first upload. Changing
   it needs a new package registered in the Firebase console plus a re-run of
   flutterfire configure, so it is left for whoever holds those credentials.
```

---

## Git workflow

```
Branch: dev
Remote: origin

Commands:
  git add .
  git commit -m "your message"
  git push origin dev

Auth: Use Personal Access Token (not password)
GitHub: Settings → Developer Settings → Personal Access Tokens → Classic
```

---

*This file is read automatically by Claude Code at the start of every session.*
*Update the screen checklist above as you complete each screen.*
*Cervantes, Miko D. — NTC BSIT Capstone 2025-2026*
