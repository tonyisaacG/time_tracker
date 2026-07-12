# Implementation Plan - Time Accountability (Tracked vs. Untracked Time)

This plan outlines the implementation of the **Time Accountability** visualization feature to address the user's goal of understanding and exposing "wasted" (untracked) time.

## User Review Required

> [!IMPORTANT]
> **Visualization Mechanics**:
> To avoid complex database updates, we will calculate the period's total capacity in minutes (e.g., 24h/day, 168h/week, calendar days * 24h/month) directly in the UI controller.
> Any time NOT tracked in a session during the period is treated as "Untracked / Wasted" time. 
> We will represent this comparison using:
> 1. A dedicated premium dashboard card.
> 2. A dual-segment progress bar showing the percentage of tracked vs. untracked time.

## Open Questions

None. The layout fits cleanly under the existing overall summary card in the Reports screen.

---

## Proposed Changes

### Report Component

#### [MODIFY] [report_screen.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/report/presentation/report_screen.dart)
* Add `_buildTimeAccountabilityCard(ReportData report)` to `_ReportScreenState`.
* This card will:
  * Determine the total hours in the selected period (24 hours for Day, 168 hours for Week, variable calendar hours for Month).
  * Calculate `untrackedMinutes = max(0, totalPeriodMinutes - report.totalMinutes)`.
  * Calculate percentages: `trackedPercent = (report.totalMinutes / totalPeriodMinutes) * 100` and `untrackedPercent = 100 - trackedPercent`.
  * Show a horizontal progress bar split into two segments: **Tracked Time** (using `AppTheme.primary`) and **Untracked / Wasted Time** (using a subtle Coral red/warning indicator or Slate border color).
  * Provide a helpful textual tip (e.g., *"Tip: To track wasted time specifically, create a 'Wasted Time' category, or use this unaccounted gap to reflect on hidden time sinks."*).
* Integrate `_buildTimeAccountabilityCard` in the main scrollable list of the report screen right below the overall summary card.

---

## Verification Plan

### Automated Tests
* We will check that the app builds and tests continue to pass.
* We can run `flutter test`.

### Manual Verification
* Build and launch the application on Windows.
* Navigate to the **Reports** screen.
* Verify the new **Time Accountability** card displays correctly.
* Switch between **Day**, **Week**, and **Month** views and check that the total hours adjust accordingly (e.g., 24.0h, 168.0h, 720.0h).
* Toggle historical weeks (using `<` and `>` navigation arrows) and verify that the percentages update in real-time.
