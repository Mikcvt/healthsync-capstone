# Panel prep: what can go wrong with the box and the app

> Nov 1, 2026. Traced from the code on `fixing-bugs-and-ble` (firmware 0.4.2,
> `schedule.cpp`, `healthsync_box.ino`, `box_provider.dart`,
> `patient_provider.dart`), not from the design docs alone.
> Firmware fixes need Christian's agreement; app fixes go to dev first.

Each item: **Now** (what the code actually does), **Risk**, **Say** (the answer
for the panel), **Fix** (if one is worth doing). Risk: 🔴 fix before the
defense · 🟠 fix if there is time, or have a strong answer · 🟢 answer only.

---

## The short list (fix these first)

| # | Problem | Fix | Where | Size |
|---|---|---|---|---|
| A1 | One press confirms **every** lit compartment, even if only 2 of 3 were taken | One press = one compartment; the one to take next blinks | Firmware | Small |
| A2 | A wrong button press can never be corrected in the app | "I didn't take this" on a button-confirmed dose | App + rules | Medium |
| B1 | Patient presses the button, but the care partner still gets "Running late" and "Missed" (no sync until the app is opened) | Background sync after each box dose time, or at least a nudge | App | Medium–large |
| B3 | Caregiver deletes or moves a medicine; the box keeps lighting the old one until the patient opens the app | Show "box has the old schedule" to the care partner; fix the misleading delete text | App | Small |
| D1 | "Pills per dose" is never asked: the app always says "1 tablet" and counts 1 pill off | Add the field; count it off | App | Small–medium |
| A5 | A quick tap (< 0.3 s) or a long hold (> 10 s) is ignored with **no sound** | A short "try again" chirp | Firmware | Tiny |

---

## A. The button and the LEDs

### A1. Three compartments lit, one press, the patient took only two 🔴
**Now:** `schedule_take()` marks **every** lit dose taken. All three LEDs go
off, the box logs three `taken` events, the app saves three taken doses and
counts one pill off each. The medicine that was not taken shows as taken. No
one is alerted.

**Why it matters:** this is the most likely panel question, and the record is
wrong in the worst direction (a missed dose looks taken).

**Fix (recommended): one press confirms one compartment.**
- Several lit: the compartment to take **next blinks**, the others stay steady.
- Press: that one is taken, its LED goes off, the next one starts blinking.
- A compartment the patient skips stays lit, keeps alarming, and is marked
  missed at +60 min like any other dose. The care partner gets the normal
  missed alert.
- Firmware only: `schedule_take()` takes the lowest lit compartment instead of
  all of them, and the LED code blinks that one. Each press is already its own
  event, so **no app, protocol or Firestore change**.
- It also makes the title true: the LEDs *guide* the patient one medicine at a
  time.

**Say:** "When several medicines are due together, the box blinks the one to
take now. The button confirms the blinking one, then the next one blinks. If
the patient stops after two, the third stays lit and is reported missed."

**If not fixed, say:** "The button means *I took everything the box showed*.
If a patient took only some, they correct it in the app." (Only true once A2
exists.)

### A2. A wrong press cannot be undone 🔴
**Now:** a button press reaches Firestore at the next sync, with `logged_at` =
the press time. The rules allow Undo only for 2 minutes after `logged_at`, so
by the time the patient sees it in the app, Undo is closed. There is no
"I didn't take this" action for a taken dose. A child pressing the button, or
a patient pressing it to stop the beeping, is recorded as taken for good.

**Fix:** on a dose with `confirmed_via: "button"`, same day only, a
"Not taken? Correct it" action: status `skipped`, reason "Box button pressed
by mistake", one pill back, the care partner gets a correction notice.
Needs one **added** rule (taken → skipped when `confirmed_via == 'button'` and
same day). Adding a transition is safe for the live 1.0.0+2 build; dev first.

### A3. The patient presses the button but never swallowed the pill 🟢
**Now:** nothing can tell. The same is true of the app's Done button.

**Say:** "No consumer pillbox verifies swallowing; that needs video or an
ingestible sensor. HealthSync records *confirmed by the patient*, with the
time and whether it came from the box or the app. The pill count and the care
partner's refill checks are the cross-check." Adherence is self-reported,
the same as every study tool that uses a button or diary.

