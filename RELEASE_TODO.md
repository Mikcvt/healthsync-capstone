# HealthSync 1.0.0: Google Play release to-do

**Target:** HealthSync 1.0.0 on Google Play by **November 1, 2026** (23 days from today)
**Written:** October 9, 2026 · **Deadline moved** from Nov 30 to Nov 1
**Scope:** dose logging, caregiver alerts and authentication are working. Small
bugs are acceptable for 1.0.0. Anything that crashes the app, loses a dose or
leaks data is not.

Tick each box as you go. Put your name next to each section you take. Items
marked **(after Nov 1 OK)** can slip without blocking the release.

---

## 0. Read this first: what Nov 1 can mean

Before choosing a plan, find out what kind of developer account you'll use.
That decides whether Nov 1 is possible at all.

A **personal** Google Play developer account created after November 13, 2023
can't publish to Production straight away. It must first run a **closed test
with at least 12 testers, opted in for 14 days in a row**, then apply for
production access (reviewed in up to ~7 days), and then get the release itself
reviewed (1–7 days). That adds up to **about 4 weeks minimum**, and Nov 1 is
23 days away.

### Day 1 decision (Oct 10): which account?

**Decided Oct 9: personal account.** The team has no organization account or
D-U-N-S number, so an organization account is out.

> **Accepted risk:** Google's account-type guidance says to choose an
> organization account for "Health apps, such as Medical apps", and lists
> medication reminders under *Medical*. It doesn't say a personal account will
> be refused, and many pill-reminder apps are published from personal
> accounts. To keep the risk low:
> - present HealthSync as a **reminder and adherence tracker**, never as
>   something that diagnoses, treats or monitors health (no "clinical",
>   "medical monitoring" or outcome claims)
> - use Google's exact disclaimer wording in the description (section 6)
> - Health apps declaration: *Medication and Treatment Management* only;
>   **not** "Medical Device Apps"
> - if a review asks for an organization account anyway, reply that it is a
>   non-regulated student capstone reminder app, and include the
>   disclaimer. That response becomes the fallback plan.

**Plan A or Plan B?** It depends only on **when the personal account was
created**:

- **Before Nov 13, 2023 → Plan A.**
- **After that, or not created yet → Plan B.**

To check, open Play Console → the app's **Dashboard**. If it lists *"Run a
closed test"* / *"Apply for production access"*, you're on Plan B.

