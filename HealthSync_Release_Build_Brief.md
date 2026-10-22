# HealthSync: Release Build Brief (for the Lead Dev)

**Goal:** Produce a signed release `.aab` for the Play closed test track, ideally today or tomorrow. Release target is Nov 1 and READY BY is Fri Nov 6.

**Package ID:** `com.healthsyncteam.app`. This is permanent after the first upload, so don't improvise it.

**Access status (confirmed, no blockers):**
- Siemonne (account owner, developer name `seymoneym`) has Play Console access and knows the `.aab` is coming.
- You have Firebase project access.

**Already done:** The tagline has been changed to "Stay on top of every dose." The Play listing graphics, screenshots and feature graphic are ready in `ASSETS\play-ready\`.

**Rules**
- Don't run `flutter pub upgrade`. Only change dependencies when the build requires it, and review the diff.
- Never commit the keystore, `key.properties` or secrets. Check `.gitignore` before every commit.
- If something looks risky, pause and message Siemonne or Miko.

---

## 1. Package ID and Firebase
- Set `applicationId` and `namespace` to `com.healthsyncteam.app` in `android/app/build.gradle(.kts)`.
- Move `MainActivity` to `kotlin/com/healthsyncteam/app/` and update its `package` line.
- In the Firebase console, add a new Android app with this package ID. Download a fresh `google-services.json`, or run `flutterfire configure`.
- Add the release SHA-1 and SHA-256 after you create the keystore (step 5). Re-download `google-services.json` afterwards if needed.
- Search the whole project for leftover old IDs (`ph.edu.ntc.healthsync`, `com.healthsync.app`, `com.example`).

## 2. Manifest and permissions
- Remove `USE_EXACT_ALARM`.
- Check the merged manifest and make sure `com.google.android.gms.permission.AD_ID` is absent. We declared no advertising ID in Play Console.
- Confirm `INTERNET` is present and there is no cleartext traffic (`usesCleartextTraffic`).
- **Open (Oct 22, 2026 BLE decision, not started / pending confirmation):** the box now talks to the phone over BLE ([BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md)). Bluetooth permissions are not in the manifest yet, the Data safety form and privacy policy must be checked for them, and a BLE update after the Oct 30 freeze needs a freeze-exception decision. Tracked in `RELEASE_TODO.md` section 10.

## 3. Branding and version
- App label is "HealthSync".
- Launcher icon comes from `ASSETS\app icon.png`.
- Bump the version in `pubspec.yaml`, for example `1.0.0+1`. Every later upload needs a higher build number.

## 4. App wording, Terms and Privacy
- Replace "Guardian" and "Caregiver" with "Care partner" everywhere in the UI (for example "Guardian Dashboard" and "Caregiver … is monitoring").
- Change "Deactivate your HealthSync account" to "Delete". The behavior must match the wording.
- Confirm the in-app account deletion does what the policy says. Deleting a care partner's account also deletes their managed patients, and data is removed within 30 days.
- Replace brand-name and real-name demo data (for example "Advil (Ibuprofen)" and "Adi") with generic sample data if it's quick. This is not a blocker.
- **Double-check that Terms and Privacy are done and correct.** I understand they're finished, but please verify:
  - Open the live pages at https://healthsync-site.pages.dev/ (Terms, Privacy, and the deletion page at `/delete-account/`). Confirm each URL loads and the paths match what the app links to.
  - Check the content against the app and our Play Console answers:
    - Effective date is October 12, 2026.
    - It says "care partner", not "caregiver" or "guardian".
    - The support email is support.healthsync@gmail.com.
    - It says data is stored in Singapore (Firebase `asia-southeast1`).
    - Retention is 30 days after deletion.
    - Deleting a care partner also deletes their managed patients.
    - There are no ads, no advertising ID, and no sharing of data with third parties.
  - Confirm the in-app links (welcome screen, sign-up, settings) open the right pages and that the app's own Terms text matches the website.
  - Report anything that doesn't match to Miko or Mona before the build goes out.

## 5. Signing
- Create an upload keystore with `keytool`. Create `android/key.properties` and wire up `signingConfigs` in Gradle for release.
- Add the keystore and `key.properties` to `.gitignore`.
- Back up the keystore and passwords in two separate places. Losing them is painful. Tell Siemonne where the backups are.
- Use Play App Signing (the default when Siemonne uploads).

## 6. Build and test
- Run:
  ```
  flutter clean
  flutter pub get
  flutter build appbundle --release
  ```
- The output is `build/app/outputs/bundle/release/app-release.aab`.
- Install a **release** build on a real phone and smoke test these flows:
  - Care partner sign up and sign in
  - Adding a managed patient and signing in as the patient with the single-use OTP
  - Reminders firing on time
  - Missed-dose alerts reaching the care partner
  - Taken, snooze and skip actions
  - Account deletion
- Fix SEC-001 if it's still open.
- Note any known issues, such as the Cloudflare Worker "Too many subrequests" overflow.

## 7. Handoff
- Send Siemonne the `.aab` file and the version name and number.
- Also send the review demo account details so he can enter them under App access: HealthSync Demo, healthsync.reviewer1@gmail.com. Miko has the password.
- Let Siemonne and Miko know in the group chat when it's done.

**Done when:** The signed `.aab` installs and runs on a real phone, Terms and Privacy are verified, and Siemonne has the file.