### A4. LED 3 is lit but the patient takes from compartment 2 🟢
**Now:** the box has no lid sensors, so it cannot know which compartment was
opened. The press is recorded for compartment 3.

**Say:** "The LED points to the right compartment; we do not detect which lid
opened. That is future work." Be ready with the cost: one reed switch +
magnet or one micro-switch per lid. Six free input pins exist: GPIO 4, 27,
34, 35, 36, 39 (34–39 are input-only and need external pull-up resistors).

### A5. A quick tap or a long hold does nothing, silently 🟠
**Now:** a press counts only if held 0.3–10 s (`BUTTON_CONFIRM_MS`,
`BUTTON_CONFIRM_MAX_MS`). A quick tap under 0.3 s, or a hold over 10 s, is
ignored **with no sound**. An elderly patient tapping quickly gets no answer;
if the tap lands in the alarm's 2 s pause, it can even seem to have worked.

**Fix:** play a short distinct chirp ("hold a little longer") on a too-short
or too-long press. Two lines in `onPress()` in `healthsync_box.ino`.

**Say (the 0.3 s rule itself):** "A bump or a loose contact must never mark a
dose taken, so the button needs a deliberate press."

### A6. The patient presses before the LED lights 🟢
**Now:** nothing is taken; 0.8 s "nothing due" tone. The app, though, unlocks
Done 30 min before (and asks "Logging early?" up to 3 h before).

**Say:** "Early logging is app-only on purpose: a press before the alarm may
be an accident, and an accidental press must not record a dose."

### A7. The patient presses after the LED went off (+60 min) 🟢
**Now:** the dose is already missed on the box; the press does nothing.

**Say:** "They open the missed dose in the app and choose *I took it but
forgot to log it*. It is saved as taken, logged late, and the care partner
gets a correction."

### A8. The patient presses just to stop the beeping 🟠
**Now:** the only way to silence the box is to confirm the dose. (It goes
silent by itself after 30 min; the LED stays lit until +60.)

**Say:** the same as A3. With A1 fixed, a silencing press confirms one
medicine, not all of them. With A2 fixed, it can be corrected.

### A9. Loose wire on the button 🟢
**Now:** the button is normally-closed, so a broken wire reads as "pressed".
Held over 30 s it is flagged as stuck and ignored. But a contact that drops
for 0.3–10 s and comes back counts as a press.

**Say:** "The 0.3 s minimum filters bumps and bounce; a wire that breaks for
good is detected as stuck. The final build is soldered, not on a breadboard."

### A10. The care partner loads a medicine into the wrong compartment 🟢
**Now:** the box cannot know what is inside a compartment.

**Say:** "The app shows which medicine belongs in each compartment (patient's
Box tab and the care partner's Smart box screen). Filling it correctly is
the care partner's job, like filling any pill organiser."

---

## B. Box ↔ phone sync (connect-on-demand)

### B1. The button was pressed, but the care partner gets "Missed" 🔴
**Now:** the phone talks to the box only when the app is opened, right after
Done/Skip in the app, or on the Sync button. There is **no background sync**
(decision M2, `BLE_CONNECT_ON_DEMAND.md`). So:

1. 08:00 the box lights, 08:05 the patient presses the button.
2. 08:30 the Worker sends the care partner "Running late".
3. 09:00 the Worker marks the dose missed and alerts the care partner.
4. Whenever the patient next opens the app: the press is saved as taken, and
   the care partner gets a "correction" alert.

A patient who uses only the box and rarely opens the app will look like they
miss **every** dose, in alerts and in the reports, until the next sync.

**Say (why it is like this):** "We chose connect-on-demand: a permanent
Bluetooth connection on Android needs a foreground service, which Play reviews
strictly and which drains the battery. The box never loses a press; it stores
it and the phone uploads it at the next sync. The record is corrected and the
care partner is told."

**Fix options:**
- **(a) Background sync after each box dose time (recommended if time
  allows).** Schedule a short sync at about +25 min (before the "Running late"
  alert) and +55 min (before "Missed") for every dose in a compartment. The
  phone already knows the box's address, so no scan is needed. Needs a
  background callback (an Android alarm) that starts Firebase and Bluetooth;
  must be tested on the Xiaomi phones, which kill background work.
