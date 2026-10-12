# UI polish plan: wording, verify screen, medicine box, empty stock

> **Status (Oct 12, 2026): all items done, plus the splash timeout.** Chosen:
> green Online dot, "Care Partner" in titles and "care partner" in sentences.
> Passes `flutter analyze` and the Worker typecheck; not yet tested on a phone.

A plan for review before any code is written. Each item says what the app does
today (checked in the code), what will change, and what to decide.

| # | Item | Size |
|---|---|---|
| 1 | "Email already in use": explain it and offer Log in (option A) | Small |
| 2 | Verify screen: tuck the three extra links behind a toggle | Small |
| 3 | Remove the "Shared with your care partner" card | Very small |
| 4 | Patient's Medicine box screen in blue | Small |
| 5 | Allow logging a dose when the stock count is 0, with a refill note | Medium |
| 6 | Say "Care Partner" everywhere instead of caregiver / guardian | Medium (many small edits) |

---

## 1. "Email already in use": explain it and offer Log in (option A)

**Today:** registering with an email that already has an account shows the
generic error *"An account already exists for this email."* The most common
reason is someone who registered earlier and never verified. Registering
created the account, and verifying only flips a flag (see the earlier
explanation), so they are stuck.

**Change:** when Register gets "email already in use", show a dialog instead of
the error:

> **This email already has an account**
> If you signed up before and didn't finish verifying, log in to continue. You
> can resend the verification link from there.
> **[Cancel]  [Log in]**

**Log in** opens the Login screen with the email already filled in. After
login, an unverified account lands on the Verify screen as it does today, and
**Forgot password** still works for unverified accounts.

**Files:** `register_screen.dart`, `login_screen.dart` (accepts a prefilled
email), `auth_service.dart` (so the screen can tell this error apart from others
without matching the message text).

---

## 2. Verify screen: tuck the three extra links behind a toggle

**Today:** under the main **I verified my email** button there are three links
in a column: *Resend verification email*, *Wrong email? Change it*, *Use a
different account*. With the main button, that's four choices at once.

**Change:**
```
[ I verified my email ]          ← main action, unchanged

  Didn't get it? More options ⌄  ← one quiet toggle

  (tapped → slides open)
  Resend verification email   (keeps its 60 s countdown)
  Wrong email? Change it
  Use a different account
```
Tapping the toggle again closes it (the arrow flips). It starts closed.

**One exception:** if the user already tapped *Resend* and the countdown is
running, the section stays open, so they can see the countdown.

**Files:** `email_verification_screen.dart`.

---

## 3. Remove the "Shared with your care partner" card

**Today:** after the last round it opens a "What your care partner sees" sheet,
but you'd rather not have it on the patient's analytics screen.

**Change:** remove the card and its sheet from `analytics_screen.dart`.
Nothing else uses them. The "Today: … · N doses taken in total" fix from the
last round stays.

---

## 4. Patient's Medicine box screen in blue

**Today:** the patient's **Medicine box** screen (`medicine_box_status_screen`)
uses the care partner green: the filled compartment cards (Col 1, Col 7),
their bulb icons, and the "Online" text and dot.

**Change:** switch it to the patient blue:
| Element | Now | After |
|---|---|---|
| Filled compartment card background | mint green | `blueLight` |
| Filled compartment border, bulb, "Col N" | green | `patientBlue` |
| Device card accents | green | `patientBlue` |
| **Lit** compartment (dose due now) | amber | **amber, unchanged**: it mirrors the real LED colour on the box |
| "Online" dot and word | green | see decision below |

**Decision:** the **Online dot** is a status signal, like a traffic light.
Green = online is understood everywhere, and blue reads as "information".
**I recommend keeping the dot green and making only the word and card accents
blue.** Say if you want it all blue.

The care partner's own box screen (`patient_box_screen.dart`) stays green, as
care partner screens are green.

**Files:** `medicine_box_status_screen.dart`.

---

## 5. Allow logging a dose when the stock count is 0

**Today:** when a medicine's pill count reaches 0, the patient **cannot** mark
a dose as taken. The button is disabled on the dashboard, the alarm screen and
the medicine page, with *"Out of stock · Refill required"*. The reasoning in the
code was: an empty box means they couldn't have taken it, so recording it would
tell the care partner something false.

