# HealthSync — Dose Logic Proposal (Review and Additions)

A review of the proposed changes to archiving, the dashboard, dose actions,
timing rules and the missed-dose flow. Each requirement is checked against how
the app works today (October 2026), with additions where the proposal leaves a
gap. Section 12 records the six decisions, all made in October 2026.

> **Status: implemented (October 2026)** — see
> [section 14](#14-implementation-status) for where each part lives and the
> two parts that wait for the box hardware.

**Contents**

1. [Verdict at a glance](#1-verdict-at-a-glance)
2. [The status model (fixes "Due Now")](#2-the-status-model-fixes-due-now)
3. [Action buttons: Done, Skip, early logging](#3-action-buttons-done-skip-early-logging)
4. [Undo](#4-undo)
5. [Snooze only on the alarm screen](#5-snooze-only-on-the-alarm-screen)
6. [Dashboard](#6-dashboard)
7. [Missed medication flow](#7-missed-medication-flow)
8. [Archive instead of delete](#8-archive-instead-of-delete)
9. [Data model changes](#9-data-model-changes)
10. [Adherence and reports](#10-adherence-and-reports)
11. [Caregiver side](#11-caregiver-side)
12. [Decisions](#12-decisions)
13. [Build order and test checklist](#13-build-order-and-test-checklist)
14. [Implementation status](#14-implementation-status)

---

## 1. Verdict at a glance

| # | Requirement | Verdict | Why |
|---|---|---|---|
| 1.1 | Remove deleting dose logs | ✅ Keep | Today three code paths still delete dose logs (section 8). All three must change, not just the button |
| 1.2 | Keep Archive | ✅ Keep | Already exists |
| 1.3 | Archive cancels future doses and alarms, keeps history | ✅ Keep, change how | Alarms are already cancelled. Future doses are currently *deleted*; they should be marked `cancelled` instead |
| 2.1 | Today's medications only | ✅ Keep | Mostly the case already; add a start/end date check (6.1) |
| 2.2 | Done / Missed move to the bottom | ✅ Keep, with a collapsed section | Today they disappear entirely. A collapsed "Done today" group keeps the list short and the record visible |
| 2.3 | "View tomorrow" toggle | ✅ Keep, tomorrow only | Show tomorrow, not "future days"; the Schedule tab already covers the week |
| 2.4 | Date and time on cards | ✅ Keep | Use relative words: "Today · 8:00 AM", "Tomorrow · 8:00 AM" |
| 2.5 | Countdown ("Due in 2 hrs" / "15 mins") | ✅ Keep | Exact wording rules in 6.4 |
| 3.1 | Done / Skip unlock 30 min before | ✅ Keep | |
| 3.2 | Locked look with "Actions unlock at [time]" | ✅ Keep | |
| 3.3 | Early logging confirmation | ✅ Keep, add a limit | Without a limit, a patient can log tomorrow's doses tonight. Cap it (3.3) |
| 3.4 | Undo toast | ✅ Keep, hold back the caregiver push | Otherwise the caregiver is told "Dose taken" for a tap that was undone |
| 3.5 | Snooze only on the alarm screen | ⚠️ Needs work first | **There is no alarm screen today.** Tapping a reminder does nothing (section 5) |
| 4.1 | "Due Now" only at the exact time | ✅ Keep | |
| 4.2 | 0–29 min is still on time | ✅ Keep | |
| 4.3 | 30–60 min is "Late" | ✅ Keep | |
| 4.4 | Over 1 hour is "Missed" | ✅ Decided: Option C | Missed at 60 min, with a "running late" caregiver alert at 30 min to keep the paper's 30-minute promise. See 2.3 |
| 5.1 | Missed dose asks for a reason | ⚠️ Needs wiring | The reason screen exists but **nothing opens it** |
| 5.2 | "I took it but forgot to log it" | ✅ Keep, with rules | Needs a time limit, a "when did you take it?" question, and a separate label so reports stay honest (7.3) |
| 5.3 | Change Missed back to Done | ✅ Keep as "Taken – logged late" | Never overwrite silently; keep both what happened and when it was recorded |

**Most valuable additions:**
- A separate **Skipped** status, distinct from Missed (2.4).
- A **Cancelled** status, replacing deletes (8.2).
- A **3-hour cap** on early logging (3.3).
- A **delayed caregiver push** so Undo is real (4.2).
- A **"Done today" collapsed group** (6.2).
- Fixing **restore** so it doesn't silently lose today's doses (8.4).

---

## 2. The status model (fixes "Due Now")

### 2.1 What happens today

| Where | Today's rule |
|---|---|
| Patient dashboard badge | "Upcoming" until 15 min before, "Due now" from −15 to +30 min, "Overdue" after |
| Worker sweep | Marks `missed` at **30 min** after the dose time |
| Snoozed dose | Missed at 30 min after the dose time **and** 10 min after the snooze ends |
| Skip button | Writes status `missed` (same as a real miss) |

The "an hour early" report may come from an older build, which showed "Due now"
for any logged dose regardless of time. The current build is 15 minutes early,
which your rule removes.

### 2.2 Proposed timeline

```
          −30 min           0          +30 min        +60 min
  ────────────┼─────────────┼──────────────┼──────────────┼──────────►
   Upcoming   │  Upcoming   │   Due now    │    Late      │  Missed
   (locked)   │  (unlocked) │  (on time)   │              │
              │             │              │              │
   Done/Skip  │  Done/Skip  │  Done/Skip   │  Done/Skip   │  Add reason
   ask "early"│  allowed    │  allowed     │  allowed     │  (section 7)
```

| Minutes from dose time | Badge | Badge colour | Buttons |
|---|---|---|---|
| before −30 | **Upcoming** · "Due in 2 hrs" | `upcomingBlue` | Locked: tap asks "logging early?" |
| −30 to −1 | **Upcoming** · "Due in 15 mins" | `upcomingBlue` | Unlocked |
| 0 to 29 | **Due now** | `pendingAmber` | Unlocked |
| 30 to 59 | **Late** · "35 mins late" | `missedRed` (outline) | Unlocked |
| 60 or more | **Missed** | `missedRed` (filled) | "Add a reason" |

Buttons unlock 30 minutes **before** the dose, but the badge says "Upcoming"
until the exact time. That is intentional: unlocking early lets someone take a
dose a little before bedtime without a pop-up, while the badge stays truthful.

### 2.3 Missed at 30 or 60 minutes? (decided: Option C)

The capstone spec says "No confirmation after 30 minutes → missed → alert the
caregiver". The proposal moves Missed to 60 minutes. Three options:

| Option | Missed at | Caregiver alerted at | Effect |
|---|---|---|---|
| A. Keep the spec | 30 min | 30 min | No "Late" window. Simplest, matches the paper |
| B. Proposal as written | 60 min | 60 min | Caregiver hears 30 min later than the paper says |
| **C. Chosen** | 60 min | **"Running late" at 30 min**, "Missed" at 60 min | Keeps the paper's 30-minute caregiver alert and gives the patient the hour |

Option C keeps the panel-facing promise ("the caregiver knows within 30
minutes") while giving the patient room. **Option C was chosen.** Update the paper,
CLAUDE.md, the sweep and the badge **together**.

### 2.4 Addition: Skipped is not Missed

Today "Skip dose" writes `missed`, so "I chose not to take it because I felt
sick" looks the same as "I forgot". Proposed final states:

| Status | Meaning | Counts in adherence as |
|---|---|---|
| `taken` | Taken (any timing) | taken |
| `skipped` | Patient decided not to take it, with a reason | not taken (shown separately) |
| `missed` | Nothing recorded within 60 min | not taken |
| `cancelled` | Medicine archived before this dose came due | **excluded** |

### 2.5 Addition: timing is a separate field

"Late" describes **when** a dose was taken, not whether. Store it alongside
`taken` instead of as its own status, so "taken" queries keep working:

| `timing` | When |
|---|---|
| `early` | Confirmed through the early-logging prompt |
| `on_time` | Taken from −30 to +29 min |
| `late` | Taken from +30 to +59 min |
| `logged_late` | Was missed, then corrected with "I took it but forgot to log it" |

---

## 3. Action buttons: Done, Skip, early logging

### 3.1 Locked state

- Buttons are grayed with a 🔒 icon and "Actions unlock at 7:30 AM".
- The locked button stays **tappable**: a tap opens the early-logging prompt
  rather than doing nothing. A dead button reads as broken.

### 3.2 Early-logging prompt

> **Logging early**
> This dose is due at 9:00 PM (in 2 hrs 10 mins). Are you taking it now?
> [Cancel] [Yes, I took it now]

- Store `timing: early` and the real `taken_at`.
- The caregiver push says "Taken early (2 hrs before)".

### 3.3 Addition: limit how early

Without a limit, a patient could clear the whole day, or log tomorrow's doses,
from bed. Proposed rule:

- Early logging is allowed **up to 3 hours** before the dose time, but never
  more than **half the gap to the previous dose of the same medicine**. For a
  medicine taken every 4 hours (8:00, 12:00, 16:00) the 12:00 dose can be
  logged from 10:00, not 9:00, so it can't be logged before the 8:00 dose is
  dealt with. For once- or twice-daily medicines this changes nothing.
- Beyond that the prompt says "Too early to log this dose. You can log it from
  6:00 PM." with no confirm button.
- The 3-hour cap is measured from the dose time, so a 12:30 AM dose can still
  be logged at 11:00 PM the night before (it crosses midnight). "View tomorrow"
  therefore shows Done only on doses inside that window.

### 3.4 Skip

- Skip asks for the reason **first**, using the same list as the missed flow
  (7.2), then writes `skipped` with `skipped_reason`.
- One reason picker for both flows keeps the data comparable.

### 3.5 Box button (when the patient has a box)

The physical button should follow the same window: from −30 min to +59 min it
confirms the dose. Outside it, the press is ignored with a short buzz. Early
logging stays an app-only action, because the prompt needs a screen.

---

## 4. Undo

### 4.1 Behaviour

- After **Done** or **Skip**, show a snackbar for **5 seconds**: "Metformin
  marked as taken. [UNDO]". (Raise to 8 seconds if elderly testers miss it.)
- Undo restores the dose to exactly how it was.

### 4.2 Addition: hold back the caregiver push

Today the app calls the Worker's `/dose-events` the moment a dose is
confirmed, and the Worker pushes "Dose taken" to the caregiver straight away.
With Undo, that would notify for a tap that was reversed. Proposed:

1. Write the dose to Firestore immediately, so a closed app never loses it.
2. Wait until the Undo toast closes, then call `/dose-events`.
3. If Undo is tapped, revert the write and never call the Worker.

If the app is killed during those 5 seconds, the dose is still saved; only the
"Dose taken" push is lost, which is harmless. For **Skip** (which alerts the
caregiver), the sweep should also pick up `skipped` doses with
`caregiver_notified: false` older than 2 minutes, so that alert is never lost.

### 4.3 What Undo must revert

| Done | Skip |
|---|---|
| `status` back to `pending` (or `snoozed`) | `status` back to `pending` (or `snoozed`) |
| `taken_at`, `timing`, `confirmed_via` cleared | `skipped_reason` cleared |
| `pills_remaining` + 1 | — |
| Low-stock notification removed if this dose triggered it | — |
| `led_active` back to `true` if the box is in use and the dose is still due | same |

---

## 5. Snooze only on the alarm screen

### 5.1 The problem

**There is no alarm screen that "pops up" today.** In
`NotificationService.initialize()`, tapping a reminder runs only
`debugPrint('Notification clicked: ...')`. The full-screen dose screen
(`DoseAlertScreen`) is opened **only** from the dashboard row's button, and
that is the only place Snooze exists. Removing Snooze from the dashboard
without building the alarm route would remove Snooze from the app entirely.

### 5.2 What has to be built first

1. **Tap-to-open:** a tapped reminder opens `DoseAlertScreen` for that dose.
   The reminder already carries the schedule id as its payload; the app needs a
   global navigator key to open a screen from outside the widget tree.
2. **Cold start:** if the app was closed, read the launch notification on
   startup and open the same screen once the patient's data has loaded.
3. **Background-run hint for Xiaomi, Oppo and Vivo phones:** a one-time
   screen asking the patient to let HealthSync run in the background, with a
   button to the right setting. These phones' battery savers can stop
   scheduled reminders from firing at all, which matters more than how the
   reminder looks.
4. **Deferred until after Play Store approval:** Android's full-screen alarm
   style (`fullScreenIntent: true`), which shows the reminder over the lock
   screen like an alarm clock. Google Play restricts the
   `USE_FULL_SCREEN_INTENT` permission on Android 14+ (it needs a Play Console
   declaration and the user's consent), and Xiaomi phones block it by default.
   Not needed for the Snooze rule: reminders already fire as exact,
   maximum-importance alarm-category notifications, and step 1 makes tapping
   one open the dose screen.

### 5.3 Then the rule

- The dashboard shows **Done** and **Skip** only. There is no Snooze anywhere
  else.
- `DoseAlertScreen` shows Done, Snooze and Skip.
- Snooze stays available until the dose is Missed (60 min). Three 10-minute
  snoozes fit inside that, and the existing one-at-a-time rule stays.

---

## 6. Dashboard

### 6.1 Today only

Mostly the case: the list is built from today's schedules, filtered by
weekday. It does **not** check `start_date` / `end_date`, so a course that
ended yesterday, or starts next week, still shows today if its weekday matches.
Add that check while rebuilding the list.

### 6.2 Ordering

Today, taken doses and dismissed missed doses **vanish** from the list.
Proposed groups, top to bottom:

```
NEEDS ACTION
  Late       Losartan    · Today 8:00 AM · 40 mins late      [Done] [Skip]
  Due now    Metformin   · Today 8:15 AM · due now           [Done] [Skip]

UPCOMING
  Atorvastatin           · Today 1:00 PM · Due in 4 hrs      🔒 Unlocks 12:30 PM
  Metformin              · Today 8:00 PM · Due in 11 hrs     🔒 Unlocks 7:30 PM

▸ DONE TODAY (3)                       ← collapsed by default
▸ VIEW TOMORROW (4)                    ← collapsed by default
```

- **Needs action** sorts Late before Due now (the oldest first).
- **Upcoming** sorts by time.
- **Done today** holds Taken, Skipped and Missed doses, newest first.
  - A missed dose without a reason shows an **"Add reason"** chip and a count on
    the group header, so it isn't forgotten at the bottom.
  - This replaces today's "✕ dismiss" button on missed doses.

### 6.3 Date and time on every card

| When | Label |
|---|---|
| Today | `Today · 8:00 AM` |
| Tomorrow | `Tomorrow · 8:00 AM` |
| Later (Schedule tab) | `Thu, Oct 10 · 8:00 AM` |

### 6.4 Countdown wording

| Time until due | Text |
|---|---|
| 2 hours or more | `Due in 3 hrs` (whole hours, rounded down) |
| 60 – 119 min | `Due in 1 hr 20 mins` |
| 2 – 59 min | `Due in 15 mins` |
| 0 – 1 min | `Due now` |
| 1 – 29 min after | `Due now · 12 mins ago` |
| 30 – 59 min after | `35 mins late` |

It refreshes every minute; the badge already has a one-minute timer to reuse.
Use singular forms correctly ("1 hr", "1 min").

### 6.5 View tomorrow

- Collapsed by default, with a count: "View tomorrow (4)".
- Read-only, except doses inside the 3-hour early window (3.3).
- Tomorrow only. The Schedule tab already shows the full week.

---

## 7. Missed medication flow

### 7.1 The problem

`MissedDoseScreen` (with a reason list and a save path) exists but **no screen
opens it**. Today a missed dose on the dashboard has only a ✕ button that sets
`acknowledged_at`. Tapping a missed card should open this screen.

### 7.2 Reason list

Current list, plus the new option at the top:

1. **I took it but forgot to log it** ← new
2. Forgot to take
3. Felt sick / side effects
4. Was away from the medicine
   (reworded from "Was away from medicine box", which doesn't fit phone-only
   patients)
5. Prescription ran out
6. Other reason (with a short text field)

### 7.3 Rules for "I took it but forgot to log it"

| Rule | Why |
|---|---|
| Ask **"About what time did you take it?"** (default: the scheduled time) | `taken_at` should be the real time, not the moment of correcting |
| Allowed only **until the end of the next day** | Prevents rewriting old history to raise adherence |
| Set `status: taken`, `timing: logged_late`, `logged_at: now` | Counts as taken, but reports can still show it was self-corrected |
| Decrease `pills_remaining` by 1 | The pill was used |
| Refuse if stock is already 0 | Same guard as normal confirmation |
| Send the caregiver a **correction** notice: "Update: Lola says she took Metformin at 8:10 AM (logged later)" | They were already told it was missed |
| Show "Logged late" on history, never just "Taken" | Honest record for the caregiver and the panel |

**Box corroboration:** if the patient has a box and nobody pressed its button
for that dose, label it "Logged late (not confirmed on box)" for the caregiver.
This is cheap to add once the box endpoints exist, and it answers the obvious
panel question: "can't patients just lie?"

### 7.4 Other reasons

Every other reason keeps `status: missed` and saves `skipped_reason`. The dose
moves into "Done today" with the reason shown.

---

## 8. Archive instead of delete

### 8.1 Where dose logs are deleted today

| Code path | What it deletes |
|---|---|
| Archive a medicine (`deletePatientMedication` → `_purgeFutureDoseLogs`) | Future `pending` logs |
| "Delete for good" on the archive screen (`permanentlyDeleteMedication`) | The medicine, its schedules and **every** dose log |
| Worker materialiser (`runMaterialize`) | Future `pending` logs left over after a dose time was edited |

The security rules already have **no** delete permission on `dose_logs`, so the
first two will fail as soon as the rules leave test mode. Removing deletes fixes
that too.

### 8.2 Proposed: cancel, never delete

| Event | Instead of deleting |
|---|---|
| Medicine archived | Future `pending` logs → `status: cancelled`, `cancelled_reason: "archived"` |
| Dose time edited | Orphaned future `pending` logs → `cancelled`, `cancelled_reason: "rescheduled"` |
| "Delete for good" | **Remove the button.** Archive is the only way out |

Cancelled logs are excluded from adherence, dashboards and reports, but stay
in Firestore. Add `allow delete: if false;` to the `dose_logs` rule so the
intent is explicit.

### 8.3 Medicines entered by mistake

Today, "Remove — entered by mistake" exists so its logs can be erased. Without
deletes, keep the two archive reasons, but for `archived_reason: "mistake"`
**exclude that medicine's past logs from adherence**. They stay stored and
visible in the archive, marked "Entered by mistake — not counted".

### 8.4 Addition: restore has a hidden bug once cancel replaces delete

Dose-log ids are fixed (`{schedule}_{date}_{time}`), and the materialiser
skips any id that already exists. If archiving leaves a `cancelled` log for
tomorrow 8:00 AM, restoring the medicine will **not** recreate that dose,
because the id is taken. Restore must turn future `cancelled` logs (with
`cancelled_reason: "archived"`) back into `pending`.

### 8.5 Alarms

Archiving already cancels the phone's alarms: the schedule becomes inactive,
the patient app's schedule stream updates, and all reminders are re-armed
without it. Snooze alarms use the same id range, so they are cleared too. On
the box, `led_active` is already set to `false` on archive. **No change
needed**, but include it in testing.

---

## 9. Data model changes

### `dose_logs`

| Field | Change | Values |
|---|---|---|
| `status` | **extended** | `pending` · `taken` · `snoozed` · `missed` · `skipped` (new) · `cancelled` (new) |
| `timing` | **new** | `early` · `on_time` · `late` · `logged_late`; null unless taken |
| `logged_at` | **new** | When the record was written, if different from `taken_at` (retro logs) |
| `cancelled_reason` | **new** | `archived` · `rescheduled` |
| `missed_reason` | rename (optional) | `skipped_reason` is used today for both; keep the name if a rename is too costly |
| `acknowledged_at` | keep | Now set when a reason is given, instead of by the ✕ button |

### `notifications`

| `notification_type` | New? | When |
|---|---|---|
| `late` | new | Option C only: 30 min with no action (caregiver) |
| `correction` | new | "I took it but forgot to log it" (caregiver) |
| `confirmed` | existing | Now sent after the Undo window |
| `missed` | existing | At 60 min (or 30, per decision 2.3) |

### Rules

- `dose_logs`: add `allow delete: if false;`.
- `dose_logs` update: today a patient may change the status freely. Consider
  limiting the patient to `pending`/`snoozed` → `taken`/`skipped`, and
  `missed` → `taken` only with `timing: logged_late`. That stops a patient
  turning a `taken` dose back into `pending` outside Undo. Undo can stay
  allowed by checking that `taken_at` is less than a minute old.

### Worker

- Sweep: `MISSED_AFTER_MINUTES` changes to 60 (options B and C). Option C adds
  a 30-minute "running late" pass that only notifies and doesn't change the
  status.
- Materialiser: cancel instead of delete (8.2).
- New: pick up `skipped` with `caregiver_notified: false` (4.2).

---

## 10. Adherence and reports

Today adherence is `taken ÷ (taken + missed)`. Proposed definitions:

| Metric | Formula | Shown to |
|---|---|---|
| **Adherence** | `taken ÷ (taken + missed + skipped)`, excluding `cancelled` and medicines archived as mistakes | patient, caregiver |
| **On-time rate** | `taken with timing on_time or early ÷ taken` | caregiver reports |
| **Self-corrected** | count of `timing: logged_late` | caregiver reports |
| **Skips with reasons** | breakdown of `skipped_reason` | caregiver reports |

Keeping "on time" separate from "taken" means a patient who always takes doses
50 minutes late still shows 100% adherence (which is true), while the
caregiver can see the habit (also true). That answers the panel better than a
single number.

---

## 11. Caregiver side

- Patient detail and patient schedule screens use the same badges and colours
  (Upcoming / Due now / Late / Missed / Taken – late / Logged late / Skipped).
- History shows reasons for Skipped and Missed, and "Logged late at 9:40 PM,
  says taken at 8:10 AM" for corrections.
- Alerts tab gains the `late` and `correction` types, with icons.
- Caregiver settings: "Missed dose alerts" covers `late`, `missed` and
  `correction` together, so no new switches are needed.

---

## 12. Decisions

All six are decided (October 2026).

1. **Missed at 30 or 60 minutes → Option C (2.3).** The caregiver gets a
   "running late" alert at 30 minutes; the dose becomes Missed at 60. The
   30-minute alert uses the existing "Missed dose alerts" switch, so there is
   no new setting. Replacement sentence for the paper:
   > If a dose is not confirmed within 30 minutes, the caregiver receives a
   > late-dose alert; after 60 minutes the dose is recorded as missed.
2. **Early logging cap → 3 hours, but never more than half the gap to the
   previous dose of the same medicine (3.3).** The half-gap rule only changes
   anything for medicines taken every 4 hours or more often.
3. **Retro-logging window → until the end of the next day (7.3).** Older
   misses stay Missed.
4. **Full-screen alarm over the lock screen → deferred until after Play Store
   approval (5.2, step 4).** Play review risk and Xiaomi restrictions outweigh
   the benefit before the November 30 deadline. Tap-to-open and the
   background-run hint (5.2, steps 1–3) ship instead.
5. **Undo duration → 5 seconds (4.1).** Raise to 8 seconds if testing with
   elderly users shows they miss the toast. The caregiver push waits the same
   length.
6. **Remove "Delete for good" → yes (8.2).** Medicines archived as "Entered by
   mistake" stay stored, are shown as "not counted", and are left out of
   adherence (8.3). A genuine request to erase someone's data is handled by an
   admin from the Firebase console, never by a button in the app.

---

## 13. Build order and test checklist

Ordered so each step works on its own and nothing is left half-wired.

| Step | Work | Depends on |
|---|---|---|
| 1 | Status model: badge rules, `skipped`, `cancelled`, `timing` field, adherence formula | — |
| 2 | Archive without deletes, restore fix, `delete: if false` rule, remove "Delete for good" | — |
| 3 | Worker: sweep threshold to 60 min, 30-min late pass (Option C), cancel instead of delete, skipped backstop | Step 1 |
| 4 | Notification tap → `DoseAlertScreen`, cold start, background-run hint (full-screen alarm deferred) | — |
| 5 | Dashboard: groups, date + time, countdown, tomorrow toggle, inline Done/Skip, Snooze removed | Steps 1, 4 |
| 6 | Action window, early prompt with cap, Undo with delayed push | Step 5 |
| 7 | Missed flow: open the reason screen, new reason, retro logging, correction notice | Steps 1, 5 |
| 8 | Caregiver screens and reports | Steps 1, 7 |
| 9 | Update CLAUDE.md, `MEDICATION_DATA_MAP.md` and the paper | All |

### Test checklist

- [ ] At 7:00 for an 8:00 dose: "Upcoming · Due in 1 hr", buttons locked,
      "Actions unlock at 7:30 AM"
- [ ] At 7:40: still "Upcoming · Due in 20 mins", buttons unlocked
- [ ] At 8:00: "Due now"; at 8:35: "Late · 35 mins late"; at 9:05: "Missed"
- [ ] Tap a locked button at 6:00 for a 9:00 PM dose → "Too early" (over 3 hrs)
- [ ] Tap at 7:00 PM → early prompt; confirm → `taken`, `timing: early`
- [ ] Done → Undo within 5 s → status, stock and LED restored; caregiver gets
      nothing
- [ ] Done → wait 5 s → caregiver gets "Dose taken"
- [ ] Skip → reason required → `skipped`; caregiver alerted
- [ ] Tap a reminder notification with the app closed → alarm screen opens
      with Snooze; the dashboard has no Snooze
- [ ] Missed dose → "I took it but forgot" → time asked → `taken`,
      `timing: logged_late`, stock − 1, caregiver correction notice
- [ ] The same option on a dose from 3 days ago is not offered
- [ ] Archive with doses later today → those become `cancelled`; past logs
      untouched; alarms gone
- [ ] Restore the same day → today's remaining doses come back as `pending`
- [ ] Adherence ignores `cancelled` and mistake-archived medicines
- [ ] With the deployed rules, no screen can delete a dose log

---

## 14. Implementation status

Built in the order of section 13. Timing and adherence rules are covered by
26 unit tests (`test/dose_timing_test.dart`); the dose-log security rules by
18 Firestore-emulator checks.

| Section | Where it lives |
|---|---|
| 2 Status model, timeline, timing tags | `lib/utils/dose_timing.dart`, `lib/models/dose_log_model.dart` (`DoseStatus`, `DoseTimingTag`), `lib/utils/dose_status_display.dart` |
| 3 Lock, early prompt, 3-hour and half-gap cap, Skip reason | `lib/widgets/patient/dose_actions.dart`, `lib/widgets/patient/dose_reason_picker.dart` |
| 4 Undo, delayed caregiver push | `PatientProvider.takeDose` / `skipDose` / `undoDoseAction` / `finalizeDoseAction`, `SnackbarHelper.showUndo` |
| 5 Tap-to-open, cold start, background-run hint, Snooze on the alarm only | `lib/services/dose_launch_router.dart`, `NotificationService.initialize`, `PatientMainScreen`, `lib/services/device_settings_service.dart` + `MainActivity.kt`, `DoseAlertScreen` |
| 6 Dashboard groups, date + time, countdown, tomorrow | `lib/screens/patient/patient_dashboard_screen.dart`, `PatientProvider.slotsForDay` |
| 7 Missed flow, retro logging, correction | `lib/screens/patient/missed_dose_screen.dart`, `PatientProvider.logTakenLate` / `saveMissedReason` |
| 8 Cancel instead of delete, restore revives, mistake not counted | `FirestoreService` (`deletePatientMedication`, `restoreMedication`), `firestore.rules`, archive screen |
| 9 Worker | `healthsync-api/src/handlers/sweep.ts` (late, missed, skip backstop), `materialize.ts` (cancel/revive), `dose-events.ts` + `src/lib/dose-copy.ts` (wording) |
| 10 Adherence and reports | `lib/utils/adherence.dart`, `reports_screen.dart` |
| 11 Caregiver screens | patient detail, schedule, history, alerts, dashboard, settings |

**Not built, waiting for the box endpoints (Phase 7):**

- **3.5 Box button window.** The ESP32 endpoints do not exist yet. When they
  do, the button press should confirm only from −30 to +59 minutes.
- **7.3 Box corroboration** ("Logged late — not confirmed on box").

**Also done along the way:**

- A dose acted on before the Worker materialised it is now written under the
  Worker's own id. Previously it got a random id, the materialiser then made
  a second, pending copy, and the sweep marked that copy missed.
- The "Full-screen alert" switch in Settings and Profile was removed: it was
  never read, and the feature it described is deferred (decision 4).

**Still to do by the team:** replace the 30-minute sentence in the paper with
the one in decision 1, deploy the Worker, and deploy the rules and indexes.

