# Making the app seamless

> **Status (Oct 12, 2026): all six items implemented.** Decisions taken: the
> preview address for the legal links (kept in `AppStrings`, one line to
> change), the 1024×1024 logo, the welcome screen's sage-to-green backdrop for
> the splash, and "Add another medicine" returning to Manage medications.
> Passes `flutter analyze`; not yet checked on a phone, so the icon crop and
> the splash hand-off still need a look on a real device.

A plan for review before any code is written. For each item: what the code
does today (checked, not guessed), what will change, and the files touched.
Decisions that are yours to make are collected at the end.

| # | Item | Size |
|---|---|---|
| 1 | Terms & Privacy links open the real pages | Small |
| 2 | App logo as the launcher icon (and app name) | Small |
| 3 | Animated splash screen that flows into the app | Medium |
| 4 | "Shared with Guardian" card does nothing | Small |
| 5 | Back button on a tab closes the app | Small |
| 6 | "Add another medicine" after adding one | Small |

---

## 1. Terms & Privacy links open the real pages

**Today:** the "Terms" and "Privacy" links at the bottom of the welcome screen
have an empty tap handler (`// open terms` in `welcome_screen.dart`). They do
nothing, and they appear nowhere else in the app.

**Plan:**
- Add the `url_launcher` package. Links open in an **in-app browser tab**
  (Chrome Custom Tabs): the page slides up inside HealthSync with a close
  button, without leaving the app. No WebView package is needed.
- Keep both addresses in one place (`AppStrings.termsUrl`,
  `AppStrings.privacyUrl`).
- Wire them in three places:
  1. the welcome screen footer (the links that exist now);
  2. the **About HealthSync** sheet (patient and care partner);
  3. care partner **Settings** and patient **Settings**, under a new "Legal"
     row, so they can be found after sign-up too. Google Play also expects the
     privacy policy to be reachable from inside the app.
- If no browser can open the link, show a snackbar with the address.

**Which address:** the links you sent are a Cloudflare Pages *preview* address
(`5f45d49d.healthsync-site.pages.dev`). That address is tied to one deployment
and never changes, so an updated policy would not show up there. The permanent
address `https://healthsync-site.pages.dev/terms/` (and `/privacy/`) also works
(both return 200). **I recommend the permanent one.**

