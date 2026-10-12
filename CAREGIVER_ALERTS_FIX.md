# Caregiver alerts fix: procedure

**Date:** October 9, 2026 · **Branch:** `dev`

## The problem

The patient app showed every notification. The caregiver (care partner) app
missed some of them. Some alerts never reached the Alerts tab, and some pushes
arrived silently or on the wrong phone.

The two sides receive alerts in different ways, which is why only the caregiver
was affected:

| | Patient | Caregiver |
|---|---|---|
| Dose reminders | Scheduled **on the phone** (`DoseReminderScheduler`) | — |
| Low stock | Written **by the app** for itself | Sent by the **Worker** |
| Taken / skipped / late / missed / correction | — | Sent by the **Worker** only |

The patient's notifications are created locally and don't depend on the
network, so they always appeared. Every caregiver alert goes through the
Cloudflare Worker (`/dose-events` or the 5-minute cron sweep) and then FCM. That
path had the gaps listed below.

---

## Root causes

| # | Where | What was wrong | Effect on the caregiver |
|---|---|---|---|
| 1 | `sweep.ts` missed pass | A dose was marked `missed`, then only the first 8 got an alert. If an alert failed (FCM error, subrequest limit) or didn't fit in the 8, nothing retried it. The next run only queries `pending` and `snoozed`. | Missed-dose alerts **lost permanently** |
| 2 | `sweep.ts` + `dose-events.ts` | Each alert made 6+ uncached reads. The three passes allowed up to 24 alerts in one run, far past the free plan's **50 subrequests**. When a run went over the limit, every alert after that point threw an error. | Alerts dropped on busy runs, then hit #1 |
| 3 | `sweep.ts` backstop | The backstop only retried **skips**. When a **Done** report was lost (app killed or offline during the 5-second Undo window), nothing retried it. | "Dose taken" alert never arrived, and neither did its **low-stock** alert |
| 4 | `fcm.ts` | The Worker pushed on channel `healthsync_doses`, but the app never created that channel. The caregiver's phone never schedules reminders, so it had no app channel at all. | Pushes went to Android's silent fallback channel: no pop-up, easy to miss |
| 5 | `notification_service.dart` | No `onTokenRefresh` listener. | After FCM rotated the token, every push went to a dead token |
| 6 | `auth_provider.dart` sign-out | The token was never cleared on sign-out. On a phone used for both test accounts, the caregiver and patient `users` docs held the **same** token. | Caregiver alerts went to the patient's phone |
| 7 | `sweep.ts` wording | Cron alerts said "has not taken **their medication**". | The alert didn't say which medicine |
| 8 | Alerts tab | Alert docs had no `patient_ref` or `dose_log_ref`. Tapping an alert only marked it read. | With two patients, the caregiver couldn't open the right one |

---

## What changed

### Cloudflare Worker (`healthsync-api/`)

- **`src/lib/read-cache.ts`** (new): caches document reads for one request or
  cron run. The patient profile, users, preferences, schedule and medicine are
  each read once per run instead of once per alert.
- **`src/handlers/dose-events.ts`**
  - `notifyCaregiver()` now returns `'delivered' | 'suppressed'` and throws on
    failure, so the sweep can separate "nobody to tell" from "retry later".
  - New `medicationNameFor()` follows dose log → schedule →
    `patient_medications.medication_name`.
  - Alert docs now include `patient_ref`, `dose_log_ref` and `read_at: null`.
  - The push payload now includes `dose_log_ref`.
- **`src/handlers/sweep.ts`**
  - One **shared budget of 5 alerts per run** across all passes. Doses that
    don't fit are handled on the next run, 5 minutes later.
  - Pass order: **missed → running late → backstop**.
  - The **backstop** now retries every alert that didn't land:
    - `taken` / `skipped` / `missed` doses the app reported, where
      `caregiver_notified` is still false 2–30 min after `logged_at`. This
      also re-runs the low-stock check for `taken`.
    - doses the sweep marked `missed` whose alert failed, retried for up to
      6 hours after the dose time.
  - The backstop has its own `try/catch`. If its indexes aren't built yet,
    the late and missed passes still run.
- **`src/lib/fcm.ts`**: the push channel is now `healthsync_alerts`.
- **`src/index.ts`**: updated the cron log line.

### Firestore

- **`firestore.indexes.json`**: two new `dose_logs` composite indexes for the
  backstop:
  - `caregiver_notified` + `logged_at`
  - `status` + `caregiver_notified` + `scheduled_at`

### Flutter app

- **`lib/services/notification_service.dart`**
  - Creates the `healthsync_alerts` ("Care alerts") channel at startup, at
    maximum importance.
  - Pushes received while the app is open are shown on that channel.
  - New `onTokenRefresh` listener saves rotated tokens.
  - New `clearTokenForUser(uid)` deletes `fcm_token` and the device token.
- **`lib/providers/auth_provider.dart`**: `signOut()` clears the token
  **before** signing out, because the rules only let the owner write it.
- **`android/app/src/main/AndroidManifest.xml`**: sets
  `default_notification_channel_id` to `healthsync_alerts`.
- **`lib/models/notification_model.dart`**: new `patientRef` field
  (`patient_ref`).
