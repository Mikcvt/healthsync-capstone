# HealthSync — Claude Code Context File
# Auto-read by Claude Code every session. Do not delete.
# Last updated: November 7, 2026

---

## Project overview

**A Mobile-Based Medication Reminder System with an IoT-Assisted LED-Guided
Medicine Box for Care Partner-Supported Medication Adherence** (system name:
HealthSync)

- Institution: National Teachers College, Quiapo, Manila
- Course: BSIT Capstone (Capstone 1 in AY 2025–2026, Capstone 2 in AY 2026–2027)
- Key dates: UAT Nov 3–6 · consolidation Nov 7 · paper ready Nov 10 · defense Nov 12–14, 2026
- Team: Martin Merry Siemonne O. (project lead) · Cervantes Miko D. (lead
  developer; builds and signs every APK) · Fernandez Adia Charlotte · General
  Feonna Anne D. · San Luis Christian D. (hardware)
- Distribution: a **hosted APK** (GitHub Releases on the public repo
  `Mikcvt/healthsync-capstone`, linked from the project website). Not on
  Google Play: production was refused (health apps need an organisation
  developer account). History: [docs/archive/CLAUDE_HISTORY.md](docs/archive/CLAUDE_HISTORY.md).

---

## What this system does

HealthSync helps patients take their medications on time. Two parts:

1. **Flutter Android app** for care partners and managed patients: medicine
   schedules, dose reminders scheduled on the patient's phone, Done / Skip /
   Snooze, adherence history, and care partner alerts. Works fully without a
   box ("phone-only mode").

2. **Optional LED-guided medicine box** (ESP32, firmware 0.4.3): 6
   compartments with one LED each, a buzzer, a DFPlayer Mini with one speaker
   for recorded voice prompts, a push button, a DS3231 clock and a microSD
   event log, on a rechargeable 18650 cell. At dose time the box lights the
   compartment, sounds the tone and speaks the prompt from its own saved
   schedule, even with no phone nearby. **Pressing the button while a
   compartment is lit confirms every lit dose as taken.** The box talks only
   to the patient's phone over Bluetooth Low Energy (connect-on-demand); it
   has no Wi-Fi or cloud link. The phone carries box events to Firebase.

---

## Tech stack

| Layer | Technology |
|-------|-----------|
| Mobile app | Flutter / Dart, Android only, minimum Android 7.0 (API 24) |
| Backend | Firebase **Spark (free) plan**: Firestore, Auth, FCM |
| Server-side jobs | **Cloudflare Worker** (free plan, TypeScript): patient accounts, code redemption and custom tokens, FCM to care partners, dose creation and the late/missed sweep, account deletion. Cloud Functions are NOT used: they cannot deploy on Spark. |
| Box link | BLE: NimBLE-Arduino on the ESP32 (peripheral), `flutter_blue_plus` 1.34.5 in the app (central) |
| Reminders | `flutter_local_notifications` exact alarms, `Asia/Manila` time zone |
| Background box sync | `flutter_foreground_task` (connectedDevice), every build |
| State management | Provider |
| Font | Plus Jakarta Sans — **bundled** in `fonts/`, declared in `pubspec.yaml` (not `google_fonts`) |
| Design source | Figma |
| Version control | Git / GitHub (public repo `Mikcvt/healthsync-capstone`), see "Git workflow" |

---

## Repo layout

```
healthsync-capstone/
├── lib/
│   ├── config/         environment.dart (dev/prod Firebase and Worker URL)
│   ├── constants/      app_colors, app_strings, app_styles
│   ├── models/         13 files (one per collection, plus dose_slot,
│   │                   box_messages for the BLE protocol)
│   ├── services/       14 files: auth, firestore, api (the only Worker
│   │                   caller), notification, dose_reminder_scheduler,
│   │                   box_link (BLE), box_watch (foreground service),
│   │                   device, connectivity, reminder_health, ...
│   ├── providers/      auth, patient, caregiver, schedule, box
│   ├── utils/          dose_timing (the dose rules), box_watch, adherence,
│   │                   validators, snackbar_helper, date_formatter, ...
│   ├── screens/
│   │   ├── auth/       10 screens
│   │   ├── patient/    21 screens
│   │   └── caregiver/  15 screens
│   ├── widgets/
│   │   ├── shared/     12 widgets
│   │   ├── patient/    dose_actions, dose_reason_picker
│   │   └── caregiver/  delete_patient_dialog
│   ├── firebase_options.dart (prod), firebase_options_dev.dart (dev)
│   └── main.dart
├── test/               6 test files (see "Tests")
├── healthsync-api/     Cloudflare Worker (src/index.ts, src/handlers, src/lib)
├── firmware/healthsync_box/   ESP32 firmware (config.h is the source of truth for pins)
├── firestore.rules, firestore.indexes.json
├── android/app/src/{main,dev,prod}/   manifests; google-services.json per flavor
├── fonts/              Plus Jakarta Sans TTF files
├── docs/               paper-crosscheck/, uat-it-experts/, archive/
└── CLAUDE.md           ← this file
```

