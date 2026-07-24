# Implementation Plan - Move Combined Tasks & Schedules Timeline to Reports

Shift the combined Tasks + Schedules timeline and daily breakdown from the Schedule screen to the **Reports screen** (`ReportScreen`), restoring the Schedule screen's timeline to display only appointments (`Appointment`s).

## User Review Required

> [!IMPORTANT]
> **All Tasks Guaranteed to Appear on Timeline**
> Even if a task does NOT have a specific reminder time set (`reminderTime == null`), it will still be displayed on the timeline in the Reports screen (as an Untimed / All-Day task block on that day) so that **every single task you add appears on the timeline**.

## Proposed Changes

### Schedule Screen (`WeeklyTimelineView`)

#### [MODIFY] [weekly_timeline_view.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/schedule/presentation/weekly_timeline_view.dart)
- Revert `WeeklyTimelineView` back to displaying only scheduled appointments (`Appointment`s).

---

### Report Screen (`ReportScreen`)

#### [MODIFY] [report_screen.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/report/presentation/report_screen.dart)
- Add a new section/card in `ReportScreen`: **"Timeline & Schedule/Task Breakdown"**.
- Display a combined daily/weekly timeline for the selected date/period containing:
  - All scheduled appointments.
  - All tasks: Timed tasks placed at their scheduled hour, and Untimed tasks displayed clearly as All-Day/Untimed task blocks on the timeline column.
- Display total Consumed Time vs. Free Time (with visual progress bar).
- Include interactive daily items listing:
  - All scheduled appointments for each day.
  - All day tasks (both timed and untimed) for each day, complete with checkboxes to toggle completion.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure code quality and clean compilation.

### Manual Verification
- Open the Schedule screen's **Timeline** tab: verify it only displays scheduled appointments.
- Add a task without a reminder time in the Daily Planner, open the **Reports** screen, and confirm it appears on the timeline.
- Add a task with a reminder time, open the **Reports** screen, and confirm it appears at its scheduled hour on the timeline.
- Toggle task completion in the Reports screen and ensure the database updates reactively.
