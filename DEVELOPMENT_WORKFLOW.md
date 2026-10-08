# HealthSync — Development Workflow

**Target:** Google Play Store publication by **November 30, 2026**
**Today:** October 5, 2026 — **8 working weeks remain**
**Branch:** `dev` → merge to `main` only for release builds

---

## Decisions locked in

| Question | Decision |
|---|---|
| Managed-patient OTP login | **Cloudflare Worker + Firebase custom token.** The Worker pre-creates the patient Auth account, validates the OTP, and mints a custom token the app signs in with. |
| Backend hosting | **Firebase stays on the free Spark plan.** Cloud Functions cannot deploy on Spark at all, so the four server-side jobs move to a **Cloudflare Worker** (free plan, no credit card, cron triggers included). Total cost: ₱0. |
| Solo user | ~~Full third role~~ — **removed October 2026.** Scaffolded but never documented in the capstone paper or fully built. Caregiver is the only self-registering account. |
| Plan priority | **Shippable app by Nov 30.** Phases ordered by what blocks a Play Store release. |

**What the Worker exists to do.** Three things need a private key that must never ship inside the APK, and one needs a clock that runs when every phone is asleep:

1. Minting Firebase **custom tokens** (RS256-signed with the service account key) — the only way to log a patient in with no password.
2. Creating patient Auth accounts via the Identity Toolkit admin API.
3. Sending **FCM HTTP v1** messages to another user's device, which needs an OAuth token from the service account. A client app can never do this; the legacy server-key API was retired in 2024.
4. Running the **missed-dose sweep** on a schedule, because the 30-minute rule has to fire whether or not anyone's app is open.

Everything else — all reads, all writes the user is allowed to make — goes straight from Flutter to Firestore as it does today. The Worker is a small privileged sidecar, not a backend the app routes through.

---

## Where the code actually stands

85 Dart files exist and the screens are real implementations, not stubs (200–480 lines each). But the codebase implements the **old flow**, not the one in `CLAUDE.md`:

**Built and working**
- 10 Firestore models, `firestore_service.dart` (471 lines), 4 providers, Firestore rules, FCM wiring
- Auth: welcome, role select, register, login, forgot password, email verification
- 24 patient screens, 18 caregiver screens, 9 shared widgets

**The gap — old flow vs. CLAUDE.md spec**

| `CLAUDE.md` says | Code does |
|---|---|
| Caregiver creates the patient account | Patient self-registers with email + password |
| Caregiver generates OTP, patient enters it | Patient generates invite code, caregiver enters it (`linkByInviteCode()`) |
| `otp_codes` collection, 48h expiry, one-time use | No `otp_codes` collection at all |
| ~~Three roles including solo~~ | `UserModel.role` is patient or caregiver only — **this gap closed from the other side:** the solo role was removed in Oct 2026, so two roles is now correct |
| `account_type`, `can_edit_medications` fields | Neither field exists on `UserModel` |
| Server-side missed-dose sweep | No server-side component of any kind yet |

**Spec contradiction to resolve in Phase 5:** `CLAUDE.md` says both "ESP32 sets `led_active: true`" *and* "ESP32 polls `led_active`". It cannot be both. This workflow assumes **the app or the Worker writes `led_active`, and the ESP32 polls and obeys it** — the phone knows the real time and the schedule; the box is a display. Update `CLAUDE.md` to match.

---

## Phase 0 — Unblock (Oct 5–7, 2 days)

Nothing else can start until these are done.

1. **Firebase stays on Spark.** Do not upgrade. Confirm the free quotas cover you: 50k Firestore reads/day, 20k writes/day, 50k monthly auth users, unlimited FCM. You will not come close.
2. **Generate the service account key.** Firebase console → Project settings → Service accounts → Generate new private key. This JSON is the credential that lets the Worker mint tokens and send FCM. **It must never enter the repo or the APK.** Add `*serviceAccount*.json` and `.dev.vars` to `.gitignore` before you download it.
3. **Create the Cloudflare account and Worker.** Free plan, no card. `npm create cloudflare@latest healthsync-api` → Worker, TypeScript. Then `npx wrangler deploy` to confirm a hello-world responds.
4. **Load the key as a secret, not a file:** `npx wrangler secret put FIREBASE_SA_KEY` and paste the whole JSON. For local dev put it in `.dev.vars`, which is gitignored.
5. **Create a KV namespace** for caching OAuth access tokens: `npx wrangler kv namespace create TOKEN_CACHE`. Without this cache you re-sign a JWT on every request and will hit the 10 ms CPU ceiling.
6. Baseline the code health: `flutter analyze > analyze-baseline.txt`. Fix anything that is an **error**; leave warnings for Phase 9.
7. `CLAUDE.md` is now in the repo root (it was only in Downloads, so Claude Code never auto-read it). Commit it, and correct its tech-stack row from "Cloud Functions" to "Cloudflare Workers".