---

## Wording: "Care Partner", never caregiver or guardian, on screen

"caregiver" in code (CaregiverProvider, caregiver_ref, account_type
"caregiver", file names) is the same role users see as **Care Partner**. Code
and stored fields keep the old name; renaming them would break every account.
Anything a user sees or hears says "Care Partner" in titles and labels and
"care partner" inside sentences. Never "guardian".

## Two user types

### 1. Care partner (`caregiver` in code)
- Registers and logs in with email and password (the only self-registering role)
- Adds patients from their dashboard (Worker `POST /patients`)
- Enters every medicine, dose time and box compartment
- Gets a one-time sign-in code for each patient and passes it on (Copy button)
- **Only the care partner can add, edit, archive or delete medicines**
- Receives FCM alerts: dose taken (also early/late), skipped, running late,
  missed, correction ("Dose update"), low stock, and the patient's account deletion
- Can monitor several patients; no fixed limit on patients or medicines

### 2. Managed patient (`managed` in code)
- Installs the APK and enters the 8-character code; the account opens
- **No signup, no password, no form**: account and schedule are pre-loaded
- Confirms, skips (with a reason) or snoozes doses, views their own history,
  pairs a box, and can delete their own account
- Cannot edit medicines (read-only)

> **A third "solo user" role was removed in October 2026.** Caregiver is the
> only self-registering account; a patient always arrives with a code.
> Do not reintroduce it.

---

## Sign-in code rules (`otp_codes`)

```
- "HS" + 6 random characters from ABCDEFGHJKMNPQRSTUVWXYZ23456789
  (8 in total, shown as HS7K-2M9Q); stored under the code as document id
- One-time use: the Worker marks used: true on redemption (otp.ts);
  clients can never set `used`
- Expires 48 hours after creation (OtpCodeModel.validity)
- Rate-limited: a device that enters too many wrong codes is blocked for 10 min
- The Worker refuses a code unless the patient's profile names the code's
  care partner and the account is an active managed patient
- account_type: "managed" (patient) or "caregiver"
- can_edit_medications: true for caregiver only, false for managed patient
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

// Box compartment status
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
- Care partner: 5 tabs — Home, Patients, Alerts, Reports, Profile
- Active color: patient=blue, care partner=green

---

## Firestore data model (11 collections + 1 Worker-only)

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
deletion_requested_at  timestamp ┐ set by the Worker when the account is
deletion_requested_by  string    │ deleted (own uid, or the care partner's);
deletion_scheduled_for timestamp ┘ purged on that date unless restored.
                                   Written by the Worker only: the rules
                                   refuse any client write to these three.
                                   is_active is false meanwhile.
reminders_notifications_ok bool  ┐ reported by the patient app
reminders_exact_alarms_ok  bool  │ (ReminderHealthService) for the care
reminders_battery_ok       bool  │ partner dashboard; written on change or
app_last_opened_at    timestamp  ┘ at most every 6 hours
                (none of these are in UserModel.toMap, so a profile save
                cannot overwrite them)
No password is stored here: passwords live only in Firebase Auth.
```

### patient_profile
```
profile_id         string
user_ref           string (→ users)
caregiver_ref      string (→ users)   one care partner per patient
date_of_birth      timestamp (optional)
gender             string (optional)
medical_conditions array  of string  ← NOT a string. The Dart model parses with
allergies          array  of string     a list reader; the Worker writes arrays
                                        to match. A plain string here threw a
                                        TypeError and took down the whole
                                        patient_profile stream.
emergency_contact  string
emergency_phone    string
treatment_completed_at timestamp  (set by "Mark treatment complete"; read-only
                                   in the Dart model, never written by toMap)
created_at         timestamp
is_active          bool
```

### caregiver_profile
```
profile_id         string
user_ref           string (→ users)
alert_pref_missed  bool   (running late, missed, skipped, logged late)
alert_pref_low_stock bool
alert_pref_daily   bool   UNUSED: nothing sends a daily summary and the
                          switch was removed. To be removed (see "Open items").
created_at         timestamp
is_active          bool
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
is_active       bool
```

