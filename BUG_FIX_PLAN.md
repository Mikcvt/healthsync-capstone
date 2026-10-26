# Bug fix plan: Oct 23, 2026 test round

Source: *HealthSync Test Evidence* (PDF, Oct 23) and the Bug Log in
*HealthSync Test Notes - Organized.xlsx*. Bug IDs match both.

Every cause below was traced in the code on Oct 27, 2026, with file and line.
The ones marked **(to confirm)** are likely causes that still need the
reproduction listed on page 13 of the PDF.

**Nothing has been changed yet.** The decisions below were agreed on Oct 27,
2026; the fixes follow them.

---

## Summary

| ID | Bug | Pri | Cause found | Size |
|----|-----|-----|-------------|------|
| BUG-004 | Verify button spins on its own | P1 | The 4-second background check reuses the button's spinner | S |
| BUG-016/017 | Phone: no +63, no length limit | P1 | Validator allows 7–15 digits; two phone fields have no validator at all | M |
| BUG-020 | Stock fields accept 20+ digits | P1 | No input limit; only checked on Save | S |
| BUG-022 | Re-pairing stops changing anything | P1 | Every pairing adds another active device; the screen shows an arbitrary one | M |
| BUG-023 | One box paired to two accounts | P1 | No uniqueness check on the serial | M (same fix as 022) |
| BUG-025 | Medicines can be added to a deleted patient | P1 | The card and detail screen never check `hasPendingDeletion` | S |
| BUG-026 | Text cut off at large font | P1 | No text-scaling handling anywhere in the app | M–L |
| CR-06 | Show the patient's code again | P1 | The code screen is only reachable during onboarding | S |
| BUG-002 | "CAREGIVER" on sign-up | P2 | `register_screen.dart` prints the code role name | XS |
| BUG-003 | "Juan" / "Dela Cruz" in sign-up | P2 | Sample hint text | XS |
| BUG-005 | Password box shows dots before typing | P2 | Hint text is `'••••••••'` | XS |
| BUG-024 | Compartment colours | P2 | Lit and low-stock use two near-identical ambers; the legend explains only one | S |
| BUG-007/008 | Verify flow after link / no way back | – | (to confirm) | – |
| BUG-010 | New patient missing on first load | – | (to confirm) | – |
| BUG-018/019 | Dosage strength: ignores form, 20+ digits | – | Free text prefilled `500mg`, no limit | S |
| BUG-021 | New medicine slow to appear | – | (to confirm) Save waits on the server once per dose time | S |

Size: XS < 30 min · S < 2 h · M half a day · L a day or more.

---

## Decisions (agreed Oct 27, 2026)

| # | Question | Decision | For |
|---|----------|----------|-----|
| D1 | Phone rule | `+63` fixed in front, then **10 digits starting with 9** (Philippine mobile, e.g. `+63 961 784 0760`). Stored as `+639617840760`. A pasted `0961…` or `+63961…` is converted, not refused. Optional fields stay optional: many patients have no phone of their own. | 016/017 |
| D2 | Stock limits ("2 to 3 digits") | On hand: **0–999** (a 90-day supply at 3 a day is 270). Alert threshold: **0–99**, and **not more than the amount on hand**, or the alert would fire the moment the medicine is saved. The defaults (30 / 5) already fit. | 020 |
| D3 | "Pills on hand" vs "Doses on hand" | **Keep both.** It is deliberate: tablets and capsules count pills; liquids, inhalers and the like count doses (`add_medicine_step3_screen.dart:261`). Reply to the tester. | 020 |
| D4 | 6 or 8 compartments | **6.** The firmware lights 6 LEDs and **rejects compartments 7 and 8** over Bluetooth (`protocol.cpp:140`, `BLE_PROTOCOL.md`). The app offers 8 in four places, so a medicine put in 7 or 8 would never light. Also update CLAUDE.md (it still says 8 LEDs and the old GPIO pins) and check whether the capstone paper says 8 before the defense. | 024 and the box work |
| D5 | Should a deleted patient still show on Home? | **No.** Hide them from Home and from the "still to take" totals. Keep them on **My Patients** with the deletion banner and Restore, the one place to restore from. The Worker has already paused their schedules and cancelled their open doses, so a Home card would show nothing useful for 30 days. | 025 |
| D6 | CR-06: same code or a new one? | **A new code.** A code is one-time and is marked used on first sign-in, so the old one cannot work again. Reuse an unexpired, unused code if one exists; make a new one only otherwise. The Worker already supports a second code for a linked patient, and only the linked care partner can make it (the rules require `isCaregiverOf`). Hidden while the account is pending deletion. | CR-06 |
| D7 | Where do these fixes go? | **`release` only builds the APK.** All fixes, app and Bluetooth, go on **`fixing-bugs-and-ble`**, branched from `feature/medbox-integration` on Oct 27. Pairing (BUG-022/023) is rebuilt there together with the Bluetooth pairing flow. Nothing is pushed until the team reviews it. | All |

