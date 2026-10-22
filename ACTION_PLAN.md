# HealthSync: action plan, steps 1–6

> Written October 20, 2026 on branch `feature/medbox-integration`, from a full
> read of the app (`lib/`), the Worker (`healthsync-api/`), the firmware
> (`firmware/healthsync_box/`) and the status docs (`RELEASE_TODO.md`,
> `firmware/healthsync_box/WORK_NOTES.md`, `QA_FINDINGS.md`).
>
> **How to use this file:** tick **Approved** on each task you want Claude to do.
> Claude does only the ticked ones, one step at a time, and stops at every
> 🔒 gate to ask again. Tasks marked 👤 need a person (hardware, keys,
> Play Console) and Claude only prepares them.

---

> **Oct 22, 2026: the box transport changed.** The medbox now talks to the
> patient's phone over **BLE, connect-on-demand**: no Wi-Fi, no hotspot, no
> direct box-to-cloud link, no device secret. See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). Tasks below that were
> built on the Wi-Fi/Worker link (1.5, 2.2, 2.3, 2.5, 2.6, 2.7, 3.2, 4.5, and
> parts of 1.4 and 6.1) are marked **SUPERSEDED** and kept for the record.
> The new tasks are in **Step 7**.

---

## Ground rules Claude follows

1. **Nothing is committed, pushed, merged or deployed** without a separate,
   explicit OK at that moment, even if the task is approved here.
2. **No `wrangler deploy`.** The live Worker is shared with the app; only the
   lead software developer deploys (WORK_NOTES §6).
3. **The app (`lib/`) is treated as final.** Any task that changes `lib/` is
   marked 🔒 **app change** and needs the lead's OK.
4. **Secrets never enter the repo or the chat.** Claude does not handle the
   Firebase key; a person pastes it into `.dev.vars`.
5. Work stays on `feature/medbox-integration` unless step 4 says otherwise.
6. After each task Claude reports what changed, the check that was run and its
   real output.

**Legend:** 🤖 Claude can do it · 👤 a person must do it · 🔒 asks again before
doing it · ✅ done-when (the check that proves it)

---

## Step 1: Get the project building on this PC

Today nothing in the Flutter app can build, analyze or test on this PC, and the
firmware cannot compile.

### 1.1 Upgrade Flutter 🤖 🔒 (changes the SDK for every project on this PC)

- **Why:** `pubspec.lock` was made with a newer SDK. It needs Flutter ≥ 3.44.0
  and Dart ≥ 3.12.0, and this PC has Flutter 3.41.2. `flutter pub get` fails
  with: *flutter_native_splash 2.4.8 depends on meta ^1.18.0, flutter_test pins
  meta 1.17.0*.
- **Do:** `flutter upgrade` (stable channel), then `flutter --version`.
- **Not doing:** downgrading `flutter_native_splash` in `pubspec.yaml`. That
  would change the lockfile for the whole team to suit one PC.
- ✅ `flutter pub get` succeeds.
- **Approved:** [ ]

### 1.2 Analyze and test the app 🤖

- **Do:** `flutter analyze`, then `flutter test`.
- **Expect:** `test/widget_test.dart` fails (it is Flutter's default counter
  test; fixed in 5.2). Any other failure or analyzer error gets listed and
  brought back to you before anything is fixed.
- ✅ Analyzer and test output reported in full.
- **Approved:** [ ]

### 1.3 Create the firmware's `secrets.h` 🤖 + 👤

- **Why:** `net.cpp` includes `secrets.h`, which is git-ignored and missing,
  so `healthsync_box.ino` cannot compile.
- **Do (Claude):** copy `config.example.h` to `secrets.h` with
  `DEVICE_SERIAL "HS-0001"` and `SETUP_AP_PASSWORD "<see secrets.h>"` (the values
  already recorded in WORK_NOTES §0 and §11).
- **👤 Confirm:** that `HS-0001` is the serial paired in the app.
- ✅ `git status` does **not** list `secrets.h` (still ignored).
- **Approved:** [ ]

### 1.4 Compile the firmware from the command line 🤖