### patient_medications
```
pat_med_id          string
patient_ref         string (→ users)
medication_ref      string (→ medications)
medication_name     string
prescribed_dosage   string
quantity_per_dose   number
dosage_form         string ("Tablet" | "Capsule" | "Liquid" | "Drops" |
                            "Inhaler" | "Injection"). Only Tablet and Capsule
                            default into a box compartment.
purpose             string
color_label         string
instructions        string
prescribing_doctor  string
date_prescribed     date
start_date          date
end_date            date
is_active           bool
archived_reason     string (why it was archived)
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
mat_box_column  number (1–6) or null  (ScheduleModel.boxCompartments; a stored 7 or 8
                from an older build reads as "not in the box")
                null = not in the box: no box paired yet, or a liquid,
                inhaler or seventh medicine. Every dose time of one medicine
                shares one compartment. Never display null as a compartment.
pills_remaining number (an estimate; shared with the box button)
low_stock_threshold number (default 5)
start_date      date
end_date        date
is_active       bool
led_active      bool   legacy: still written by the app (false after Done
                       or when a medicine leaves the box); the box does not
                       read it. The box lights LEDs from the schedule the
                       phone sends over BLE.
paused_for_deletion bool  (switched off by an account deletion; a restore
                           switches back on exactly these)
created_at      timestamp
updated_at      timestamp  (server time; stamped by every caregiver change that
                           alters which doses exist. The Worker creates doses
                           hourly and runs early only when it sees a recent
                           stamp — a schedule write without it waits an hour.
                           Patient writes never set it.)
```

### dose_logs
```
dose_log_id         string   (deterministic: {schedule_id}_{YYYY-MM-DD}_{HH:mm};
                              the box uses the same id for its events)
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
taken_at            timestamp  (for logged_late: when the patient says; for a
                               box press: when the button was pressed)
logged_at           timestamp  (when the patient last acted, by the phone's
                               clock; the rules allow Undo for 2 minutes after
                               it)
synced_at           timestamp  (server time the change ARRIVED; stamped on
                               every app write. The alert backstop goes by it,
                               so a dose logged offline still gets its alert)
missed_at           timestamp  (when it was marked missed; set by the sweep)
undone_at           timestamp  (when Undo was tapped; lets an offline Undo
                               pass the 2-minute rule after a late sync)
stock_counted       bool       (false = taken while the count read 0)
snooze_count        number
snoozed_until       timestamp  (when the current snooze ends; another snooze
                               is refused before then)
dose_count          number     (default 1)
confirmed_via       string ("app" | "button" | "" while pending)
caregiver_notified  bool       (the caregiver has the alert, pushed or in-app)
late_notified       bool       (the 30-minute running-late alert went out)
skipped_reason      string     (reason for a skipped dose, required; or for a
                               missed dose, optional)
acknowledged_at     timestamp  (a reason was given)
cancelled_reason    string ("archived" | "rescheduled" | "account_deleted")
excluded_from_adherence bool   (medicine archived as "entered by mistake")
recorded_by         string
created_at          timestamp
is_active           bool

NEVER DELETED by the app. firestore.rules has `allow delete: if false` on
dose_logs. Archiving cancels future pending doses; restoring revives them.
The one exception is account deletion: 30 days after POST /account/delete
or /patients/delete, the Worker's purge cron erases the dose logs with
everything else.
```

### notifications
```
notif_id            string
user_ref            string (→ users)
patient_ref         string (→ users) — caregiver alerts only; the Alerts tab
                    opens this patient on tap
dose_log_ref        string (→ dose_logs)
notification_type   string ("reminder" | "confirmed" | "late" | "missed" |
                            "skipped" | "correction" | "low_stock" | "streak" |
                            "account_deletion")
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

One link per patient, created by POST /patients. No screen links a second
care partner or unlinks one (unlinkPatient() exists but has no caller).
Ownership checks use patient_profile.caregiver_ref, never the links.
```

### devices
```
device_id       string
device_type     string ("medicine_box")
device_name     string
serial_number   string (e.g. "HS-0001", read from the box when pairing)
firmware_version string
patient_ref     string (→ users)
status          string ("online" | "offline"); online = synced in the last
                10 minutes (DeviceModel.onlineWindow)
last_sync       timestamp (last sync with the phone)
columns_active  number
created_at      timestamp
is_active       bool
                NOTE: there is no battery_level field. This build has no
                battery monitoring on any GPIO pin.
```

### otp_codes
```
code            string   (document id; "HS" + 6 characters)
patient_ref     string   (→ users, pre-created document)
caregiver_ref   string   (→ users)
created_at      timestamp
expires_at      timestamp  (created_at + 48 hours)
used            bool       (set to true by the Worker on redemption)
```

