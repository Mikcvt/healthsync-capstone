# HealthSync box: BLE connect-on-demand

> **Status: Transport decided Oct 22, 2026; design details pending confirmation
> by Miko and Christian.**
>
> This file holds the decision, the proposed design, its consequences, the
> open questions with their owners, the dates and the fallbacks. Every older
> description of the box talking to the Cloudflare Worker over Wi-Fi/HTTP is
> marked **SUPERSEDED** where it appears (list at the end) and kept for the
> record.

---

## 1. Decision (final, Oct 22, 2026)

**The medbox communicates with the patient's phone over Bluetooth Low Energy
(BLE), connect-on-demand.**

- There is **no Wi-Fi, no hotspot and no direct box-to-cloud link.**
- This supersedes the earlier plan where the ESP32 talked to the Cloudflare
  Worker over Wi-Fi/HTTP with a per-box device secret.
- **Connect-on-demand** means the app connects, syncs and disconnects. It is
  not a permanent connection.
- **The box stays optional (DEC-8).** The app must work fully with no box.

---

## 2. Proposed design

Every row in this section is **proposed, pending confirmation by Miko and
Christian.** Nothing here is final until both confirm it.

| # | Area | Proposal | Status |
|---|---|---|---|
| P1 | Hardware | The ESP32 (38-pin NodeMCU-32S) has BLE built in, so no hardware change. | Proposed, pending confirmation by Miko and Christian |
| P2 | Roles | The ESP32 is the BLE peripheral (NimBLE-Arduino). The Flutter app is the central (flutter_blue_plus). | Proposed, pending confirmation by Miko and Christian |
| P3 | GATT characteristics | Time, schedule, commands, dose events. | Proposed, pending confirmation by Miko and Christian |
| P4 | Data path | Care partner edits schedule → Firebase/Worker → patient's phone → BLE → box. Only the patient's paired phone talks to the box. | Proposed, pending confirmation by Miko and Christian |
| P5 | Offline alarms | The box alarms offline using the DS3231 RTC and a stored schedule. It does not need the phone to alarm. | Proposed, pending confirmation by Miko and Christian |
| P6 | On each connect | The phone sets the RTC time, pushes schedule changes, and pulls the dose events the box logged since the last sync (timestamped, stored on the microSD), then disconnects. | Proposed, pending confirmation by Miko and Christian |
| P7 | Why on-demand | Android background Bluetooth limits; BLE range of about 10 m; a permanent connection would need a `connectedDevice` foreground service (Play requires a description, user impact, an in-app pairing video and review). The box also uses less battery without Wi-Fi. | Proposed, pending confirmation by Miko and Christian |
| P8 | App changes | Bluetooth permissions (the manifest has no Bluetooth permission today), a pairing flow, a sync service, and a path from box dose events to Firebase. Ask for Bluetooth permission only when the user chooses to pair a box. | Proposed, pending confirmation by Miko and Christian |
| P9 | Server | The Worker has no device endpoints yet, so the device-secret endpoints are **not planned**. | Proposed, pending confirmation by Miko and Christian |
| P10 | Firmware | BLE GATT service, schedule and event storage, RTC time set from the phone. No Wi-Fi code. | Proposed, pending confirmation by Miko and Christian |
| P11 | Enclosure | No change. Battery is one 18650 in a single-cell holder (75 x 21 x 18 mm), which matches the v2.2 base. | Proposed, pending confirmation by Miko and Christian |

### How it fits together (proposed, pending confirmation by Miko and Christian)

```
Care partner app ──► Firebase / Worker ──► Patient's phone ◄──BLE, on demand──► Box
                                              (central)                      (peripheral)
                                                                             DS3231 + microSD:
                                                                             alarms and logs
                                                                             with no phone
```

---

## 3. Consequences to record

1. **Box adherence data is delayed until the phone syncs.** A dose confirmed
   on the box reaches Firebase (and the care partner) only after the patient's
   phone next connects to the box.
2. **A schedule change reaches the box only after the phone and box
   connect.** Until then the box alarms from its stored schedule.
3. **Play reviewers and closed testers cannot test the box,** so the Play
   build is judged as app-only.

