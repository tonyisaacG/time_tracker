# Walkthrough - Activity Limits & Enforcement Rules

We have successfully designed, built, and verified the **Target vs. Limit** weekly constraints and **Enforcement** (forced limit) rules.

---

## 🛠️ Implemented Features

### 1. Database Schema Version 2
* **File**: [database.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/core/db/database.dart)
* Added `isLimit` and `enforceLimit` columns to the `Activities` table.
* Incremented `schemaVersion` to `2` and configured custom migration scripts to seamlessly add columns to existing local databases.
* Regenerated type-safe representations with `build_runner`.

### 2. Activity Management Options
* **File**: [activity_manage_screen.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/activity/presentation/activity_manage_screen.dart)
* Added a segmented ChoiceChip selection inside the creation dialog:
  * **Spend at least (Target)**: Default behavior for productive tasks.
  * **Spend at most (Limit)**: For limit activities (e.g., Social Media).
* Added a checkbox **"Enforce limit (Force-stop active timer)"** (visible only if Limit is selected) to block tracking when the limit is breached.
* Activity Cards now display whether they are minimum targets (`Goal: XXh/wk`), soft limits (`Limit: XXh/wk`), or enforced limits (`Limit: XXh/wk (Forced)`).

### 3. Report Screen Progress
* **File**: [report_screen.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/report/presentation/report_screen.dart)
* Re-designed `_buildActivityProgressTile` to render according to the constraint type:
  * Target: Shows `$percentString% Met` using the activity's main theme color.
  * Limit (Within Limit): Shows `$percentString% Used` in Emerald Green (`Color(0xff10b981)`).
  * Limit (Broken): Shows `Limit Broken (+XXh)` in Coral Red (`Color(0xffef4444)`).

### 4. Enforcement Checks
* **Active Timer Auto-Stop** ([timer_dashboard.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/session/presentation/timer_dashboard.dart)):
  * Added a reactive listener on `activeSessionDurationProvider` that monitors elapsed tracking minutes.
  * Once the cumulative tracking time this week meets the weekly limit, the active session stops automatically and raises a SnackBar notification.
* **Block Start** ([timer_dashboard.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/session/presentation/timer_dashboard.dart)):
  * Pressing the quick start card for an activity that is already at or above its enforced limit raises an alert dialog informing the user and prevents starting the tracker.
* **Block Manual Log** ([session_history_list.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/session/presentation/session_history_list.dart)):
  * When manually logging a session, the dialog checks the duration against other entries for that week. If saving would exceed the enforced limit, it displays a block dialog and prevents saving.

### 5. Settings Backup/Restore Custom Columns
* **File**: [settings_screen.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/settings/presentation/settings_screen.dart)
* Updated database export and import parser logic to include the new `isLimit` and `enforceLimit` columns.

---

## 🧪 Testing & Verification

* Modified all static `Activity` constructor references in the testing file [widget_test.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/test/widget_test.dart) and in standard fallback constructor blocks (in `timer_dashboard.dart` and `settings_screen.dart`) to compile cleanly with the new schema.
* Run command: `flutter test`
* Result: **All tests passed!**