> **SUPERSEDED in part by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). A command-line
> compile is still useful, but WiFiManager is no longer needed; the proposed
> firmware uses NimBLE-Arduino (pending confirmation by Miko and Christian).

- **Why:** lets Claude check every firmware change before Christian uploads it.
- **Do:** use the `arduino-cli` bundled with the installed Arduino IDE, board
  `esp32:esp32:esp32` (ESP32 Dev Module), and report flash use. If the ESP32
  core 3.3.12, ArduinoJson 7.x or WiFiManager 2.0.17 isn't visible to the CLI,
  Claude says so and asks before installing anything.
- ✅ Compiles; flash use about 87% (as recorded on Oct 20).
- **Approved:** [ ]

### 1.5 Put the Firebase key in `healthsync-api/.dev.vars` 👤

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). The key was needed so
> a local Worker could answer the box's `/state` polls; the box no longer
> calls the Worker. Kept for the record.

- **Why:** without it `wrangler dev` cannot reach Firestore. This is the
  blocker for the Phase 1 test.
- **Do (person):** WORK_NOTES §9.1–9.2. Claude does **not** read, write or
  paste the key.
- **Then (Claude):** start `npx wrangler dev --ip 0.0.0.0` and call
  `http://localhost:8787/device/HS-0001/state`.
- ✅ The response is `{"server_time":"…","lit":[],"buzz":false}` (or a real
  `lit` list), not `invalid_grant`, `PEM` or `device_not_found`.
- **Approved:** [ ]

---

## Step 2: Medicine box firmware and Worker

> **SUPERSEDED in part by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). Tasks 2.2 (Wi-Fi
> setup test), 2.3 (Phase 1 via the Worker), 2.5 (button → Worker), 2.6
> (offline via Worker/NTP) and 2.7 (device key) are superseded and kept for
> the record. 2.1 (button wiring) and 2.4 (debug prints) concern the bench
> hardware; how "dose taken" is recorded is now open question C5. The BLE
> firmware tasks are in Step 7.

Work happens in phase order: each phase is finished only when its pass check
works on the real box (WORK_NOTES §1.4).

### 2.1 Fix the button wiring 👤 (Christian)

- Fault: it reads "held" when nobody touches it and "up" when pressed.
- **Do:** WORK_NOTES §11.5, "Rewire, step by step" (diagonal legs, across the
  breadboard gap, the two wires in different strips).
- ✅ 1 minute untouched with no `Button down`; a press prints `Button down`,
  letting go prints `Button up after 0.x s`.

### 2.2 Re-upload the main firmware and finish the Phase 3 test 👤 + 🤖

- **Claude:** compiles `healthsync_box.ino` (1.4) and hands over the upload
  steps.
- **Christian:** uploads, runs WORK_NOTES §11.3 items 1b and 4–9, and sends the
  Serial Monitor output.
- **Claude:** reads the log, decodes any `Backtrace:` with
  `xtensa-esp32-elf-addr2line`, and proposes fixes (🔒 before editing).
- ✅ All 9 items in §11.3 pass. Recorded in WORK_NOTES §11.5.
- **Approved:** [ ]

### 2.3 Phase 1 pass check against real Firestore 👤 + 🤖

- **Needs:** 1.5 done, the box and this PC on the same Wi-Fi, `config.h`
  pointing at this PC's current IP (Claude checks `ipconfig` and updates
  `WORKER_BASE_URL` if it changed).
- **Do:** WORK_NOTES §7.5, items 1–8. Claude watches the `wrangler dev` log and
  Firestore results. Christian does the physical steps.
- ✅ All 8 items in §7.5 pass.
- **Approved:** [ ]

### 2.4 Turn off the button debug prints 🤖

- **Do:** `BUTTON_DEBUG 1` → `0` in `config.h`, after 2.1 passes. Recompile.
- **Approved:** [ ]

### 2.5 Phase 2: the button confirms the dose 🤖 🔒 (Worker change)

**Bugs found in the existing `handleDeviceDose`** (`device.ts:184`), so it is
rewritten, not just routed:

