import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/features/activity/application/activity_providers.dart';
import 'package:tracker_time/features/schedule/application/schedule_providers.dart';
import 'package:tracker_time/features/planner/application/planner_providers.dart';
import 'package:tracker_time/features/report/application/report_service.dart';

const double _kHourHeight = 60.0;
const double _kLabelWidth = 46.0;
const int _kStartHour = 6;
const int _kEndHour = 23;

// ─────────────────────────────────────────────────────────────────────────────
// Data model for timeline placement
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineItem {
  final String id;
  final String title;
  final String? notes;
  final DateTime startTime;
  final int durationMinutes;
  final Activity? activity;
  final bool isTask;
  final bool isCompleted;
  final DayTask? task;
  final Appointment? appt;

  // Overlap positioning values
  int subColumnIndex = 0;
  int totalSubColumns = 1;

  _TimelineItem({
    required this.id,
    required this.title,
    this.notes,
    required this.startTime,
    required this.durationMinutes,
    this.activity,
    required this.isTask,
    this.isCompleted = false,
    this.task,
    this.appt,
  });

  double get startMinutes => startTime.hour * 60.0 + startTime.minute;
  double get endMinutes => startMinutes + durationMinutes;
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout Algorithm for Overlapping Events (Side-by-Side)
// ─────────────────────────────────────────────────────────────────────────────

void _layoutOverlappingItems(List<_TimelineItem> items) {
  if (items.isEmpty) return;
  items.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  final List<List<_TimelineItem>> groups = [];
  for (final item in items) {
    bool added = false;
    for (final group in groups) {
      final groupEnd = group.map((e) => e.endMinutes).reduce((a, b) => a > b ? a : b);
      if (item.startMinutes < groupEnd) {
        group.add(item);
        added = true;
        break;
      }
    }
    if (!added) {
      groups.add([item]);
    }
  }

  for (final group in groups) {
    final columns = <List<_TimelineItem>>[];
    for (final item in group) {
      bool placed = false;
      for (int i = 0; i < columns.length; i++) {
        final col = columns[i];
        if (col.last.endMinutes <= item.startMinutes) {
          col.add(item);
          item.subColumnIndex = i;
          placed = true;
          break;
        }
      }
      if (!placed) {
        item.subColumnIndex = columns.length;
        columns.add([item]);
      }
    }
    final totalCols = columns.length;
    for (final item in group) {
      item.totalSubColumns = totalCols;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Duration & Consumed Time Calculations
// ─────────────────────────────────────────────────────────────────────────────

double _calculateConsumedHours(List<_TimelineItem> dayItems) {
  if (dayItems.isEmpty) return 0.0;
  final List<List<double>> intervals = dayItems
      .map((item) => [item.startMinutes, item.endMinutes])
      .toList();
  intervals.sort((a, b) => a[0].compareTo(b[0]));

  final List<List<double>> merged = [];
  for (final current in intervals) {
    if (merged.isEmpty) {
      merged.add(current);
    } else {
      final last = merged.last;
      if (current[0] <= last[1]) {
        last[1] = last[1] > current[1] ? last[1] : current[1];
      } else {
        merged.add(current);
      }
    }
  }

  double totalMinutes = 0;
  for (final interval in merged) {
    totalMinutes += (interval[1] - interval[0]);
  }
  return totalMinutes / 60.0;
}

double _calculateLongestFreeSlotHours(List<_TimelineItem> dayItems) {
  final dayStart = _kStartHour * 60.0;
  final dayEnd = _kEndHour * 60.0;
  if (dayItems.isEmpty) return (dayEnd - dayStart) / 60.0;

  final List<List<double>> intervals = dayItems
      .map((item) => [item.startMinutes, item.endMinutes])
      .toList();
  intervals.sort((a, b) => a[0].compareTo(b[0]));

  double maxGap = 0.0;
  double lastEnd = dayStart;

  for (final interval in intervals) {
    if (interval[0] > lastEnd) {
      final gap = interval[0] - lastEnd;
      if (gap > maxGap) maxGap = gap;
    }
    if (interval[1] > lastEnd) {
      lastEnd = interval[1];
    }
  }
  if (dayEnd > lastEnd) {
    final gap = dayEnd - lastEnd;
    if (gap > maxGap) maxGap = gap;
  }
  return maxGap / 60.0;
}

String _formatHours(double hours) {
  final h = hours.floor();
  final m = ((hours - h) * 60).round();
  if (h > 0 && m > 0) {
    return '${h}h ${m}m';
  } else if (h > 0) {
    return '${h}h';
  } else {
    return '${m}m';
  }
}

List<DateTime> _occurrencesInDateRange(Appointment appt, DateTime rangeStart, DateTime rangeEnd) {
  final results = <DateTime>[];

  switch (appt.recurrenceType) {
    case 'once':
      if (!appt.startTime.isBefore(rangeStart) && appt.startTime.isBefore(rangeEnd)) {
        results.add(appt.startTime);
      }
      break;

    case 'daily':
      var current = DateTime(rangeStart.year, rangeStart.month, rangeStart.day, appt.startTime.hour, appt.startTime.minute);
      while (current.isBefore(rangeEnd)) {
        if (!current.isBefore(rangeStart)) {
          results.add(current);
        }
        current = current.add(const Duration(days: 1));
      }
      break;

    case 'weekly':
      final List<int> days = appt.recurrenceDays != null
          ? List<int>.from(jsonDecode(appt.recurrenceDays!))
          : [];
      var current = DateTime(rangeStart.year, rangeStart.month, rangeStart.day, appt.startTime.hour, appt.startTime.minute);
      while (current.isBefore(rangeEnd)) {
        if (days.contains(current.weekday) && !current.isBefore(rangeStart)) {
          results.add(current);
        }
        current = current.add(const Duration(days: 1));
      }
      break;

    case 'monthly':
      var current = DateTime(rangeStart.year, rangeStart.month, rangeStart.day, appt.startTime.hour, appt.startTime.minute);
      while (current.isBefore(rangeEnd)) {
        if (current.day == appt.startTime.day && !current.isBefore(rangeStart)) {
          results.add(current);
        }
        current = current.add(const Duration(days: 1));
      }
      break;
  }
  return results;
}

// ─────────────────────────────────────────────────────────────────────────────
// Public Widget
// ─────────────────────────────────────────────────────────────────────────────

class UnifiedPlanningTimeline extends ConsumerWidget {
  final DateTime selectedDate;
  final PeriodType periodType;

  const UnifiedPlanningTimeline({
    super.key,
    required this.selectedDate,
    required this.periodType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    late DateTime startDate;
    late DateTime endDate;

    if (periodType == PeriodType.daily) {
      startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      endDate = startDate.add(const Duration(days: 1));
    } else if (periodType == PeriodType.weekly) {
      final daysToSubtract = selectedDate.weekday - 1;
      startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
          .subtract(Duration(days: daysToSubtract));
      endDate = startDate.add(const Duration(days: 7));
    } else {
      startDate = DateTime(selectedDate.year, selectedDate.month, 1);
      endDate = DateTime(selectedDate.year, selectedDate.month + 1, 1);
    }

    final appointmentsAsync = ref.watch(allAppointmentsProvider);
    final tasksAsync = ref.watch(weeklyTasksProvider(startDate));
    final activitiesAsync = ref.watch(allActivitiesProvider);

    final appointments = appointmentsAsync.valueOrNull ?? [];
    final tasks = tasksAsync.valueOrNull ?? [];
    final activities = activitiesAsync.valueOrNull ?? [];

    final Map<String, Activity> actMap = {for (final a in activities) a.id: a};
    final activeAppointments = appointments.where((a) => !a.isArchived && a.isEnabled).toList();

    // If Month View, render Monthly Calendar Overview Grid
    if (periodType == PeriodType.monthly) {
      return _buildMonthlyView(context, ref, startDate, endDate, activeAppointments, tasks, actMap);
    }

    // Single Day or 7-Day Grid View
    final daysCount = endDate.difference(startDate).inDays;
    final days = List.generate(daysCount, (i) => startDate.add(Duration(days: i)));

    final List<_TimelineItem> allTimedItems = [];
    final Map<String, List<DayTask>> untimedTasksMap = {};

    for (final appt in activeAppointments) {
      for (final dt in _occurrencesInDateRange(appt, startDate, endDate)) {
        allTimedItems.add(_TimelineItem(
          id: appt.id,
          title: appt.title,
          notes: appt.notes,
          startTime: dt,
          durationMinutes: appt.durationMinutes,
          activity: actMap[appt.activityId],
          isTask: false,
          appt: appt,
        ));
      }
    }

    for (final task in tasks) {
      if (task.reminderTime != null) {
        final dt = task.reminderTime!;
        if (!dt.isBefore(startDate) && dt.isBefore(endDate)) {
          allTimedItems.add(_TimelineItem(
            id: task.id,
            title: task.title,
            notes: task.notes,
            startTime: dt,
            durationMinutes: task.estimatedMinutes,
            activity: actMap[task.activityId],
            isTask: true,
            isCompleted: task.isCompleted,
            task: task,
          ));
        }
      } else {
        untimedTasksMap.putIfAbsent(task.date, () => []).add(task);
      }
    }

    // Run overlap layout per day
    for (final day in days) {
      final dayItems = allTimedItems.where((item) =>
          item.startTime.year == day.year &&
          item.startTime.month == day.month &&
          item.startTime.day == day.day).toList();
      _layoutOverlappingItems(dayItems);
    }

    final totalHours = _kEndHour - _kStartHour;
    final now = DateTime.now();

    return Column(
      children: [
        // Day Header & Untimed tasks
        _HeaderRow(
          days: days,
          allTimedItems: allTimedItems,
          untimedTasksMap: untimedTasksMap,
          onTapDay: (day, dayTasks) {
            final dayItems = allTimedItems.where((item) =>
                item.startTime.year == day.year &&
                item.startTime.month == day.month &&
                item.startTime.day == day.day).toList();
            _showDaySummaryModal(context, ref, day, dayItems, dayTasks);
          },
        ),

        const Divider(height: 1, color: AppTheme.border),

        // Scrollable Grid
        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              height: totalHours * _kHourHeight + 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hour labels
                  SizedBox(
                    width: _kLabelWidth,
                    child: Stack(
                      children: List.generate(totalHours + 1, (i) {
                        final hour = _kStartHour + i;
                        return Positioned(
                          top: i * _kHourHeight - 8,
                          left: 0, right: 0,
                          child: Text(
                            _formatHour(hour),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Day columns
                  Expanded(
                    child: Stack(
                      children: [
                        // Grid lines
                        ...List.generate(totalHours + 1, (i) => Positioned(
                          top: i * _kHourHeight,
                          left: 0, right: 0,
                          child: Container(height: 1, color: AppTheme.border.withOpacity(0.4)),
                        )),

                        // Live current time red line
                        _RedCurrentTimeLine(days: days, now: now),

                        // Render timeline items with side-by-side overlap
                        LayoutBuilder(builder: (ctx, constraints) {
                          final colWidth = constraints.maxWidth / days.length;
                          return Stack(
                            children: allTimedItems.map((item) {
                              final colIndex = days.indexWhere((d) =>
                                  d.year == item.startTime.year &&
                                  d.month == item.startTime.month &&
                                  d.day == item.startTime.day);
                              if (colIndex == -1) return const SizedBox.shrink();

                              final startFrac = (item.startTime.hour + item.startTime.minute / 60.0) - _kStartHour;
                              final durFrac = item.durationMinutes / 60.0;

                              final clampedStart = startFrac.clamp(0.0, totalHours.toDouble());
                              final clampedDur = durFrac.clamp(0.0, totalHours - clampedStart);
                              if (clampedDur <= 0) return const SizedBox.shrink();

                              final color = item.activity != null
                                  ? Color(item.activity!.color)
                                  : AppTheme.primaryGlow;

                              final subColWidth = colWidth / item.totalSubColumns;
                              final itemLeft = colIndex * colWidth + (item.subColumnIndex * subColWidth);

                              return Positioned(
                                top: clampedStart * _kHourHeight + 1,
                                left: itemLeft + 1,
                                width: subColWidth - 2,
                                height: (clampedDur * _kHourHeight - 2).clamp(18.0, double.infinity),
                                child: _TimelineItemCard(item: item, color: color),
                              );
                            }).toList(),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _formatHour(int h) {
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  // Monthly Overview Card Grid
  Widget _buildMonthlyView(
    BuildContext context,
    WidgetRef ref,
    DateTime startDate,
    DateTime endDate,
    List<Appointment> appointments,
    List<DayTask> tasks,
    Map<String, Activity> actMap,
  ) {
    final daysCount = endDate.difference(startDate).inDays;
    final days = List.generate(daysCount, (i) => startDate.add(Duration(days: i)));

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final day = days[i];
        final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final dayTasks = tasks.where((t) => t.date == dateStr).toList();
        final dayAppts = <Appointment>[];
        for (final appt in appointments) {
          if (_occurrencesInDateRange(appt, day, day.add(const Duration(days: 1))).isNotEmpty) {
            dayAppts.add(appt);
          }
        }

        final completedTasks = dayTasks.where((t) => t.isCompleted).length;
        final totalTasks = dayTasks.length;
        final compPercent = totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 100;

        return InkWell(
          onTap: () {
            final dayItems = <_TimelineItem>[];
            for (final appt in dayAppts) {
              dayItems.add(_TimelineItem(
                id: appt.id,
                title: appt.title,
                notes: appt.notes,
                startTime: appt.startTime,
                durationMinutes: appt.durationMinutes,
                activity: actMap[appt.activityId],
                isTask: false,
                appt: appt,
              ));
            }
            _showDaySummaryModal(context, ref, day, dayItems, dayTasks);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${day.day}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                    ),
                    Text(
                      DateFormat('E').format(day),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tasks: $totalTasks', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    Text('Appts: ${dayAppts.length}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      '$compPercent% Done',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: compPercent == 100 ? Colors.greenAccent : AppTheme.primaryGlow,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header row
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  final List<DateTime> days;
  final List<_TimelineItem> allTimedItems;
  final Map<String, List<DayTask>> untimedTasksMap;
  final void Function(DateTime day, List<DayTask> dayTasks) onTapDay;

  const _HeaderRow({
    required this.days,
    required this.allTimedItems,
    required this.untimedTasksMap,
    required this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.only(left: _kLabelWidth, top: 4, bottom: 4),
      child: Row(
        children: days.map((day) {
          final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
          final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          final dayItems = allTimedItems.where((item) =>
              item.startTime.year == day.year &&
              item.startTime.month == day.month &&
              item.startTime.day == day.day).toList();
          final consumedHours = _calculateConsumedHours(dayItems);
          final untimedTasks = untimedTasksMap[dateStr] ?? [];

          return Expanded(
            child: InkWell(
              onTap: () => onTapDay(day, untimedTasks),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                decoration: isToday
                    ? BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(day),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isToday ? AppTheme.primaryGlow : AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isToday ? AppTheme.primaryGlow : AppTheme.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: consumedHours > 0
                            ? AppTheme.primaryGlow.withOpacity(0.15)
                            : AppTheme.textMuted.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${consumedHours.toStringAsFixed(consumedHours % 1 == 0 ? 0 : 1)}h',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: consumedHours > 0 ? AppTheme.primaryGlow : AppTheme.textMuted,
                        ),
                      ),
                    ),
                    if (untimedTasks.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGlow.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '${untimedTasks.length} untimed',
                          style: const TextStyle(fontSize: 8, color: AppTheme.primaryGlow, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Red Current Time Line Indicator
// ─────────────────────────────────────────────────────────────────────────────

class _RedCurrentTimeLine extends StatelessWidget {
  final List<DateTime> days;
  final DateTime now;

  const _RedCurrentTimeLine({required this.days, required this.now});

  @override
  Widget build(BuildContext context) {
    final colIndex = days.indexWhere((d) =>
        d.year == now.year && d.month == now.month && d.day == now.day);
    if (colIndex == -1 || now.hour < _kStartHour || now.hour >= _kEndHour) {
      return const SizedBox.shrink();
    }

    final topOffset = ((now.hour + now.minute / 60.0) - _kStartHour) * _kHourHeight;

    return Positioned.fill(
      child: LayoutBuilder(builder: (ctx, constraints) {
        final colWidth = constraints.maxWidth / days.length;
        return Stack(
          children: [
            Positioned(
              top: topOffset,
              left: colIndex * colWidth,
              width: colWidth,
              child: Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                  Expanded(child: Container(height: 1.5, color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item Card Block
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineItemCard extends StatelessWidget {
  final _TimelineItem item;
  final Color color;

  const _TimelineItemCard({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(item.startTime);

    return Container(
      decoration: BoxDecoration(
        color: item.isTask ? color.withOpacity(0.18) : color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: item.isTask ? color.withOpacity(0.8) : color,
          width: item.isTask ? 1.2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (item.isTask)
                    Icon(
                      item.isCompleted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      color: color,
                      size: 9,
                    ),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: item.isTask ? AppTheme.textPrimary : Colors.white,
                        decoration: (item.isTask && item.isCompleted) ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (item.durationMinutes >= 30)
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 7, color: item.isTask ? AppTheme.textSecondary : Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day Summary Modal
// ─────────────────────────────────────────────────────────────────────────────

void _showDaySummaryModal(
  BuildContext context,
  WidgetRef ref,
  DateTime day,
  List<_TimelineItem> dayItems,
  List<DayTask> dayTasks,
) {
  final double consumedHours = _calculateConsumedHours(dayItems);
  final double freeHours = (24.0 - consumedHours).clamp(0.0, 24.0);
  final double longestFreeSlot = _calculateLongestFreeSlotHours(dayItems);

  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(day),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statBox('Busy Time', _formatHours(consumedHours), AppTheme.primaryGlow),
                _statBox('Free Time', _formatHours(freeHours), Colors.greenAccent),
                _statBox('Longest Free Slot', _formatHours(longestFreeSlot), Colors.cyanAccent),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Tasks (${dayTasks.where((t) => t.isCompleted).length}/${dayTasks.length} Completed)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: dayTasks.length,
                itemBuilder: (context, i) {
                  final task = dayTasks[i];
                  return Row(
                    children: [
                      Checkbox(
                        value: task.isCompleted,
                        activeColor: AppTheme.primaryGlow,
                        onChanged: (_) {
                          ref.read(taskControllerProvider.notifier).toggleTask(task);
                        },
                      ),
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 12,
                            color: task.isCompleted ? AppTheme.textMuted : AppTheme.textPrimary,
                            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _statBox(String label, String val, Color col) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      const SizedBox(height: 2),
      Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: col)),
    ],
  );
}