**Done when:** a deployed Worker URL returns a hello-world response, and `flutter analyze` reports zero errors.

### The three Worker limits that shape the design

Free plan, and all three are real constraints rather than trivia:

- **10 ms CPU per invocation** — including cron runs. Network waiting does *not* count, so `fetch()` time is free; only your own computation counts. RSA signing is ~1–3 ms of that budget, which is why the OAuth token gets cached in KV for ~55 minutes instead of being re-minted per request.
- **50 external subrequests per invocation** — so the sweep must use one `:runQuery` call and one batched `:commit` call, not one write per document.
- **100,000 requests/day** — irrelevant at your scale. A 5-minute cron is 288 runs/day.

---

## Phase 1 — Data layer for three roles (Oct 8–12, 5 days)

Pure model and rules work. No UI. Do this before any screen, or every screen gets rewritten.

1. `UserModel` — add `accountType` (managed / solo / caregiver) and `canEditMedications` (bool). Add getters `isSolo` and `isManaged`. Keep `role` for backward compatibility. *(Done. `solo` and `isSolo` have since been removed with the role.)*
2. New `lib/models/otp_code_model.dart` matching the `otp_codes` schema in `CLAUDE.md`.
3. `firestore_service.dart` — add `createOtpCode()`, `getOtpCodeByCode()`, `markOtpUsed()`. **Do not delete** `linkByInviteCode()` or `generatePatientInviteCode()` yet; mark them `@Deprecated` and remove in Phase 9 once the OTP path is proven.
4. `firestore.rules` — add an `otp_codes` block: caregivers create, **nobody reads or updates from the client at all** (the Worker reads it with admin privileges, which bypass rules). A client-readable `otp_codes` collection would be a brute-forceable list of account keys. Gate `patient_medications` and `schedules` writes on `can_edit_medications`.
5. `firestore.indexes.json` — add the composite indexes the dose-log and schedule queries need. Run the app and copy the index URLs Firestore prints to the console.

**Done when:** rules pass `firebase emulators:exec --only firestore` with a test proving a managed patient cannot write to `patient_medications`.

---

## Phase 2 — The Worker (Oct 13–19, 1 week)

Build the shared plumbing first — every endpoint depends on it — then the four jobs.

### 2a. Plumbing (days 1–2)

- **`getAccessToken()`** — build a JWT (`aud: https://oauth2.googleapis.com/token`, scopes `datastore` + `firebase.messaging`), sign RS256 with the service account key via WebCrypto `importKey` on the PKCS8 private key, POST to Google's token endpoint. **Cache the result in KV for 55 minutes.** This one function is the difference between fitting in 10 ms CPU and not.
- **`verifyIdToken()`** — fetch and cache Google's public certs, then verify the RS256 signature plus `aud`, `iss` and `exp`. Needed so the Worker can trust "this request really is from that signed-in patient."
- **`firestore(method, path, body)`** — thin wrapper over the Firestore REST API, including `:runQuery` and batched `:commit`.

### 2b. The four jobs (days 3–5)