| # | Problem | Effect |
|---|---|---|
| a | Picks the schedule by compartment with limit 1 (`device.ts:211`) | Each dose time is its own schedule, and all of one medicine's dose times share a compartment. It can mark the 8 PM dose when the 8 AM one is due |
| b | "Today" comes from `toISOString()` (`device.ts:225`), which is UTC | A press between 12:00 and 8:00 AM Manila time looks for yesterday's dose |
| c | Only matches `status == 'pending'` (`device.ts:230`) | A snoozed dose cannot be confirmed with the button |
| d | Writes only `status`, `taken_at`, `confirmed_via` | No `timing`, `logged_at`, `synced_at` or `caregiver_notified`. No pill taken off the count, no low-stock alert, no care partner push. The backstop goes by `synced_at`, so it never retries it either |

**Proposed design (for your OK):**

- **Firmware:** a short press while LEDs are lit sends
  `POST /device/{serial}/dose` with `{ "compartments": [<lit, not yet
  silenced>] }`. LEDs and buzzer go off at once on the box (as Phase 1 does
  now). If the POST fails, the box keeps them off and retries on the next
  poll. The offline queue on the SD card comes with Phase 4.
- **Worker:** finds the due doses exactly as `/state` does (status
  pending/snoozed, `scheduled_at` in the last 60 min, this patient, the
  schedule's `mat_box_column` in the posted list). For each due dose it writes
  the same fields the app writes for **Done**:
  - `status: "taken"`
  - `timing` per `lib/utils/dose_timing.dart` (ported to the Worker)
  - `taken_at` and `logged_at` = now
  - `synced_at` = server time
  - `confirmed_via: "button"`
  - `caregiver_notified: false`
  - `stock_counted`
  
  It also takes one pill off `pills_remaining` and turns off `led_active`.
  Then it runs the same care partner push and low-stock logic as
  `POST /dose-events`.
- **Open question:** one press confirms *every* lit compartment (proposed,
  simplest for the patient), or only the first one?
- **Where the Worker code is shared:** Claude reads `dose-events.ts` and the
  app's Done path (`PatientProvider.confirmDoseTaken`) first and reuses them,
  so the button and the app write the same fields.
- ✅ `npx tsc --noEmit` clean. On the bench: press → dose log `taken`,
  `confirmed_via: "button"`, care partner phone gets "Dose taken", and the app
  shows it as taken.
- **Approved:** [ ]  **Answer (one press = all lit?):** ________

### 2.6 Phase 4: offline (DS3231 clock + SD card) 🤖 🔒 (Worker + firmware)

`rtc_clock.cpp`, `storage.cpp` and `schedule.cpp` are one-line stubs today.

- **Fix `handleDeviceSchedule`** (`device.ts:141`): it reads a `dose_times`
  field (`device.ts:159`) that schedules don't have. Each schedule has one
  `scheduled_time` and `days_of_week`, so it always returns no slots. It also
  uses the UTC date (`device.ts:169`). Return the week's schedule
  (compartment, time, days, start/end date) with Manila-time dates.
- **Firmware:**
  - Set the DS3231 from `server_time` on every successful poll.
  - Cache the schedule on the SD card (refreshed every N polls).
  - While offline, light and buzz from the cache by the DS3231 time.
  - Queue button presses on the SD card with the press time.
  - Replay the queue on reconnect, then clear it.
- **Worker:** the dose endpoint accepts a `pressed_at` time for replayed
  presses. A replayed press is accepted only for a dose still pending/snoozed
  or missed after the press (same rule the app uses for offline logs).
- **Arduino IDE:** Partition Scheme → **Huge APP (3MB No OTA/1MB SPIFFS)**
  (flash is at 87%).
- ✅ Router off → a dose still lights by the clock; a press is queued; router
  on → the dose log becomes `taken` with the press time.
- **Approved:** [ ]

### 2.7 Phase 5: device key 🤖 🔒 (Worker + firmware)

- **Why:** any caller who guesses `HS-0001` can read `/state`, and it writes
  the heartbeat.
- **Proposal, no app change:** a random key per box in `secrets.h`, sent as
  `X-Device-Key`. On the first request after pairing the Worker stores a
  **hash** of it in the `devices` doc (trust on first use). After that a wrong
  or missing key gets 401. Re-pairing in the app clears it.
- **Check first:** that `firestore.rules` won't let a client read or change
  that field.
- **Approved:** [ ]

---

## Step 3: Gaps between the app and the box (decisions)

### 3.1 Compartments 7 and 8 🔒 app change, decision needed

- The app offers compartments 1–8 (`add_medicine_step3_screen.dart:26`,
  `patient_box_screen.dart:404`). The box has 6 LEDs. A medicine put in 7 or 8
  never lights, and nobody is warned.
- **Options:**
  - **A.** Limit both pickers to 6 (two loops, `<= 8` → `<= 6`, plus a check
    that existing schedules aren't already on 7–8).
  - **B.** Wire LEDs 7 and 8. Needs two free GPIOs; the pins in the old
    CLAUDE.md are taken by the button and buzzer now.
  - **C.** Keep 8 in the app and show "This box has 6 compartments" on 7–8.
- **Recommended: A.**
- **Choice:** ____  **Approved:** [ ]

### 3.2 A box never shows as offline 🤖 🔒 (Worker change)

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). There is no box
> heartbeat to the Worker. What "online/last seen" means for a BLE box is
> part of the sync design (Miko). Kept for the record.

- The app treats `status == 'online'` as online (`device_model.dart:30`), and
  nothing ever writes `offline`, so an unplugged box shows **Online** forever.
- **Fix, no app change:** in the 5-minute cron, query
  `devices where status == 'online'` and set `status: "offline"` on any whose
  `last_sync` is more than 10 minutes old.
  - Cost: one small query per run. The single-field index is automatic.
  - This counts against the 50-subrequest budget, so it is placed after the
    alert passes.
- ✅ Unplug the box → within about 15 min the app shows it offline; plug it in
  → online again within 60 s.
- **Approved:** [ ]

---

## Step 4: Merge and deploy

### 4.1 Decide the branch flow 👤 decision, 🤖 does it

Found on Oct 20:

- `feature/medbox-integration` = `origin/release` + 2 firmware commits.
- `dev` is **6 commits behind** and lacks the 30-day account deletion work
  (`63a8fbc`, `1b63277`, `f2ac776`, `fdbe0f9`), the splash fix (`bd82304`) and
  the release blockers (`3edb7cf`).

**Proposal:**

1. Fast-forward `dev` to `origin/release`. No conflicts: `dev` has nothing
   `release` lacks.
2. When steps 2.3 and 2.5 pass, open a PR from `feature/medbox-integration`
   into `release`.

- 🔒 Claude asks before every `git push` and before creating the PR.
- **Approved:** [ ]

### 4.2 Check the live Worker before any deploy 🤖 (read-only)

- Deploying this branch ships `/state` **and** the new `account.ts` (30-day
  grace period). WORK_NOTES §6 says nobody knows whether the live Worker
  matches `release`.
- **Do:** `npx wrangler deployments list` and `npx wrangler versions list`
  (read-only). Compare the live version's date with the `release` commits, and
  call `/health` on production.
- ✅ A short note saying "live = `<commit>`" or "unknown".
- **Approved:** [ ]

### 4.3 Deploy 👤 (lead software developer only)

- Claude prepares the exact commands and a checklist (indexes first, then the
  Worker, then `wrangler tail` to watch). Claude does **not** run
  `wrangler deploy`.

### 4.4 Check the indexes and rules are deployed 🤖 (read-only)

- `firestore.indexes.json` gained an index in `fdbe0f9` and the rules changed
  in `f2ac776`.
- **Do:** `firebase firestore:indexes` (read-only) and compare it with the
  file.
- ✅ Every index in the file is listed as deployed.
- **Approved:** [ ]

### 4.5 Point the box at production 🤖 (after 4.3)

> **SUPERSEDED by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). The box has no Worker
> URL. Kept for the record.

