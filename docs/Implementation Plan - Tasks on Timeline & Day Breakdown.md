# Implementation Plan - Tasks on Timeline & Day Breakdown

Enable tasks to be displayed on the weekly timeline alongside scheduled appointments, calculate the total consumed vs. free time for each day, and offer a daily breakdown.

## User Review Required

> [!IMPORTANT]
> **Task Duration Representation**
> Since `DayTask` has a `reminderTime` but no duration field in the database, we will represent tasks on the timeline using a default duration of 30 minutes. This allows us to position them on the timeline and include them in the daily "consumed time" calculation.
> 
> **Daily Statistics Display**
> To avoid cluttering the narrow 7-day columns on mobile screens:
> 1. We will add a small badge/bar under each day header indicating consumed time (e.g., `2.5h`).
> 2. Tapping any day header will open a premium, modern bottom sheet displaying:
>    - A breakdown of total consumed time vs. free time (using a sleek progress bar).
>    - A list of all schedules (appointments) on that day.
>    - A list of all tasks (both timed and untimed) on that day, with checkboxes to toggle completion.

## Proposed Changes

### Database & Repository Layer

#### [MODIFY] [planner_repository.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/planner/domain/planner_repository.dart)
- Add `Stream<List<DayTask>> watchTasksForDateRange(String startStr, String endStr)` to the repository interface.

#### [MODIFY] [planner_repository_impl.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/planner/infrastructure/planner_repository_impl.dart)
- Implement `watchTasksForDateRange` to query `dayTasks` table within the start and end dates.

#### [MODIFY] [planner_providers.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/planner/application/planner_providers.dart)
- Create `weeklyTasksProvider(DateTime weekMonday)` to stream the tasks for the selected week.

---

### Presentation Layer

#### [MODIFY] [weekly_timeline_view.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/schedule/presentation/weekly_timeline_view.dart)
- Read `weeklyTasksProvider` in `WeeklyTimelineView` to fetch all tasks for the week.
- Map tasks that have a `reminderTime` to timeline blocks:
  - Assign a checklist icon and dashed borders to visually distinguish tasks from appointments.
  - Tapping a task block will show a detail dialog or allow toggling completion.
- Calculate and display consumed vs. free time:
  - Implement a helper to calculate the union of busy time intervals (appointments + timed tasks) on each day.
  - Update `_DayHeaderRow` to show the consumed hours at a glance.
  - Update `_DayHeaderRow` to make headers interactive (tappable) so users can open a daily report sheet.
- Implement the day breakdown bottom sheet (`_showDaySummaryBottomSheet`) displaying:
  - Consumed time vs Free time statistics.
  - List of appointments and all tasks (completed / pending) for that day.
- Update `_LegendBar` to explain the new visual representations of tasks.

## Verification Plan

### Manual Verification
- Add a new task in the daily planner with a reminder time (e.g., 10:00 AM).
- Go to the Timeline tab in the Schedule screen and verify:
  - The task appears at 10:00 AM.
  - The task looks distinct from scheduled appointments.
  - The day header shows an updated consumed time.
- Tap the day header and verify the bottom sheet opens with correct statistics, schedule list, and task list.
- Tap a task in the bottom sheet to toggle its completion and see the UI update.