### account_deletions (Worker only)
```
One job per deletion: who asked, which accounts, purge_after = +30 days.
The */15 cron purges jobs whose purge_after has passed.
```

---

## Dose rules (one implementation: lib/utils/dose_timing.dart,
## unit-tested in test/dose_timing_test.dart; see DOSE_LOGIC_PROPOSAL.md)

```
Reminders: the patient's phone schedules an exact alarm for every dose
(dose_reminder_scheduler.dart, Asia/Manila); they fire with the app closed
and offline. The Worker creates the dose records and does the sweep.

         −30 min           0          +30 min        +60 min
  ───────────┼─────────────┼──────────────┼──────────────┼────────►
   Upcoming  │  Upcoming   │   Due now    │    Late      │  Missed
   (locked)  │  (unlocked) │  (on time)   │              │

    → Done/Skip unlock 30 min before. Before that they look locked but a tap
      asks "Logging early?" — allowed up to 3 hrs before, never more than half
      the gap to the previous dose of the same medicine.
    → +30 min, nothing recorded: caregiver gets "Running late" (once, Worker)
    → +60 min, nothing recorded: status "missed", caregiver alerted (Worker)
    The Worker runs every 5 minutes, so alerts arrive within about 5 minutes
    of those points.

Patient taps Done or Skip (dashboard, alarm screen, medicine detail)
    → written to Firestore at once; Skip asks for a reason first (required)
    → 5-second Undo toast; the caregiver push (POST /dose-events) waits until
      it closes, so an undone tap never notifies anyone
    → led_active: false; Done counts one pill off
    → the Worker backstops a skip whose call never arrived (2–30 min later)

Missed dose → tap → reason (missed_dose_screen.dart). A reason is OPTIONAL
(decided Nov 7): a dose that is never tapped stays missed with no reason.
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
    → at 0 pills the dose can still be logged (the count is only an estimate:
      the box may have been refilled). A note says to refill; the count stays
      at 0, the dose log gets stock_counted: false, Undo gives no pill back,
      and the Worker skips a repeat "Out of stock" alert
```

---

## Offline-first dose logging

```
A signed-in patient can log doses with no internet. Firestore keeps every
write on the phone (surviving restarts) and sends it when back online.

  App:    dose actions issue their writes and FirestoreService.settle() them:
          wait up to 4 s for the server, else accept them as saved offline.
          NEVER await a single Firestore write in a dose action: on Android
          its Future only completes when the server confirms, so offline it
          never does. Reads before a write use the phone's copy when offline
          (getDoseLog). setDoseLog merges, so Worker-only fields survive.
  Rules:  missed -> taken/skipped is allowed when the patient acted
          (logged_at) before the sweep wrote the dose off (missed_at).
          Undo passes by undone_at when it syncs after the 2-minute window.
  Worker: the sweep stamps missed_at; such a dose arriving later is a
          "correction" alert ("their phone was offline"); the backstop
          queries caregiver_notified=false by synced_at (index deployed).
  UI:     offline banner on the dashboard (ConnectivityService), "Waiting to
          sync" on a dose with pending writes, "(saved offline, will sync)"
          in the Undo toast.

Limits: sync happens while the app is open; times come from the phone's
clock; the first-ever launch needs internet. Sign-up, login, OTP redemption,
adding/deleting patients and changing email stay online-only.
```

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
  box     → grid of 6, taken compartments locked, plus "Not in the box";
            defaults to the first free compartment, or none for a non-pill
Compartments are moved per medicine on the caregiver's Smart box screen
(patient_box_screen.dart), never per dose time. Edit-medicine shows the
compartment read-only. Patients can pair a box but cannot assign
compartments: the rules let them write only led_active and pills_remaining.
```

## Medicine box and Bluetooth (BLE_CONNECT_ON_DEMAND.md, BLE_PROTOCOL.md)

```
Link     BLE only, connect-on-demand. The box is the peripheral, the phone the
         central. No Wi-Fi, no hotspot, no box-to-cloud link, no key on the box.
Pairing  Hold the box button 5 s with nothing lit → pairing mode for 2 min
         (running light 1→6). The phone pairs with the 6-digit passkey printed
         on the box label (LE Secure Connections + bonding, so Bluetooth 4.2+).
         The passkey lives in firmware/healthsync_box/secrets.h: git-ignored,
         never commit it. Android 12+ asks for "Nearby devices"; Android 11
         and older ask for location (ACCESS_FINE_LOCATION, maxSdk 30).
Sync     The phone sends the clock, the whole schedule (compartment, time,
         days) and "done in the app"; the box sends its events (taken by
         button, missed). Events have sequence numbers; the phone acks them
         and the box deletes its copy. A sync happens when the app opens or
         resumes (at most every 2 min), after Done/Skip, on the Sync button,
         on pairing, and every minute while a box dose is due (background
         box watch, below).