- `WORKER_BASE_URL` in `config.h`: `http://192.168.1.11:8787` →
  `https://healthsync-api.healthsync12.workers.dev`. Recompile.
- **Approved:** [ ]

---

## Step 5: Play release

### 5.1 Replace the placeholder description 🤖

- `pubspec.yaml:2` says `description: "A new Flutter project."` →
  `"HealthSync: medicine reminders with care partner alerts and an optional LED smart medicine box."`
- **Approved:** [ ]

### 5.2 Fix the default widget test 🤖

- `test/widget_test.dart` is Flutter's counter test and always fails.
- **Proposal:** delete it. The real tests are `auth_flow_test.dart` and
  `dose_timing_test.dart`, and a smoke test of `main.dart` would need Firebase
  mocks.
- ✅ `flutter test` all green.
- **Approved:** [ ]

### 5.3 Worker subrequest overflow (RELEASE_TODO §3) 🤖 🔒 (Worker change)

- On Oct 9 the cron hit `Too many subrequests` once.
  `CAREGIVER_ALERTS_FIX.md` later added an alert budget, which may already fix
  it.
- **Do:** read `sweep.ts` and `index.ts` and count the worst case. Report
  first; change only if it can still go over 50 (and 3.2 adds a query to it).
- **Approved:** [ ]