---

## 4. Open questions

Recorded, not answered. Each has an owner.

### Miko (app/backend)

| # | Question | Status |
|---|---|---|
| M1 | Is pairing and sync on the patient's phone only? | **Decided Oct 27 (Miko): yes, the patient's phone only.** The care partner still assigns compartments and sees box doses through Firebase |
| M2 | When does the app connect? Suggested: on app open, on schedule change, on a manual Sync button. | **Decided Oct 27 (Miko): on app open, right after Done or Skip in the app (sends `app_done` so the box stops beeping), and on a manual Sync button.** No background service |
| M3 | How do box dose events reach Firestore, and how does the Worker's missed-dose sweep treat a dose the box logged but has not synced? A late sync could cause a false missed-dose alert. | **Decided Oct 27 (Miko): the phone writes each event under `{sid}_{date}_{time}`: `taken` → status taken, `confirmed_via: "button"`, `taken_at` and `logged_at` = the press time, the box's `timing`, one pill off. A late sync after the sweep marked it missed is allowed by the existing rule (`logged_at < missed_at`) and the care partner gets the existing correction notice. No Worker or rules change. A box `missed` never overwrites a final status from the app** |
| M4 | Which schedule wins if it changes while the box is offline? Suggested: the phone, with a version number. | **Decided Oct 27: the phone.** `sched_ver` = the newest `schedules.updated_at`; the phone resends when it differs |
| M7 | How is a box paired in the app? | **Decided Oct 27 (Miko): scan for nearby `HealthSync-…` boxes, type the 6-digit label code once (Android's own dialog), and read the serial from `hello`.** Replaces typing the serial |
| M5 | Android 12+ and older Bluetooth permission flow. Does it affect the Play listing, Data safety form, or privacy policy? Check before the production application. | Open |
| M6 | One box per patient, up to 3 patients per care partner. | Open |

### Christian (hardware/firmware)

| # | Question | Status |
|---|---|---|
| C1 | Can NimBLE run with the RTC and microSD log reliably? | Open |
| C2 | Low-power wake: does the DS3231 SQW/INT output need to be wired to a wake-capable ESP32 pin? The v2.3 wiring guide does not include it. The pin map in the separate v2.3 wiring guide is not yet reconciled with the repo firmware's pin map; Christian must confirm the wake pin against the firmware. | Open |
| C3 | Security: how does the box refuse writes from other phones (bonding with a passkey, or an app-level secret)? Undecided; it replaces the old device secret. | Open |
| C4 | Sequence IDs on dose events so repeated syncs never create duplicates. | Open |
| C5 | How is "dose taken" recorded? The pin map in the separate v2.3 wiring guide is not yet reconciled with the repo firmware's pin map; Christian must confirm the dose-taken button pin against the firmware. | Open |
| C6 | 18650 holder inner cell length (assumed about 70 mm) needs measuring. | Open |
| C7 | 134N3P pad positions, 5 V output and short-circuit behavior are assumed, not measured; it has no reverse-polarity protection. | Open |
| C8 | The wiring guide covers v2.3 only and assumes battery terminals; a v2.2 guide for the 18650 holder is still to be written. | Open |

---

## 5. Dates

| Date | Milestone |
|---|---|
| Oct 22 | Decision and confirmation |
| Oct 23-30 | Pilot (separate from UAT) |
| about Oct 27 | BLE stability checkpoint |
| about Oct 28 | Play closed-test Day 14 |
| about Oct 29 | Production application |
| Oct 30 | Feature freeze, hardware test, UAT approval package submitted |
| Nov 2 | Adviser signatures |
| Nov 3-6 | Survey |
| Nov 7 | Tally |
| Nov 10 | READY BY at the latest |
| Nov 12-14 | Defense (Nov 13 most likely, unconfirmed) |

### Open timeline issues

| # | Issue | Status |
|---|---|---|
| T-a | A BLE update shipped after the Oct 30 freeze needs a team decision on a freeze exception. | Open |
| T-b | It is unconfirmed whether a new build resets the 12-tester, 14-day closed-test clock. | Open |
| T-c | Fallback if BLE is not stable by about Oct 27: ship the app without BLE and add it as a production update before Nov 10, if the freeze exception is allowed. | Open |
| T-d | A hosted APK is the fallback deployment evidence. | Open |

---

## 6. Fallbacks

| If | Then |
|---|---|
| BLE is not stable by about Oct 27 | Ship the app without BLE; add BLE as a production update before Nov 10, if the freeze exception is allowed (T-a, T-c) |
| The Play deployment cannot be shown | A hosted APK is the fallback deployment evidence (T-d) |
| No working box by the UAT window | Hardware UAT becomes a demo recording plus pilot notes |

---

## 7. Tasks

Tracked in [ACTION_PLAN.md](ACTION_PLAN.md), Step 7. All are **Not started /
pending confirmation.**

| Owner | Tasks |
|---|---|
| Miko | Pairing, sync, permissions, Firebase event path, missed-dose rule |
| Christian | BLE firmware, storage, wake decision, security choice, holder measurement, v2.2 wiring guide |
| Project Lead | Track the Oct 27 checkpoint and the freeze-exception decision |
| Documentation | Update the architecture figure and Chapters 1-3 text |
| Testing | BLE on several real Android phones, and app-works-without-box |

---

## 8. What this supersedes

The Wi-Fi/Worker device link described in these places is kept as written and
marked **SUPERSEDED by the Oct 22, 2026 BLE decision**:

- `firmware/healthsync_box/WORK_NOTES.md`: §0, §2, §4 (phases), §5
  decisions 5 and 9, §6, §7 (Phase 1 via the Worker), §8 (open items), §9,
  §10, §11 (Wi-Fi setup hotspot)
- `firmware/healthsync_box/FIRMWARE_ARCHITECTURE.md`: whole file (Worker
  polling, Phases 1–5 as written, Wi-Fi setup, device key)
- `firmware/healthsync_box/HARDWARE_ASSESSMENT.md`: Wi-Fi role of the ESP32,
  Wi-Fi setup hold, Worker-based scenarios, `net.cpp`
- `HARDWARE_ARCHITECTURE.md`: Steps 0, 2, 6 (NTP), 7, 8, 9, 10, 12
- `CLAUDE.md`: "Hardware … via HTTP REST API", "ESP32 polls `led_active`",
  "Medicine box integration" (Firestore REST link), the two `/device/…`
  Worker endpoints
- `DEVELOPMENT_WORKFLOW.md`: Phase 7 (ESP32 through the Worker, device secret)
- `MEDICATION_DATA_MAP.md`: box polling in the sequence diagram, the
  heartbeat note on `devices.last_sync` in §7, the ESP32 column in §9, the
  `/device/…` row in §11, items 3 and 4 in §12
- `ACTION_PLAN.md`: tasks built on the Wi-Fi/Worker link (1.5, 2.2, 2.3, 2.5,
  2.6, 2.7, 3.2, 4.5 and parts of 1.4 and 6.1)
- `HARDWARE_ARCHITECTURE.local.md`: an untracked older copy of
  `HARDWARE_ARCHITECTURE.md`, banner only

---

## 9. Conflicts found in the repo (not resolved here)

These were found while recording the decision. The decision text above is kept
exactly as agreed; the repo text is left as it is. Each needs an answer from
its owner.

| # | This decision says | The repo says | Where |
|---|---|---|---|
| X1 | The box stays optional (**DEC-8**) | No decision log or `DEC-` numbering exists in the repo. "The box is optional" is in CLAUDE.md, "The box is optional (phone-only mode)". WORK_NOTES §5 decision **#8** is about the test Wi-Fi password, not the optional box | CLAUDE.md; WORK_NOTES §5 |
| X2 | The Worker has no device endpoints yet | True for the deployed Worker and for `release`/`dev`. On `feature/medbox-integration`, `GET /device/{serial}/state` is written and **routed** in `healthsync-api/src/index.ts` (not deployed); `/schedule` and `/dose` exist in `device.ts` but are not routed | `healthsync-api/src/handlers/device.ts`, `index.ts` |
| X3 | The manifest has only `SCHEDULE_EXACT_ALARM` | The manifest also declares `INTERNET`, `ACCESS_NETWORK_STATE`, `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`. It has **no Bluetooth permission**, which is the point that matters | `android/app/src/main/AndroidManifest.xml` |
| X4 | ESP32 is a 38-pin NodeMCU-32S | Docs say "ESP32 DevKit V1 (ESP32-WROOM-32, 30 or 38 pin)"; firmware is built as "ESP32 Dev Module". The NodeMCU-32S is also WROOM-32 based, so this may be naming only | HARDWARE_ARCHITECTURE Step 1; HARDWARE_ASSESSMENT 1.1 |
| X5 | GPIO 13 is spare (C2) | GPIO 13 drives **LED compartment 1** | `config.h`; HARDWARE_ARCHITECTURE Step 3; WORK_NOTES §3 |
| X6 | Button: Oct 20 handoff says 6 mm NC button on GPIO 5, firmware must invert; Oct 13 note says none (C5) | WORK_NOTES (Oct 20) and the docs: 12 mm tactile button, **GPIO 16 → GND**, internal pull-up, pressed = LOW. The Oct 13 draft had a button on GPIO 5 with a pull-down. The "Oct 20 handoff" and "Oct 13 note" are not in the repo | WORK_NOTES §3, §11.5; HARDWARE_ARCHITECTURE Step 4.2; CLAUDE.md pin list |
| X7 | Battery: one 18650 in a single-cell holder; 134N3P module; v2.2 base; v2.3 wiring guide | "There is **no battery in this build**", 5 V 2 A USB adapter. No 18650, 134N3P, enclosure v2.2 or wiring guide v2.3 exists in the repo | HARDWARE_ARCHITECTURE Steps 1, 4.6, 5 |
| X8 | Dates: READY BY Nov 10 at the latest; Day 14 about Oct 28; production application about Oct 29 | CLAUDE.md: deadline **Nov 30, 2026**. RELEASE_TODO: target **Nov 1**, Plan B "Oct 27: 14 days complete → apply for production access". Release Build Brief: "Release target is Nov 1 and READY BY is Fri Nov 6" | CLAUDE.md; RELEASE_TODO §0; HealthSync_Release_Build_Brief.md |
| X9 | Up to 3 patients per care partner (M6) | CLAUDE.md: "Can monitor multiple patients". No limit in the app code | CLAUDE.md "Two user types" |
| X11 | App changes: Bluetooth permissions, pairing flow, sync service, box events to Firebase (P8) | WORK_NOTES ground rule: "never anything that may affect the app. **The app is final.**" §2: "Bluetooth setup from the app was rejected: it needs app changes." The decision reverses both | WORK_NOTES §1, §2 |
| X12 | The box alarms offline from the DS3231 and a stored schedule (P5) | CLAUDE.md: "the box is a display … **The ESP32 never decides a dose is due.**" HARDWARE_ARCHITECTURE Step 0: the box does not decide a dose is due "except when offline" | CLAUDE.md "Rule-based notification logic"; HARDWARE_ARCHITECTURE Step 0 |
| X10 | No Wi-Fi code | The firmware on this branch has Wi-Fi + WiFiManager (Phases 1 and 3), and a local `secrets.h` holds the setup hotspot password. Code was not changed by this doc update | `firmware/healthsync_box/net.cpp`, `secrets.h` |

---

## 10a. App side built (Oct 27, 2026, branch `fixing-bugs-and-ble`)

Built to M1–M4 and M7 above and to `firmware/healthsync_box/BLE_PROTOCOL.md`
(firmware 0.4.1). **Not yet tested with a real box.**

| Part | File |
|---|---|
| Bluetooth package `flutter_blue_plus` 1.34.5 (2.x clashes with `connectivity_plus` over a Linux-only dependency) | `pubspec.yaml` |
| Permissions: BLUETOOTH_SCAN (neverForLocation), BLUETOOTH_CONNECT; BLUETOOTH, BLUETOOTH_ADMIN, ACCESS_FINE_LOCATION capped at API 30; `bluetooth_le` not required | `android/app/src/main/AndroidManifest.xml` |
| Link: scan by service UUID, connect at MTU 247, bond, JSON request/reply | `lib/services/box_link_service.dart` |
| Messages (hello, sched_item, event) | `lib/models/box_messages.dart` |
| Schedule sent to the box and its version (`hs1-` + FNV-1a of what is sent; `updated_at` is not stamped when a compartment moves) | `lib/utils/box_schedule.dart` |
| Pairing, sync, triggers (app open/resume at most every 2 min, after Done/Skip once Undo closes, Sync button) | `lib/providers/box_provider.dart` |
| Button presses → dose logs (`confirmed_via: "button"`, one pill off); box `missed` is left to the Worker | `PatientProvider.recordBoxPress` |
| Screens: scan-and-tap pairing; Box tab status + Sync / Pair this phone | `device_pairing_screen.dart`, `medicine_box_status_screen.dart` |
| Unit tests (schedule, version, events, ids) | `test/box_sync_test.dart` |

No rules, index or Worker change: a late box press passes the existing
`logged_at < missed_at` rule. The care partner's correction notice still says
"Their phone was offline"; box-specific wording would be a Worker change.
The care partner's Smart box screen still adds a box by serial; the patient
then pairs their phone from the Box tab ("Pair this phone").

### How to test with the box (dev app only)

1. Flash firmware 0.4.1 with Christian's `secrets.h` (serial + 6-digit code).
2. Install `app-dev-debug.apk`, sign in as a dev patient whose care partner
   put a medicine in a compartment.
3. Box: hold the button 5 s until the lights run. App: Box tab → Pair a box →
   Search → tap the box → type the code in Android's dialog (within 30 s).
4. Expect: "Medicine box paired.", the serial on the Box tab, and on the box's
   serial console `Schedule replaced by the phone`.
5. At a dose time press the box button, then tap Sync with box: the dose shows
   taken (via the box button) and the care partner gets the push.
6. Tap Done in the app while the box beeps: within about 10 s (after the Undo
   toast) the box goes quiet.
7. Re-open the app: it syncs quietly (built-in LED on GPIO 2 lights while
   connected).
8. Failure paths: Bluetooth off, box switched off ("Box not found"), wrong
   code ("Pairing did not finish"), and "Forget the box on this phone" then
   Sync ("Pair this phone").

## 10. Docs changed for this decision (Oct 22, 2026)

| File | Change |
|---|---|
| `BLE_CONNECT_ON_DEMAND.md` | **New.** This file |
| `ACTION_PLAN.md` | New Step 7 with BLE tasks and owners (all "Not started / pending confirmation"); Wi-Fi/Worker tasks marked SUPERSEDED |
| `RELEASE_TODO.md` | New section 10 of open items: Bluetooth permission, Data safety/privacy check, freeze exception, closed-test clock, BLE fallback, hosted APK fallback, app-only review; date conflict noted |
| `HealthSync_Release_Build_Brief.md` | Open item under "Manifest and permissions": Bluetooth permission, Data safety/privacy check, freeze exception |
| `firmware/healthsync_box/WORK_NOTES.md` | Decision entry added to §5 (number to be assigned); Wi-Fi/Worker sections marked SUPERSEDED |
| `firmware/healthsync_box/FIRMWARE_ARCHITECTURE.md` | Marked SUPERSEDED (whole file and the Worker/Wi-Fi sections) |
| `firmware/healthsync_box/HARDWARE_ASSESSMENT.md` | Wi-Fi and Worker passages marked SUPERSEDED |
| `HARDWARE_ARCHITECTURE.md` | Banner, plus Steps 0, 2, 6, 7, 8, 9, 10, 12 marked SUPERSEDED |
| `CLAUDE.md` | One-line pointer to this decision under "What this system does"; old box link (tech stack row, `led_active` polling, "the ESP32 never decides a dose is due", Medicine box integration, `/device/…` endpoints) marked SUPERSEDED |
| `DEVELOPMENT_WORKFLOW.md` | Phase 7 marked SUPERSEDED |
| `MEDICATION_DATA_MAP.md` | Box polling, ESP32 sync column and `/device/…` items marked SUPERSEDED |
| `HARDWARE_ARCHITECTURE.local.md` | SUPERSEDED banner (untracked older copy) |
