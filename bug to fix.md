# TASK: Resolve 10 Verified Bugs in HealthSync Flutter App
## Context & Repository Architecture
HealthSync is a Flutter medication adherence app for BSIT Capstone.
- Framework: Flutter / Dart (Android)
- Backend: Firebase Firestore, Firebase Auth, FCM, Cloudflare Worker backend
- State Management: Provider (`AuthProvider`, `PatientProvider`, `CaregiverProvider`, `ScheduleProvider`)
- Key files: `lib/providers/`, `lib/screens/patient/`, `lib/screens/caregiver/`, `lib/services/`
---
## Issues to Fix
### 1. Fix Schedule Times Resetting in Add Medicine Wizard
- **Problem**: When a user adds medicine with dose times (e.g., 06:00 AM, 12:00 PM, 06:00 PM), the step 3 success card displays `"Scheduled Times: 08:00 AM"` instead.
- **Root Cause**: In `lib/providers/schedule_provider.dart`, `saveNewMedication()` calls `resetForm()` right before returning `true`. `resetForm()` wipes `_scheduledTimes` to `['08:00 AM']`. In `lib/screens/patient/add_medicine_step3_screen.dart`, `AddMedicineSuccessScreen` reads `scheduleProvider.scheduledTimes`, which has already been wiped.
- **Fix**: Cache the medicine name and scheduled times locally in `add_medicine_step3_screen.dart` before calling `saveNewMedication()`, or defer `resetForm()` until `AddMedicineSuccessScreen` is dismissed. Pass the actual saved times to `AddMedicineSuccessScreen`.
---
### 2. Fix Red Screen Crash (`_dependents.isEmpty: is not true`) on Archive Permanent Delete
- **Problem**: In `ArchivedMedicinesScreen`, entering `DELETE` and pressing "Delete for good" deletes the record, but crashes with: `'package:flutter/src/widgets/framework.dart': Failed assertion: line 6281: '_dependents.isEmpty': is not true`.
- **Root Cause**: In `lib/screens/caregiver/archived_medicines_screen.dart` (`_permanentlyDelete`), `final controller = TextEditingController()` is disposed immediately on `controller.dispose()` right after `await showDialog(...)` returns. The dialog is still animating out, and disposing the controller during teardown breaks Flutter's element tree.
- **Fix**: Move the dialog into a standalone `StatefulWidget` (e.g. `_ConfirmDeleteDialog`) where the `TextEditingController` is initialized and disposed in `State.dispose()`, or defer `controller.dispose()` until after the route transition finishes.
---
### 3. Fix Red Screen Crash on Edit Profile Cancel / Save
- **Problem**: In Caregiver Settings -> Edit profile dialog, tapping "Cancel" or "Save" crashes with `'package:flutter/src/widgets/framework.dart': Failed assertion: '_dependents.isEmpty': is not true`. Tapping "Cancel" also incorrectly displays `"Profile update failed."`.
- **Root Cause**: In `lib/screens/caregiver/caregiver_settings_screen.dart` (`_editProfile`), `first`, `last`, and `phone` `TextEditingController`s and `GlobalKey<FormState>` are instantiated locally and disposed immediately after `await showDialog(...)`. Tapping Cancel pops `false`, triggering `_showMessage(auth.errorMessage ?? 'Profile update failed.')`.
- **Fix**:
  1. Extract Edit Profile into a dedicated `StatefulWidget` dialog (`_EditProfileDialog`) that manages its own controllers and `dispose()`.
  2. Have Cancel pop `null` (or dismiss without returning `false`), and only show an error if `saved == false` AND an actual update attempt failed.
---
### 4. Fix Inaccurate "Due now" Status Badge
- **Problem**: On the patient dashboard, a dose scheduled for 6:00 AM shows `"Due now"` even at 1:00 AM.
- **Root Cause**: In `lib/screens/patient/patient_dashboard_screen.dart` (`_DoseStatusChip`), if a dose log exists and is not taken, missed, or snoozed, the code unconditionally falls back to `label = 'Due now'` without checking current time against the scheduled dose time.
- **Fix**: Check `now` against `sch.scheduledTime` or `log.scheduledAt`:
  - If current time is earlier than 15-30 minutes before dose time: label as `'Upcoming'` (`AppColors.upcomingBlue`).
  - If current time is within [doseTime - 15m, doseTime + 30m]: label as `'Due now'` (`AppColors.pendingAmber`).
  - If more than 30m past without confirmation: handle according to missed/pending status.
