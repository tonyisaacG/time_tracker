import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/features/activity/application/activity_providers.dart';
import 'package:tracker_time/features/planner/application/planner_providers.dart';
import '../application/schedule_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const double _kHourHeight = 60.0;   // pixels per hour
const double _kLabelWidth = 46.0;   // left time-label column width
const int    _kStartHour  = 6;      // timeline starts at 6 AM
const int    _kEndHour    = 23;     // timeline ends at 11 PM

// ─────────────────────────────────────────────────────────────────────────────
// Helper Models & Calculations
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

  const _TimelineItem({
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
}

double _calculateConsumedHours(List<_TimelineItem> dayItems) {
  if (dayItems.isEmpty) return 0.0;
  final List<List<double>> intervals = [];
  for (final item in dayItems) {
    final startMinutes = item.startTime.hour * 60.0 + item.startTime.minute;
    final endMinutes = startMinutes + item.durationMinutes;
    intervals.add([startMinutes, endMinutes]);
  }
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

// ─────────────────────────────────────────────────────────────────────────────
// Helper: expand recurring appointment → list of DateTime occurrences for week
// ─────────────────────────────────────────────────────────────────────────────

List<DateTime> _occurrencesInWeek(Appointment appt, DateTime weekMonday) {
  final results = <DateTime>[];
  final weekEnd = weekMonday.add(const Duration(days: 7));

  switch (appt.recurrenceType) {
    case 'once':
      final d = appt.startTime;
      if (!d.isBefore(weekMonday) && d.isBefore(weekEnd)) {
        results.add(d);
      }
      break;

    case 'weekly':
      final List<int> days = appt.recurrenceDays != null
          ? List<int>.from(jsonDecode(appt.recurrenceDays!))
          : [];
      for (int i = 0; i < 7; i++) {
        final day = weekMonday.add(Duration(days: i));
        if (days.contains(day.weekday)) {
          results.add(DateTime(
            day.year, day.month, day.day,
            appt.startTime.hour, appt.startTime.minute,
          ));
        }
      }
      break;

    case 'monthly':
      for (int i = 0; i < 7; i++) {
        final day = weekMonday.add(Duration(days: i));
        if (day.day == appt.startTime.day) {
          results.add(DateTime(
            day.year, day.month, day.day,
            appt.startTime.hour, appt.startTime.minute,
          ));
        }
      }
      break;
  }

  return results;
}

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

class WeeklyTimelineView extends ConsumerStatefulWidget {
  const WeeklyTimelineView({super.key});

  @override
  ConsumerState<WeeklyTimelineView> createState() => _WeeklyTimelineViewState();
}

class _WeeklyTimelineViewState extends ConsumerState<WeeklyTimelineView> {
  late DateTime _weekMonday;
  final ScrollController _vertScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _weekMonday = _mondayOf(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      final offset = ((now.hour - _kStartHour) * _kHourHeight - 80).clamp(0.0, double.infinity);
      if (_vertScroll.hasClients) {
        _vertScroll.animateTo(offset, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _vertScroll.dispose();
    super.dispose();
  }

  static DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  void _prevWeek() => setState(() => _weekMonday = _weekMonday.subtract(const Duration(days: 7)));
  void _nextWeek() => setState(() => _weekMonday = _weekMonday.add(const Duration(days: 7)));

  bool get _isCurrentWeek {
    final now = _mondayOf(DateTime.now());
    return _weekMonday == now;
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(allAppointmentsProvider);
    final tasksAsync        = ref.watch(weeklyTasksProvider(_weekMonday));
    final activitiesAsync   = ref.watch(allActivitiesProvider);

    if (appointmentsAsync.isLoading || tasksAsync.isLoading || activitiesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGlow));
    }
    if (appointmentsAsync.hasError) {
      return Center(child: Text('Error: ${appointmentsAsync.error}', style: const TextStyle(color: Colors.red)));
    }
    if (tasksAsync.hasError) {
      return Center(child: Text('Error: ${tasksAsync.error}', style: const TextStyle(color: Colors.red)));
    }

    final appointments = appointmentsAsync.valueOrNull ?? [];
    final tasks        = tasksAsync.valueOrNull ?? [];
    final activities   = activitiesAsync.valueOrNull ?? [];

    final now = DateTime.now();
    final totalHours = _kEndHour - _kStartHour;

    final Map<String, Activity> actMap = {for (final a in activities) a.id: a};

    // 1. Map appointments and timed tasks to timelineItems
    final List<_TimelineItem> timelineItems = [];

    for (final appt in appointments) {
      if (appt.isArchived || !appt.isEnabled) continue;
      for (final dt in _occurrencesInWeek(appt, _weekMonday)) {
        timelineItems.add(_TimelineItem(
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

    // Timed tasks
    for (final task in tasks) {
      if (task.reminderTime == null) continue;
      final dt = task.reminderTime!;
      final weekEnd = _weekMonday.add(const Duration(days: 7));
      if (dt.isBefore(_weekMonday) || !dt.isBefore(weekEnd)) continue;

      timelineItems.add(_TimelineItem(
        id: task.id,
        title: task.title,
        notes: task.notes,
        startTime: dt,
        durationMinutes: 30, // Default task duration
        activity: actMap[task.activityId],
        isTask: true,
        isCompleted: task.isCompleted,
        task: task,
      ));
    }

    // 2. Untimed tasks map (grouped by date string)
    final Map<String, List<DayTask>> untimedTasksMap = {};
    for (final task in tasks) {
      if (task.reminderTime == null) {
        untimedTasksMap.putIfAbsent(task.date, () => []).add(task);
      }
    }

    return Column(
      children: [
        // ── Week navigation bar ─────────────────────────────────────────────
        _WeekNavBar(
          weekMonday: _weekMonday,
          isCurrentWeek: _isCurrentWeek,
          onPrev: _prevWeek,
          onNext: _nextWeek,
          onToday: () => setState(() => _weekMonday = _mondayOf(DateTime.now())),
        ),

        // ── Day-header row with consumed time ────────────────────────────────
        _DayHeaderRow(
          weekMonday: _weekMonday,
          now: now,
          timelineItems: timelineItems,
          weeklyTasks: tasks,
        ),

        // ── Untimed Tasks Row ───────────────────────────────────────────────
        _UntimedTasksHeaderRow(
          weekMonday: _weekMonday,
          untimedTasksMap: untimedTasksMap,
          onTapDay: (day, dayTasks) {
            final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
            final dayItems = timelineItems.where((item) =>
                item.startTime.year == day.year &&
                item.startTime.month == day.month &&
                item.startTime.day == day.day).toList();
            _showDaySummaryBottomSheet(context, ref, day, dayItems, dayTasks);
          },
        ),

        const Divider(height: 1, color: AppTheme.border),

        // ── Scrollable hour grid ───────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            controller: _vertScroll,
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
                          left: 0,
                          right: 0,
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
                        // Hour grid lines
                        ...List.generate(totalHours + 1, (i) => Positioned(
                          top: i * _kHourHeight,
                          left: 0, right: 0,
                          child: Container(height: 1, color: AppTheme.border.withOpacity(0.4)),
                        )),

                        // "Now" line (today only, current week)
                        if (_isCurrentWeek && now.hour >= _kStartHour && now.hour < _kEndHour)
                          _NowLine(now: now, weekMonday: _weekMonday),

                        // Timeline blocks (Schedules & Timed Tasks)
                        LayoutBuilder(builder: (ctx, constraints) {
                          final colWidth = constraints.maxWidth / 7;
                          return Stack(
                            children: timelineItems.map((item) {
                              final colIndex = item.startTime.weekday - 1; // 0=Mon
                              final startFrac = (item.startTime.hour + item.startTime.minute / 60.0) - _kStartHour;
                              final durFrac   = item.durationMinutes / 60.0;

                              final clampedStart = startFrac.clamp(0.0, (_kEndHour - _kStartHour).toDouble());
                              final clampedDur   = durFrac.clamp(0.0, (_kEndHour - _kStartHour) - clampedStart);
                              if (clampedDur <= 0) return const SizedBox.shrink();

                              final color = item.activity != null
                                  ? Color(item.activity!.color)
                                  : AppTheme.primaryGlow;

                              return Positioned(
                                top: clampedStart * _kHourHeight + 1,
                                left: colIndex * colWidth + 2,
                                width: colWidth - 4,
                                height: (clampedDur * _kHourHeight - 2).clamp(18.0, double.infinity),
                                child: _TimelineItemBlock(item: item, color: color),
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

        // ── Legend / hint bar ─────────────────────────────────────────────
        const _LegendBar(),
      ],
    );
  }

  static String _formatHour(int h) {
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Week navigation bar
// ─────────────────────────────────────────────────────────────────────────────

class _WeekNavBar extends StatelessWidget {
  final DateTime weekMonday;
  final bool isCurrentWeek;
  final VoidCallback onPrev, onNext, onToday;

  const _WeekNavBar({
    required this.weekMonday,
    required this.isCurrentWeek,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final sunday = weekMonday.add(const Duration(days: 6));
    final label = '${DateFormat('MMM d').format(weekMonday)} – ${DateFormat('MMM d, yyyy').format(sunday)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textSecondary),
            onPressed: onPrev,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            onPressed: onNext,
            visualDensity: VisualDensity.compact,
          ),
          if (!isCurrentWeek)
            TextButton(
              onPressed: onToday,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Today', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day header row (Mon, Tue, … Sun) with consumed time pills
// ─────────────────────────────────────────────────────────────────────────────

class _DayHeaderRow extends ConsumerWidget {
  final DateTime weekMonday;
  final DateTime now;
  final List<_TimelineItem> timelineItems;
  final List<DayTask> weeklyTasks;

  const _DayHeaderRow({
    required this.weekMonday,
    required this.now,
    required this.timelineItems,
    required this.weeklyTasks,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.only(left: _kLabelWidth),
      child: Row(
        children: List.generate(7, (i) {
          final day = weekMonday.add(Duration(days: i));
          final isToday = day == today;
          final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

          final dayItems = timelineItems.where((item) =>
              item.startTime.year == day.year &&
              item.startTime.month == day.month &&
              item.startTime.day == day.day).toList();

          final consumedHours = _calculateConsumedHours(dayItems);
          final dayTasks = weeklyTasks.where((t) => t.date == dateStr).toList();

          return Expanded(
            child: InkWell(
              onTap: () => _showDaySummaryBottomSheet(context, ref, day, dayItems, dayTasks),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: isToday
                    ? BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        border: const Border(bottom: BorderSide(color: AppTheme.primaryGlow, width: 2)),
                      )
                    : null,
                child: Column(
                  children: [
                    Text(
                      dayNames[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isToday ? AppTheme.primaryGlow : AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isToday ? AppTheme.primaryGlow : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Untimed Tasks Header Row (displays untimed tasks directly above the grid)
// ─────────────────────────────────────────────────────────────────────────────

class _UntimedTasksHeaderRow extends StatelessWidget {
  final DateTime weekMonday;
  final Map<String, List<DayTask>> untimedTasksMap;
  final void Function(DateTime day, List<DayTask> dayTasks) onTapDay;

  const _UntimedTasksHeaderRow({
    required this.weekMonday,
    required this.untimedTasksMap,
    required this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: _kLabelWidth, top: 4, bottom: 4),
      child: Row(
        children: List.generate(7, (i) {
          final day = weekMonday.add(Duration(days: i));
          final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          final tasks = untimedTasksMap[dateStr] ?? [];

          if (tasks.isEmpty) {
            return const Expanded(child: SizedBox.shrink());
          }

          final completedCount = tasks.where((t) => t.isCompleted).length;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: GestureDetector(
                onTap: () => onTapDay(day, tasks),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGlow.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.primaryGlow.withOpacity(0.4), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.playlist_add_check_rounded, size: 10, color: AppTheme.primaryGlow),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          '$completedCount/${tasks.length}',
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.primaryGlow),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Now" horizontal line
// ─────────────────────────────────────────────────────────────────────────────

class _NowLine extends StatelessWidget {
  final DateTime now;
  final DateTime weekMonday;

  const _NowLine({required this.now, required this.weekMonday});

  @override
  Widget build(BuildContext context) {
    final topOffset = ((now.hour + now.minute / 60.0) - _kStartHour) * _kHourHeight;
    final colIndex  = now.weekday - 1;

    return LayoutBuilder(builder: (ctx, constraints) {
      final colWidth = constraints.maxWidth / 7;
      return Positioned(
        top: topOffset,
        left: colIndex * colWidth,
        width: colWidth,
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
            ),
            Expanded(child: Container(height: 1.5, color: Colors.redAccent)),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline item block (Appointments & Timed Tasks)
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineItemBlock extends StatelessWidget {
  final _TimelineItem item;
  final Color color;

  const _TimelineItemBlock({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(item.startTime);
    final endTime = item.startTime.add(Duration(minutes: item.durationMinutes));
    final endStr  = DateFormat('h:mm a').format(endTime);

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: item.isTask
              ? color.withOpacity(0.15)
              : color.withOpacity(0.85),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: item.isTask ? color.withOpacity(0.8) : color,
            width: item.isTask ? 1.5 : 1,
          ),
          boxShadow: item.isTask
              ? null
              : [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.isTask) ...[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  item.isCompleted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  color: color,
                  size: 10,
                ),
              ),
              const SizedBox(width: 3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: item.isTask ? AppTheme.textPrimary : Colors.white,
                        height: 1.1,
                        decoration: (item.isTask && item.isCompleted) ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.durationMinutes >= 30)
                    Text(
                      '$timeStr–$endStr',
                      style: TextStyle(
                        fontSize: 8,
                        color: item.isTask ? AppTheme.textSecondary : Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(item.startTime);
    final endTime = item.startTime.add(Duration(minutes: item.durationMinutes));
    final endStr  = DateFormat('h:mm a').format(endTime);
    final icon    = item.activity != null
        ? (AppTheme.activityIcons[item.activity!.icon] ?? Icons.category_rounded)
        : (item.isTask ? Icons.task_alt_rounded : Icons.event_note_rounded);

    showDialog(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(
                  icon: Icons.access_time_rounded,
                  text: item.isTask
                      ? '$timeStr (Task)'
                      : '$timeStr → $endStr  (${item.durationMinutes} min)',
                ),
                _DetailRow(icon: Icons.calendar_today_rounded, text: DateFormat('EEEE, MMMM d').format(item.startTime)),
                if (item.activity != null)
                  _DetailRow(icon: Icons.label_rounded, text: item.activity!.name, color: color),
                if (item.notes != null && item.notes!.trim().isNotEmpty)
                  _DetailRow(icon: Icons.notes_rounded, text: item.notes!),
                if (item.isTask)
                  _DetailRow(
                    icon: Icons.check_circle_outline_rounded,
                    text: item.isCompleted ? 'Completed' : 'Pending',
                    color: item.isCompleted ? Colors.greenAccent : Colors.orangeAccent,
                  ),
              ],
            ),
            actions: [
              if (item.isTask && item.task != null)
                TextButton(
                  onPressed: () {
                    ref.read(taskControllerProvider.notifier).toggleTask(item.task!);
                    Navigator.pop(context);
                  },
                  child: Text(item.isCompleted ? 'Mark Pending' : 'Mark Completed'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        }
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _DetailRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: color ?? AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day Summary Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

void _showDaySummaryBottomSheet(
  BuildContext context,
  WidgetRef ref,
  DateTime day,
  List<_TimelineItem> dayItems,
  List<DayTask> dayTasks,
) {
  final double consumedHours = _calculateConsumedHours(dayItems);
  final double freeHours = (24.0 - consumedHours).clamp(0.0, 24.0);
  final percentConsumed = consumedHours / 24.0;
  
  final dayNameStr = DateFormat('EEEE, MMMM d, yyyy').format(day);

  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (context) {
      return Consumer(
        builder: (context, ref, _) {
          final String dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          final weeklyTasksAsync = ref.watch(weeklyTasksProvider(
            DateTime(day.year, day.month, day.day).subtract(Duration(days: day.weekday - 1))
          ));
          final currentWeeklyTasks = weeklyTasksAsync.valueOrNull ?? [];
          final currentDayTasks = currentWeeklyTasks.where((t) => t.date == dateStr).toList();
          
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppTheme.border,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        dayNameStr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Progress Bar Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Consumed Time', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatHours(consumedHours),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGlow),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Free Time', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatHours(freeHours),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: percentConsumed,
                                minHeight: 10,
                                backgroundColor: Colors.greenAccent.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGlow),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(percentConsumed * 100).toStringAsFixed(0)}% of the day is consumed',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Schedules List
                      const Text(
                        'Schedules',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      if (dayItems.where((item) => !item.isTask).isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No schedules today', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                        )
                      else
                        ...dayItems.where((item) => !item.isTask).map((item) {
                          final timeStr = DateFormat('h:mm a').format(item.startTime);
                          final endTime = item.startTime.add(Duration(minutes: item.durationMinutes));
                          final endStr = DateFormat('h:mm a').format(endTime);
                          final activityColor = item.activity != null ? Color(item.activity!.color) : AppTheme.primaryGlow;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: activityColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$timeStr – $endStr',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        
                      const SizedBox(height: 24),
                      
                      // Tasks List
                      const Text(
                        'Tasks',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      if (currentDayTasks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No tasks today', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                        )
                      else
                        ...currentDayTasks.map((task) {
                          final timeStr = task.reminderTime != null ? DateFormat('h:mm a').format(task.reminderTime!) : 'Untimed Task';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: task.isCompleted,
                                  activeColor: AppTheme.primaryGlow,
                                  onChanged: (_) {
                                    ref.read(taskControllerProvider.notifier).toggleTask(task);
                                  },
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: task.isCompleted ? AppTheme.textMuted : AppTheme.textPrimary,
                                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 10, color: AppTheme.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            timeStr,
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend bar
// ─────────────────────────────────────────────────────────────────────────────

class _LegendBar extends StatelessWidget {
  const _LegendBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          _legendItem(Colors.redAccent, 'Now'),
          const SizedBox(width: 12),
          _legendItem(AppTheme.primaryGlow, 'Scheduled'),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGlow.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: AppTheme.primaryGlow.withOpacity(0.8), width: 1.2),
                ),
              ),
              const SizedBox(width: 4),
              const Text('Task', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Empty space = free time',
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}
