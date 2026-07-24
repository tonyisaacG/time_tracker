import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/features/activity/application/activity_providers.dart';
import '../application/schedule_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const double _kHourHeight = 60.0;   // pixels per hour
const double _kLabelWidth = 46.0;   // left time-label column width
const int    _kStartHour  = 6;      // timeline starts at 6 AM
const int    _kEndHour    = 23;     // timeline ends at 11 PM

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
      // Map weekday: Mon=1…Sun=7
      for (int i = 0; i < 7; i++) {
        final day = weekMonday.add(Duration(days: i));
        // Flutter weekday: Mon=1, Sun=7  — matches our storage convention
        if (days.contains(day.weekday)) {
          results.add(DateTime(
            day.year, day.month, day.day,
            appt.startTime.hour, appt.startTime.minute,
          ));
        }
      }
      break;

    case 'monthly':
      // Show on the matching day-of-month if it falls within this week
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
    // Auto-scroll to current hour on open
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
    final activitiesAsync   = ref.watch(allActivitiesProvider);

    final now = DateTime.now();
    final totalHours = _kEndHour - _kStartHour;

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

        // ── Day-header row ─────────────────────────────────────────────────
        _DayHeaderRow(weekMonday: _weekMonday, now: now),

        const Divider(height: 1, color: AppTheme.border),

        // ── Scrollable hour grid ───────────────────────────────────────────
        Expanded(
          child: appointmentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGlow)),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
            data: (appointments) {
              final activities = activitiesAsync.valueOrNull ?? [];
              final Map<String, Activity> actMap = {for (final a in activities) a.id: a};

              // Expand all enabled, non-archived appointments into occurrences
              final List<_Occurrence> occurrences = [];
              for (final appt in appointments) {
                if (appt.isArchived || !appt.isEnabled) continue;
                for (final dt in _occurrencesInWeek(appt, _weekMonday)) {
                  occurrences.add(_Occurrence(appt: appt, dateTime: dt, activity: actMap[appt.activityId]));
                }
              }

              return SingleChildScrollView(
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

                            // Appointment blocks
                            LayoutBuilder(builder: (ctx, constraints) {
                              final colWidth = constraints.maxWidth / 7;
                              return Stack(
                                children: occurrences.map((occ) {
                                  final colIndex = occ.dateTime.weekday - 1; // 0=Mon
                                  final startFrac = (occ.dateTime.hour + occ.dateTime.minute / 60.0) - _kStartHour;
                                  final durFrac   = occ.appt.durationMinutes / 60.0;

                                  // Clamp to visible range
                                  final clampedStart = startFrac.clamp(0.0, (_kEndHour - _kStartHour).toDouble());
                                  final clampedDur   = durFrac.clamp(0.0, (_kEndHour - _kStartHour) - clampedStart);
                                  if (clampedDur <= 0) return const SizedBox.shrink();

                                  final color = occ.activity != null
                                      ? Color(occ.activity!.color)
                                      : AppTheme.primaryGlow;

                                  return Positioned(
                                    top: clampedStart * _kHourHeight + 1,
                                    left: colIndex * colWidth + 2,
                                    width: colWidth - 4,
                                    height: (clampedDur * _kHourHeight - 2).clamp(18.0, double.infinity),
                                    child: _AppointmentBlock(occ: occ, color: color),
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
              );
            },
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
// Day header row (Mon, Tue, … Sun)
// ─────────────────────────────────────────────────────────────────────────────

class _DayHeaderRow extends StatelessWidget {
  final DateTime weekMonday;
  final DateTime now;

  const _DayHeaderRow({required this.weekMonday, required this.now});

  @override
  Widget build(BuildContext context) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.only(left: _kLabelWidth),
      child: Row(
        children: List.generate(7, (i) {
          final day = weekMonday.add(Duration(days: i));
          final isToday = day == today;
          return Expanded(
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
                ],
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
// Appointment block
// ─────────────────────────────────────────────────────────────────────────────

class _Occurrence {
  final Appointment appt;
  final DateTime dateTime;
  final Activity? activity;
  const _Occurrence({required this.appt, required this.dateTime, this.activity});
}

class _AppointmentBlock extends StatelessWidget {
  final _Occurrence occ;
  final Color color;

  const _AppointmentBlock({required this.occ, required this.color});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(occ.dateTime);
    final endTime = occ.dateTime.add(Duration(minutes: occ.appt.durationMinutes));
    final endStr  = DateFormat('h:mm a').format(endTime);

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.85),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color, width: 1),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                occ.appt.title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (occ.appt.durationMinutes >= 30)
              Text(
                '$timeStr–$endStr',
                style: const TextStyle(fontSize: 9, color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(occ.dateTime);
    final endTime = occ.dateTime.add(Duration(minutes: occ.appt.durationMinutes));
    final endStr  = DateFormat('h:mm a').format(endTime);
    final color   = occ.activity != null ? Color(occ.activity!.color) : AppTheme.primaryGlow;
    final icon    = occ.activity != null
        ? (AppTheme.activityIcons[occ.activity!.icon] ?? Icons.category_rounded)
        : Icons.event_note_rounded;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
                occ.appt.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(icon: Icons.access_time_rounded, text: '$timeStr → $endStr  (${occ.appt.durationMinutes} min)'),
            _DetailRow(icon: Icons.calendar_today_rounded, text: DateFormat('EEEE, MMMM d').format(occ.dateTime)),
            if (occ.activity != null)
              _DetailRow(icon: Icons.label_rounded, text: occ.activity!.name, color: color),
            if (occ.appt.notes != null && occ.appt.notes!.trim().isNotEmpty)
              _DetailRow(icon: Icons.notes_rounded, text: occ.appt.notes!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
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
          const SizedBox(width: 16),
          _legendItem(AppTheme.primaryGlow, 'Scheduled'),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Empty space = free time',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
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
        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
