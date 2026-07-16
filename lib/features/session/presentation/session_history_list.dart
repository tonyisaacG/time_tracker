import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/features/activity/application/activity_providers.dart';
import '../application/session_providers.dart';

class SessionHistoryList extends ConsumerStatefulWidget {
  const SessionHistoryList({super.key});

  @override
  ConsumerState<SessionHistoryList> createState() => _SessionHistoryListState();
}

class TimeGap {
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;

  TimeGap({
    required this.startTime,
    required this.endTime,
  }) : durationMinutes = endTime.difference(startTime).inMinutes;
}

class _SessionHistoryListState extends ConsumerState<SessionHistoryList> {
  bool _showTimeline = false;
  DateTime _selectedDate = DateTime.now();

  List<dynamic> _buildTimelineItems(List<Session> sessions, DateTime selectedDate) {
    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final endOfPeriod = isToday ? now : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

    final daySessions = sessions.where((s) {
      if (s.endTime == null || s.isDeleted) return false;
      return s.startTime.year == selectedDate.year &&
          s.startTime.month == selectedDate.month &&
          s.startTime.day == selectedDate.day;
    }).toList();

    daySessions.sort((a, b) => a.startTime.compareTo(b.startTime));

    final List<dynamic> items = [];
    DateTime currentTime = startOfDay;

    for (final session in daySessions) {
      if (session.startTime.difference(currentTime).inMinutes >= 1) {
        items.add(TimeGap(
          startTime: currentTime,
          endTime: session.startTime,
        ));
      }
      items.add(session);
      currentTime = session.endTime!;
    }

    if (endOfPeriod.difference(currentTime).inMinutes >= 1) {
      items.add(TimeGap(
        startTime: currentTime,
        endTime: endOfPeriod,
      ));
    }

    return items;
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allSessionsProvider);
    final activitiesAsync = ref.watch(allActivitiesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_showTimeline ? 'Daily Timeline' : 'History'),
        actions: [
          IconButton(
            icon: Icon(_showTimeline ? Icons.list_alt_rounded : Icons.timeline_rounded),
            tooltip: _showTimeline ? 'Show List View' : 'Show Timeline View',
            onPressed: () {
              setState(() {
                _showTimeline = !_showTimeline;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_time_rounded, color: AppTheme.primaryGlow),
            tooltip: 'Log Manual Session',
            onPressed: () => _showManualLogDialog(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_showTimeline) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _changeDate(-1),
                  ),
                  Text(
                    DateFormat('EEEE, MMM d, y').format(_selectedDate),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _changeDate(1),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),
          ],
          Expanded(
            child: sessionsAsync.when(
              data: (sessions) {
                final completedSessions = sessions.where((s) => s.endTime != null).toList();

                if (completedSessions.isEmpty && !_showTimeline) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_toggle_off_rounded,
                          size: 64,
                          color: AppTheme.textMuted.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No tracked sessions yet',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showManualLogDialog(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Log Manual Session'),
                        ),
                      ],
                    ),
                  );
                }

                final activities = activitiesAsync.value ?? [];

                if (_showTimeline) {
                  final timelineItems = _buildTimelineItems(completedSessions, _selectedDate);

                  if (timelineItems.isEmpty) {
                    return const Center(
                      child: Text(
                        'No slots in timeline',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: timelineItems.length,
                    itemBuilder: (context, index) {
                      final item = timelineItems[index];
                      if (item is Session) {
                        final activity = activities.firstWhere(
                          (a) => a.id == item.activityId,
                          orElse: () => Activity(
                            id: item.activityId,
                            name: 'Deleted Activity',
                            color: AppTheme.textMuted.value,
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
                        return _buildSessionTile(context, ref, item, activity);
                      } else if (item is TimeGap) {
                        return _buildGapTile(context, ref, item);
                      }
                      return const SizedBox.shrink();
                    },
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: completedSessions.length,
                  itemBuilder: (context, index) {
                    final session = completedSessions[index];
                    final activity = activities.firstWhere(
                      (a) => a.id == session.activityId,
                      orElse: () => Activity(
                        id: session.activityId,
                        name: 'Deleted Activity',
                        color: AppTheme.textMuted.value,
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

                    return _buildSessionTile(context, ref, session, activity);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGlow)),
              error: (err, stack) => Center(child: Text('Error loading history: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGapTile(BuildContext context, WidgetRef ref, TimeGap gap) {
    final startStr = DateFormat('jm').format(gap.startTime);
    final endStr = DateFormat('jm').format(gap.endTime);
    final durationStr = gap.durationMinutes >= 60
        ? '${gap.durationMinutes ~/ 60}h ${gap.durationMinutes % 60}m'
        : '${gap.durationMinutes}m';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.surface.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppTheme.border.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                color: Colors.orangeAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Untracked Time Gap',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$startStr - $endStr • $durationStr',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGlow.withOpacity(0.15),
                foregroundColor: AppTheme.primaryGlow,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () {
                _showManualLogDialog(
                  context,
                  ref,
                  initialDateTime: gap.startTime,
                  initialDuration: gap.durationMinutes,
                );
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Fill Gap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(BuildContext context, WidgetRef ref, Session session, Activity activity) {
    final activityColor = Color(activity.color);
    final iconData = AppTheme.activityIcons[activity.icon] ?? Icons.category_rounded;
    final dateString = DateFormat('EEE, MMM d, y').format(session.startTime);
    final timeString = '${DateFormat('jm').format(session.startTime)} - ${DateFormat('jm').format(session.endTime!)}';

    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xffef4444).withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: Color(0xffef4444)),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete Session?'),
              content: const Text('Are you sure you want to delete this tracked session?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete', style: TextStyle(color: Color(0xffef4444))),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        ref.read(sessionControllerProvider.notifier).deleteSession(session.id);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: activityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: activityColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          activity.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${session.durationMinutes}m',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: activityColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateString • $timeString',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    if (session.notes != null && session.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border, width: 0.5),
                        ),
                        child: Text(
                          session.notes!,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualLogDialog(
    BuildContext context,
    WidgetRef ref, {
    DateTime? initialDateTime,
    int? initialDuration,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return ManualLogDialog(
          initialDateTime: initialDateTime,
          initialDuration: initialDuration,
          onSave: (activityId, startTime, durationMinutes, notes) {
            ref.read(sessionControllerProvider.notifier).createManualSession(
              activityId: activityId,
              startTime: startTime,
              durationMinutes: durationMinutes,
              notes: notes,
            );
          },
        );
      },
    );
  }
}

class ManualLogDialog extends StatefulWidget {
  final String? initialActivityId;
  final DateTime? initialDateTime;
  final int? initialDuration;
  final void Function(
    String activityId,
    DateTime startTime,
    int durationMinutes,
    String? notes,
  ) onSave;

  const ManualLogDialog({
    required this.onSave,
    this.initialActivityId,
    this.initialDateTime,
    this.initialDuration,
  });

  @override
  State<ManualLogDialog> createState() => ManualLogDialogState();
}

class ManualLogDialogState extends State<ManualLogDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedActivityId;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late int _duration;
  String? _notes;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDateTime ?? DateTime.now();
    _startTime = widget.initialDateTime != null
        ? TimeOfDay.fromDateTime(widget.initialDateTime!)
        : TimeOfDay.now();
    _duration = widget.initialDuration ?? 30;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final activities = ref.watch(activeActivitiesProvider).valueOrNull ?? [];

        if (activities.isEmpty) {
          return AlertDialog(
            title: const Text('No Activities'),
            content: const Text('You must create an activity before logging sessions manually.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        }

        // Initialize selected activity
        _selectedActivityId ??= widget.initialActivityId ?? activities.first.id;

        return AlertDialog(
          scrollable: true,
          title: const Text('Log Time Manually'),
          content: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedActivityId,
                  decoration: const InputDecoration(labelText: 'Activity'),
                  items: activities.map((act) {
                    return DropdownMenuItem<String>(
                      value: act.id,
                      child: Row(
                        children: [
                          Icon(
                            AppTheme.activityIcons[act.icon] ?? Icons.category_rounded,
                            color: Color(act.color),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(act.name),
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
                const Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _selectDate,
                        child: Text(DateFormat('MM/dd/yyyy').format(_startDate)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _selectTime,
                        child: Text(_startTime.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _duration.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                    hintText: 'e.g. 60',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please enter duration';
                    }
                    final parsed = int.tryParse(val);
                    if (parsed == null || parsed <= 0) {
                      return 'Duration must be positive';
                    }
                    return null;
                  },
                  onSaved: (val) => _duration = int.parse(val!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'What did you accomplish?',
                  ),
                  maxLines: 2,
                  onSaved: (val) => _notes = val?.trim(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();

                  final fullStartDateTime = DateTime(
                    _startDate.year,
                    _startDate.month,
                    _startDate.day,
                    _startTime.hour,
                    _startTime.minute,
                  );

                  // Check weekly limit for enforced max limits
                  final activity = activities.firstWhere((a) => a.id == _selectedActivityId);
                  if (activity.weeklyGoalMinutes != null && activity.isLimit && activity.enforceLimit) {
                    final sessions = ref.read(allSessionsProvider).valueOrNull ?? [];
                    
                    bool isSameWeek(DateTime d1, DateTime d2) {
                      final days1 = d1.weekday - 1;
                      final mon1 = DateTime(d1.year, d1.month, d1.day).subtract(Duration(days: days1));
                      final days2 = d2.weekday - 1;
                      final mon2 = DateTime(d2.year, d2.month, d2.day).subtract(Duration(days: days2));
                      return mon1.isAtSameMomentAs(mon2);
                    }

                    final sameWeekSessions = sessions.where((s) {
                      if (s.activityId != _selectedActivityId) return false;
                      if (s.endTime == null) return false;
                      if (s.isDeleted) return false;
                      return isSameWeek(s.startTime, fullStartDateTime);
                    });
                    
                    final weeklyMinutesBefore = sameWeekSessions.fold(0, (sum, s) => sum + s.durationMinutes);
                    if (weeklyMinutesBefore + _duration > activity.weeklyGoalMinutes!) {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Limit Exceeded'),
                            content: Text(
                              'Logging this session would put you at '
                              '${((weeklyMinutesBefore + _duration) / 60.0).toStringAsFixed(1)}h tracked this week, '
                              'exceeding the limit of ${(activity.weeklyGoalMinutes! / 60.0).toStringAsFixed(1)}h for "${activity.name}".\n\n'
                              'This activity is set to enforce limits.',
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
                      return;
                    }
                  }

                  widget.onSave(
                    _selectedActivityId!,
                    fullStartDateTime,
                    _duration,
                    _notes,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Save', style: TextStyle(color: AppTheme.primaryGlow, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (time != null) {
      setState(() {
        _startTime = time;
      });
    }
  }
}
