# Time Investment Tracker - User Goals & Design Focus

This document records the user's primary goals for the Time Investment Tracker application, establishing the product focus and defining how the system addresses each requirement.

---

## 📋 Core User Goals

### 1. Complete Activity Time Tracking
> "i want track all time all activities what time spend in every one"
* **Focus**: The app must record and categorize every tracked minute of the user's day under distinct activity categories (e.g., Learning, Coding, English, Exercise, Leisure).
* **Implementation**:
  * Clean, single-click "Start/Stop" buttons in the dashboard.
  * Auto-stopping of previous running timers when a new one starts to guarantee accurate, non-overlapping intervals.
  * Complete categorization and sorting of activities in reports by total hours tracked.

### 2. Identifying Wasted/Untracked Time
> "i wnat know wasted time where does it go?"
* **Focus**: The user wants to expose hidden time sinks and see where their unaccounted hours are going. 
* **Implementation**:
  * **Explicit Tracking**: Allow creating dedicated categories for distractions (e.g., "Social Media", "Netflix", "Procrastination") to see them in the category distribution donut chart.
  * **Gap Analysis**: Calculate and display "Untracked Time" (the remainder of the 24-hour day or 168-hour week that has no recorded sessions) to show exactly how much time is escaping their notice.

### 3. Weekly Re-Prioritization & Comparative Reports
> "for rearrange priority this weel foucs in some thing i will next week focus at another then less time for another and i wnat report at last week to know if this week fine or not and to know if time wast or i work but i not feel with it"
* **Focus**: The user needs a dynamic way to set weekly focus areas (increasing targets for some activities, lowering them for others) and wants to compare current performance against previous weeks to confirm if they are staying on track.
* **Implementation**:
  * **Dynamic Targets**: Easily adjustable weekly goals (in hours/minutes) per activity via the Activity Management screen.
  * **Historical Navigation**: Simple left/right period navigation arrows in the Weekly Reports view. This lets the user jump to "last week" (or older weeks) to compare actual minutes tracked and goal-completion percentages, showing whether they actually worked or simply let time slip by.
