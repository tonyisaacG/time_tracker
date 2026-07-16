# Implementation Plan - Timeline Gap Logging & Schedule/Notification Enhancements

This plan details the implementation of the remaining roadmap requirements: **Retroactive Gap Filling (Timeline Gap Logging)** and **Scheduled Appointments Enhancements** (rich notifications with action buttons and smart tracking integration).

## Proposed Changes

### 1. Retroactive Gap Filling (Timeline Gap Logging)
To allow users to account for their whole day retroactively:
- We will add a **Timeline** view tab or toggle in the History/Session Screen.
- We will calculate untracked gaps for the selected day:
  - We define the day boundary as `00:00:00` (midnight) to `23:59:59` (or `DateTime.now()` if the selected day is today).
  - We sort the day's completed sessions chronologically.
  - We compute the gaps between midnight and the first session, between consecutive sessions, and between the last session and the end-of-day / current time.
  - Each gap will display as a card: **"Untracked Time (Gap)"** with a **"Fill this Gap"** button.
  - Tapping **"Fill this Gap"** will open the `ManualLogDialog` with the start time, end time (or duration), and date pre-filled to cover that exact gap.

### 2. Scheduled Appointments, Meetings & Recurrent Reminders Enhancements
To improve the scheduling and notifications:
- **Notification Actions**: Add a **"Start Tracking Now"** action button to scheduled notifications.
- **Custom Vibration & Sound Configuration**: Enhance the Android Notification Channel and notification details to use custom vibrations (e.g. repeating patterns) and custom sound configurations if desired.
- **Smart Tracking Handling**:
  - In `NotificationService`, we will setup a stream or notifier of notification actions.
  - In the main app lifecycle / app shell (`MainNavigationScreen`), we will listen to this stream/notifier.
  - When the user clicks the "Start Tracking Now" action, the app will automatically start a live session pre-filled with the appointment's activity details (or its title if no activity is linked) and switch the navigation tab to the **Timer** screen.

---

## Proposed File Changes

### Core Database / Models
No changes are required for the database schema since the `Sessions` and `Appointments` tables already contain the necessary fields (`startTime`, `endTime`, `durationMinutes`, `activityId`).

### Core Services

#### [MODIFY] [notification_service.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/core/services/notification_service.dart)
- Define a global stream or notifier to receive notification payloads when an action is clicked.
- Register Android notification actions: **"Start Tracking Now"** (`start_tracking`) and **"Dismiss"** (`dismiss`).
- Set up custom vibration patterns and sound settings in the channel/details.
- In `onDidReceiveNotificationResponse`, check if the action was `start_tracking` and emit the payload to the notification actions stream.

### Application Layer

#### [MODIFY] [timer_providers.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/session/application/timer_providers.dart)
- Add support for checking notification launch details or incoming stream events to trigger starting a session from an appointment payload.

### UI Components

#### [MODIFY] [session_history_list.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/features/session/presentation/session_history_list.dart)
- Add a toggle button or tab at the top of the history screen: **"List View"** vs. **"Timeline View"**.
- Implement **Timeline View**:
  - Let the user select a date (defaults to Today, with `<` and `>` buttons to navigate dates).
  - Fetch all completed sessions for that date.
  - Calculate gaps:
    - If no sessions exist for the entire day, show a single gap covering from midnight to the end-of-day / current time.
    - Otherwise, find all gaps: from midnight to first session start, between consecutive sessions, and from last session end to midnight/now.
  - Display sessions and gaps in chronological order.
  - Clicking **"Fill this Gap"** on a gap card opens the manual log dialog pre-filled with that gap's date, start time, and duration.
- Update `ManualLogDialog` to accept optional `initialStartTime`, `initialDuration`, and `initialDate` parameters to pre-fill the form fields.

#### [MODIFY] [main.dart](file:///e:/2026/MyBigProjects_SimpleLib/TrackerTime/lib/main.dart)
- Listen to the notification actions stream.
- When an action is received, start the timer with the specified activity ID and switch tab to the **Timer** (index 0).

---

## Verification Plan

### Automated Tests
- Run `flutter test` to ensure existing tests pass.

### Manual Verification
1. Open the History tab and switch to **Timeline View**.
2. Verify that the current day's timeline is shown, displaying tracked sessions and gaps (e.g., Midnight to First Session, gaps in between, and last session to Now).
3. Tap **"Fill this Gap"** on a gap, verify the dialog is pre-filled with correct times, select an activity, and save. Verify the gap is replaced by the new session.
4. Schedule an appointment starting in 1 minute.
5. Wait for the notification. Tap the **"Start Tracking Now"** action.
6. Verify the app opens to the Timer screen with the active timer running for that activity.