Button   Press and release (0.3–10 s) while a compartment is lit: every lit
         dose is taken ("Dose confirmed."). Nothing lit: nothing is taken
         (never early). The phone records the press as taken with
         confirmed_via "button" and taken_at = the press time
         (PatientProvider.recordBoxPress). If the app already logged that
         dose, the app's answer is kept. A press that reaches the phone after
         the dose was marked missed still counts as taken, and the care
         partner gets a correction.
Box rules The box alarms from its saved schedule and DS3231 clock, even with
         no phone. It never takes a dose early. At +60 min with no press it
         logs "missed" for the phone. It does not decide alerts: the Worker does.

GPIO pins (firmware/healthsync_box/config.h is the source of truth):
  LED Compartment 1–6 → GPIO 13, 14, 25, 26, 32, 33 (each through 220 Ω)
  Push button   → GPIO 16  (6 mm normally-closed, to GND, internal pull-up;
                            idle LOW, pressed HIGH)
  Active buzzer → GPIO 17  (NPN transistor, 1 kΩ base resistor)
  DS3231 SDA    → GPIO 21,  SCL → GPIO 22
  MicroSD SCK 18, MISO 23, MOSI 19, CS 15 (module on 5 V)
  Built-in LED  → GPIO 2   (on while a phone is connected; bench aid)
  DFPlayer RX   ← GPIO 27  (through 1 kΩ)   ┐ VCC on 5 V with 470 µF;
  DFPlayer TX   → GPIO 34  (input-only pin)  │ speaker on SPK1/SPK2,
  DFPlayer BUSY → GPIO 35  (input-only pin)  ┘ never to GND
Wiring and parts: HARDWARE_ARCHITECTURE.md (§4.8 for the DFPlayer).

Firmware: 0.4.3 on the release branch. Christian's unmerged branch
feature/medbox-integration has 0.5.0 (power saving, status flashes, Oct 29).
Confirm which one is flashed on the demo box before describing it.
```

## Box sounds (firmware 0.4.3)

```
Tone first, then voice, always. The beep is never replaced.
Clips: /01/NNN.mp3 on the DFPlayer's own card (VOICE_CLIPS.md, 14 English clips).

  Dose due     rounds of: 5 s tone → "Please take your medicine.
               Compartment one (, two and three)." → 5 s silence.
               Voice every round for 5 min, then every 3rd round; silent
               after 30 min (LED stays lit); missed at +60 min.
  Box button   1.5 s tone → "Dose confirmed."
  Pairing      2 s tone → "Pairing mode."; 3 s / 0.5 s tone → "Phone
               connected."; 0.8 s tone → "Pairing cancelled."
  Power on     1 s tone → "HealthSync med box is ready. Please pair or sync
               your phone." Once per power-on, not after an automatic restart.
  Tone only    nothing due (0.8 s), too-short press, clock problems.

No DFPlayer, or no answer at start-up → tones only; the alarm never goes
silent. After a brownout reset the voice stays off until the next power-on.
Power: on laptop USB, volume 30 + Bluetooth browned the ESP32 out (Nov 3);
on the 18650 + 134N3P it works, and resets seen on the battery were a low
battery (Christian, Nov 4): charge the box before UAT and demos.
Never send the DFPlayer its reset command.
Code: firmware/healthsync_box/voice.cpp, buzzer.cpp (alarm rounds), config.h.
Bench test sketch: firmware/healthsync_box/dfplayer_test/.
```

## Background box watch (every build since Nov 3, 2026)

```
While a box dose is due (dose time to +60 min, nothing recorded), the app
syncs with the box every minute, in the background too, so a press of
the box button is saved without the Sync button. A foreground service
(flutter_foreground_task, type connectedDevice) keeps the app awake and
shows an ongoing "Medicine box watch" notification; it starts when the app
comes on screen or leaves it (the only moments Android allows) and runs
until today's last box dose is done. Swiping the app away stops it.

  lib/utils/box_watch.dart              when to watch (test/box_watch_test.dart)
  lib/services/box_watch_service.dart   the service; the sync stays in BoxProvider
  android/app/src/main/AndroidManifest.xml   the service + permissions

