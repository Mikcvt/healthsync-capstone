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
| Font | Plus Jakarta Sans |
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

## Three user types (redesigned flow)

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

### 3. Solo user
- Downloads app → selects Solo on welcome screen
- Self-registers with email and password
- Manages their own medications completely independently
- Has full add, edit, delete access to their own medications
- No caregiver connection needed
- Receives their own FCM reminders

---

## OTP code rules

```
- One-time use only
- Mark used: true in Firestore immediately after first login
- Expires 48 hours after generation
- Patient auth via OTP token — no password required
- account_type field: "managed" (patient) or "solo" (solo user) or "caregiver"
- can_edit_medications: true for caregiver and solo only, false for managed patient
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
// Patient / Solo
patientBlue:    Color(0xFF1B5FD4)
blueLight:      Color(0xFFEBF1FF)
blueDark:       Color(0xFF0F3E9E)

// Caregiver
caregiverGreen: Color(0xFF0D9B6B)
greenLight:     Color(0xFFE4F7F0)
greenDark:      Color(0xFF066845)

// Solo user accent
soloP urple:    Color(0xFF7C3AED)

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
role            string ("patient" | "caregiver" | "solo")
account_type    string ("managed" | "solo" | "caregiver")
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
medical_conditions string
allergies          string
emergency_contact  string
emergency_phone    string
created_at         timestamp
```

### caregiver_profile
```
profile_id         string
user_ref           string (→ users)
alert_pref_missed  bool
alert_pref_low_stock bool
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
instructions        string
prescribing_doctor  string
date_prescribed     date
start_date          date
end_date            date
is_active           bool
created_by          string (caregiver uid or solo uid)
updated_at          timestamp
```

### schedules
```
schedule_id     string
pat_med_ref     string (→ patient_medications)
patient_ref     string (→ users)
scheduled_time  string ("08:00 PM")
days_of_week    array  (["Mon","Tue","Wed","Thu","Fri","Sat","Sun"])
mat_box_column  number (1–8)
start_date      date
end_date        date
is_active       bool
led_active      bool   (ESP32 polls this to activate/deactivate LED)
created_at      timestamp
```

### dose_logs
```
dose_log_id         string
schedule_ref        string (→ schedules)
patient_ref         string (→ users)
scheduled_date      date
scheduled_time      string
status              string ("taken" | "missed" | "snoozed" | "pending")
taken_at            timestamp
snooze_count        number
confirmed_via       string ("app" | "button")
caregiver_notified  bool
skipped_reason      string
recorded_by         string
created_at          timestamp
is_active           bool
```

### notifications
```
notif_id            string
user_ref            string (→ users)
dose_log_ref        string (→ dose_logs)
notification_type   string ("reminder" | "missed" | "confirmed" | "low_stock" | "streak")
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
    → ESP32 sets led_active: true in Firestore → LED lights up on box
    → FCM push notification sent to patient

Patient confirms via app OR push button on box
    → dose_logs status: "taken"
    → led_active: false → LED turns off
    → caregiver_notified: true → FCM to caregiver

No confirmation after 30 minutes
    → dose_logs status: "missed"
    → FCM alert to caregiver
    → led_active: false

Snooze
    → Re-trigger after 10 minutes
    → Max 3 snoozes before marking MISSED

Low stock (pills remaining < threshold)
    → FCM to patient and caregiver
```

---

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

## Screens to build (track progress here)

### AUTH screens
```
[ ] welcome_screen.dart               ✅ DONE
[ ] role_select_screen.dart
[ ] register_screen.dart
[ ] login_screen.dart
[ ] forgot_password_screen.dart
[ ] email_verification_screen.dart
[ ] otp_entry_screen.dart             (patient enters code)
[ ] otp_success_screen.dart
```

### PATIENT screens
```
[ ] patient_main_screen.dart          (bottom nav wrapper)
[ ] patient_dashboard_screen.dart
[ ] schedule_screen.dart
[ ] add_medicine_step1_screen.dart
[ ] add_medicine_step2_screen.dart
[ ] add_medicine_step3_screen.dart
[ ] add_medicine_success_screen.dart
[ ] medicine_detail_screen.dart
[ ] edit_medicine_screen.dart
[ ] delete_medicine_screen.dart
[ ] medicine_box_status_screen.dart
[ ] dose_alert_screen.dart
[ ] dose_confirmed_screen.dart
[ ] missed_dose_screen.dart
[ ] intake_history_screen.dart
[ ] analytics_screen.dart
[ ] notifications_screen.dart
[ ] patient_profile_screen.dart
[ ] edit_profile_screen.dart
[ ] guardian_link_screen.dart
[ ] change_password_screen.dart
[ ] settings_screen.dart
[ ] device_pairing_screen.dart        ✅ DONE
[ ] patient_profile_setup_screen.dart ✅ DONE (bug fixed)
```

### CAREGIVER screens
```
[ ] caregiver_main_screen.dart        (bottom nav wrapper)
[ ] caregiver_dashboard_screen.dart
[ ] my_patients_screen.dart
[ ] add_patient_screen.dart
[ ] setup_medications_screen.dart
[ ] generate_otp_screen.dart
[ ] patient_detail_screen.dart
[ ] patient_schedule_screen.dart
[ ] patient_history_screen.dart
[ ] caregiver_alerts_screen.dart
[ ] reports_screen.dart
[ ] caregiver_profile_screen.dart
[ ] caregiver_settings_screen.dart
[ ] caregiver_main_screen.dart
```

### SOLO USER screens
```
[ ] solo_dashboard_screen.dart
[ ] solo_analytics_screen.dart
(shares all other patient screens)
```

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
         and run the 30-minute missed-dose sweep on a cron.

Secrets: FIREBASE_SA_KEY via `wrangler secret put` — NEVER in the repo or the APK
Cache:   KV namespace TOKEN_CACHE holds the OAuth access token for 55 min
Limits:  free plan = 10ms CPU per invocation, 50 external subrequests, 100k req/day

Endpoints:
  POST /patients              caregiver creates a managed patient account
  POST /otp/redeem            code in → Firebase custom token out (rate-limited)
  POST /dose-events           dose confirmed/missed → caregiver FCM
  cron */5 * * * *            missed-dose sweep + low-stock check
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
