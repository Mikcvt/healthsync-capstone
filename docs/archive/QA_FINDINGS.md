# QA findings: email verification, requests, dashboard (Oct 12, 2026)

Checked against the code, starting from the issues in
`healthsync_fixes_prompt_guide.md`. Each item gives the confirmed cause (not the
guessed one), the fix, and its status.

**All items were implemented on Oct 12, 2026 and pass `flutter analyze`, but
none has been tested on a phone yet.** Use each item's test steps.

| # | Issue | Type | Status |
|---|---|---|---|
| 1 | "Use a different account" does nothing | Bug | ✅ Fixed (not yet tested on a phone) |
| 2 | Care partner cannot decline a deletion request | Bug | ✅ Done (rules deployed) |
| 3 | Care partner sign-out has no confirmation | Bug | ✅ Done |
| 4 | Welcome screen promises too much | Copy | ✅ Done |
| 5 | No "Change email" before verifying | Missing feature | ✅ Done |
| 6 | No check that reminders can actually fire | Missing feature | ✅ Done |
| 7 | Care partner dashboard could show more | Enhancement | ✅ Done |

---

## 1. "Use a different account" does nothing ✅ Fixed

**Where:** `lib/screens/auth/email_verification_screen.dart`

**Cause:** the button *did* sign out. But Register and Login open this screen
**on top of** AuthGate (the app's start screen). Signing out switched AuthGate
to the Welcome screen *underneath*, while the verification screen stayed in
front, so the tap looked dead.

**Fix:** `_useDifferentAccount()` now stops the screen's 4-second verification
check and the resend countdown, signs out, then closes every screen down to the
first one (`popUntil(isFirst)`), which reveals Welcome.

**Test:** register a care partner → on "Verify your email" tap **Use a
different account** → the Welcome screen appears.

---

## 2. Care partner cannot decline a deletion request

**Where:** `FirestoreService.cancelAccountDeletionRequest()` (called by
`CaregiverProvider.declineDeletionRequest()`), and `firestore.rules`
(`match /users/{userId}`).

**Cause (confirmed):** Decline clears `deletion_requested_at` and
`deletion_reason` on the **patient's** `users` document. The rules only let a
user update **their own** `users` document, so the care partner's write is
refused every time. The patient's own "withdraw request" works because they
are the owner.

**Fix:**
1. **Rule:** allow the patient's own care partner to change *only* the two
   request fields, plus a new `deletion_declined_at`:
   ```
   allow update: if (isOwner(userId) && ...existing checks...)
     || (isCaregiverOf(userId)
         && request.resource.data.diff(resource.data).affectedKeys()
              .hasOnly(['deletion_requested_at', 'deletion_reason',
                        'deletion_declined_at']));
   ```
2. **App:** Decline also sets `deletion_declined_at` and writes a notification
   to the patient: *"Your care partner declined your request to delete your
   account."*
3. **Patient profile screen:** show "Declined by your care partner" until the
   patient makes a new request.

**Not adopted from the guide:** a `pending / approved / declined / expired`
status field. "Approved" deletes the account, so nothing is left to carry that
status, and no rule exists for "expired". A timestamp plus a notification
covers it. The guide's "Cloud Functions / Supabase" do not apply: this is a
Firestore rules fix.

**Test:** patient taps "Delete my account" → care partner taps **Decline** → no
error, the banner disappears, and the patient gets the notification.

---

## 3. Care partner sign-out has no confirmation

**Where:** `lib/screens/caregiver/caregiver_settings_screen.dart`, the
"Sign out" row.

**Cause:** the row calls `auth.signOut()` directly on tap. The patient's
sign-out (`patient_profile_screen.dart`) already confirms first.

**Fix:** a reusable `showConfirmDialog()` helper (title, message, confirm
label, destructive flag) in `lib/widgets/shared/`, used here with:
- Title: **Sign out?**
- Message: *"Are you sure you want to sign out of HealthSync? Alerts about your
  patients will stop on this phone until you sign in again."*
- Actions: **Cancel** / **Sign out**

The patient's sign-out moves onto the same helper. The password-protected
deletes (account, patient) keep their own dialogs; they need more than yes/no.

---

## 4. Welcome screen promises too much

**Where:** `lib/screens/auth/welcome_screen.dart` (around lines 231–241) and
`AppStrings.appTagline`.

**Cause:** "Never miss a dose" is an absolute promise, and "Smart LED visual
guidance" suggests the medicine box is required. RELEASE_TODO already says to
present the app as a reminder and adherence tool, with no health-outcome claims.

**Fix:**
| Now | Change to |
|---|---|
| Never miss a dose | **Stay on top of every dose.** |
| Smart LED visual guidance and live care partner tracking… | **Medicine reminders and missed-dose alerts for you and your care partner.** |
| *(none)* | Small badge: *Works with the optional HealthSync medicine box.* |

---

## 5. No "Change email" before verifying

**Where:** `email_verification_screen.dart`, `AuthService`.

**Problem:** a care partner who typed the wrong email can only resend to that
same wrong address, or start over with a new account.

**Fix:** a **Change email** button that asks for the new address and calls
Firebase's `verifyBeforeUpdateEmail()`. The link goes to the new address;
opening it changes the email and verifies it in one step. The `users` document's
`email` field must be updated too. The existing 4-second check then moves the
user on automatically.

**Already done (the guide asked for them):** the resend button with a 60-second
cooldown, and the automatic check every 4 seconds while the screen is open.

---

## 6. No check that reminders can actually fire

**Problem:** reminders are scheduled on the phone. If notifications, exact
alarms or battery optimisation are blocked, they never fire, silently. Xiaomi,
Oppo and Vivo phones are the worst for this, and the team's test phone is a
Xiaomi.

**Already exists:**
- notification and exact-alarm permissions are requested at startup
  (`DoseReminderScheduler.requestPermissions`);
- a prompt to open the vendor background settings on Xiaomi, Oppo and Vivo
  (`patient_main_screen.dart`, `MainActivity.openBackgroundSettings`).

**Missing:** a **Reminder check** card on first launch and in Settings, showing
each item as ✅ or ⚠️ with a **Fix** button:
| Check | How |
|---|---|
| Notifications allowed | flutter_local_notifications |
| Exact alarms allowed (Android 12+) | flutter_local_notifications |
| Battery optimisation off | new method on the existing `healthsync/device` channel in `MainActivity` (`PowerManager.isIgnoringBatteryOptimizations`) |
| Vendor autostart (Xiaomi etc.) | can't be read; show the existing "Open settings" step |

Care partners need the notification check too, or missed-dose alerts won't show.

---

## 7. Care partner dashboard could show more

**Correction to the guide:** the dashboard does not show only the name. It has
an overview, totals, and a card per patient with today's taken, missed and
outstanding doses (`caregiver_dashboard_screen.dart`, `_PatientTodayCard`). If it
looked empty, the likely reason is that no doses existed yet: the Worker's
5-minute job was failing from the Firebase project switch until the key fix on
Oct 10, so no doses were created. Re-check before redesigning.

**Worth adding:**
| Item | Data source | Cost |
|---|---|---|
| Today's upcoming doses per patient | `schedules` + `dose_logs` (already streamed) | Small |
| Recent alerts per patient | `notifications` where `patient_ref` = patient | Small |
| "Box last seen 5 min ago" | `devices.last_sync` / `status` (already exists) | Small |
| Patient's reminders blocked / last opened | new: the patient app writes its Reminder check result (item 6) on open | Medium: one write per app open |

**Do not add: battery level.** The box has no battery monitoring, and showing
the phone's battery is not useful. CLAUDE.md ("No phantom features") forbids
readings the hardware cannot produce.

---

## Suggested order

1. Item 2: decline request (real bug, small)
2. Item 3: sign-out confirmation (very small)
3. Item 4: welcome copy (very small)
4. Item 5: change email (small)
5. Item 6: reminder check (medium)
6. Item 7: dashboard additions (medium; decide scope first)