- **`lib/screens/caregiver/caregiver_alerts_screen.dart`**: tapping an alert
  marks it read and opens that patient's detail screen. A chevron shows which
  alerts can be opened.
- **`lib/providers/patient_provider.dart`**: sends an empty medicine name
  instead of `'their medication'`, so the Worker looks up the real one.

---

## Deployment procedure

Do these steps **in this order**. The Worker's backstop needs the indexes.

### 1. Deploy the Firestore indexes

```powershell
cd C:\Users\cerva\healthsync-capstone
firebase deploy --only firestore:indexes --project healthsync-b8394
```

Index builds take a few minutes. Check that both new `dose_logs` indexes say
**Enabled** in Firebase console → Firestore → Indexes.

### 2. Deploy the Worker

```powershell
cd C:\Users\cerva\healthsync-capstone\healthsync-api
npx tsc --noEmit -p .        # must print nothing
npx wrangler deploy
```

No new secrets are needed. `FIREBASE_SA_KEY` and the `TOKEN_CACHE` KV
namespace stay as they are.

### 3. Rebuild and reinstall the app

```powershell
cd C:\Users\cerva\healthsync-capstone
flutter clean
flutter pub get
flutter run --dart-define=API_BASE_URL=<your Worker URL>
```

Use the same `--dart-define` you normally use. The manifest changed, so do a
full rebuild, not a hot reload.

### 4. Reset push tokens on every test phone

Old tokens may still point at the wrong account (cause #6):

1. On **each** phone, open the app and **Log out**.
2. Log back in with the account that phone is meant for.
3. In Firestore → `users`, check that the caregiver's and the patient's
   `fcm_token` values are **different**.

### 5. Allow notifications on the caregiver phone

Go to Android Settings → Apps → HealthSync → Notifications. Check that
**Care alerts** is on and set to *Alert / Pop on screen*.

---

## Test procedure

Keep the Worker logs open in a second terminal:

```powershell
cd C:\Users\cerva\healthsync-capstone\healthsync-api
npx wrangler tail
```

The cron runs every 5 minutes, so an alert can take up to 5 minutes after its
threshold to appear.

| # | Do this on the patient phone | Expect on the caregiver phone |
|---|---|---|
| T1 | Tap **Done** on a due dose. Let the Undo toast close. | Within seconds: push *"Dose taken"* naming the medicine, plus a new row in Alerts |
| T2 | Tap **Done**, then close the app from recents within 5 seconds | Within 2–7 min: *"Dose taken"*. Log shows `dropped alert(s) re-sent by the backstop` |
| T3 | Tap **Skip** and pick a reason | *"Dose skipped — <reason>"* |
| T4 | Leave a dose untouched for 30 min | *"Running late"* naming the medicine |
| T5 | Leave it untouched for 60 min | *"Missed dose"* naming the medicine |
| T6 | Tap **Snooze** three times (10 min apart), then once more | *"Missed dose"* |
| T7 | Missed dose → *"I took it but forgot to log it"* | *"Dose update … (logged later)"* |
| T8 | Take doses until pills reach the low-stock threshold | *"Low medicine stock"*, and *"Out of stock"* at 0 |
| T9 | Caregiver phone **in the app** when any alert arrives | Pop-up still appears, and the Alerts badge goes up |
| T10 | Caregiver taps an alert | Alert is marked read and that patient's detail screen opens |
| T11 | Caregiver turns off *Missed dose alerts* in settings, then repeat T3 | **No** alert (by design) |
| T12 | Log out of the caregiver account | `fcm_token` is removed from that `users` doc |

To check each alert in Firestore (`notifications` collection), confirm that
`user_ref` is the caregiver's uid, `patient_ref` is set, and
`is_active: true`. The matching `dose_logs` doc should have
`caregiver_notified: true`.

---

## Troubleshooting

| Symptom | Check |
|---|---|
| Row appears in Alerts but no push | `users/{caregiver}.fcm_token` is missing, or the notification's `channel` is `in_app`. Log out and back in on the caregiver phone. |
| Push arrives but no pop-up | The phone's **Care alerts** channel is muted, or the app was installed before this fix and not rebuilt (step 3). |
| Log shows `Alert backstop failed: … FAILED_PRECONDITION … index` | The indexes from step 1 aren't built yet. Wait, or open the link in the error. |
| Log shows `Too many subrequests` | Too many patients alerting in one run. Lower `MAX_ALERTS_PER_RUN` in `sweep.ts`. |
| Patient phone gets caregiver alerts | Both accounts share a token. Redo step 4. |
| Alert says "their medication" | The schedule's `pat_med_ref` or the medicine's `medication_name` is empty in Firestore. |

---

## Known limits

- **Alerts created before this fix** have no `patient_ref`. Tapping them only
  marks them read.
- After the Worker is deployed, the first sweep may send alerts for missed
  doses from the **last 6 hours** that were never alerted. This happens once
  and is expected.
- If a caregiver turned an alert type off, or a patient has no linked
  caregiver, the backstop checks those doses again each run until their
  window closes (30 min or 6 h). The reads are cached, so this costs one or
  two reads per patient per run.
- The "Running late" alert is still sent at most once per dose, even if it
  fails. The missed alert at 60 minutes is the one that is guaranteed.
