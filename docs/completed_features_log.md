# Completed Features Log

This document records the features implemented in the repository today to complete the upcoming roadmap requirements.

---

## 🚀 1. Retroactive Gap Filling (Timeline Gap Logging)
* **Description**: Instead of just displaying untracked time as a static metric in reports, the app now shows a chronological day timeline highlighting both tracked slots and blank untracked gaps.
* **Key Components**:
  - **Timeline View Toggle**: Added to the top of the **History** tab to switch between List and Timeline views.
  - **Date Selector Navigation**: Allows changing the selected day to retroactively fill historical gaps.
  - **Dashed Gap Cards**: Highlight untracked time with a **"Fill Gap"** button.
  - **Smart Manual Logging Dialog**: Automatically pre-fills with the gap's date, start time, and duration when clicked.

---

## 📅 2. Scheduled Appointments & Rich Notifications
* **Description**: Enhancements to the scheduling system to plan and receive local alarms/reminders.
* **Key Components**:
  - **Vibration Pattern**: Configured custom, strong, repeating vibration patterns (`[0, 1000, 500, 1000, 500, 1000]`) in the system-level notifications channel.
  - **"Start Tracking Now" Action Button**: Added as a direct callback in local notification alerts.
  - **Smart Wake & Launch**: Handled in `main.dart` so that tapping the button automatically starts a live tracking session pre-filled with the appointment's linked activity and redirects the user to the **Timer** dashboard.

---

## 🔄 3. Custom Schedule Recurrence & Archiving
* **Description**: Clearer labeling for schedule recurrence and options to archive/restore scheduled reminders.
* **Key Components**:
  - **Custom Weekdays Label**: Renamed `"Weekly (Repeating)"` to **`"Custom Days of Week"`** in the schedule builder and cards to clarify that multiple weekdays can be selected.
  - **Schedule Archiving Switch**: Added a **"Show Archived"** toggle to the **Schedule** screen.
  - **Archive/Unarchive Card Controls**: Added action buttons on cards. Archiving a schedule automatically cancels its alarms/notifications, and restoring it reschedules them.

---

## 📊 4. Activity Log & Session Notes Timeline
* **Description**: Allows granular tracking of sub-tasks (e.g. books read under "Reading", or courses watched under "Programming") without cluttering the activities list.
* **Key Components**:
  - **Activity Log Icon**: Added to each activity card in the **Activities** tab.
  - **Log Bottom Sheet**: Shows the total hours tracked for that activity alongside a chronological timeline of all session notes logged for it.