---

## Order of work

1. **Quick wins** (one sitting): BUG-002, 003, 005, 004.
2. **Input limits**: BUG-016/017, 020, 018/019. These share one approach: limit what can be typed and also validate on Save.
3. **Deleted-patient guard**: BUG-025.
4. **CR-06**: button on the patient page.
5. **Large font**: BUG-026, app-wide.
6. **Box screen**: BUG-024 and D4 (6 compartments).
7. **Reproduce, then fix**: BUG-007, 008, 010, 021.

8. **Pairing**: BUG-022/023, with the Bluetooth pairing flow.

All on `fixing-bugs-and-ble`.

---

## Details

### BUG-002: "CAREGIVER" on the sign-up screen (P2)

- **Cause:** [register_screen.dart:132](lib/screens/auth/register_screen.dart#L132) prints `'You are signing up as a ${widget.role.toUpperCase()} user.'`, using the code name of the role.
- **Fix:** Replace it with fixed text, for example "You are signing up as a Care Partner." (sign-up is Care Partner only).
- **Rest of the app:** A search of every quoted string in `lib/` and of the Worker's push text found **no other** user-visible "caregiver" or "guardian". This line is the only one.
- **Test:** Welcome → Get Started → Create your account reads "Care Partner" in both places.

### BUG-003: Sample names in the sign-up form (P2)

- **Cause:** `hint: 'Juan'` and `hint: 'Dela Cruz'` at [register_screen.dart:194](lib/screens/auth/register_screen.dart#L194) and [:206](lib/screens/auth/register_screen.dart#L206).
- **Fix:** Remove both hints. Also remove `'+63 912 345 6789'` (line 242); the `+63` prefix from BUG-016 replaces it. The email hint `you@example.com` and the password hints are not sample personal data and can stay.
- **Test:** Tap each field: only the floating label shows.

### BUG-004: Verify button spins without being tapped (P1)

- **Cause:** [email_verification_screen.dart:90](lib/screens/auth/email_verification_screen.dart#L90). A timer runs `_checkVerification` every 4 s (line 36). It sets `_isChecking`, which is also what swaps the button label for a spinner (line 198). So the spinner flashes every 4 s, and on a slow network it stays on almost permanently.
- **Fix:** Split the state: `_isPolling` for the background check (no visible change) and `_isManualCheck` for a tap (spinner). A tap during a background check waits for it rather than being refused. Add a timeout of about 10 s to the reload so a stuck request cannot hold the button.
- **Test:** Open the screen and wait 30 s: the label stays. Tap it before verifying: spinner, then "Email is not verified yet". Verify in the email app: the screen moves on within 4 s.

### BUG-005: Password box shows dots before typing (P2)

- **Cause:** `hint: '••••••••'` at [login_screen.dart:138](lib/screens/auth/login_screen.dart#L138). It looks like a saved password.
- **Fix:** Remove the hint. No other screen has a dotted hint.
- **Test:** Tap Password on the login screen: it is empty.

### BUG-016 / BUG-017: Phone number (P2 / P1)

- **Cause:** `Validators.phone` ([validators.dart](lib/utils/validators.dart)) accepts any 7–15 digits. Two fields have **no validator at all**: sign-up ([register_screen.dart:238](lib/screens/auth/register_screen.dart#L238)) and the Care Partner's Edit profile dialog ([caregiver_settings_screen.dart:528](lib/screens/caregiver/caregiver_settings_screen.dart#L528)). That is how the 40-digit number in the screenshot was saved.
- **Fix** (per D1):
  - Add `Validators.phPhone`: empty is allowed where the field is optional; otherwise exactly 10 digits starting with 9.
  - Make one shared phone field widget: fixed `+63 ` prefix, digits only, at most 10, spaced as typed (`961 784 0760`). Store `+63` plus the 10 digits.
  - Use it in all six phone fields: sign-up; Care Partner Edit profile; patient Edit profile (phone and emergency phone, [edit_profile_screen.dart:163](lib/screens/patient/edit_profile_screen.dart#L163)); Add patient (phone and contact phone, [add_patient_screen.dart:176](lib/screens/caregiver/add_patient_screen.dart#L176)).
  - Pre-fill existing numbers, and convert pasted ones the same way: `09XXXXXXXXX`, `639XXXXXXXXX` and `+639XXXXXXXXX` become the 10 digits; anything else shows empty with "Re-enter your number".
  - Profile card ([caregiver_settings_screen.dart:120](lib/screens/caregiver/caregiver_settings_screen.dart#L120)): one line with an ellipsis, so old bad data cannot break the layout.
  - The Worker's `POST /patients` should refuse a phone that is not `+639` plus 9 digits, so the rule cannot be bypassed.
- **Test:** Each of the six fields: letters cannot be typed, an 11th digit cannot be typed, `812…` is refused, and a valid number saves and shows as `+63 961 784 0760`. The test account with the long number shows it on one line until re-entered.

### BUG-020: Stock fields accept 20+ digits (P1)

- **Cause:** [add_medicine_step3_screen.dart:258](lib/screens/patient/add_medicine_step3_screen.dart#L258) and [:269](lib/screens/patient/add_medicine_step3_screen.dart#L269) use a number keyboard but no input limit. The check on Save (line 103) uses `int.tryParse`, which returns null past about 19 digits. That number is not saved, but the field still accepts it. The same two fields in [edit_medicine_screen.dart](lib/screens/patient/edit_medicine_screen.dart) ("Pills remaining", "Alert below") have the same gap.
- **Fix** (per D2): `FilteringTextInputFormatter.digitsOnly` plus a length limit (3 for the amount on hand, 2 for the threshold). Validate with the existing `Validators.positiveInt(max: …)` and add "the alert must not be above the amount on hand".
- **Label** (per D3): no change; tell the tester the two labels are deliberate.
- **Test:** Add medicine step 3 and Edit medicine: a 4th digit cannot be typed; threshold 50 with 20 on hand is refused with a message.

### BUG-018 / BUG-019: Dosage strength (no screenshot yet)

- **Cause:** [add_medicine_step1_screen.dart:20](lib/screens/patient/add_medicine_step1_screen.dart#L20) prefills `'500mg'` and keeps it when the form changes to Liquid or Inhaler. The field (line 180) is free text with no length limit.
- **Fix:** Split it into an amount (digits and one decimal point, at most 6 characters) and a unit dropdown that follows the form: Tablet/Capsule → mg, mcg, g · Liquid → ml, mg/5ml · Drops → drops · Inhaler → puff, mcg · Injection → ml, units. Changing the form resets the unit, and no amount is prefilled. It is still saved as one string (`"500 mg"`), so nothing that reads `prescribed_dosage` changes. Same change in Edit medicine.
- **Test:** Pick Liquid: the unit becomes ml. The amount stops at 6 characters.

### BUG-022 / BUG-023: Pairing (P1)

- **Cause:** [firestore_service.dart:943](lib/services/firestore_service.dart#L943) `pairDevice()` creates a **new** device document with a random ID every time. It never deactivates the old one and never checks whether the serial is already used. The box screen reads devices with `.limit(1)` ([device_service.dart:9](lib/services/device_service.dart#L9)) and takes whichever active one Firestore returns. After a few pairings it keeps showing an old box, so it looks as if "pairing changes nothing" (022). Nothing stops a second account from pairing the same serial (023).
- **Two more problems on the same path:**
  - `pairDevice` writes `status: 'online'` and `last_sync: now`. A box that has never been switched on shows "Online · synced 1 minute ago" (PDF page 8: serial `ANYA100`), and the box screen showed "Online" next to "Last sync 4 days ago" (page 9). Online should be derived from `last_sync` age, not stored at pairing.
  - The serial field has no format check: the page 9 screenshot has serial `10000000000000`. It should be `HS-` plus 4 digits, matching `DEVICE_SERIAL` in the firmware.
- **Fix:**
  1. Use the serial as the document ID: `devices/{SERIAL}`. Pairing becomes create-if-absent. If the box is already paired to this patient it is a no-op; if it is paired to someone else, the user sees "This box is already paired to another account".
  2. Rules: allow `create` only when the document does not exist; `update` stays limited to the owner or their Care Partner.
  3. When pairing a new box, set the patient's previous device to `is_active: false` in the same batch.
  4. Write no `status` and no `last_sync` at pairing; show "Not connected yet" until the box reports.
  5. Validate the serial format in both pairing screens ([device_pairing_screen.dart:154](lib/screens/patient/device_pairing_screen.dart#L154), [patient_box_screen.dart:212](lib/screens/caregiver/patient_box_screen.dart#L212)).
  6. Migration: existing test documents have random IDs. Deactivate them, or ask testers to pair again.
- **Branch (D7):** fixed on `fixing-bugs-and-ble`, where the box moves to Bluetooth with a 6-digit pairing code on the label ([BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md)), so pairing is rebuilt once, together with that flow. Keep writing the `serial_number` field: the Worker's `device.ts` looks devices up by it.
- **Test:** Pair `HS-0001`, then `HS-0002`: the screen shows `HS-0002`. Pair `HS-0001` from a second account: refused. A fresh pairing shows "Not connected yet".

### BUG-024: Compartment colours (P2)

- **Cause:** [medicine_box_status_screen.dart:355](lib/screens/patient/medicine_box_status_screen.dart#L355). There are four states: empty (grey), lit (`ledActiveBg` #FEF3C7), low stock (`pendingAmberBg` #FAEEDA) and filled (blue). Lit and low stock are both amber and barely distinguishable, and the legend (line 79) explains only "amber = lit". In the screenshot, Col 2 is amber because its dose was due (`led_active`), so the colour was correct but unexplained. The tile's doc comment (line 337) still says "green when stocked", which is probably where "changed again" comes from: it was green in an earlier build.
- **Fix:**
  - Keep the colours as they are now and fix the comment.
  - Give low stock its own look: the blue tile with a red "Low" tag, not a second amber.
  - Replace the single sentence with a small legend: Lit now · In use · Low stock · Empty.
  - Per D4, show 6 compartments, and correct CLAUDE.md (LED count and GPIO pins). Change the 8 in [compartment_picker.dart:39](lib/widgets/shared/compartment_picker.dart#L39), [add_medicine_step3_screen.dart:26](lib/screens/patient/add_medicine_step3_screen.dart#L26), [patient_box_screen.dart:404](lib/screens/caregiver/patient_box_screen.dart#L404) and the box status grid to one constant, `AppConstants.boxCompartments = 6`.
  - Any schedule already in 7 or 8 shows as "Not in the box" and is listed for the Care Partner to move.
- **Test:** A due dose turns its tile amber, with a legend entry. Low stock shows the tag. Only 6 tiles appear.

### BUG-025: Medicines can be added to a deleted patient (P1)

- **Cause:** [my_patients_screen.dart:199](lib/screens/caregiver/my_patients_screen.dart#L199) shows the Medicines button whether or not `patient.hasPendingDeletion`. Tapping the card opens Patient detail, whose "Manage medications" button ([patient_detail_screen.dart:309](lib/screens/caregiver/patient_detail_screen.dart#L309)) has the same gap. The Home list counts the patient's doses as if the account were active.
- **Fix:**
  - When `hasPendingDeletion` is true, hide the Medicines button and disable Manage medications, with the note "Restore this account to manage medicines".
  - On Home (per D5): leave the patient out of the list and out of the "still to take" totals. My Patients keeps the card with the banner and Restore.
  - In `firestore.rules`, refuse `patient_medications` and `schedules` writes for a patient whose `users.is_active` is false, so the guard does not rely on the UI alone.
- **To confirm:** Home showed an 08:00 AM dose "still to take" for the deleted patient. The Worker should have cancelled the open doses at deletion. Check whether the dashboard builds that chip from schedules or from a dose log that was not cancelled.
- **Test:** Delete a test patient: no Medicines button, Manage medications disabled, gone from Home and its totals, still on My Patients with Restore. Restore: everything comes back.

### BUG-026: Text cut off at large font (P1)

- **Cause:** The app has no text-scaling handling at all: no search hit for `textScaler` or `textScaleFactor` in `lib/`. On the welcome screen, the "Works with the optional HealthSync medicine box" chip is a `Row` with an unwrapped `Text` ([welcome_screen.dart:285](lib/screens/auth/welcome_screen.dart#L285)). It cannot wrap, so it is cut off.
- **Fix:**
  1. App-wide: in the `MaterialApp` builder, clamp text scaling to at most about 1.3×. The phone's large-font setting still makes text larger, but extreme sizes cannot break fixed layouts. This also covers most of CR-04 (font size).
  2. Welcome chip: `Flexible` text that wraps to two centred lines.
  3. Retest every main screen at the phone's largest font size and fix what still overflows. Likely trouble spots: fixed-height buttons (`height: 54`), the 4-column compartment grid, the stat tiles on Patient detail, and the bottom nav labels.
- **Test:** Set the phone's font size to maximum. Go through every screen in the screen checklist in [CLAUDE.md](CLAUDE.md): no yellow-black overflow stripes, nothing cut off.

### CR-06: Show the patient's code again (P1)

- **Current state:** [generate_otp_screen.dart](lib/screens/caregiver/generate_otp_screen.dart) can only be reached from Add patient and Set up medications. `CaregiverProvider.regenerateOtp()` and `getOrCreateOtp()` already exist, and the Worker accepts a new code for an already-linked patient.
- **Fix** (per D6): Add "Send a new sign-in code" to Patient detail. It opens `GenerateOtpScreen` for that patient: it reuses an unexpired unused code, or makes a new one, and shows the share sheet. Only for active (not deleted) patients.
- **Note:** The patient's old phone stays signed in after a new code is redeemed elsewhere. That is fine for a lost or reset phone; say so on the screen.
- **Test:** Patient detail → new code → redeem on a second phone: the same account opens with its schedule.

### BUG-007 / BUG-008: Verify flow (reproduce first)

- **007** (verify does not let the user in after the link was used): the BUG-004 change touches the same function. Retest after it. If it still fails, check whether `reloadAndCheckEmailVerification` returns `null` (session ended by an email change) when it should return `true`.
- **008** (no way back to registration): "Use a different account" exists, but it is hidden under "Didn't get it? More options". Test whether a user who closes and reopens the app lands back on this screen with the options closed. If so, consider showing "Use a different account" without the toggle.

### BUG-010: New patient missing on first load (reproduce first)

- The list comes from the `caregiver_patient_links` stream ([caregiver_provider.dart:182](lib/providers/caregiver_provider.dart#L182)). The Worker creates the link, so it arrives a moment after `POST /patients` returns. Likely cause: the card renders before the new patient's `users` document arrives and shows an empty state. Confirm with the recording, then show a "Setting up…" card instead of nothing.

### BUG-021: New medicine slow to appear (reproduce first)

- [schedule_provider.dart:136](lib/providers/schedule_provider.dart#L136) `saveNewMedication()` awaits the server for the medication and then for each dose time in turn (line ~180). On mobile data that is several round trips before the success screen. Fix: write everything in one batch and settle it the way dose actions do (`FirestoreService.settle()`). The list then updates from the phone's own copy at once.

### CR-01 to CR-05: Change requests

Not part of this round. They go to the tracker as features. CR-04 (font size) is mostly covered by the BUG-026 work.

---

## Done when

- Each fix meets the definition of done in [CLAUDE.md](CLAUDE.md): reads from a provider or stream, writes reach Firestore, and failures show a message through `SnackbarHelper`.
- `flutter analyze` is clean and `flutter test` passes.
- The tester retests every item above on a real phone, at normal and at maximum font size, and the Bug Log is updated.
- Release build number bumped per the release notes.