A Google Play release would first need the Play Console foreground-service
declaration (connectedDevice).
```

---

## Screens

**A screen is DONE when** it reads its data from a provider or stream, its write
path reaches Firestore, and its failure path shows a message through
`SnackbarHelper`. Rendering correctly is not done. (Two screens once passed
as done without saving anything; see `docs/archive/PHASE_4.5_REMEDIATION.md`.)

All screens below are done.

```
AUTH (10)
  splash_screen                  launch screen
  welcome_screen                 care partner sign-up / patient code / log in
  role_select_screen
  register_screen                care partner only
  login_screen
  forgot_password_screen
  email_verification_screen      skipped for managed patients
  otp_entry_screen               8-char code → Worker → custom token
  otp_success_screen             shows the pre-loaded schedule
  pending_deletion_screen        a deleted care partner signing in: Restore / Sign out

PATIENT (21)
  patient_main_screen            bottom nav wrapper
  patient_dashboard_screen
  schedule_screen
  add_medicine_step1/2/3_screen, add_medicine_success_screen
                                 opened by the care partner only
                                 (from setup_medications_screen)
  medicine_detail_screen         read-only: no edit / delete actions
  edit_medicine_screen           care partner only, via PatientProvider
  delete_medicine_screen         care partner only; retires the medicine AND its schedules
  medicine_box_status_screen     live 6-compartment view and the Sync button
  device_pairing_screen          Bluetooth scan → Android pairing (label passkey)
                                 → serial from the box → devices doc
  dose_alert_screen              alarm screen, opened by tapping a reminder
                                 (also from a closed app); the only Snooze
  dose_confirmed_screen
  missed_dose_screen             optional reason, or "took it but forgot" → logged late
  analytics_screen               history and adherence
  notifications_screen           reads the notifications collection
  patient_profile_screen         includes "Delete my account"
  edit_profile_screen            saves to users + patient_profile
  change_password_screen
  settings_screen                device-local prefs via PreferencesService

CARE PARTNER (15)
  caregiver_main_screen          bottom nav wrapper
  caregiver_welcome_screen
  caregiver_dashboard_screen
  my_patients_screen             includes Restore for a deleted patient
  add_patient_screen             Worker POST /patients
  setup_medications_screen       authors to the patient's uid
  generate_otp_screen            48-hour countdown, Copy
  patient_detail_screen          includes "Mark treatment complete"
  patient_schedule_screen        real day strip + materialised doses
  patient_history_screen         real dose_logs, grouped by day
  archived_medicines_screen      archived medicines, restore
  caregiver_alerts_screen        reads the notifications collection
  reports_screen                 live adherence from dose logs
  patient_box_screen             pair a box, assign compartments per medicine
  caregiver_settings_screen      profile, alert switches, password, delete account
```

---

## No phantom features

This build has **6 LEDs, a push button, a buzzer, a DS3231 RTC, a microSD
card, and a DFPlayer Mini with one speaker for recorded voice prompts**. It
has no heart-rate sensor, no pulse oximeter, no battery monitoring, no pill
detection, no microphone or speech recognition, no smartwatch and no SMS
gateway. The voice only plays fixed English MP3 clips; it cannot say anything
that is not on its card. The app is English only and has no report export.

Box parts: ESP32; 6 LEDs with 220 Ω resistors; active buzzer (rated 12 V DC,
works 3–24 V, switched by an NPN); DS3231 with CR2032; microSD module (5 V);
DFPlayer Mini (MP3-TF-16P) with its own microSD; speaker 8 Ω, 0.5 W, 36 mm;
6 mm NC push button; 3.7 V 3000 mAh 18650 cell with a 134N3P charge/boost
board (5 V to VIN).

Earlier screens displayed `HR 78 bpm`, `SpO2 98%`, `Battery 84%`,
`WearOS · Connected` and an "SMS fallback" toggle. All of it was traced from
mockups, and all of it is now removed. **Do not reintroduce a reading the
hardware cannot produce** — a panelist who sees "SpO2 98%" will ask which sensor
produced it.

---

## Coding standards (follow every time)

```
1. Clean architecture always:
   /screens  /widgets  /models  /services  /providers  (+ /utils, /config)

2. NEVER call Firebase directly from UI widgets.
   All Firebase calls go inside lib/services/ (auth_service, firestore_service,
   notification_service, device_service, ...). api_service.dart is the ONLY
   place that calls the Worker.

3. Use StreamBuilder for real-time Firestore data
   Use FutureBuilder for one-time data fetches

4. Handle all errors with SnackBar messages
   Use snackbar_helper.dart

5. Every screen file uses snake_case naming
   e.g. patient_dashboard_screen.dart

6. Support Android 7.0 (API 24) and above (flutter.minSdkVersion)

7. Use Plus Jakarta Sans everywhere — fontFamily: 'PlusJakartaSans'

8. State management: Provider
   Import providers from /providers folder

