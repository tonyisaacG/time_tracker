import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/features/activity/application/activity_providers.dart';
import 'package:tracker_time/features/session/application/session_providers.dart';
import '../domain/report_models.dart';

final reportDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final dailyReportProvider = Provider<AsyncValue<ReportData>>((ref) {
  final date = ref.watch(reportDateProvider);
  final sessionsAsync = ref.watch(allSessionsProvider);
  final activitiesAsync = ref.watch(allActivitiesProvider);

  if (sessionsAsync is AsyncLoading || activitiesAsync is AsyncLoading) {
    return const AsyncLoading();
  }
  if (sessionsAsync is AsyncError || activitiesAsync is AsyncError) {
    return AsyncError(sessionsAsync.error ?? activitiesAsync.error!, StackTrace.current);
  }

  final sessions = sessionsAsync.value ?? [];
  final activities = activitiesAsync.value ?? [];

  final start = DateTime(date.year, date.month, date.day);
  final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  return AsyncData(_calculateReport(sessions, activities, start, end, PeriodType.daily));
});

final weeklyReportProvider = Provider<AsyncValue<ReportData>>((ref) {
  final date = ref.watch(reportDateProvider);
  final sessionsAsync = ref.watch(allSessionsProvider);
  final activitiesAsync = ref.watch(allActivitiesProvider);

  if (sessionsAsync is AsyncLoading || activitiesAsync is AsyncLoading) {
    return const AsyncLoading();
  }
  if (sessionsAsync is AsyncError || activitiesAsync is AsyncError) {
    return AsyncError(sessionsAsync.error ?? activitiesAsync.error!, StackTrace.current);
  }

  final sessions = sessionsAsync.value ?? [];
  final activities = activitiesAsync.value ?? [];

  // Monday start: weekday is 1 for Mon, 7 for Sun
  final daysToSubtract = date.weekday - 1;
  final start = DateTime(date.year, date.month, date.day).subtract(Duration(days: daysToSubtract));
  final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));

  return AsyncData(_calculateReport(sessions, activities, start, end, PeriodType.weekly));
});

final monthlyReportProvider = Provider<AsyncValue<ReportData>>((ref) {
  final date = ref.watch(reportDateProvider);
  final sessionsAsync = ref.watch(allSessionsProvider);
  final activitiesAsync = ref.watch(allActivitiesProvider);

  if (sessionsAsync is AsyncLoading || activitiesAsync is AsyncLoading) {
    return const AsyncLoading();
  }
  if (sessionsAsync is AsyncError || activitiesAsync is AsyncError) {
    return AsyncError(sessionsAsync.error ?? activitiesAsync.error!, StackTrace.current);
  }

  final sessions = sessionsAsync.value ?? [];
  final activities = activitiesAsync.value ?? [];

  final start = DateTime(date.year, date.month, 1);
  final nextMonth = DateTime(date.year, date.month + 1, 1);
  final end = nextMonth.subtract(const Duration(milliseconds: 1));

  return AsyncData(_calculateReport(sessions, activities, start, end, PeriodType.monthly));
});

enum PeriodType { daily, weekly, monthly }

ReportData _calculateReport(
  List<Session> allSessions,
  List<Activity> activities,
  DateTime start,
  DateTime end,
  PeriodType type,
) {
  final periodSessions = allSessions.where((s) {
    if (s.endTime == null) return false; // Ignore active timer
    return (s.startTime.isAfter(start) && s.startTime.isBefore(end)) || 
           s.startTime.isAtSameMomentAs(start) || 
           s.startTime.isAtSameMomentAs(end);
  }).toList();

  int totalMinutes = 0;
  final Map<String, int> durationByActivity = {};
  final Map<int, int> subPeriodTime = {};

  for (final s in periodSessions) {
    totalMinutes += s.durationMinutes;
    durationByActivity[s.activityId] = (durationByActivity[s.activityId] ?? 0) + s.durationMinutes;

    int key;
    if (type == PeriodType.daily) {
      key = s.startTime.hour; // 0-23
    } else if (type == PeriodType.weekly) {
      key = s.startTime.weekday; // 1-7
    } else {
      key = s.startTime.day; // 1-31
    }
    subPeriodTime[key] = (subPeriodTime[key] ?? 0) + s.durationMinutes;
  }

  final List<ActivityReportItem> items = [];
  final List<Activity> neglectedActivities = [];
  
  for (final act in activities) {
    final mins = durationByActivity[act.id] ?? 0;
    final hasGoal = act.weeklyGoalMinutes != null && act.weeklyGoalMinutes! > 0;
    
    // Include in general list if tracked minutes exist, OR (for weekly reports and active goals)
    if (mins > 0 || (type == PeriodType.weekly && !act.isArchived && hasGoal)) {
      items.add(ActivityReportItem(activity: act, totalMinutes: mins));
    }

    // Neglected: Active activity, has a weekly goal/limit, but has 0 minutes tracked so far
    if (!act.isArchived && !act.isDeleted && hasGoal && mins == 0) {
      neglectedActivities.add(act);
    }
  }

  // Sort: highest tracking duration first
  items.sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));

  return ReportData(
    startDate: start,
    endDate: end,
    totalMinutes: totalMinutes,
    items: items,
    timeBySubPeriod: subPeriodTime,
    neglectedActivities: neglectedActivities,
  );
}