### 5.4 Website deletion page 👤 (Mona)

- Update the site per `WEBSITE_DELETION_UPDATE.md` **before** build 1.0.0+2 is
  uploaded (Play compares the two).

### 5.5 Release build and smoke test 👤 (keystore holder)

- `android/key.properties` and the keystore are not on this PC, so only the
  keystore holder can build `app-release.aab`.
- Run smoke tests S1–S17 (RELEASE_TODO §7) on two phones. Claude can turn the
  table into a test sheet if wanted.

### 5.6 Closed test → production 👤 (Play Console owner)

- RELEASE_TODO §8: 12+ testers opted in for 14 days in a row, then apply for
  production access.

---

## Step 6: Documents and cleanup 🤖

### 6.1 Fix CLAUDE.md's hardware section

> **SUPERSEDED in part by the Oct 22, 2026 BLE decision.** See
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). The rows about
> polling `/device/{serial}/state` and the Phase 5 device key no longer
> apply; CLAUDE.md now carries SUPERSEDED markers instead. The pin rows are
> still open, and the button pin is now disputed (BLE_CONNECT_ON_DEMAND.md
> §9, X5 and X6).

| CLAUDE.md says | The real box (WORK_NOTES §3) |
|---|---|
| 8 LEDs, GPIO 13, 14, 25, 26, 27, 32, 33, 4 | **6** LEDs: 13, 14, 25, 26, 32, 33 |
| Push button GPIO 5, 10 kΩ pull-down | GPIO **16** → GND, internal pull-up |
| Buzzer GPIO 18 | GPIO **17** (through an NPN transistor) |
| SD MOSI 23, MISO 19, SCK 15, CS 17 | SCK **18**, MOSI **19**, MISO **23**, CS **15** |
| ESP32 polls `led_active` in `schedules` | Polls `GET /device/{serial}/state`; `lit` comes from `dose_logs` |
| ESP32 uses a service account API key | No key on the box; device key is Phase 5 |
| DS3231 offline scheduling, microSD log | Not built yet (Phase 4) |

Also add the box's Wi-Fi setup hotspot (Phase 3) and the `/state` endpoint to
the Worker endpoint list.

- **Approved:** [ ]

### 6.2 Agree on one deadline 👤 decision

- CLAUDE.md says **Nov 30, 2026**; RELEASE_TODO.md says **Nov 1, 2026**.
  Claude updates whichever is wrong.
- **Correct date:** ________

### 6.3 Archive `bug to fix.md`

- Spot-checked 4 of its 10 items, and all are fixed:
  - #2: "Delete for good" is gone.
  - #5: the box grid uses aspect ratio 0.66.
  - #8: low-stock alerts are wired up.
  - #9: a custom About sheet replaced the license page.
- **Do:** check the other 6, then move it to `docs/archive/` with a line on
  top saying what was verified.
- **Approved:** [ ]

### 6.4 Reconcile `HARDWARE_ARCHITECTURE.local.md`

- Your untracked copy (570 lines), renamed during the checkout, vs. the
  branch's `HARDWARE_ARCHITECTURE.md` (636 lines).
