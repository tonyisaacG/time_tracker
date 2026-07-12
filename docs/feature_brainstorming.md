# Feature Brainstorming: Weekly Planning & Focus Sessions

This document records our brainstorming notes and technical design considerations for two key proposed features.

---

## 📅 Feature 1: Dynamic Weekly Planning
> **User Idea**: Targets and limits change each week. Instead of setting goals on the activity itself, goals should be tied to a specific week so that historical reports remain accurate and the user can plan weekly.

### 1. The Core Problem
Currently, `weeklyGoalMinutes`, `isLimit`, and `enforceLimit` are columns in the `Activities` table.
* If you set a goal of 10 hours for *Coding* this week, but next week you change it to 5 hours, **last week's report will recalculate using the new 5-hour goal**. This breaks historical accuracy.
* You cannot "plan" next week's focus in advance without overwriting this week's active targets.

### 2. Proposed Database Schema
We can introduce a new `WeeklyPlans` table to isolate goals to their specific calendar week:

```dart
class WeeklyPlans extends Table {
  TextColumn get id => text()();
  TextColumn get activityId => text().references(Activities, #id)();
  
  // Stores the Monday of the planned week (e.g., 2026-06-08)
  DateTimeColumn get weekStartDate => dateTime()(); 
  
  IntColumn get targetMinutes => integer().nullable()();
  BoolColumn get isLimit => boolean().withDefault(const Constant(false))();
  BoolColumn get enforceLimit => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()(); // Added for weekly strategy notes
  
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 3. User Experience (UX) Flow
* **Weekly Planner Screen**: A simple dashboard tab where the user selects a week (e.g., "Next Week: June 15 - June 21") and enters target hours for each activity.
* **Reports Screen**: When querying the weekly report, the app retrieves the `WeeklyPlans` associated with that week's Monday start date, ensuring historical reports remain perfectly accurate.

---

## ⏱️ Feature 2: Flexible Tracking (Indefinite vs. Pomodoro Focus)
> **User Idea**: When starting a session, the user can choose between an unlimited count-up timer or a fixed-duration focus timer (e.g., Pomodoro mode).

### 1. Modes of Operation
1. **Open-Ended Mode (Indefinite)**: Standard start/stop count-up timer.
2. **Fixed Focus Mode (Pomodoro)**: A count-down timer for a preset period (e.g., 25, 45, or 60 minutes).

### 2. Technical Design
* **Database Representation**:
  * Add a nullable column `targetDurationMinutes` to the `Sessions` table.
  * If a session has a target duration, we can display a countdown timer instead of a count-up timer on the dashboard.
* **Auto-Stop Trigger**:
  * Similar to our limit-enforcement listener, when `elapsedDuration >= targetDuration`, the system automatically calls `stopTimer()`, plays a soft completion sound/vibration, and alerts the user that their focus session is complete.
* **UI Integration**:
  * On the dashboard, tapping an activity card could show a quick sheet or popup:
    * `[▶ Start Unlimited]`
    * `[⏱ 25m Focus (Pomodoro)]`
    * `[⏱ 50m Focus]`
    * `[✏ Custom Duration...]`

---

## 📊 Feature 3: Activity Monthly Trend (Breakdown by Week)
> **User Idea**: Select a specific activity and view a monthly report showing a breakdown of each week in that month. For each week, display actual hours spent vs. target/limit hours, along with notes for the session and the weekly plan.

### 1. Goal
Provide a deep-dive analysis of a single activity over a month-long period. This lets the user see trends (e.g., *Is my English tracking increasing or decreasing week-by-week? Did I stick to the plan?*).

### 2. UI Layout
* **Activity Selector Dropdown**: Select a single activity.
* **Month Selector**: Choose a calendar month.
* **Weekly Breakdown Cards**:
  * For each week (Week 1, Week 2, Week 3, Week 4/5):
    * **Progress Ring/Bar**: Visually compare actual minutes logged vs the planned target/limit for *that specific week* (retrieved from `WeeklyPlans` for that week).
    * **Weekly Strategy Note**: Displays the notes from the `WeeklyPlans` (e.g., *"Focus on speaking practice this week"*).
    * **Session Notes Timeline**: A collapsible list of all session notes logged during that week, so the user can see exactly what they did (e.g., *"Read 5 pages of novel"*, *"Watched a documentary"*).