9. AppColors class for all colors — never hardcode hex in screens
   AppStyles class for reusable decorations and input styles

10. Every delete, remove or archive action shows what it takes with it and
    needs an explicit confirm. Account deletes also need an "I understand"
    checkbox, and the password for a care partner
    (lib/widgets/caregiver/delete_patient_dialog.dart).
```

## When I send you a Figma screenshot

Tell me the file to create or change, give complete code that follows the
standards above, and say what to run and what I should see on screen.

---

## Tests

```
flutter test        6 files in test/:
  dose_timing_test (26), input_rules_test (19), box_sync_test (12),
  box_watch_test (7)                                   → all pass
  auth_flow_test (1), widget_test (1)                  → FAIL (Nov 6 run):
    stale whole-app smoke tests (no Firebase in the test; widget_test is
    Flutter's counter template). See "Open items".
Firmware bench sketches: firmware/healthsync_box/hw_test, rtc_test, sd_test,
dfplayer_test.
```

---

## Firebase project

```
Project ID:     healthsyncapp-b546b   (PROD; dev is healthsyncapp-dev, see "Environments")
Package:        com.healthsyncteam.app
Plan:           Spark (free) — do NOT upgrade to Blaze
Auth:           Email/Password + Custom Token (for managed patients)
Firestore:      asia-southeast1 (Singapore); rules in firestore.rules; no backups
FCM:            Enabled — sent only from the Cloudflare Worker, never from the app,
                and only to care partners
Flutter config: lib/firebase_options.dart (prod), lib/firebase_options_dev.dart (dev)
The google-services.json files and firebase_options*.dart are public in the
repo by design (client config); the data is protected by firestore.rules.
```

## Environments: dev and prod share nothing (Oct 27, 2026)

```
              dev (testing, the default)          prod (the hosted APK)
App flavor    --flavor dev                        --flavor prod
Package       com.healthsyncteam.app.dev          com.healthsyncteam.app
App name      HealthSync Dev (DEV corner banner)  HealthSync
Firebase      healthsyncapp-dev                   healthsyncapp-b546b
Worker        healthsync-api-dev                  healthsync-api
Config        android/app/src/dev/,               android/app/src/prod/,
              lib/firebase_options_dev.dart       lib/firebase_options.dart

Run:      flutter run --flavor dev     (VS Code: "HealthSync (dev)")
Release:  flutter build apk --release --flavor prod --split-per-abi
          → build/app/outputs/flutter-apk/app-arm64-v8a-prod-release.apk
            (plus armeabi-v7a for 32-bit phones)
Firebase: firebase deploy --only firestore                  → dev (default alias)
          firebase deploy --only firestore --project prod   → live
Worker:   npx wrangler deploy                               → dev
          npx wrangler deploy --env prod                    → live

lib/config/environment.dart picks Firebase and the Worker URL from the
flavor (override with --dart-define=API_BASE_URL=...). Anything not built as
dev is prod. The two apps install side by side. The defaults are dev on
purpose: reaching the live app always takes an explicit prod flag.
Old project healthsync-b8394 is unused; never deploy to it.
```

## Live app safety (hosted APK users)

```
Everyone who installed a hosted APK shares ONE live Firebase project
(healthsyncapp-b546b: Auth, Firestore data, rules, indexes, FCM) and ONE
Worker (healthsync-api). A code change reaches users only in a new APK.
A deploy reaches them at once.

  1. Test every change on dev first. Deploy to prod (`--project prod`,
     `--env prod`) only from the release branch, and only together with the
     APK that needs it.
  2. Every rules, index, Worker or data-shape change must keep working for
     every hosted APK still in use (1.0.0+3 onward). Add, never require:
     new fields optional, old writes still allowed. Write the tightening
     down as an open item for after everyone has updated.
  3. Never hand-edit live documents that real users' or UAT accounts use.
     UAT uses dedicated accounts with made-up data.
  4. Every new APK gets a higher build number (1.0.0+4, ...).
  5. Every APK is signed with Miko's release key (android/key.properties +
     the .jks, both git-ignored). A different key means users must uninstall
     to update. Never paste the key or its passwords into a chat or the repo.
  6. Publish the SHA-256 of the exact APK file next to its download link.
```

## Cloudflare Worker (server-side)

```
Why:     Cloud Functions cannot deploy on the Spark plan. The Worker holds the
         Firebase service account key and does what a client cannot: mint
         custom tokens, create Auth accounts, send FCM to another user, and
         run the late (30 min) and missed (60 min) sweep on a cron.