1. **`POST /patients`** — caller must be a caregiver (verify their ID token, check `account_type`). Creates the patient Auth account via the Identity Toolkit admin API with a random password nobody ever sees, writes the `users` and `patient_profile` docs, returns the new uid.
2. **`POST /otp/redeem`** — unauthenticated, takes a code. Checks `used == false` and `expires_at > now`, flips `used: true`, and returns a **Firebase custom token** (a JWT with `aud: https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit`, the patient's `uid` claim, 1-hour expiry, signed with the service account key). The app then calls `signInWithCustomToken()`. **The entire managed-patient flow rests on this endpoint — write its tests first.**
3. **Cron `*/5 * * * *` — the missed-dose sweep.** One `:runQuery` for `pending` logs older than 30 minutes, one batched `:commit` to set them `missed` and `led_active: false`, then the caregiver FCM sends. Cap the batch at ~40 docs per run to stay inside both the CPU and subrequest limits; at 288 runs a day that is far more headroom than you need.
4. **`POST /dose-events`** — **this one replaces a Firestore trigger, which Spark cannot give you.** When a patient confirms or misses a dose, the app calls this with its ID token; the Worker sends the caregiver's FCM and writes the `notifications` doc. Design note: the dose log itself is still written directly from the app to Firestore, so **a failed Worker call must never lose the dose confirmation.** Write to Firestore first, then call the Worker fire-and-forget; the cron sweep is the backstop if the call fails.

### Security must-haves

- **Rate-limit `/otp/redeem`** by IP — it is your only unauthenticated endpoint and it grants account access. Cloudflare's own rate limiting rules are free.
- Lock CORS to nothing. This is called from a native app, not a browser.
- Generate OTP codes with **8 characters** from an unambiguous alphabet (no `0`/`O`, no `1`/`I`/`l`). `HS` + 6 random gives ~2.2 billion combinations.
- Every endpoint except `/otp/redeem` verifies an ID token and re-checks the caller's role server-side. Never trust a role passed in the request body.

**Done when:** you can insert an `otp_codes` doc by hand in the Firebase console, `curl` your Worker's `/otp/redeem`, get a custom token back, and exchange it for a real session with the Firebase Auth REST API.

---

## Phase 3 — Auth flows (Oct 20–26, 1 week)

Now the UI, against a data layer that already works.

- `welcome_screen.dart` — rework to a **three-way** split: "I'm a caregiver" / "I have a code" / "Just for myself". It is currently a two-way patient/caregiver split.
- `otp_entry_screen.dart` — **new.** Eight-character code entry, POSTs to the Worker's `/otp/redeem`, then `signInWithCustomToken()`. No email field, no password field, no forgot-password link. Handle all three failure modes distinctly: wrong code, expired code, already-used code.
- New `lib/services/api_service.dart` — the only place the app talks to the Worker. The Worker base URL belongs in a `--dart-define`, not hardcoded, so you can point at a local `wrangler dev` while developing.
- `otp_success_screen.dart` — **new.** Shows the patient their name and their pre-loaded schedule, then goes straight into `PatientMainScreen`.
- `role_select_screen.dart` — add the solo option (currently hardcoded to patient and caregiver). *(Done, then reverted: the solo card was removed with the role, leaving caregiver as the only self-registering option.)*
- `register_screen.dart` — accept `role: 'solo'`, set `account_type: 'solo'` and `can_edit_medications: true`. *(Superseded: the form is caregiver-only and rejects any other role.)*
- `main.dart` `AuthGate` — route on `accountType`, not `role`: managed to patient screens read-only, caregiver to caregiver screens. Skip the email-verification gate for managed patients, who have no real email. *(The solo branch was removed with the role.)*

**Done when:** on a real device you can go caregiver signup → create patient → generate code → install on a second device → enter code → land on a dashboard with the schedule already there. **This is the capstone's core claim. Demo it to your adviser this week.**

---

## Phase 4 — Caregiver authoring (Oct 27–Nov 2, 1 week)

The caregiver is the only one who can author medications, so these screens are load-bearing.

- `add_patient_screen.dart` — **new.** Name, phone, conditions, allergies, emergency contact, then calls the Worker's `POST /patients`.
- `setup_medications_screen.dart` — **new.** Reuse the `add_medicine_step1/2/3` screens, but writing to the *patient's* uid instead of the caregiver's own.
- `generate_otp_screen.dart` — **new.** Big readable code, 48-hour countdown, share sheet for SMS or email, regenerate button.
- `my_patients_screen.dart` — currently 78 lines and the thinnest caregiver screen. Needs per-patient adherence percentage, a pending-link state, and an "awaiting first login" badge.

**Done when:** a caregiver can take a patient from nonexistent to fully scheduled without touching the Firebase console.

---

## Phase 5 — The dose loop (Nov 3–9, 1 week)

The feature the project is graded on. All screens exist; they need wiring to real data.

- Local notification scheduling from `schedules` via `flutter_local_notifications` with exact alarms. **Android 13+ needs `POST_NOTIFICATIONS` at runtime and Android 14+ needs `SCHEDULE_EXACT_ALARM`** — budget a day for permission plumbing alone.
- `dose_alert_screen.dart` → Take / Snooze / Skip, writing `dose_logs`.
- Snooze: 10-minute re-trigger, max 3, then `missed`. Enforce the cap in the app *and* in the Worker's cron sweep.
- `led_active` lifecycle: set `true` at dose time, `false` on confirm or on miss.
- `medicine_box_status_screen.dart` → live 8-column view off the `devices` and `schedules` streams.

**Done when:** a scheduled dose fires a notification on a locked phone, confirming it updates Firestore, and the caregiver's phone gets the alert.

---

## Phase 6 — Solo role — REMOVED (Nov 10–13 freed)

**The solo role was cut in October 2026 and will not be built.** It was
scaffolded only and was never documented in the capstone paper, so removing it
cost nothing downstream. Caregiver is the only self-registering account; a
patient always arrives with a code from their caregiver.

Neither `solo_dashboard_screen.dart` nor `solo_analytics_screen.dart` was ever
created. The purple accent stays in `app_colors.dart` as `streakPurple`, which
is what actually uses it — the streak notification type.

A follow-up sweep removed what the role left behind: patient-side Add / Edit /
Delete medicine buttons (the add, edit and delete screens remain, reached only
from the caregiver's `setup_medications_screen`), the now-unreachable
`patient_profile_setup_screen.dart`, the patient branch of email verification,
and the `isOwner` path in the `mayAuthorFor()` Firestore rule.

The four days this phase held are now slack, which the schedule previously had
none of. Spend them on Phase 7 (ESP32), historically the phase most likely to
overrun.

---

## Phase 7 — ESP32 integration (Nov 14–20, 1 week)

Hardware comes late deliberately: it can be demoed from a working app, and it is the part most likely to eat a week.

1. **Route the ESP32 through the Worker, not straight to Firestore.** `CLAUDE.md` currently says the box authenticates with a Firebase service account key. Don't — anyone who desolders the flash chip gets admin access to every patient's data, and a panelist may well ask about exactly that. Instead give each box a device secret, add `GET /device/{serial}/schedule` and `POST /device/{serial}/dose` to the Worker, and let it hold the privileged key. Firmware gets simpler too: no OAuth dance, no JWT signing on a microcontroller.
2. Firmware polls the Worker every 30s and drives the 8 LEDs on the GPIO pins listed in `CLAUDE.md`.
3. Push button on GPIO 5 posts to the Worker, which writes the `dose_logs` doc with `confirmed_via: "button"` and fans out the caregiver FCM.
4. Offline: DS3231 fires locally, microSD queues the log, flush to Firestore on reconnect with the **original** timestamp, not the sync time.
5. `devices.status` and `last_sync` heartbeat so the app can show online/offline honestly.

**Done when:** the physical box lights the right LED at the right time, the button marks the dose taken in the app, and a dose taken with Wi-Fi unplugged appears correctly after reconnect.

---

## Phase 8 — Adherence, reports, polish (Nov 21–25, 5 days)

- Adherence percentage calculation, shared by `analytics_screen`, `patient_analytics_screen`, and `reports_screen`. Write it **once** in a util, not three times.
- Low-stock threshold triggering FCM to both parties — folded into the Worker's existing cron run, not a second schedule.
- Streak logic for the `streak` notification type.
- Empty states and error states on every screen. `snackbar_helper.dart` already exists — use it everywhere.
- Fix everything in `analyze-baseline.txt`.

---

## Phase 9 — Release (Nov 26–30, 5 days)

1. Remove the deprecated invite-code methods from `firestore_service.dart`.
2. Switch Firestore from **test mode to locked rules**. Test-mode rules expire and will break the app in the store — verify every flow still works after the switch.
3. **Audit the repo for the service account key** before the first public build: `git log -p --all | grep -i "private_key"`. If it was ever committed, rotate the key in the Firebase console — deleting the file is not enough, because git history keeps it.
4. Confirm the Worker's production URL is what the release build is compiled against, and that rate limiting is live on `/otp/redeem`.
5. App icon, splash, store listing, screenshots, privacy policy. The privacy policy is required, not optional, because this app handles medical data.
6. `minSdkVersion 21` per `CLAUDE.md`; generate the upload keystore and **back it up off-machine** — lose it and you can never update the app.
7. `flutter build appbundle --release`, then internal testing track first, then production.
8. Submit by **Nov 26** at the latest. Google review takes up to 7 days and there is no appeal for a missed deadline.

---

## Schedule at a glance

| Week | Dates | Phase |
|---|---|---|
| 1 | Oct 5–12 | 0 Unblock + 1 Data layer |
| 2 | Oct 13–19 | 2 Cloudflare Worker |
| 3 | Oct 20–26 | 3 Auth flows ← **core demo milestone** |
| 4 | Oct 27–Nov 2 | 4 Caregiver authoring |
| 5 | Nov 3–9 | 5 Dose loop |
| 6 | Nov 10–13 | ~~6 Solo role~~ — removed; days are now slack |
| 7 | Nov 14–20 | 7 ESP32 |
| 8 | Nov 21–25 | 8 Polish |
| 8 | Nov 26–30 | 9 Release |

**Slack is now four days**, freed by removing the solo role. If a phase slips beyond that, the cut list in priority order is: ESP32 offline sync (7.4), then streaks and low stock (Phase 8). Never cut Phase 2 or Phase 9.

---

## Working rules for each session

1. One phase per branch off `dev`. Commit at each "Done when".
2. `flutter analyze` before every commit.
3. Never call Firebase from a widget — services only (`CLAUDE.md` coding standard 2).
4. Never hardcode a hex colour — `AppColors` only.
5. Update the screen checklist in `CLAUDE.md` as screens land. It is currently wrong: many screens marked `[ ]` are in fact built.
6. Test on a **real Android device**, not just the emulator. Notifications, exact alarms, and Wi-Fi behaviour all differ.
