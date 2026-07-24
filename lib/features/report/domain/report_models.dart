import 'package:tracker_time/core/db/database.dart';

class ActivityReportItem {
  final Activity activity;
  final int totalMinutes;
  
  ActivityReportItem({
    required this.activity,
    required this.totalMinutes,
  });

  double get completionPercentage {
    final goal = activity.weeklyGoalMinutes;
    if (goal == null || goal == 0) return 0.0;
    return (totalMinutes / goal) * 100.0;
  }
}

class ReportData {
  final DateTime startDate;
  final DateTime endDate;
  final int totalMinutes;
  final List<ActivityReportItem> items;
  // Key represents the sub-period:
  // - Daily: Hour (0 to 23)
  // - Weekly: Day of week (1 = Monday, 7 = Sunday)
  // - Monthly: Day of month (1 to 31)
  final Map<int, int> timeBySubPeriod;
  final List<Activity> neglectedActivities;

  ReportData({
    required this.startDate,
    required this.endDate,
    required this.totalMinutes,
    required this.items,
    required this.timeBySubPeriod,
    required this.neglectedActivities,
  });
}