Secrets: FIREBASE_SA_KEY via `wrangler secret put` — NEVER in the repo or the APK
         Upload from Git Bash or cmd with a redirect:
           npx wrangler secret put FIREBASE_SA_KEY < key.json
         NOT `Get-Content key.json | ...` in Windows PowerShell: it prepends a
         byte-order mark, and every Firebase call then failed with "Something
         went wrong" (Oct 2026). parseServiceAccount now strips it anyway.
Cache:   KV namespace TOKEN_CACHE holds the OAuth access token for 55 min
Limits:  free plan = 10ms CPU per invocation, 50 external subrequests, 100k req/day

Endpoints:
  GET  /health
  POST /patients              caregiver creates a managed patient account
  POST /otp/redeem            code in → Firebase custom token out (rate-limited)
  POST /dose-events           dose taken/skipped/missed → caregiver FCM
  POST /account/delete        caregiver deletes their account AND every managed
                              patient (found via patient_profile.caregiver_ref,
                              never via links; needs a sign-in < 5 min old), or
                              a managed patient deletes their own (no approval,
                              no re-auth; care partner notified). Either way:
                              an account_deletions job with purge_after = +30
                              days, then the accounts are PAUSED (is_active
                              false, tokens cleared, schedules off with
                              paused_for_deletion, open doses cancelled).
  POST /patients/delete       caregiver deletes ONE patient. Same pause, same
                              recent-sign-in rule, ownership via patient_profile.
  POST /account/restore       within the 30 days: the caller's own deletion (with
                              its patients), or {patient_uid} for one of theirs.

Crons:
  */5 * * * *    materialise doses (only on the :00 run, or when a schedule's
                 updated_at is < 10 min old), missed sweep, running-late alerts,
                 then a backstop that retries any taken/skipped/missed alert
                 still caregiver_notified=false (missed alerts for up to 6 h).
                 5 alerts per run, shared by all passes (50-subrequest limit).
                 FCM channel: healthsync_alerts
  */15 * * * *   purges account_deletions jobs whose purge_after has passed,
                 re-purging for 65 min (ID-token stragglers); at 19:00 UTC also
                 queues caregivers deleted before this existed

Alert copy: healthsync-api/src/lib/dose-copy.ts (one switch per alert kind).
handlers/device.ts is the old Wi-Fi box API, switched off; the box never
calls the Worker.
```

---

## Capstone paper and UAT

```
Paper audit:  docs/paper-crosscheck/ (start at REPORT.md; also published as a
              shared page). Decisions recorded there (Nov 4–7):
              - the box button confirms doses
              - no limit on patients per care partner or medicines per patient
              - a missed-dose reason is optional; a skip reason is required
              - final deployment is the hosted APK; the Play closed test was
                only an attempt
              - title as in "Project overview"; school year 2026–2027
UAT:          UAT Evaluation Tool v2 (adviser-approved), ISO/IEC 25010:2023:
              Part A app (19), Part B box (reported separately), Part C IT
              experts (25). Adult respondents first; at least 3 IT experts.
IT experts:   docs/uat-it-experts/IT_EXPERT_RESOURCES.md
Website:      Terms and Privacy Policy say users are 18 or older; the app has
              no age check.
```

## Open items (decided, not built yet)

```
- Remove the unused alert_pref_daily field (auth_service.dart, models).
- Fix or remove the two failing tests (widget_test.dart, auth_flow_test.dart).
- Replace the Flutter template README.md with a real project README.
- Create a GitHub Release (with the APK and its SHA-256) and a tag for the
  evaluated build.
- Correction alert for a late box press still says "Their phone was offline"
  (dose-copy.ts); a box press should say it was confirmed on the box.
- Restrict the Firebase API key to the package + signing certificate (REL-03).
- Now that 1.0.0+2 is no longer supported: the devices create rule may
  require id == serial (firestore.rules).
```

---

## Git workflow

```
Remote:  origin (github.com/Mikcvt/healthsync-capstone, public)
Branches (Nov 7, 2026):
  release-without-google-terms   newest app code; the hosted APK 1.0.0+3
  healthsync-docs-help           docs only (paper audit, UAT resources,
                                 this file); merges into the release branch
  dev, fixing-bugs-and-ble       two commits behind the release branch
  feature/medbox-integration     Christian's firmware 0.5.0, not merged
Ask Miko which branch to base new app work on.

Stage specific files (git add <path>), not `git add .`: the generated plugin
files under linux/, macos/ and windows/ change on every build and should not
be committed. Commit messages follow "feat(app): ...", "fix: ...",
"docs: ...". Auth: a GitHub Personal Access Token, not a password.
```

---

*This file is read automatically by Claude Code at the start of every session.*
*Keep it describing the current build; move history to docs/archive/CLAUDE_HISTORY.md.*
