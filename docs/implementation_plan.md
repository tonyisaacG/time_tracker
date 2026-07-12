# Implementation Plan - Time Investment Tracker (Phase 1)

This document outlines the technical design and step-by-step plan for building Phase 1 of the **Time Investment Tracker** application. It focuses on setting up a local-first, premium productivity app using Flutter, Drift (SQLite), and Riverpod, adhering to the requested folder structures and architecture layers.

## User Review Required

> [!IMPORTANT]
> **Key Architecture Decisions:**
> 1. **Local Device ID**: To enable the synchronization strategy (Phase 3) without requiring native permissions or complex native code in Phase 1, we will generate a unique UUID on the first app launch and store it in `SharedPreferences` as the `deviceId`.
> 2. **Active Timer Persistence**: The active timer will be represented directly in the database as a `Session` with a `null` value for `endTime`. This ensures that even if the app crashes, is closed, or the device restarts, the timer state is fully preserved and can be resumed.
> 3. **Premium Visuals & Custom Charts**: Instead of relying on heavy third-party plotting libraries that can look generic, we will implement custom widgets using Flutter's `CustomPainter` to draw gorgeous, fluid, and modern interactive charts (gradient rings, glowing progress bars, and animated vertical bar charts) that match our design aesthetic.

## Open Questions

None at this time. The domain model, business rules, and folder structure have been fully specified.

---

## Proposed Changes

### Project Initialization

#### [NEW] [pubspec.yaml](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/pubspec.yaml)
Initialize the Dart and Flutter package dependencies. We will include:
- `flutter_riverpod` and `riverpod_annotation` for state management
- `drift`, `sqlite3_flutter_libs`, and `path_provider` for local database storage
- `path` for file path resolution
- `uuid` for generating unique IDs for Activities and Sessions
- `intl` for datetime formats and calendar calculations
- `shared_preferences` for storing device configurations (e.g., Device ID)
- Dev dependencies: `build_runner`, `drift_dev`, and `riverpod_generator`

### Core Layer

#### [NEW] [app_theme.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/core/theme/app_theme.dart)
Define a premium design system:
- **Dark Mode First**: Deep slate backgrounds (`#0F172A`), glassmorphic cards with subtle translucent borders, and glowing accents.
- **Harmonious Accents**: Vibrant HSL-based color palettes for activities (e.g., Electric Violet, Emerald Green, Sunset Orange, Cyan Glow).
- **Typography**: Sleek Sans-serif font weights with structured hierarchies.
- **Animations**: Soft hover transitions and pulsing glows for active timer indicators.

#### [NEW] [database.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/core/db/database.dart)
Set up the Drift database using SQLite:
- Define `Activities` and `Sessions` tables matching the domain models.
- Enforce UNIQUE constraint on Activity Name.
- Support soft delete (`isDeleted` flag) for both tables to pave the way for Phase 3 synchronization.
- Include indices and reactive watches for efficient querying.

#### [NEW] [device_id.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/core/utils/device_id.dart)
Utility to retrieve or generate a unique `deviceId` using `SharedPreferences` and `uuid`.

---

### Activity Feature Component

#### [NEW] [activity.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/activity/domain/activity.dart)
Define the domain `Activity` class representing categories (e.g., English, Coding, Reading) with validation rules (e.g., name validation).

#### [NEW] [activity_repository.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/activity/domain/activity_repository.dart)
Repository interface specifying data retrieval and mutation contracts.

#### [NEW] [activity_repository_impl.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/activity/infrastructure/activity_repository_impl.dart)
Drift-backed implementation of `ActivityRepository` enforcing business rules:
- Activity name uniqueness.
- Prevent deletion of activities if active/inactive sessions refer to them.
- Support archiving.

#### [NEW] [activity_providers.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/activity/application/activity_providers.dart)
Riverpod providers managing activities state (list, archived list, creation, updating).

#### [NEW] [activity_manage_screen.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/activity/presentation/activity_manage_screen.dart)
UI to create, view, archive, and delete activities. Uses custom dialogs with color picker and icon picker.

---

### Session Feature Component

#### [NEW] [session.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/session/domain/session.dart)
Domain `Session` class with properties: ID, Activity ID, Start/End times, Duration, Device ID, Notes, and Timestamps. Enforces rules:
- Duration must be positive.
- Start and End times must be logical.

#### [NEW] [session_repository.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/session/domain/session_repository.dart)
Repository interface for saving, updating, and querying sessions.