- **Do:** diff them. If the local copy has nothing the branch version lacks,
  delete it; if it does, list what and ask.
- **Approved:** [ ]

### 6.5 Update WORK_NOTES.md §0 at the end of each session

- Keep the status table there current, as the file asks.
- **Approved:** [ ]

---

## Step 7: BLE connect-on-demand (Oct 22, 2026 decision)

The transport is decided; the design is **proposed, pending confirmation by
Miko and Christian** ([BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md)).
Every task below is **Not started / pending confirmation**. Nothing here is
done.

### 7.1 Miko (app/backend)

| # | Task | Related open question | Status |
|---|---|---|---|
| 7.1.1 | Pairing flow in the app (ask for Bluetooth permission only when the user chooses to pair a box) | M1, M6 | Not started / pending confirmation |
| 7.1.2 | Sync service: connect, set the RTC time, push schedule changes, pull dose events, disconnect | M2, M4 | Not started / pending confirmation |
| 7.1.3 | Bluetooth permissions (Android 12+ and older), and the Play listing / Data safety / privacy policy check | M5 | Not started / pending confirmation |
| 7.1.4 | Firebase event path: box dose events → Firestore | M3 | Not started / pending confirmation |
| 7.1.5 | Missed-dose rule for a dose the box logged but has not synced (avoid a false missed-dose alert from a late sync) | M3 | Not started / pending confirmation |

### 7.2 Christian (hardware/firmware)

| # | Task | Related open question | Status |
|---|---|---|---|
| 7.2.1 | BLE firmware: GATT service (time, schedule, commands, dose events), NimBLE-Arduino | C1 | Not started / pending confirmation |
| 7.2.2 | Storage: schedule and dose events on the microSD, with sequence IDs | C1, C4 | Not started / pending confirmation |
| 7.2.3 | Wake decision: DS3231 SQW/INT to a wake-capable pin or not | C2 | Not started / pending confirmation |
| 7.2.4 | Security choice: bonding with a passkey, or an app-level secret | C3 | Not started / pending confirmation |
| 7.2.5 | Measure the 18650 holder's inner cell length | C6 | Not started / pending confirmation |
| 7.2.6 | Write the v2.2 wiring guide for the 18650 holder | C8 | Not started / pending confirmation |

### 7.3 Project Lead

| # | Task | Status |
|---|---|---|
| 7.3.1 | Track the about Oct 27 BLE stability checkpoint | Not started / pending confirmation |
| 7.3.2 | Get a team decision on the freeze exception for a BLE update after the Oct 30 freeze (T-a) | Not started / pending confirmation |

### 7.4 Documentation

| # | Task | Status |
|---|---|---|
| 7.4.1 | Update the architecture figure (box ◄─BLE─► phone, no box-to-cloud link) | Not started / pending confirmation |
| 7.4.2 | Update the Chapters 1-3 text | Not started / pending confirmation |

### 7.5 Testing

| # | Task | Status |
|---|---|---|
| 7.5.1 | BLE on several real Android phones | Not started / pending confirmation |
| 7.5.2 | The app works fully with no box | Not started / pending confirmation |

---

## Suggested order

> **SUPERSEDED in part by the Oct 22, 2026 BLE decision.** The box rows
> below (1.5, 2.2, 2.3, 2.5, 2.6, 2.7, 4.5) follow the old Wi-Fi/Worker link.
> The BLE work follows the dates in
> [BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md) §5.

```
1.1 → 1.2 → 1.3 → 1.4          today, Claude alone (1.1 needs your OK)
1.5                            Firebase teammate, the moment they can
2.1 → 2.2 → 2.4                Christian on the bench, Claude reads the logs
2.3                            once 1.5 and 2.1 are done
3.1 decision, 3.2              while waiting on the bench
2.5 (Phase 2)                  after 2.3 passes
4.1 → 4.2 → 4.4 → 4.3 → 4.5    when Phase 1 + 2 pass
5.x, 6.x                       in parallel, any time
2.6, 2.7 (Phase 4, 5)          after the release build is safe
```