---
### 5. Fix RenderFlex Overflow Text in Medicine Box Compartments Grid
- **Problem**: In `MedicineBoxStatusScreen`, yellow and black stripes with overflow text (`BOTTOM OVERFLOWED BY X PIXELS`) appear under the compartment tiles.
- **Root Cause**: In `lib/screens/patient/medicine_box_status_screen.dart`, `GridView.count` has `childAspectRatio: 0.82`, `crossAxisCount: 4`, and `padding: 10`. The tile elements (Icon, Col number, 2-line medicine name, pills left) exceed the allotted ~75px vertical height.
- **Fix**:
  - Adjust `childAspectRatio` to `0.70` (or `0.72`) to provide adequate vertical height.
  - Decrease internal padding of `_CompartmentTile` to `EdgeInsets.symmetric(horizontal: 6, vertical: 8)`.
  - Wrap tile texts with `Flexible` or ensure proper line clamping.
---
### 6. Fix Rapid Snooze Abuse (Immediate 3-Snooze Missed Dose)
- **Problem**: Users can tap "Snooze 10m" 3 times in immediate succession, instantly reaching `(3/3)` and causing the dose to be marked missed immediately.
- **Root Cause**: Neither `DoseAlertScreen` nor `PatientProvider` enforces a cooldown or wait period for an active snooze. Once snoozed, the user can immediately reopen the dose alert and snooze again.
- **Fix**:
  - In `lib/screens/patient/dose_alert_screen.dart` and `lib/providers/patient_provider.dart`:
  - When a dose is currently snoozed and the 10-minute snooze duration has not yet passed, disable the snooze button or show `"Snooze active (reminding at <time>)"`.
  - Only allow snoozing again when the scheduled snooze reminder has fired or the 10-minute duration has elapsed.
---
### 7. Prevent "Mark Dose as Taken" When Pills Remaining is 0
- **Problem**: In `MedicineDetailScreen` (and `DoseAlertScreen`), when `pillsRemaining == 0`, `"Mark Dose as Taken Now"` remains clickable. It marks the dose as taken, decrements by 0, and notifies the caregiver that the patient took their medicine.
- **Root Cause**: `lib/screens/patient/medicine_detail_screen.dart` does not check `currentSchedule.pillsRemaining > 0`, and `patient_provider.dart` (`confirmDoseTaken`) proceeds to notify the caregiver even when stock is 0.
- **Fix**:
  - In `lib/screens/patient/medicine_detail_screen.dart` and `dose_alert_screen.dart`: If `currentSchedule.pillsRemaining <= 0`, disable the "Mark Dose as Taken" button and display a badge/message: `"Out of stock · Refill required"`.
  - In `lib/providers/patient_provider.dart` (`confirmDoseTaken`): Check `schedule.pillsRemaining <= 0`. If 0, prevent marking as taken, set `_errorMessage = 'No pills remaining. Please refill compartment.'`, and return `DoseActionResult.failed`.
---
### 8. Wire Up Low Stock Alert Notifications
- **Problem**: When pills run low (below low stock threshold, e.g. 5 pills), no low stock alert is triggered or received.
- **Root Cause**: `NotificationService.sendLowStockAlert()` in `lib/services/notification_service.dart` exists, but has 0 callers across the entire codebase.
- **Fix**:
  - In `lib/providers/patient_provider.dart` inside `confirmDoseTaken()`:
  - After decrementing pills, check if `(schedule.pillsRemaining - 1) <= schedule.lowStockThreshold`.
  - If threshold is reached, trigger `NotificationService().sendLowStockAlert(...)` for the user, and notify the caregiver if linked.
---
### 9. Replace Endless Flutter License Screen with Custom About/Licenses Modal
- **Problem**: Clicking "About HealthSync" opens Flutter's default `LicensePage`, which lists hundreds of C++/Dart engine packages in an endless scroll view.
- **Root Cause**: `lib/screens/patient/settings_screen.dart` and `lib/screens/patient/patient_profile_screen.dart` call Flutter's built-in `showAboutDialog()`.
- **Fix**: Replace `showAboutDialog()` in `showAboutHealthSync(BuildContext context)` with a sleek, clean custom dialog/sheet that displays:
  - App Name & Version (`HealthSync 1.0.0`)
  - Project Title & NTC Manila BSIT Capstone 2025-2026 details
  - Team members
  - A clean, concise software license & attribution summary without opening the infinite Flutter engine license list.
---
### 10. Refine & Streamline Notification Alerts & Navigation Clutter
- **Problem**: Feedback indicates navigation and notification buttons feel cluttered and overcrowded (`"4 notif alerts need bawasan kasi andami nang button masyado"`).
- **Fix**:
  - Review `FloatingNavBar` in `lib/widgets/shared/floating_nav_bar.dart` and `patient_main_screen.dart`: ensure clean spacing, subtle unread pill badges, and avoid redundant action buttons on notification cards in `NotificationsScreen` and `CaregiverAlertsScreen`.
  - Consolidate settings toggles in `lib/screens/caregiver/caregiver_settings_screen.dart` and `settings_screen.dart` so they are intuitive and uncluttered.