#### [NEW] [session_repository_impl.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/session/infrastructure/session_repository_impl.dart)
Drift-backed implementation of `SessionRepository` enforcing rules:
- Only one active session (where `endTime` is null) can run at a time.
- Starting a session stops any existing active session automatically and calculates its duration.
- Prevent session overlap (though starting via the app automatically stops the previous, manual entry validation checks this).

#### [NEW] [timer_providers.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/session/application/timer_providers.dart)
Riverpod notifier to manage active timer state, ticking seconds, notes, and session starting/stopping.

#### [NEW] [session_providers.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/session/application/session_providers.dart)
Providers for list of past sessions (ordered by time), deleting sessions (soft delete), and manual session editing.

#### [NEW] [timer_dashboard.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/session/presentation/timer_dashboard.dart)
Main workspace screen showing the active timer (with notes field and stop button) and quick-start cards for each activity.

#### [NEW] [session_history_list.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/session/presentation/session_history_list.dart)
View listing previous sessions, showing details (duration, activity color/icon, notes) and offering deletion or manual adding.

---

### Report Feature Component

#### [NEW] [report_models.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/report/domain/report_models.dart)
Structured domain models representing Daily, Weekly, and Monthly breakdowns (aggregates calculated on-demand).

#### [NEW] [report_service.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/report/application/report_service.dart)
Riverpod-driven service that queries raw sessions from Drift and computes aggregated totals:
- Daily report: Today vs. yesterday.
- Weekly report: Start of week is Monday. Goal vs. actual comparison percentage.
- Monthly report: Calendar month aggregate.

#### [NEW] [report_screen.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/report/presentation/report_screen.dart)
Dashboard containing:
- Period selection tabs (Daily, Weekly, Monthly).
- Goal tracker progress bars (Actual vs. Goal with completion percentage).
- Visual charts: Sleek custom bar chart and pie breakdown chart.

#### [NEW] [custom_charts.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/report/presentation/widgets/custom_charts.dart)
Premium custom-painted components for:
- Animated Gradient Progress Ring (for goals).
- Animated Bar Chart (for weekly comparisons).
- Interactive Donut Chart (for activity time distribution).

---

### Settings Feature Component

#### [NEW] [settings_screen.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/settings/presentation/settings_screen.dart)
Options to:
- Show local device sync details.
- Export all data (JSON dump for user ownership).
- Import data.
- Clear database (with double confirmation).

---

### App Shell & Bootstrapping

#### [NEW] [main.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/main.dart)
Entry point:
- Initialize Flutter binding, path providers, and device ID.
- Wrap app in `ProviderScope`.
- Build the main premium App Shell (`MainNavigationScreen`) housing the NavigationRail (desktop) and NavigationBar (mobile) to switch between:
  1. Dashboard & Timer
  2. Activity Management
  3. Reports
  4. Settings

---

## Verification Plan

### Automated Tests
We will add unit and integration tests to verify critical logic:
1. **Repository & Rules Verification**:
   - Create activity with unique name, and verify that duplicate names trigger a unique constraint error.
   - Prevent deletion of activities with associated sessions.
   - Verify that starting a new session stops the currently running one and calculates duration correctly.
   - Verify that soft-deleted sessions are omitted from normal listings.
2. **Report Computation Verification**:
   - Set up test sessions and verify that the Weekly Report correctly sums minutes starting from Monday.
   - Verify that completion percentages for weekly goals match expected ratios.

We can run these using:
```powershell
flutter test
```

### Manual Verification
1. **Launch the application on Windows**:
   - Verify the visual theme, typography, dark mode styling, and smooth hover animations.
   - Confirm layout adaptation between narrow and wide screen widths (using responsive NavigationBar / NavigationRail).
2. **Activity Operations**:
   - Create new activities with customized colors and icons.
   - Try creating a duplicate activity name to verify error messages.
   - Create a session, then try to delete the activity. Confirm it is blocked.
   - Archive an activity, verify it disappears from quick-start but remains in historical records.
3. **Session Timing**:
   - Select an activity and click "Start". Observe the timer counting up, note fields editable, and pulsing indicator.
   - Click "Stop" and verify the session appears in the history list with correct duration.
   - Start a session, then start another. Check that the first session was stopped automatically with correct elapsed time.
4. **Reports & Dashboards**:
   - Verify that visual custom painters draw the ring and bar charts nicely.
   - Verify weekly reports display Monday-start boundaries.
5. **Settings & Portability**:
   - Export records to JSON, review file structure, clear database, and import the file back. Confirm data restores perfectly.
