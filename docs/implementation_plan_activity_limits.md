# Implementation Plan - Activity Limits & Enforcement

This updated plan details how we will implement the **Target vs. Limit** system and the **Enforcement (Force Limit)** option to auto-stop tracking and block manual logs once a maximum limit is reached.

## User Review Required

> [!IMPORTANT]
> **Enforcement Mechanics**:
> 1. **Active Timer Auto-Stop**: If an activity has an enforced limit, we will monitor the running timer. Once the cumulative time tracked this week hits the weekly limit, the active session is automatically stopped, and a SnackBar notifications tells the user.
> 2. **Start Tracking Block**: If the limit is already reached, trying to start a new timer for that activity will show a block dialog.
> 3. **Manual Log Block**: Trying to manually add a session that exceeds the enforced limit will show a validation error in the manual log dialog.

## Open Questions

None. The user confirmed they want an option to "force" the activity to not go over the limit.

---

## Proposed Changes

### Core Database Layer

#### [MODIFY] [database.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/core/db/database.dart)
* Add `isLimit` and `enforceLimit` columns to the `Activities` table:
  ```dart
  BoolColumn get isLimit => boolean().withDefault(const Constant(false))();
  BoolColumn get enforceLimit => boolean().withDefault(const Constant(false))();
  ```
* Set `schemaVersion` to `2`.
* Add `onUpgrade` logic to `MigrationStrategy` to add both columns if upgrade from `1` occurs:
  ```dart
  onUpgrade: (m, from, to) async {
    if (from < 2) {
      await m.addColumn(activities, activities.isLimit);
      await m.addColumn(activities, activities.enforceLimit);
    }
  }
  ```

---

### Activity Application Component

#### [MODIFY] [activity_providers.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/activity/application/activity_providers.dart)
* Update `createActivity` to accept `bool isLimit` and `bool enforceLimit`.
* Pass both fields to the database model insert and update.

---

### UI Components

#### [MODIFY] [activity_manage_screen.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/activity/presentation/activity_manage_screen.dart)
* Update `_buildActivityCard` to display target/limit styles:
  * Minimum Target: `Goal: XX.Xh/wk`
  * Maximum Limit (Enforced): `Limit: XX.Xh/wk (Forced)`
  * Maximum Limit (Soft): `Limit: XX.Xh/wk`
* Update `_ActivityFormDialog` to add:
  * Segmented selection for Goal Type: "Spend at least (Target)" vs "Spend at most (Limit)".
  * Checkbox "Force/Enforce Limit" (shown only if Limit is selected) to block tracking/logging above the limit.

#### [MODIFY] [report_screen.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/report/presentation/report_screen.dart)
* Update `_buildActivityProgressTile`:
  * If limit is soft or enforced:
    * If actual > goal: Show `Limit Broken (+XX.Xh)` or `XX% Exceeded` in Red (`Color(0xffef4444)`).
    * If actual <= goal: Show `Within Limit` or `XX% Used` in Green/Cyan.

#### [MODIFY] [timer_dashboard.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/session/presentation/timer_dashboard.dart)
* Add a listener to `activeSessionDurationProvider` using `ref.listen` in `_TimerDashboardState`:
  * If a session starts and the activity is an enforced limit, monitor the duration.
  * When `trackedMinutes + activeTimerMinutes >= weeklyLimit`, call `stopTimer()` automatically and display a SnackBar.
* In the quick-start button `onTap`:
  * Check if the activity is an enforced limit and `trackedMinutes >= weeklyLimit`. If so, show a dialog: **"Limit Reached: This activity is forced to not go above the limit of XXh."** and prevent starting the timer.

#### [MODIFY] [session_history_list.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/session/presentation/session_history_list.dart)
* Modify the save button in `_ManualLogDialogState`:
  * Verify if the activity has an enforced limit.
  * If the new manual log duration plus already tracked minutes this week exceeds the limit, block saving and show a dialog: **"Cannot Log: Adding this session exceeds your weekly limit of XXh for this enforced activity."**

---

## Verification Plan

### Automated Tests
* Run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate drift models.
* Run `flutter test` to verify everything builds.

### Manual Verification
1. Create a "Social Media" activity with a Weekly Limit of 0.5 hours (30 minutes), and check **Force/Enforce Limit**.
2. Run the timer for Social Media. When the total time reaches 30 minutes, verify that:
   * The timer stops automatically.
   * A SnackBar warning says "Limit reached! Timer auto-stopped."
3. Try starting the timer again for Social Media. Verify that it is blocked with a Dialog.
4. Try manually logging 45 minutes of Social Media in the history tab. Verify it is blocked with a Dialog.
5. Create an "English" activity with a Weekly Goal/Target of 10 hours (without enforcing it). Track 12 hours. Verify that it shows as exceeded in reports in a positive way.