| Option | Production by Nov 1? | Notes |
|---|---|---|
| **A. An existing account created before Nov 13, 2023** (a teammate's, your adviser's, the school's) | **Yes, if you submit by Oct 16** | No 12-tester rule. Upload straight to Production. The account owner must agree to host the app. |
| **B. A new personal account** | **No.** On Nov 1 the app is live in **closed testing** on Google Play, and the production application is under review. | Testers install it from the Play Store using an opt-in link. Tell your adviser or panel now that production lands around Nov 5–10. |

### Plan A timeline (exempt account → Production by Nov 1)

| By | Milestone |
|---|---|
| **Oct 10 (Sat)** | Account confirmed; app created in Play Console |
| **Oct 12 (Mon)** | Package name changed, release signing set up, icon and label done (section 2) |
| **Oct 13 (Tue)** | Privacy policy and account-deletion pages live (section 4) |
| **Oct 14 (Wed)** | Release smoke test passed on two phones (section 7) |
| **Oct 15 (Thu)** | App content forms and store listing complete (sections 5–6) |
| **Oct 16 (Fri)** | **Submit 1.0.0 to Production.** First reviews of a new app can take 7+ days. |
| **Oct 23–28** | Expected live. Days left over are buffer for one rejection and resubmission. |
| **Nov 1 (Sun)** | Deadline |

### Plan B timeline (new personal account → closed test by Nov 1)

The 14-day clock is the critical path, so the first closed-test build goes out
**as early as possible**. Only the items that can never change later (package
name, signing) and the ones Play requires before any release (privacy policy,
content forms) must be done first. Polish can follow in later builds; the
clock keeps running.

| By | Milestone |
|---|---|
| **Oct 10 (Sat)** | Account created; identity verification submitted; **12+ testers' Gmail addresses collected** |
| **Oct 11 (Sun)** | Package name changed, release signing set up (section 2.1–2.2) |
| **Oct 12 (Mon)** | Privacy policy and account-deletion pages live; app content forms complete (sections 4–5) |
| **Oct 13 (Tue)** | **First `.aab` on the closed track; 12+ testers opted in. The 14-day clock starts.** |
| Oct 14–26 | Smoke test and fixes; upload new builds (`1.0.0+2`, …) as needed |
| **Oct 27 (Tue)** | 14 days complete → **apply for production access** |
| **Nov 1 (Sun)** | Deadline: app live in closed testing on Google Play; production access under review |
| ~Nov 3 | Production access granted → submit 1.0.0 to Production |
| ~Nov 5–10 | Expected live in Production |

> If identity verification hasn't cleared by Oct 13, every Plan B date
> slips by the same number of days. Submit it on Oct 10.

---

## 1. Google Play developer account (Oct 10)

- [x] Account type: **personal** (decided Oct 9)
- [ ] **Plan A or B?** Check the Dashboard as described in section 0. If one
      teammate's personal account is older than Nov 13, 2023, publishing from
      it puts you on Plan A.
- [ ] Plan B only: create the account at play.google.com/console ($25,
      one-time) and submit identity verification **the same day**
- [ ] Decide whose account it is. It owns the app permanently, so use a team or
      shared Google account, not one student's personal email.
- [ ] Plan B only: line up **12+ testers today**: classmates, family,
      panelists. Collect their Gmail addresses. Aim for 15 in case some never
      opt in.

---

## 2. Blockers in the Android project (must do before the first upload)

### 2.1 Change the application ID. ⚠️ This can never be changed after upload.

Play rejects `com.example.*`. Pick the final ID once, for example
`ph.edu.ntc.healthsync`.

- [ ] `android/app/build.gradle.kts`: set both `namespace` and `applicationId`
      to the new ID
- [ ] Move `android/app/src/main/kotlin/com/example/healthsync/MainActivity.kt`
      to the matching folders, and update its `package` line
- [ ] Firebase console → Project settings → **Add app → Android** with the new
      package name
- [ ] Re-run `flutterfire configure --project=healthsync-b8394`. This
      regenerates `android/app/google-services.json` and
      `lib/firebase_options.dart`.
- [ ] Delete the stray `android/app/google-services (healthsync).json`
- [ ] Reinstall on test phones and **log in again**. The new package gets new
      push tokens. Existing accounts and data are unaffected, since it's the
      same Firebase project.

### 2.2 Release signing

Builds are currently signed with the **debug** key
(`signingConfig = signingConfigs.getByName("debug")`).

- [ ] Create an upload key:
      `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
- [ ] Create `android/key.properties` with `storePassword`, `keyPassword`,
      `keyAlias`, `storeFile`
- [ ] Load it in `build.gradle.kts`, and point the `release` build type at a
      `release` signing config
- [ ] Add `*.jks` and `key.properties` to `.gitignore` **before** the next
      `git add .`
- [ ] Back up the keystore and passwords in two places outside the repo. Play
      App Signing lets you reset a lost upload key, but only through a support
      request.
- [ ] In Play Console, keep **Play App Signing** on (the default)

### 2.3 App identity

- [ ] `AndroidManifest.xml`: change `android:label="healthsync"` to
      `"HealthSync"`
- [ ] Replace the launcher icon. The current one is the Flutter default. Use
      `flutter_launcher_icons`, or Android Studio → Image Asset, with an
      adaptive icon.
- [ ] `pubspec.yaml`: replace `description: "A new Flutter project."`
- [ ] Confirm `version: 1.0.0+1`. **Every upload needs a higher build number**
      (`1.0.0+2`, `1.0.0+3`, …), even when the name stays 1.0.0.

### 2.4 Exact-alarm permission (Play policy)

The manifest declares both `SCHEDULE_EXACT_ALARM` and `USE_EXACT_ALARM`.
Play only allows `USE_EXACT_ALARM` for apps whose core function is an alarm
clock or calendar, and asks for a declaration. Apps have been rejected for it.

- [ ] **Recommended:** remove `USE_EXACT_ALARM` and keep
      `SCHEDULE_EXACT_ALARM`. The app already asks the user for exact alarms
      (`DoseReminderScheduler.requestPermissions`), and settings shows when
      it's denied.
- [ ] Remove the manifest comment saying medication apps qualify
- [ ] After removing it, check that reminders still fire on Android 14+

---

## 3. Backend: production readiness

Deployed on Oct 9: Firestore rules, the two new `dose_logs` indexes, and the
new Worker.

- [ ] Firebase console → Firestore → Indexes: all indexes show **Enabled**
- [ ] **Worker subrequest overflow, still open.** The log from the 15:50 cron
      run on Oct 9 shows `Sweep: 17 dose(s) marked missed, 4 caregiver(s)
      notified` and one `Too many subrequests` error. Fix: have the sweep
      count its actual Firestore and FCM calls and stop alerting near 50,
      instead of a fixed 5 alerts. The backstop already retries anything
      skipped.
- [ ] Clean out test data before launch. Deactivate test patients and
      schedules so the cron isn't sweeping dozens of fake doses every 5
      minutes.
- [ ] After every phone has the release build: log out and in on each, then
      check that `wrangler tail` no longer shows `FCM rejected token (404)`
- [ ] Google Cloud console → APIs & Services → Credentials: restrict the
      Android API key to the new package name, plus the SHA-1 of both the
      upload key and the Play app-signing key (copy it from Play Console →
      App integrity) **(after Nov 1 OK)**
- [ ] Firebase Auth → Templates: set the sender name and app name to
      HealthSync in the verification and password-reset emails **(after Nov 1 OK)**
- [ ] Update CLAUDE.md: the "Firestore: Test mode" line is outdated, because
      the rules are locked **(after Nov 1 OK)**
- [ ] Note the free limits for the panel: Firestore Spark 50k reads and 20k
      writes per day; Cloudflare 100k requests per day; KV 1k writes per day **(after Nov 1 OK)**

---

## 4. Policy pages Play requires (host them before you fill in Play Console)

These pages can live on GitHub Pages, Google Sites or a Notion public page.
They need a stable public URL.

- [ ] **Privacy policy.** Required for any app with accounts or health data.
      It must cover:
  - what is collected: name, email, phone, medications and schedules,
        dose history, medical conditions, allergies, emergency contact, push
        token
  - where it is stored: Google Firebase (Firestore, asia-southeast1) and
        Cloudflare (the Worker processes requests and stores nothing
        long-term)
  - who sees it: the patient and their linked caregiver only
  - how to delete it, and a contact email
  - compliance with the **Philippine Data Privacy Act of 2012 (RA 10173)**
- [ ] **Account deletion page (web).** Play requires a web link as well as
      the in-app option the app already has. A page that explains the in-app
      steps and gives an email for deletion requests is enough.
- [ ] Put the privacy policy link inside the app too (welcome or settings
      screen)

---

## 5. Play Console: App content forms

All of these must be complete before any release can be reviewed.

- [ ] **Privacy policy URL** (from section 4)
- [ ] **App access.** Login is required, so give reviewers working
      credentials:
  - a caregiver email and password with a patient already set up
  - step-by-step instructions to generate a patient code and enter it on a
        second device or after logging out. Codes are single-use and expire
        in 48 hours, so **don't paste a code**; explain how to make one.
- [ ] **Ads:** No ads
- [ ] **Content rating** questionnaire (expect a rating of Everyone / PEGI 3)
- [ ] **Target audience:** 18+. Patients are added by an adult caregiver.
- [ ] **Data safety form.** It must match the privacy policy:
  - collected: personal info (name, email, phone), health info
        (medications, conditions), app activity (dose history), device
        identifiers (push token)
  - encrypted in transit: yes
  - users can request deletion: yes
  - shared with third parties: no. Firebase and Cloudflare are service
        providers, not "sharing".
- [ ] **Health apps declaration:** choose *Medication and treatment
      management*
- [ ] Financial features, government app, news app: **No**

---

## 6. Store listing

- [ ] App name: `HealthSync` (30 characters max)
- [ ] Short description (80 characters max). Example: *Medicine reminders
      with caregiver alerts and an optional LED smart pill box.*
- [ ] Full description (4,000 characters max). Rules for it:
  - describe the **box as optional**; the app works on the phone alone
  - mention only features the build has: no heart rate, SpO2, battery or
        smartwatch (see "No phantom features" in CLAUDE.md)
  - include the medical disclaimer Google's Health policy requires of
        non-regulated health apps, in the description itself: *HealthSync is
        not a medical device and does not diagnose, treat, cure, or prevent
        any medical condition. Always consult a healthcare professional for
        medical advice, diagnosis, or treatment.*
- [ ] App icon: 512 × 512 PNG
- [ ] Feature graphic: 1024 × 500 PNG/JPG
- [ ] Phone screenshots: 2–8. Suggested: patient dashboard, alarm screen,
      caregiver alerts, reports, add medicine, box status. Use demo data with
      **no real names**.
- [ ] Category: **Medical**
- [ ] Contact email (required). Website is optional.

---

## 7. Build and test the release

- [ ] Build the bundle: `flutter build appbundle --release`
      → `build/app/outputs/bundle/release/app-release.aab`
- [ ] Also build an APK (`flutter build apk --release`) for sideload testing
- [ ] **Smoke test on the release build** with two phones (caregiver +
      patient). Debug builds skip code shrinking, so only a release build
      proves the app works.

| # | Test | Pass |
|---|---|---|
| S1 | Caregiver signs up, verifies email, logs in | [ ] |
| S2 | Caregiver adds a patient and a medicine with 2 dose times | [ ] |
| S3 | Caregiver generates a code; patient enters it on a fresh install | [ ] |
| S4 | **App fully closed** → reminder fires at the dose time | [ ] |
| S5 | Patient taps Done → Undo works → Done again sticks | [ ] |
| S6 | Patient taps Done on a dose not created yet (the Oct 9 bug) → succeeds | [ ] |
| S7 | Caregiver gets a "Dose taken" push within seconds | [ ] |
| S8 | Skip with a reason → caregiver gets "Dose skipped" | [ ] |
| S9 | Ignore a dose → "Running late" at +30 min, "Missed dose" at +60 min | [ ] |
| S10 | Missed → "I took it but forgot" → caregiver gets "Dose update" | [ ] |
| S11 | Stock reaches the threshold → both sides see low stock | [ ] |
| S12 | Phone restarted → reminders still fire | [ ] |
| S13 | Airplane mode → Done shows a clear error and no crash; works again once back online | [ ] |
| S14 | Log out → log in → pushes still arrive | [ ] |
| S15 | Account deletion works for both roles | [ ] |
| S16 | Android 10, 13 and 14+ devices or emulators all install and run | [ ] |
| S17 | Phone set to a **non-Manila time zone** → today's cards still show taken doses as done (the Oct 9 fix) | [ ] |

- [ ] Triage `bug to fix.md`. Only crashes, red error screens and lost doses
      block 1.0.0. Everything else goes to 1.0.1.
- [ ] Delete or fix `test/widget_test.dart`. It's still the default counter
      test and always fails. **(after Nov 1 OK)**

---

## 8. Closed test → production (Plan B; Plan A skips to the last step)

- [ ] Play Console → Testing → **Closed testing** → create a track and add
      the tester emails
- [ ] Upload the `.aab`, write release notes, and roll out to the closed track
- [ ] Send testers the opt-in link. **Check that 12+ show as opted in.** The
      14 days only count while 12 are opted in.
- [ ] Ask testers to actually use the app. Google asks about tester engagement
      in the production-access application.
- [ ] Fix anything serious. Upload new builds with a higher build number
      (`1.0.0+2`, …); the 14-day clock continues.
- [ ] Day 14+: Dashboard → **Apply for production access**, and answer the
      questionnaire about the test
- [ ] Once approved: Production → create a release → promote the tested
      build → **submit for review**

---

## 9. Launch day and after

- [ ] Install from the Play Store link on a clean phone and run S1–S7 again
- [ ] Keep `npx wrangler tail` open during the first day. Watch for
      `Too many subrequests` and `FCM rejected token`.
- [ ] Watch Firebase usage (Firestore → Usage) against the Spark limits
- [ ] Watch Play Console → Android vitals for crashes and ANRs
- [ ] Tag the release in git: `git tag v1.0.0 && git push origin v1.0.0` **(after Nov 1 OK)**
- [ ] Merge `dev` into `main` for the release **(after Nov 1 OK)**

---

## 10. Open items from the Oct 22, 2026 BLE decision

The medbox now talks to the patient's phone over **BLE, connect-on-demand**
(no Wi-Fi, no direct box-to-cloud link). Design details are pending
confirmation by Miko and Christian: see
[BLE_CONNECT_ON_DEMAND.md](BLE_CONNECT_ON_DEMAND.md). None of these is
decided or done.

- [ ] **Bluetooth permission.** The manifest has no Bluetooth permission
      today. BLE needs one; ask for it only when the user chooses to pair a
      box. Android 12+ and older devices use different permission flows
      (open question M5, owner **Miko**). Status: Not started / pending
      confirmation.
- [ ] **Data safety form and privacy policy check.** Before the production
      application (about Oct 29), check whether the Bluetooth permission and
      the box's dose events reaching Firestore through the phone change the
      Play listing, the Data safety answers or the privacy policy (M5, owner
      **Miko**). Status: Not started / pending confirmation.
- [ ] **Feature-freeze exception.** A BLE update shipped after the Oct 30
      freeze needs a team decision on a freeze exception (T-a, owner
      **Project Lead**). Status: Not started / pending confirmation.
- [ ] **Closed-test clock.** It is unconfirmed whether a new build resets
      the 12-tester, 14-day closed-test clock (T-b). Status: Not started /
      pending confirmation.
- [ ] **Fallback if BLE is not stable by about Oct 27:** ship the app
      without BLE and add it as a production update before Nov 10, if the
      freeze exception is allowed (T-c). Status: Not started / pending
      confirmation.
- [ ] **Fallback deployment evidence:** a hosted APK (T-d). Status: Not
      started / pending confirmation.
- [ ] **App access note for reviewers.** Play reviewers and closed testers
      cannot test the box, so the Play build is judged as app-only. The
      reviewer instructions in section 5 should not depend on a box. Status:
      Not started / pending confirmation.

> **Date conflict, not resolved here.** This file targets Nov 1 with
> "Oct 27: 14 days complete → apply for production access" (section 0). The
> Oct 22 plan has closed-test Day 14 about Oct 28, the production
> application about Oct 29 and READY BY Nov 10 at the latest. CLAUDE.md says
> Nov 30. See BLE_CONNECT_ON_DEMAND.md §9 (X8).

---

## Already done (Oct 9)

- [x] "Could not record this dose": dose-log read rule fixed and deployed
- [x] Caregiver alerts: retry pass, read cache, alert budget, push channel,
      token refresh and sign-out cleanup (see `CAREGIVER_ALERTS_FIX.md`)
- [x] Firestore rules and indexes deployed; Worker deployed
- [x] Dashboard showed Done/Skip for a dose already taken on phones not set
      to Manila time: cards now match their dose log by id
- [x] Service account key kept out of git (`.gitignore` line 50)
- [x] Target SDK 36 (meets Play's target API requirement)