**Files:** `pubspec.yaml`, `app_strings.dart`, `welcome_screen.dart`,
`about_healthsync_sheet.dart`, both settings screens, a small
`lib/services/link_service.dart` (so screens don't call the plugin directly).

---

## 2. App logo as the launcher icon (and app name)

**Today:** `HealthSyncLOGO.png` sits in the project root and is not used. The
phone shows the default Flutter icon, and the app name under the icon is
lowercase **"healthsync"** (`android:label` in `AndroidManifest.xml`).

**Plan:**
- Move the logo to `assets/branding/healthsync_logo.png`.
- Use the `flutter_launcher_icons` package (a build-time tool, not shipped in
  the app) to generate every launcher icon size, including Android's
  **adaptive icon** (the shape-masked icon on Android 8+). The adaptive icon
  uses the logo as the foreground on a mint background (`greenLight`
  `#E4F7F0`) so it blends with the logo's colours.
- Rename the app label to **HealthSync**.
- The same image becomes the centre of the system splash (item 3).

**Two things to know about the logo file:**
- **It's 480×480.** That's fine for launcher icons, but the **Google Play
  store listing needs a 512×512 icon**. A larger original (1024×1024) would
  also look sharper on high-resolution phones.
- **It's cropped:** the mascot peeks in from the bottom-left corner. Launchers
  mask icons to a circle or squircle, which can cut off part of the face. I'll
  generate it, check it on your phone and show you. If the crop looks wrong,
  the fix is a version of the logo with the mascot centred and some space
  around it.

**Files:** `pubspec.yaml` (dev dependency and icon config),
`AndroidManifest.xml`, generated files under `android/app/src/main/res/`.

---

## 3. Animated splash screen that flows into the app

**Today:** opening the app shows Android's plain white launch screen while
Firebase starts, then a loading state while the sign-in and profile load, then
the first screen just appears.

**How Android splash screens work (this decides the design):** every Android
12+ phone **always** shows a system splash for the first moment: the app icon
on a solid colour, and that part can't be animated by the app. The animation
comes right after it, drawn by Flutter. Done well, the two look like one
continuous screen.

**Plan, in three stages:**

1. **System splash (Android draws it).** Using the `flutter_native_splash`
   package, it shows the logo on the same deep green as the welcome screen
   instead of white. Covers Firebase starting up (well under a second).

2. **Animated splash (Flutter draws it).** It's the same green, with the
   HealthSync mascot in the centre. The mascot is already drawn in code
   (`FloatingMascot`) with built-in motion, so it can move rather than being a
   still image. While the app loads the user's sign-in and profile it:
   - pops in, then bobs and breathes;
   - blinks, and its heart beats;
   - shows a soft pulsing ring underneath as the loading cue (no spinner).

   It stays at least ~1.2 seconds so the animation is seen, and never longer
   than the loading actually takes after that.

3. **The hand-off, depending on where the user goes:**
   - **Signed out → Welcome screen:** the welcome screen has the same mascot,
     so the splash mascot **glides and shrinks into the welcome mascot's exact
     spot**. The welcome headline and buttons then rise in, as they already do
     today. It reads as one screen settling into place, not two screens
     swapping.
   - **Signed in → dashboard:** the mascot **zooms toward the viewer and fades
     out** while the dashboard fades in behind it.

If the phone's "Remove animations" accessibility setting is on, the splash
shows the mascot standing still and switches with a simple fade.

**Files:** new `lib/screens/auth/splash_screen.dart`, `main.dart` (AuthGate's
`checking` / `loadingProfile` states show the splash, and the switch to the
next screen runs the transition), `welcome_screen.dart` (accepts "arriving
from the splash" so its mascot starts from the splash position),
`floating_mascot.dart` (a loading pose), `pubspec.yaml` (native splash config),
generated Android splash resources.

---

## 4. "Shared with Guardian" card does nothing

**Today:** on the patient's **Adherence Analytics** screen, the card is plain
text with no tap action. Its subtitle, *"Caregiver is receiving weekly
reports"*, is also **not true**: nothing sends weekly reports. The care
partner sees the patient's doses live and gets alerts. Under the "no phantom
features" rule, the text must change as well as the tap.

**Plan:**
- Make the card tappable. It opens a sheet titled **"What your care partner
  sees"**, with:
  - the care partner's name;
  - "Your doses and adherence, live" (what's taken, missed or skipped);
  - "Alerts when a dose is late or missed, and when medicine runs low";
  - "Only your care partner can change your medicines";
  - a note that the patient can see the same numbers on this screen.
- New subtitle: **"Your care partner sees your doses live"**. If the patient
  isn't linked to a care partner: "No care partner linked".
- Small fix on the same screen: *"1 doses successfully taken"* becomes
  *"1 dose taken"* (singular and plural handled).

**Files:** `analytics_screen.dart`.

---

## 5. Back button on a tab closes the app

**Today:** neither main screen (`patient_main_screen.dart`,
`caregiver_main_screen.dart`) handles the system Back button. On any tab
(Profile, Alerts, …) Back leaves the app at once.

**Plan:** both main screens catch Back (Flutter's `PopScope`):
- on any tab other than **Home**, Back switches to the **Home** tab;
- on **Home**, Back closes the app as usual.

Screens opened on top of a tab (patient detail, settings, …) are unaffected:
Back still closes them first, as now.

**Files:** `patient_main_screen.dart`, `caregiver_main_screen.dart`.

---

## 6. "Add another medicine" after adding one

**Today:** after step 3 the success screen has one button, **"Done · View
Schedule"**, which closes the wizard and returns to the **Manage medications**
screen it started from.

**Plan:** two buttons on the success screen:
| Button | Goes to |
|---|---|
| **Add another medicine** (outlined, secondary) | Closes the wizard and returns to **Manage medications** for this patient, which lists what was just added, with its add button ready |
| **Done** (filled, main) | Closes everything and returns to the care partner's **dashboard (Home tab)** |

"Done" needs a small addition: the care partner's main screen gains a way to
be told "switch to Home", because the user may have started from the Patients
tab. Item 5 needs the same switch, so it is shared.

**Files:** `add_medicine_success_screen.dart`, `caregiver_main_screen.dart`.

---

## Order of work

1. Item 5: back button (smallest, and item 6 reuses its tab switch)
2. Item 6: add another medicine
3. Item 4: Shared with Guardian
4. Item 1: Terms & Privacy
5. Item 2: logo and app name
6. Item 3: splash (largest, and uses the logo from item 2)

Then: `flutter analyze`, a release APK, and a check on your phone, especially
the icon crop and the splash transition, which can only be judged on a real
device.

---

## Decisions for you

1. **Legal links:** use the permanent `healthsync-site.pages.dev` address
   (recommended), or the preview address you sent?
2. **Logo:** do you have a bigger version (1024×1024), ideally with the mascot
   centred? If not, I'll use the 480×480 one and you can check the crop on the
   phone.
3. **Splash colour:** the welcome screen's deep green (recommended, so the
   splash flows straight into it), or white?
4. **"Add another medicine":** return to **Manage medications** (as you asked),
   or jump straight to **step 1** of a new medicine? Manage medications shows
   what's already added; step 1 is one tap faster.
