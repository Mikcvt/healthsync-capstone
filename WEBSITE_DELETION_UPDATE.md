# Website update: account deletion (for Mona)

The app's deletion changed in build 1.0.0+2. The website must match it
**before** Siemonne uploads that build, because Play compares the two.

What changed in the app:

- **Managed patients delete their own account.** No care partner approval,
  no "Send request". Their care partner is notified.
- **Nothing is erased right away.** A deleted account is closed at once
  (signed out, reminders stop) and **permanently deleted after 30 days**.
- **Restoring:** within the 30 days, a care partner restores their own account
  by signing in and tapping **Restore my account**. They restore a patient
  from **My Patients → Restore** on that patient's card.
- Deleting a care partner still deletes their managed patients, on the same
  30-day timeline. Restoring the care partner restores those patients too.

Update the **effective date** on Privacy and Terms to the day you publish.

---

## Privacy policy, section 9 "How long we keep it, and deleting it"

**Replace** the paragraph starting "In the app: a care partner can open…" with:

> In the app: a care partner can open Profile & Settings, tap Delete account,
> enter their password and confirm. A managed patient can open Profile, tap
> Delete my account and confirm. No one else needs to approve it, and their
> care partner is notified.

**Replace** the paragraph starting "Without the app, or if a request is declined…"
with:

> Without the app: follow the steps on the account deletion page, or email
> support.healthsync@gmail.com. We delete the account and the information
> linked to it within 30 days of confirming the request. Managed patients
> have no email on their account, so they can write from any address and
> include their full name and their care partner's name. We may contact the
> care partner only to confirm who the patient is, and we tell them when the
> account is deleted.

**Replace** the paragraph starting "When a deletion is confirmed in the app…" with:

> When you delete your account in the app, it is closed straight away: you
> are signed out, reminders stop, and no one can sign in to it with a code.
> It is permanently deleted 30 days later, together with the information
> linked to it. Until then it can be restored: a care partner by signing in
> again and choosing Restore, and a managed patient by their care partner, or
> by emailing us.

**Replace** "We do not keep backup copies. Deleted information cannot be
recovered, and a deleted account cannot be restored." with:

> We do not keep backup copies. After the 30 days, deleted information cannot
> be recovered and the account cannot be restored.

**Replace** the paragraph starting "If a care partner deletes their account…"
with:

> If a care partner deletes their account, the accounts of the managed
> patients they created are deleted too, together with those patients'
> medicines, schedules, dose history and alerts, on the same 30-day timeline.
> The app lists these patients and asks for confirmation first. Restoring the
> care partner's account restores those patients as well. A managed patient
> account cannot be used without a care partner.

---

## Terms of Service, section 12 "Ending your use and deleting your account"

**Replace** the whole paragraph with:

> You can stop using HealthSync at any time. A care partner can delete their
> account in the app, after entering their password and confirming; the
> managed patient accounts they created are deleted with it. A managed
> patient can delete their own account in the app; their care partner is
> notified but does not need to approve it. A deleted account is closed at
> once and permanently deleted after 30 days. Until then it can be restored,
> as explained in the Privacy Policy. After that it and its data cannot be
> recovered, because we do not keep backups. You can also ask us by email, as
> explained in the Privacy Policy and on the account deletion page. We may
> suspend or end access if these Terms are broken or to protect someone's
> safety or data.

---

## Account deletion page (/delete-account/)

**Care partners, in the app.** Change the last button name from
"Delete everything" to **Delete account**, and add this sentence at the end:

> Your account and your patients' accounts are closed at once and permanently
> deleted after 30 days. To undo it, sign in again before then and tap
> Restore my account.

**Managed patients, in the app.** Replace the paragraph with:

> Open Profile, tap Delete my account, tick the box to confirm you understand,
> and tap Delete my account. You are signed out and your reminders stop. Your
> care partner is notified and can restore your account within 30 days if it
> was a mistake. After that it is permanently deleted.

**Screenshots: retake these from build 1.0.0+2.** The current ones show the
old request flow:

| Remove | Replace with |
|---|---|
| Patient step 3, "care partner has been asked to approve" | The patient's confirm dialog with the "I understand" box |
| Care partner "sees the request in My Patients and taps Approve" | A patient card showing "…will be permanently deleted on [date]" and **Restore** |
| Care partner "taps Delete permanently" | The care partner's delete dialog with the **Delete account** button |

**"If you cannot open the app, or your request was declined"**: remove
"or your request was declined". Requests can no longer be declined.

**Replace** "In the app, the account and its data are deleted permanently as
soon as the deletion is confirmed. For an email request, we delete them within
30 days of confirming your request." with:

> In the app, the account is closed as soon as you confirm, and it and its
> data are permanently deleted 30 days later. Until then it can be restored.
> For an email request, we delete them within 30 days of confirming your
> request.

**Replace** "No backup copies. Deleted data cannot be recovered, and a deleted
account cannot be restored." with:

> No backup copies. After the 30 days, deleted data cannot be recovered and
> the account cannot be restored.

---

## Play Console (for Siemonne)

Data safety → Data deletion: keep "Users can request that data be deleted",
with the deletion page URL above. If the form asks about retention, the
answer is: **deleted within 30 days of the request**.
