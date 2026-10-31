# HealthSync App Fixes & Refinement Master Prompt

This document contains structured instructions, issue context, and concrete system prompts designed for Claude to debug, implement, and refine the HealthSync app based on your QA and design feedback notes.

---

## 🛠 Task Breakdown & Analysis

### 1. Authentication & Email Verification
- **Issue:** The "Use other account" button on the verification screen is unresponsive.
- **Root Cause:** Tapping the button fails to sign out and clear the session, causing the screen to reload the unverified state for the same user.
- **Fix Required:**
  - Call `signOut()` and reset local session state.
  - Route back to the Login screen while clearing the navigation back stack.
  - Add a "Resend Email" button with a 30–60 second cooldown.
  - Add a "Change Email" flow.
  - Implement an app resume lifecycle listener to auto-check email verification status when the user returns to the app.

### 2. Sign Out & Destructive Action Dialogs
- **Issue:** Care partner sign-out triggers immediately without confirmation.
- **Fix Required:**
  - Add a confirmation modal/dialog: *"Are you sure you want to sign out of HealthSync?"* (`Cancel` / `Sign Out`).
  - Standardize confirmation dialog components across all destructive actions (e.g., delete medicine, remove patient, delete account).

### 3. Care Partner Request Handling (Decline Request Fix)
- **Issue:** Care partner cannot decline a patient's delete request.
- **Root Cause:** Role/permission mismatch or unhandled database state transition.
- **Fix Required:**
  - Explicitly model request status: `pending`, `approved`, `declined`, `expired`.
  - Handle state transitions securely via backend validation (e.g., Cloud Function or Row Level Security rules).
  - Send status notification back to the patient upon resolution ("Declined by care partner").

### 4. Care Partner Dashboard Expansion
- **Issue:** Care partner dashboard currently only displays the patient's name.
- **Enhancement Suggestions:**
  - Visual adherence tracker / daily dose completion summary.
  - Upcoming scheduled doses for today.
  - Missed doses & alert history.
  - Patient device status (e.g., notification permissions, last active time, optional HealthSync LED Box connectivity/battery level).

### 5. Onboarding & System Health Check
- **Enhancement:**
  - Add a proactive system setup check during onboarding to verify Notification Permissions, Exact Alarm permissions (Android), and Battery Optimization settings.
  - Provide inline guidance to help patients grant necessary permissions for reliable reminders.

### 6. App Onboarding Copy & Positioning Adjustments
- **Issue:** Taglines overclaim functionality (e.g., "Smart LED visual guidance" implies hardware is required, "Never miss a dose again" makes an absolute promise).
- **Copy Changes:**
  - **Main Headline:** "Stay on top of every dose."
  - **Subline:** "Medicine reminders and missed-dose alerts for you and your care partner."
  - Optional hardware badge: *"Works with the optional HealthSync medicine box."*

---

## 🤖 Master Prompt for Claude

Copy and paste the prompt below directly into Claude to initiate the code fixes and design implementation.

```text
You are an expert mobile developer and technical product manager working on the HealthSync mobile app. 

Please analyze the following task checklist and help me implement the fixes step-by-step with clean, production-ready code and backend/database architecture recommendations.

---

### GOALS & REQUIREMENTS

#### Task 1: Fix Email Verification Screen & Session Reset
1. Make "Use other account" clear the auth token/session and navigate to the Login screen with the navigation stack reset.
2. Add a "Resend Verification Email" button with a 30-to-60 second countdown timer state.
3. Add a "Change Email" option allowing users to update their email address before verifying.
4. Implement an auto-check listener when the app enters the foreground (`onResume` / lifecycle check) to automatically navigate forward if the email has been verified.

#### Task 2: Standardize Confirmation Dialogs
1. Implement a reusable Confirmation Modal component for destructive actions.
2. Add the Sign-Out modal for Care Partner and Patient accounts with copy:
   - Title: "Sign Out"
   - Message: "Are you sure you want to sign out of HealthSync?"
   - Actions: [Cancel] | [Sign Out]
3. Apply this standardized dialog pattern to: Delete Medicine, Remove Patient, and Delete Account.

#### Task 3: Fix Care Partner Request Decline Flow
1. Update the Request data model with explicit statuses: `pending`, `approved`, `declined`, `expired`.
2. Fix backend authorization / database update rules (Cloud Functions / Firebase / Supabase) to allow care partners to modify request states.
3. Update patient-side state to reflect when a request is marked as "Declined by care partner" and show a notification.

#### Task 4: Enhance Care Partner Dashboard UI/UX
1. Redesign the Care Partner Dashboard beyond showing just the patient's name.
2. Design components for:
   - Adherence Summary Card (% completed today/this week).
   - Upcoming Doses Timeline.
   - Recent Alerts / Missed Doses section.
   - Patient Hardware & App Health Status (Permissions enabled / Optional Smart Box status).

#### Task 5: Onboarding System Permissions Health Check
1. Implement an Onboarding Permissions Check screen evaluating:
   - Notification Permissions
   - Exact Alarm scheduling permissions
   - Battery Optimization exemptions
2. Create step-by-step guidance cards to assist users in resolving missing permissions.

#### Task 6: Copywriting & Tagline Updates
1. Replace overclaiming landing/welcome text with accurate copy:
   - Headline: "Stay on top of every dose."
   - Sub-headline: "Medicine reminders and missed-dose alerts for you and your care partner."
   - Subtext for optional hardware: "Works with the optional HealthSync medicine box."

---

### INSTRUCTIONS FOR CLAUDE
1. Ask me which specific framework/tech stack I am using (e.g., React Native, Flutter, Swift/Kotlin, Firebase, Supabase) if not clear.
2. Provide code snippets modularly, focusing first on Task 1 and Task 3.
3. Provide clean UI components adhering to best practices for accessibility and clean code architecture.
```