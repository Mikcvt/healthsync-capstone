# Answers to the open questions (section 6)

> November 3, 2026. Answered from the code on `dev` / `fixing-bugs-and-ble`
> (commit `fff59b0`), the git history and the team's notes. **Not yet tested on
> a phone**: each answer says what the code does. The "How to confirm" lines
> give a quick test to turn each one into evidence.

| # | Question | Short answer |
|---|---|---|
| 1 | Is the website APK built from current dev code with `--flavor prod`, including the Bluetooth box? | **Unknown.** Nothing records how it was built. Only a build from `dev` with `--flavor prod` has the box |
| 2 | Does a box press made while the app was closed show as taken when the app opens, without Sync? | **Yes**, if Bluetooth is on, the box is near, and this phone is paired with it |
| 3 | Are notifications, alarms and nearby devices (or location) the only permissions listed? | **Yes**, for a prod build of the current code |
| 4 | If a press syncs after the dose was marked missed, does the care partner get a correction alert? | **Yes**, but its wording blames the phone being offline |
| 5 | Does the patient's old one-time code fail after the account is deleted? | **Yes** |

---

## 1. The website APK and the Bluetooth box

**Unknown which build is on the website.** Neither the repo nor the team's
notes record how that APK was built. What is certain:

- The `release` branch, which built the Play app (version 1.0.0+2), has **no
  Bluetooth code**: no `flutter_blue_plus` package and no
  `lib/services/box_link_service.dart`.
- The Bluetooth box is only in `dev` / `fixing-bugs-and-ble`. An APK has it
  only if it was built from there with:

  ```
  flutter build apk --release --flavor prod
  ```

  which produces `app-prod-release.apk`. Without `--flavor prod`, the build is
  not the production app.

**How to confirm:** install the website APK and open the **Box** tab. If it
offers **Pair this phone** and **Sync with box**, it has the Bluetooth box.

## 2. A box press while the app was closed

**Yes, under conditions.** When the app is opened, or brought back from the
background, it syncs with the box quietly by itself (`syncOnOpen()` in
`lib/providers/box_provider.dart`). The press is saved as **taken** within a
few seconds, with no Sync tap.

It works only when:

- **Bluetooth is on.** The quiet sync never asks to turn it on.
- **The box is near the phone.**
- **This phone is the one paired with the box.**
- **No sync was attempted in the last 2 minutes.** The automatic sync runs at
  most once every 2 minutes.

Otherwise the patient taps **Sync with box** on the Box tab.

Since the hosted APK 1.0.0+3, the app also syncs every minute while a box dose
is due, even with the app minimized (the background box watch, Nov 3). A small
notification, "HealthSync is watching your medicine box", shows meanwhile.

**How to confirm:** close the app, press the box button during a lit dose,
open the app with Bluetooth on next to the box, and check that the dose turns
**Taken** without tapping Sync.

## 3. Permissions in App info → Permissions

**Yes.** From the merged manifest of the Play build (prod flavor, current code):

| Shown as | Why the app needs it |
|---|---|
| **Notifications** | Dose reminders and alerts |
| **Nearby devices** (Android 12 and newer) | Finding and connecting to the medicine box over Bluetooth |
| **Location** (Android 11 and older only, instead of Nearby devices) | Older Android requires it for a Bluetooth scan. The permission is limited to Android 11 and below and is never used for location |
| **Alarms & reminders** | Reminders at the exact dose time. On most phones this is under **Special app access**, not in the Permissions list |

Everything else (internet, network state, vibrate, start at boot, keep awake,
push messages, and the background box watch's foreground service) is granted
automatically and not shown on that screen. There is **no camera, microphone,
contacts, storage or location permission** on Android 12 and newer.

**How to confirm:** install the prod APK, open App info → Permissions, and take
a screenshot.

## 4. A press synced after the dose was marked missed

**Yes.** When the press syncs:

1. The app saves the dose as **taken**, with the time of the press as
   `logged_at` (`recordBoxPress` in `lib/providers/patient_provider.dart`).
2. The Firestore rules allow changing a missed dose to taken because the press
   happened **before** the Worker marked it missed (`logged_at < missed_at`).
3. The Worker sends the care partner a **correction** alert, not a plain "Dose
   taken" (`healthsync-api/src/lib/dose-copy.ts`).

**Known issue:** the correction text reads *"Update: [name] took [medicine].
Their phone was offline, so it reached HealthSync late."* For a box press this
is not accurate: the phone was not offline, the box simply had not synced yet.
A wording fix in the Worker could say "confirmed on the medicine box" instead.
It is a server change, so it must keep working for the live app (1.0.0+2).

**How to confirm:** press the box button during a dose, keep the phone away
from the box until the dose is marked missed (+60 min), then sync and check
the care partner's phone.

## 5. The old one-time code after the patient's account is deleted

**Yes, it fails.**

- **During the 30 days after deletion:** redeeming a code requires an
  **active** managed patient (`is_active` not false,
  `healthsync-api/src/handlers/otp.ts`). Deletion sets `is_active` to false, so
  the code is refused.
- **After the 30 days:** the purge erases the patient's codes along with the
  account (`healthsync-api/src/handlers/account.ts`).
- **Usually it fails even earlier:** every code works only once and expires 48
  hours after it is generated.
- **After a restore,** the patient needs a **new** code from the care partner.

**How to confirm:** delete a test patient on dev, then enter their old code on
a phone and take a screenshot of the refusal.