- **(b) Cheap partial fix:** make the dose reminder say
  "Used the box button? Open HealthSync so your care partner sees it."
- **(c)** Tell the care partner in the late/missed alert that the patient has
  a box and the press may not have synced yet (Worker change: dev first, then
  prod with a release).

### B2. The phone keeps reminding after the button was pressed 🟠
**Now:** same root as B1: the phone does not know about the press until a
sync. Worse: if the patient taps **Skip** on the phone after pressing the
button, the dose stays skipped. The later box press is ignored
(`recordBoxPress` keeps a final status).

**Say / fix:** as B1. Tapping the reminder opens the app, which syncs first.

### B3. The care partner changes the medicine; the box keeps the old schedule 🔴
**Now:** the care partner's edits reach the box only through the
**patient's** phone, at its next sync. Until then:

| Care partner does | Box does | Result |
|---|---|---|
| Deletes / archives a medicine (e.g. the doctor stopped it) | Keeps lighting its compartment every day | Patient may keep taking a stopped drug. Their presses are dropped silently (the dose is cancelled or the schedule is gone) |
| Moves 08:00 to 09:00 | Rings at 08:00 | Press at 08:00 is dropped (that dose was cancelled as rescheduled); phone rings at 09:00 → risk of a **double dose** |
| Moves the medicine to another compartment | Lights the old compartment | Patient opens the wrong lid |

Also, the delete screen tells the care partner it will "disable its smart box
LED indicator". That is not true until the patient's phone syncs.

**Fix (app only, safe for the live build):**
1. At each sync, save the box's schedule version on the `devices` document
   (new optional field). The care partner's screens compare it with the
   current schedule and show "The box still has the old schedule. Ask
   {patient} to open HealthSync near the box."
2. Correct the delete/edit text: "The box stops lighting compartment N the
   next time {patient}'s phone syncs with it. Take the pills out of that
   compartment."

**Say:** "The phone is the bridge to the box, so changes reach it at the next
sync, and the care partner sees whether the box is up to date."

### B4. Bluetooth off, phone out of range, or permission refused 🟢
**Now:** the box works alone: lights, rings, logs. Events wait on the SD card
and are collected at the next sync. Quiet syncs never pop up a Bluetooth
prompt.

**Say:** "No press is lost. The box acknowledges an event as delivered only
after the phone has saved it to Firestore."

Limit to know: **without an SD card** the box keeps only 32 events in flash
(`LOG_FALLBACK_MAX`): one event per dose, so about 5 days for a patient with
6 doses a day. Keep a card in the box.

### B5. The sync is cut off halfway 🟢
**Now:** the schedule is replaced in one step at `sched_commit` (a cut-off
sync leaves the old one). Events are acked only after they are saved. Every
dose log id is `{schedule}_{date}_{time}`, so the same press uploaded twice
can never create two doses.

**Say:** exactly that. This is one of the strongest answers you have.

### B6. The patient presses the button AND taps Done in the app 🟢
**Now:** whichever arrives second is ignored. One dose, one pill off.

### B7. The patient taps Done in the app; the box is still beeping 🟢
**Now:** the app syncs right after Done and sends `app_done`; the box stops.
If the phone cannot reach the box, it beeps until +30 min. A press then is
ignored (already taken).

### B8. Snooze in the app does not snooze the box 🟢
**Now:** only Done/Skip trigger a sync. The box beeps on (at most 30 min).

### B9. The patient's phone is lost or replaced 🟢
**Now:** the new phone pairs with the box (hold the button 5 s, type the code
on the label). Presses the old phone never collected are still on the box and
are uploaded by the new phone. The box remembers up to 3 phones.

### B10. Could a stranger connect to the box? 🟢
**Say:** "A new phone can pair only during pairing mode, which needs someone
holding the box's button for 5 seconds, plus the 6-digit code on the label.
The link is encrypted (LE Secure Connections). The SD card holds schedule ids,
compartments and times: no names, no medicines."

### B11. The patient has no smartphone, or never opens the app 🟢
**Say:** "The patient needs the app once, to redeem the code and pair the box.
After that the box alarms on its own from the last schedule it received. But
the care partner only sees doses when the phone syncs (see B1)."

---

## C. Clock and power

