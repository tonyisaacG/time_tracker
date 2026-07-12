import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/core/providers/navigation_provider.dart';
import 'package:tracker_time/features/activity/application/activity_providers.dart';
import 'package:tracker_time/features/report/application/report_service.dart';
import 'package:tracker_time/features/report/domain/report_models.dart';
import 'package:tracker_time/features/session/presentation/session_history_list.dart';
import 'package:tracker_time/features/session/application/session_providers.dart';
import '../application/timer_providers.dart';

class TimerDashboard extends ConsumerStatefulWidget {
  const TimerDashboard({super.key});

  @override
  ConsumerState<TimerDashboard> createState() => _TimerDashboardState();
}

class _TimerDashboardState extends ConsumerState<TimerDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final TextEditingController _notesController = TextEditingController();
  String? _lastSessionId;
  bool _weeksFocusOnly = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final activeSessionAsync = ref.watch(activeSessionProvider);
    final activeDurationAsync = ref.watch(activeSessionDurationProvider);
    final activitiesAsync = ref.watch(activeActivitiesProvider);

    // Sync notes text field with current running session
    activeSessionAsync.whenData((session) {
      if (session != null && session.id != _lastSessionId) {
        _lastSessionId = session.id;
        _notesController.text = session.notes ?? '';
      } else if (session == null) {
        _lastSessionId = null;
        _notesController.clear();
      }
    });

    // Auto-stop active timer if weekly limit is reached or countdown completes
    ref.listen<AsyncValue<Duration>>(activeSessionDurationProvider, (prev, next) async {
      if (next is! AsyncData<Duration>) return;
      final elapsed = next.value;

      final session = ref.read(activeSessionProvider).valueOrNull;
      if (session == null) return;

      final activities = ref.read(activeActivitiesProvider).valueOrNull ?? [];
      final activity = activities.firstWhere(
        (a) => a.id == session.activityId,
        orElse: () => Activity(
          id: session.activityId,
          name: '',
          color: 0,
          icon: '',
          isLimit: false,
          enforceLimit: false,
          isWeeklyFocus: true,
          isArchived: false,
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 1. Check countdown finish
      if (session.targetDurationMinutes != null && elapsed == Duration.zero) {
        await ref.read(timerControllerProvider.notifier).stopTimer(
          notes: _notesController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Countdown session complete for ${activity.name}!'),
              backgroundColor: const Color(0xff10b981),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // 2. Check weekly limit
      if (activity.name.isNotEmpty &&
          activity.weeklyGoalMinutes != null &&
          activity.isLimit &&
          activity.enforceLimit) {
        final weeklyReportAsync = ref.read(weeklyReportProvider);
        final weeklyReport = weeklyReportAsync.valueOrNull;
        if (weeklyReport != null) {
          final activityItem = weeklyReport.items.firstWhere(
            (item) => item.activity.id == activity.id,
            orElse: () => ActivityReportItem(activity: activity, totalMinutes: 0),
          );
          // If countdown, elapsed counts down (remaining), so we measure actual elapsed time:
          final actualElapsed = session.targetDurationMinutes != null
              ? Duration(minutes: session.targetDurationMinutes!) - elapsed
              : elapsed;
          final totalMinutesNow = activityItem.totalMinutes + actualElapsed.inMinutes;
          if (totalMinutesNow >= activity.weeklyGoalMinutes!) {
            await ref.read(timerControllerProvider.notifier).stopTimer(
              notes: _notesController.text,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Weekly limit reached! Timer automatically stopped for ${activity.name}.'),
                  backgroundColor: const Color(0xffef4444),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Dashboard'),
            floating: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Search activities',
                onPressed: () async {
                  final activities = activitiesAsync.valueOrNull ?? [];
                  if (activities.isNotEmpty) {
                    final selected = await showDialog<Activity>(
                      context: context,
                      builder: (context) => ActivitySearchDialog(activities: activities),
                    );
                    if (selected != null && mounted) {
                      _showTrackingOptionsBottomSheet(context, selected);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No activities created yet!')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: activeSessionAsync.when(
                data: (session) {
                  if (session == null) {
                    return _buildNoActiveSessionCard(context);
                  }
                  
                  final duration = activeDurationAsync.valueOrNull ?? Duration.zero;
                  return _buildActiveSessionCard(context, session, duration);
                },
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGlow)),
                  ),
                ),
                error: (err, stack) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Error: $err', style: const TextStyle(color: Color(0xffef4444))),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Start Tracking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  FilterChip(
                    label: const Text(
                      'Week\'s Focus Only',
                      style: TextStyle(fontSize: 12),
                    ),
                    selected: _weeksFocusOnly,
                    onSelected: (val) {
                      setState(() {
                        _weeksFocusOnly = val;
                      });
                    },
                    selectedColor: AppTheme.primary.withOpacity(0.2),
                    checkmarkColor: AppTheme.primaryGlow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ],
              ),
            ),
          ),
          activitiesAsync.when(
            data: (activities) {
              final displayedActivities = _weeksFocusOnly
                  ? activities.where((act) => act.isWeeklyFocus).toList()
                  : activities;

              if (displayedActivities.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            _weeksFocusOnly
                                ? 'No focused activities for this week!'
                                : 'Create an activity first to start tracking!',
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              ref.read(navigationProvider.notifier).state = 1; // Go to Activities Screen
                            },
                            child: Text(_weeksFocusOnly ? 'Manage Focus Scope' : 'Go to Activities'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisExtent: 110,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final act = displayedActivities[index];
                      final isCurrent = activeSessionAsync.valueOrNull?.activityId == act.id;
                      return _buildQuickStartButton(context, act, isCurrent);
                    },
                    childCount: displayedActivities.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGlow)),
            ),
            error: (err, stack) => SliverToBoxAdapter(
              child: Center(child: Text('Error: $err')),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildNoActiveSessionCard(BuildContext context) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppTheme.surface,
              AppTheme.surface.withRed(35).withBlue(50),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 48,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No active timer',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select an activity below to start tracking your time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(timerControllerProvider.notifier).startTimer(
                  'preset-free-session',
                  notes: 'Free Focus Session',
                );
              },
              icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
              label: const Text('Start Free Focus Session', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGlow,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard(BuildContext context, Session session, Duration elapsed) {
    final activities = ref.watch(activeActivitiesProvider).valueOrNull ?? [];
    final activity = activities.firstWhere(
      (a) => a.id == session.activityId,
      orElse: () => Activity(
        id: session.activityId,
        name: 'Unknown Activity',
        color: AppTheme.primary.value,
        icon: 'star',
        isLimit: false,
        enforceLimit: false,
        isWeeklyFocus: true,
        isArchived: false,
        isDeleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final color = Color(activity.color);
    final iconData = AppTheme.activityIcons[activity.icon] ?? Icons.category_rounded;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15 * _pulseController.value),
                blurRadius: 16 + (8 * _pulseController.value),
                spreadRadius: 2 * _pulseController.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Card(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                AppTheme.surface,
                color.withOpacity(0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(iconData, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NOW TRACKING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          activity.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () async {
                      final notes = _notesController.text;
                      final stoppedSession = session.copyWith(
                        endTime: Value(DateTime.now()),
                        durationMinutes: DateTime.now().difference(session.startTime).inMinutes,
                        notes: Value(notes),
                        updatedAt: DateTime.now(),
                      );
                      await ref.read(timerControllerProvider.notifier).stopTimer(notes: notes);
                      if (session.activityId == 'preset-free-session') {
                        if (context.mounted) {
                          _showAssignFreeSessionDialog(context, stoppedSession);
                        }
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xffef4444),
                      foregroundColor: Colors.white,
                    ),
                    iconSize: 32,
                    padding: const EdgeInsets.all(12),
                    icon: const Icon(Icons.stop_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (session.targetDurationMinutes != null) ...[
                const Text(
                  'COUNTDOWN REMAINING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                _formatDuration(elapsed),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w300,
                  fontFamily: 'Courier', // Monospace feel
                  letterSpacing: 2.0,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (What are you working on?)',
                  hintText: 'Add notes here...',
                  prefixIcon: const Icon(Icons.edit_note_rounded, color: AppTheme.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStartButton(BuildContext context, Activity act, bool isCurrent) {
    final color = Color(act.color);
    final iconData = AppTheme.activityIcons[act.icon] ?? Icons.category_rounded;

    return Card(
      color: isCurrent ? color.withOpacity(0.1) : AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCurrent ? color : AppTheme.border,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (isCurrent) {
            // Already running: stop it
            ref.read(timerControllerProvider.notifier).stopTimer(notes: _notesController.text);
          } else {
            // Show bottom sheet to choose tracking mode (Live, Countdown, Manual)
            _showTrackingOptionsBottomSheet(context, act);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconData, color: color, size: 20),
                  const Spacer(),
                  if (isCurrent)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xffef4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                act.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                isCurrent ? 'TAP TO STOP' : 'START NOW',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isCurrent ? const Color(0xffef4444) : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrackingOptionsBottomSheet(BuildContext context, Activity act) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(act.color).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          AppTheme.activityIcons[act.icon] ?? Icons.category_rounded,
                          color: Color(act.color),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              act.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const Text(
                              'Choose tracking approach',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    leading: const Icon(Icons.play_arrow_rounded, color: AppTheme.primaryGlow),
                    title: const Text('Live Timer (Count-Up)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Start tracking now and count up indefinitely'),
                    tileColor: AppTheme.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.pop(context);
                      _startLiveTimer(context, act);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.hourglass_bottom_rounded, color: Colors.orangeAccent),
                    title: const Text('Countdown Timer', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Choose a duration to count down and auto-stop'),
                    tileColor: AppTheme.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.pop(context);
                      _showCountdownSelection(context, act);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.more_time_rounded, color: Colors.tealAccent),
                    title: const Text('Log Past Session (Manual)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Directly log a session you completed earlier'),
                    tileColor: AppTheme.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.pop(context);
                      _showManualLog(context, act);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _startLiveTimer(BuildContext context, Activity act) {
    if (act.weeklyGoalMinutes != null && act.isLimit && act.enforceLimit) {
      final weeklyReport = ref.read(weeklyReportProvider).valueOrNull;
      if (weeklyReport != null) {
        final activityItem = weeklyReport.items.firstWhere(
          (item) => item.activity.id == act.id,
          orElse: () => ActivityReportItem(activity: act, totalMinutes: 0),
        );
        if (activityItem.totalMinutes >= act.weeklyGoalMinutes!) {
          _showLimitReachedDialog(context, act);
          return;
        }
      }
    }
    ref.read(timerControllerProvider.notifier).startTimer(act.id, notes: '');
  }

  void _showCountdownSelection(BuildContext context, Activity act) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final durations = [15, 30, 45, 60, 90, 120];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select Countdown for ${act.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: durations.map((mins) {
                    return SizedBox(
                      width: 100,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.background,
                          foregroundColor: AppTheme.textPrimary,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _startCountdownTimer(context, act, mins);
                        },
                        child: Text('${mins}m'),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final customMins = await _showCustomMinutesDialog(context);
                    if (customMins != null && customMins > 0) {
                      _startCountdownTimer(context, act, customMins);
                    }
                  },
                  child: const Text('Custom Duration...'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int?> _showCustomMinutesDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Custom Duration'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Duration (minutes)',
              hintText: 'e.g. 25',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final val = int.tryParse(controller.text);
                Navigator.pop(context, val);
              },
              child: const Text('Start', style: TextStyle(color: AppTheme.primaryGlow)),
            ),
          ],
        );
      },
    );
  }

  void _startCountdownTimer(BuildContext context, Activity act, int minutes) {
    if (act.weeklyGoalMinutes != null && act.isLimit && act.enforceLimit) {
      final weeklyReport = ref.read(weeklyReportProvider).valueOrNull;
      if (weeklyReport != null) {
        final activityItem = weeklyReport.items.firstWhere(
          (item) => item.activity.id == act.id,
          orElse: () => ActivityReportItem(activity: act, totalMinutes: 0),
        );
        if (activityItem.totalMinutes >= act.weeklyGoalMinutes!) {
          _showLimitReachedDialog(context, act);
          return;
        }
      }
    }
    ref.read(timerControllerProvider.notifier).startTimer(act.id, notes: '', targetDurationMinutes: minutes);
  }

  void _showManualLog(BuildContext context, Activity act) {
    showDialog(
      context: context,
      builder: (context) {
        return ManualLogDialog(
          initialActivityId: act.id,
          onSave: (activityId, startTime, durationMinutes, notes) {
            ref.read(sessionControllerProvider.notifier).createManualSession(
              activityId: activityId,
              startTime: startTime,
              durationMinutes: durationMinutes,
              notes: notes,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session logged successfully!')),
            );
          },
        );
      },
    );
  }

  void _showLimitReachedDialog(BuildContext context, Activity act) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Limit Reached'),
          content: Text(
            'You have reached your weekly limit of '
            '${(act.weeklyGoalMinutes! / 60.0).toStringAsFixed(1)}h for "${act.name}".\n\n'
            'This activity is set to enforce limits, so you cannot track more time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: AppTheme.textPrimary)),
            ),
          ],
        );
      },
    );
  }

  void _showAssignFreeSessionDialog(BuildContext context, Session stoppedSession) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _AssignFreeSessionDialog(
          session: stoppedSession,
          onSave: (updatedSession) {
            ref.read(timerControllerProvider.notifier).updateSession(updatedSession);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session assigned and saved!')),
            );
          },
        );
      },
    );
  }
}

class ActivitySearchDialog extends StatefulWidget {
  final List<Activity> activities;

  const ActivitySearchDialog({super.key, required this.activities});

  @override
  State<ActivitySearchDialog> createState() => _ActivitySearchDialogState();
}

class _ActivitySearchDialogState extends State<ActivitySearchDialog> {
  String _query = '';
  late List<Activity> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.activities;
  }

  void _filter(String query) {
    setState(() {
      _query = query;
      _filtered = widget.activities
          .where((act) => act.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search Activities'),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Type to search...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 12),
            if (_filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No matching activities', style: TextStyle(color: AppTheme.textSecondary)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final act = _filtered[index];
                    final color = Color(act.color);
                    return ListTile(
                      leading: Icon(
                        AppTheme.activityIcons[act.icon] ?? Icons.category_rounded,
                        color: color,
                      ),
                      title: Text(act.name),
                      onTap: () {
                        Navigator.of(context).pop(act);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    );
  }
}

class _AssignFreeSessionDialog extends StatefulWidget {
  final Session session;
  final void Function(Session updatedSession) onSave;

  const _AssignFreeSessionDialog({
    required this.session,
    required this.onSave,
  });

  @override
  State<_AssignFreeSessionDialog> createState() => _AssignFreeSessionDialogState();
}

class _AssignFreeSessionDialogState extends State<_AssignFreeSessionDialog> {
  late DateTime _startTime;
  late DateTime _endTime;
  String? _selectedActivityId;

  @override
  void initState() {
    super.initState();
    _startTime = widget.session.startTime;
    _endTime = widget.session.endTime ?? DateTime.now();
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.subtract(const Duration(days: 7)),
      lastDate: initial.add(const Duration(days: 1)),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final activitiesAsync = ref.watch(allActivitiesProvider);

        return activitiesAsync.when(
          data: (activities) {
            final choices = activities.where((a) => a.id != 'preset-free-session' && !a.isArchived).toList();

            return AlertDialog(
              title: const Text('Assign Session'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'You tracked a free session! Choose an activity and customize the session times.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Activity',
                    ),
                    value: _selectedActivityId,
                    items: choices.map((a) {
                      return DropdownMenuItem(
                        value: a.id,
                        child: Row(
                          children: [
                            Icon(
                              AppTheme.activityIcons[a.icon] ?? Icons.category_rounded,
                              color: Color(a.color),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(a.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedActivityId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Start Time', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    subtitle: Text(
                      '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')} (${_startTime.day}/${_startTime.month})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    trailing: const Icon(Icons.edit_calendar_rounded, color: AppTheme.primaryGlow),
                    onTap: () async {
                      final picked = await _pickDateTime(context, _startTime);
                      if (picked != null) {
                        setState(() {
                          _startTime = picked;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('End Time', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    subtitle: Text(
                      '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')} (${_endTime.day}/${_endTime.month})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    trailing: const Icon(Icons.edit_calendar_rounded, color: AppTheme.primaryGlow),
                    onTap: () async {
                      final picked = await _pickDateTime(context, _endTime);
                      if (picked != null) {
                        setState(() {
                          _endTime = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Duration: ${_endTime.difference(_startTime).inMinutes} minutes',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGlow),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Leave Unassigned', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                TextButton(
                  onPressed: _selectedActivityId == null
                      ? null
                      : () {
                          final duration = _endTime.difference(_startTime).inMinutes;
                          widget.onSave(
                            widget.session.copyWith(
                              activityId: _selectedActivityId!,
                              startTime: _startTime,
                              endTime: Value(_endTime),
                              durationMinutes: duration > 0 ? duration : 0,
                              updatedAt: DateTime.now(),
                            ),
                          );
                          Navigator.pop(context);
                        },
                  child: const Text('Save & Assign', style: TextStyle(color: AppTheme.primaryGlow, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(child: Text('Error loading activities')),
        );
      },
    );
  }
}
