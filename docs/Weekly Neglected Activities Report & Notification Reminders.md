# Weekly Neglected Activities Report & Notification Reminders

## Goal
Help users stay consistent with their goals by:
1. Finding active activities with set weekly targets/limits that have **0 minutes** of tracked time for the current week.
2. Displaying these **Neglected Activities** in the weekly Reports screen.
3. Sending a **weekly notification reminder** (e.g., on Sunday evening at 6:00 PM) listing the activities that were ignored or neglected during the week.

---

## Proposed Changes

### 1. Update Report Calculations

#### [MODIFY] [report_models.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/report/domain/report_models.dart)
Extend `ReportData` to include a list of ignored/neglected activities:
```dart
final List<Activity> neglectedActivities;
```

#### [MODIFY] [report_service.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/report/application/report_service.dart)
In `_calculateReport`, find active activities that:
- Have a weekly target/limit (`weeklyGoalMinutes != null && weeklyGoalMinutes! > 0`)
- Have **0 minutes** tracked in the current week period.
- Add them to `neglectedActivities` list in the returned `ReportData`.

---

### 2. Update UI: Show Neglected Activities in Reports

#### [MODIFY] [report_screen.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/report/presentation/report_screen.dart)
On the weekly report view, add a prominent card for **"Neglected This Week"** if any exist. It will list the activities the user hasn't worked on, prompting them to take action.

---

### 3. Periodic Background Reminder / Scheduler

#### [MODIFY] [notification_service.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/core/services/notification_service.dart)
Add `scheduleWeeklyReportSummaryReminder()` to schedule a repeating notification every Sunday at 6 PM.

#### [MODIFY] [main.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/main.dart)
Trigger the scheduling of the weekly neglected summary notification on app startup.

---

## Verification Plan
1. Compile and build the app.
2. Ensure there are active activities with targets set (e.g. "English" target 3 hours).
3. If no time is logged for them this week, verify they show up in the **Reports** screen under a new section called **"Neglected Activities (0h logged)"**.
4. Test scheduling of the notification and verify it triggers correctly.