### C1. The box is off or the battery is flat 🟠
**Now:** no light, no sound. Phone reminders still work. The app shows "Box
last synced …" after 24 h without a sync (built Oct 31; not yet installed on
the test phone). The overnight battery test (does the 134N3P cut out at low
load?) is still pending (`BOX_HARDWARE_FIXES.md`, D1).

**Say:** "The phone is the backup reminder, and the app warns when the box has
not been seen for a day. No battery percentage is shown because this build
cannot measure it, and we do not show readings the hardware cannot produce."

### C2. Power cut in the middle of an alarm 🟢
**Now:** the schedule and the taken/missed record are in flash. On restart a
dose still inside its hour lights again; one whose hour passed while the box
was off is logged missed. The 30-min beeping is counted from the dose time,
so a restart does not make it beep longer.

### C3. The DS3231's coin cell dies 🟢
**Now:** the clock resets to 2000. The box treats any time before 2024 as
invalid and **refuses to alarm** rather than ring at the wrong time. The
phone sets the time at the next sync; the app shows "the box's clock is not
working" if it still does not keep time.

### C4. Clock drift 🟢
**Say:** "The DS3231 drifts about a minute a year, and the phone resets it at
every sync."

### C5. The phone's own clock is wrong 🟠
**Now:** the box copies the phone's time at every sync. A phone set wrong
makes the box ring at the wrong time until a correct phone syncs. If the phone
was set **in the future** when a schedule was sent, the new dose times get a
future "added" time and stay silent even after the clock is corrected.

**Fix (firmware, small):** on `set_time`, pull any "added" time later than
now back to now.

**Say:** "Android sets its time from the network by default; the box follows
the phone."

### C6. Time zone 🟢
**Now:** Manila (UTC+8) is fixed on the box and the Worker. The Philippines
has no daylight saving. A patient abroad keeps Manila dose times. Out of scope.

### C7. More than 6 medicines, more than 24 dose times, liquids, inhalers 🟢
**Now:** they stay phone-only reminders; the app says so. Each compartment
holds one medicine, shared by all its dose times.

### C8. A 2 AM dose wakes the household 🟢
**Now:** the box beeps 5 s on / 2 s off for 30 min at any hour. No quiet
hours. Answer only: the alarm is the point; the care partner sets the times.

---

## D. App and data

### D1. "Pills per dose" is never asked 🔴
**Now:** `quantity_per_dose` exists in Firestore and in
`PatientMedicationModel`, but **no screen sets it**, so it is always 1.
- Without a box, the reminder says "Take **1 tablet** (500 mg)" even when the
  doctor prescribed 2.
- With a box, it says only "Compartment 3": nothing says how many.
- Every dose counts **one** pill off. A 2-tablet medicine runs out at twice
  the speed the app shows; the low-stock alert comes too late.

**Fix (app):** a "Pills per dose" field in Add medicine step 2 and in Edit
medicine; count that many off (and back on Undo); box reminder text
"Compartment 3 · 2 tablets". The live 1.0.0+2 build still counts 1 off, which
is no worse than today.

**Say (if not fixed):** "The pill count is per dose; the prescribed amount is
written in the dosage field."

### D2. The pill count is only an estimate 🟢
**Say:** "The box cannot count pills. The count drops by one dose each time a
dose is confirmed, the care partner enters refills, and a dose can still be
logged at 0 because the box may have been refilled."

---

## E. Quick answers to "why" questions

| Question | Answer |
|---|---|
| Why Bluetooth, not Wi-Fi? | No Wi-Fi setup for an elderly patient, no Wi-Fi password or cloud key on the box, works where there is no Wi-Fi, less power. The phone is already online |
| Why not live / real-time? | A permanent Bluetooth link on Android needs a foreground service (Play review, battery). The box stores every event, so nothing is lost; it arrives at the next sync |
| Why one button, not six? | Simpler for elderly hands and cheaper. With A1 fixed, the blinking LED tells them which compartment the press is for |
| What if the internet is down? | The box needs none. The app logs doses offline and uploads them later |
| What if the box breaks? | Everything works phone-only: reminders, Done/Skip, alerts, reports. The box is optional |
| How do you know they took it? | We record confirmation, not ingestion (A3) |
| Who can change the medicines? | Only the care partner. The patient can only confirm doses and view history; the Firestore rules enforce it, not just the screens |
