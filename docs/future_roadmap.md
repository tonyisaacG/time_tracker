# Future Feature Roadmap & Ideas

This document tracks upcoming ideas and planned features for the Time Investment Tracker.

---

## 🚀 Future Roadmap Ideas

### 1. Retroactive Gap Filling (Timeline Gap Logging)
> "i want to create from a specific time gap a session and write what was done in it. Meaning, I was on an errand, and I want to log that this time was spent on the errand, so I'll do it after the errand, not in a live session."

* **Description**: Instead of just seeing "Untracked Time" as a metric, the app will show a visual chronological timeline of the day's tracked slots and blank gaps (untracked periods).
* **Workflow**:
  1. The user goes to the dashboard or history tab.
  2. The timeline shows a gap (e.g., *2:00 PM - 4:00 PM (Untracked)*).
  3. The user taps a **"Fill this Gap"** button directly on that slot.
  4. A dialog pops up preset with the gap's start time (2:00 PM) and end time (4:00 PM).
  5. The user selects the activity (e.g., "Errand"), writes notes, and logs it.
* **Benefits**: Helps users easily account for their whole day retroactively without having to run a live session or calculate start/end times manually.

---

### 2. 📅 Scheduled Appointments, Meetings & Recurrent Reminders
> "schedule appointments or meetings with custom notifications (music, vibration, etc.) and configure weekly/monthly repeats (e.g. course on Monday and Thursday, weekly meetings)."

* **Description**: A dedicated scheduling sub-system to plan and receive alarms/reminders for recurring or one-off educational courses, corporate meetings, and personal tasks linked to your activities.
* **Key Features**:
  1. **Schedule Builder**:
     - Select starting date & time.
     - Set duration (e.g., 60 minutes).
     - Choose appointment category/activity (e.g., link a lecture to "English" or a sprint meeting to "Programming").
  2. **Flexible Recurrence Engine**:
     - **Once**: For one-off events (e.g., doctor visit).
     - **Weekly Days (Multiple)**: Select specific weekdays (e.g., Every Monday and Thursday for a course).
     - **Weekly / Monthly Frequency**: Set recurring meetings once a week or on specific dates of the month.
  3. **Rich Notifications & Alarms**:
     - Implement system-level notifications (using local alarm managers).
     - Configure custom ringtones/music playback options.
     - Add customized vibration patterns (long pulses, repeating beats) to guarantee you never miss the reminder.
  4. **Smart Tracking Integration**:
     - When a scheduled course/meeting reminder fires, present a direct action button: **"Start Tracking Now"** to immediately kick off a live session pre-filled with that activity's details.