**Your point is right:** the count is only what the app *thinks* is left. The
patient may have refilled the box themselves, bought a new pack, or the count
was simply entered too low. Blocking the log loses a real dose and wrongly
pushes it toward "missed".

**Change:**
1. At 0 the dose can be logged normally (Taken, Skip, and "I took it but forgot
   to log it").
2. A note shows instead of the block:
   - medicine in the box: **"Compartment 7 is empty — refill it. Your care
     partner can update the count after refilling."**
   - not in the box: **"Your stock count is at 0 — ask your care partner to
     update it after refilling."**
3. The count **stays at 0**: it never goes negative.
4. **Undo** gives a pill back only if the log actually took one. Today Undo
   always adds 1 back, which would make an empty count read 1.
5. The care partner was already told when the count reached 0 ("Out of
   stock"). Logging at 0 does not send that again.

**Not changing:** the low-stock and out-of-stock alerts, and how the care
partner refills (their medicine edit screen).

**Files:** `patient_provider.dart` (the two checks that reject the log, the
decrement, the Undo record), `dose_alert_screen.dart`,
`medicine_detail_screen.dart`, the dashboard dose card, `app_strings.dart`,
and CLAUDE.md (it currently states "at 0 pills, Mark as taken is disabled").

---

## 6. Say "Care Partner" everywhere instead of caregiver / guardian

**Today:** about **45 places** in the app still say *caregiver* or *guardian*
to the user. Examples: "Guardian Dashboard", "Ask your caregiver for a new
one", "No Caregiver Linked", "Caregiver Notified", "Patient · managed by
caregiver", the role card **Caregiver** on sign-up, "Caregiver account". The
Worker also has a few: OTP error messages ("Ask your caregiver for a new one")
and "Only caregivers can add patients."

**Change:** every word the user can **see or hear** becomes Care Partner:
screen titles, buttons, messages, empty states, errors and push-notification
text, in the app and the Worker.

**Not changing (on purpose):** code names and stored data:
`caregiver_ref`, `account_type: "caregiver"`, `CaregiverProvider`,
`caregiver_dashboard_screen.dart` and so on. Renaming those would break every
existing account and Firestore query for no visible gain. CLAUDE.md gets a
one-line glossary: *"caregiver" in code = "Care Partner" on screen.*

**Capitalisation (decision):**
- **Recommended:** **"Care Partner"** in titles, labels and buttons ("Care
  Partner Dashboard", "No Care Partner linked"), and **"care partner"** inside
  sentences ("Ask your care partner for a new code"). Capital letters in the
  middle of a sentence read as shouting.
- **Alternative:** "Care Partner" with capitals everywhere, exactly as you
  wrote it.

**Also fixed while there:**
- **"Guardian Link":** the care partner welcome screen says the patient "can
  find it in Guardian Link", but nothing in the app is called that. It will
  point to the real place.
- **"Caregiver Notified / Synced to caregiver dashboard":** on the dose
  confirmed screen this is shown even for a patient with no care partner. It
  will only say "Care Partner notified" when there is one.

**Files:** about 25 Dart files (mostly one or two lines each), `otp.ts` and
`patients.ts` in the Worker (redeployed), CLAUDE.md.

---

## Not in this round

From the last discussion, still waiting for your go-ahead:
- **Splash timeout:** after about 8 s on the splash, show *"Taking longer than
  usual — check your internet"* with **Try again**, and make the splash's exit
  independent of screen refreshes.
- Options **B** (start over with a new account) and **C** (auto-delete
  unverified accounts after 7 days) for the email issue.

---

## Order of work

1. Item 3: remove the card (smallest)
2. Item 2: verify screen toggle
3. Item 1: email already in use
4. Item 4: blue medicine box
5. Item 5: logging at 0 stock
6. Item 6: Care Partner wording (last, so it also covers text added above)

Then `flutter analyze`, a Worker deploy for the wording, and a release APK.

## Decisions for you

1. **Online dot:** keep it green (recommended), or blue like the rest?
2. **Capitalisation:** "Care Partner" in titles and "care partner" in
   sentences (recommended), or capitals everywhere?
3. **Splash timeout:** include it in this round?
