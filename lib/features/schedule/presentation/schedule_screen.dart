import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/features/activity/application/activity_providers.dart';
import '../application/schedule_providers.dart';
import 'weekly_timeline_view.dart';

import 'package:tracker_time/features/planner/application/planner_providers.dart';
import 'widgets/unified_entry_dialog.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  bool _showArchived = false;
  int _filterIndex = 0; // 0=All, 1=Appointments, 2=Tasks
  DateTime _selectedDate = DateTime.now();

  bool _appointmentOccursOnDate(Appointment appt, DateTime date) {
    if (appt.isArchived && !_showArchived) return false;
    final apptDate = DateTime(appt.startTime.year, appt.startTime.month, appt.startTime.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    if (targetDate.isBefore(apptDate)) return false;

    switch (appt.recurrenceType) {
      case 'none':
      case 'once':
        return apptDate.year == targetDate.year &&
            apptDate.month == targetDate.month &&
            apptDate.day == targetDate.day;
      case 'daily':
        return true;
      case 'weekly':
        if (appt.recurrenceDays != null) {
          try {
            final List<dynamic> days = jsonDecode(appt.recurrenceDays!);
            return days.contains(targetDate.weekday);
          } catch (_) {}
        }
        return apptDate.weekday == targetDate.weekday;
      case 'monthly':
        return apptDate.day == targetDate.day;
      default:
        return false;
    }
  }

  bool _taskOccursOnDate(DayTask task, DateTime date) {
    final targetDateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (task.date == targetDateStr) return true;
    final taskDate = DateTime.tryParse(task.date);
    if (taskDate == null) return false;
    final targetDate = DateTime(date.year, date.month, date.day);
    if (targetDate.isBefore(DateTime(taskDate.year, taskDate.month, taskDate.day))) return false;

    switch (task.recurrenceType) {
      case 'daily':
        return true;
      case 'weekly':
        if (task.recurrenceDays != null) {
          try {
            final List<dynamic> days = jsonDecode(task.recurrenceDays!);
            return days.contains(targetDate.weekday);
          } catch (_) {}
        }
        return taskDate.weekday == targetDate.weekday;
      case 'monthly':
        return taskDate.day == targetDate.day;
      default:
        return false;
    }
  }

  Widget _buildDateHeader() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final diff = sel.difference(today).inDays;

    const arabicWeekdays = ['', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    String relativeText;
    if (diff == 0) {
      relativeText = 'اليوم';
    } else if (diff == 1) {
      relativeText = 'غداً';
    } else if (diff == -1) {
      relativeText = 'أمس';
    } else {
      relativeText = arabicWeekdays[_selectedDate.weekday];
    }

    final dateFormatted = '$relativeText – ${DateFormat('MMM d').format(_selectedDate)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: AppTheme.surface.withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
            },
          ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryGlow),
                  const SizedBox(width: 8),
                  Text(
                    dateFormatted,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimary),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(_showArchived ? archivedAppointmentsProvider : activeAppointmentsProvider);
    final tasksAsync = ref.watch(allTasksProvider);
    final activitiesAsync = ref.watch(activeActivitiesProvider);

    final appointments = appointmentsAsync.valueOrNull ?? [];
    final tasks = tasksAsync.valueOrNull ?? [];
    final activities = activitiesAsync.valueOrNull ?? [];

    final dayAppts = appointments.where((a) => _appointmentOccursOnDate(a, _selectedDate)).toList();
    final dayTasks = tasks.where((t) => _taskOccursOnDate(t, _selectedDate)).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Schedule & Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Row(
            children: [
              const Text(
                'Archived',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              Switch(
                value: _showArchived,
                onChanged: (val) => setState(() => _showArchived = val),
                activeColor: AppTheme.primaryGlow,
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryGlow,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
        onPressed: () {
          activitiesAsync.whenData((activitiesList) {
            showDialog(
              context: context,
              builder: (_) => UnifiedEntryDialog(activities: activitiesList),
            );
          });
        },
      ),
      body: Column(
        children: [
          // Date Selector Header
          _buildDateHeader(),
          const SizedBox(height: 4),

          // Filter Chips (All | Appointments | Tasks)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              children: [
                _filterChip(0, 'All (${dayAppts.length + dayTasks.length})'),
                const SizedBox(width: 8),
                _filterChip(1, 'Appointments (${dayAppts.length})'),
                const SizedBox(width: 8),
                _filterChip(2, 'Tasks (${dayTasks.length})'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          Expanded(
            child: Builder(
              builder: (context) {
                final displayAppts = _filterIndex == 2 ? <Appointment>[] : dayAppts;
                final displayTasks = _filterIndex == 1 ? <DayTask>[] : dayTasks;

                if (displayAppts.isEmpty && displayTasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondary.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _showArchived ? Icons.archive_rounded : Icons.calendar_today_rounded,
                            size: 64,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showArchived ? 'No archived schedules' : 'No items found',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        if (!_showArchived)
                          const Text(
                            'Tap + to add an appointment or task.',
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  children: [
                    if (displayAppts.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('APPOINTMENTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.1)),
                      ),
                      ...displayAppts.map((appt) => _buildAppointmentCard(context, ref, appt)),
                    ],
                    if (displayTasks.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('TASKS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.1)),
                      ),
                      ...displayTasks.map((task) => _buildTaskCard(context, ref, task, activities)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(int index, String label) {
    final isSelected = _filterIndex == index;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppTheme.textSecondary)),
      selected: isSelected,
      selectedColor: AppTheme.primaryGlow,
      onSelected: (_) => setState(() => _filterIndex = index),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAppointmentCard(BuildContext context, WidgetRef ref, Appointment appt) {
    final activities = ref.watch(activeActivitiesProvider).valueOrNull ?? [];
    final activity = appt.activityId != null
        ? activities.firstWhere(
            (a) => a.id == appt.activityId,
            orElse: () => Activity(
              id: appt.activityId!,
              name: 'Deleted Activity',
              color: AppTheme.textMuted.value,
              icon: 'star',
              isLimit: false,
              enforceLimit: false,
              isWeeklyFocus: false,
              isArchived: false,
              isDeleted: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          )
        : null;

    final color = activity != null ? Color(activity.color) : AppTheme.textMuted;
    final iconData = activity != null
        ? (AppTheme.activityIcons[activity.icon] ?? Icons.category_rounded)
        : Icons.event_note_rounded;
    final timeStr = DateFormat('jm').format(appt.startTime);

    // Format recurrence text
    String recurrenceStr = 'Once';
    if (appt.recurrenceType == 'weekly') {
      if (appt.recurrenceDays != null) {
        final List<int> days = List<int>.from(jsonDecode(appt.recurrenceDays!));
        final dayNames = days.map((d) {
          switch (d) {
            case 1: return 'Mon';
            case 2: return 'Tue';
            case 3: return 'Wed';
            case 4: return 'Thu';
            case 5: return 'Fri';
            case 6: return 'Sat';
            case 7: return 'Sun';
            default: return '';
          }
        }).join(', ');
        recurrenceStr = 'Custom ($dayNames)';
      } else {
        recurrenceStr = 'Custom';
      }
    } else if (appt.recurrenceType == 'monthly') {
      recurrenceStr = 'Monthly';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appt.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (appt.notes != null && appt.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      appt.notes!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        '$timeStr (${appt.durationMinutes}m) • $recurrenceStr',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          activity != null ? activity.name : 'Free Block',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                if (!appt.isArchived)
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: appt.isEnabled,
                      activeColor: color,
                      onChanged: (val) {
                        ref.read(appointmentControllerProvider.notifier).toggleEnabled(appt, val);
                      },
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        appt.isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                      tooltip: appt.isArchived ? 'Restore Schedule' : 'Archive Schedule',
                      onPressed: () {
                        ref.read(appointmentControllerProvider.notifier).toggleArchived(appt, !appt.isArchived);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textMuted, size: 20),
                      onPressed: () {
                        _showDeleteConfirmation(context, ref, appt.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Appointment'),
          content: const Text('Are you sure you want to delete this scheduled appointment and cancel all its reminders?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                ref.read(appointmentControllerProvider.notifier).deleteAppointment(id);
                Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAppointmentForm(BuildContext context, WidgetRef ref, List<Activity> activities, {Appointment? appt}) {
    showDialog(
      context: context,
      builder: (context) {
        return _AppointmentFormDialog(
          activities: activities,
          appointment: appt,
          onSave: (title, notes, activityId, startTime, durationMinutes, recurrenceType, recurrenceDays) {
            final controller = ref.read(appointmentControllerProvider.notifier);
            controller.createAppointment(
              title: title,
              notes: notes,
              activityId: activityId,
              startTime: startTime,
              durationMinutes: durationMinutes,
              recurrenceType: recurrenceType,
              recurrenceDays: recurrenceDays,
            );
          },
        );
      },
    );
  }

  Widget _buildTaskCard(BuildContext context, WidgetRef ref, DayTask task, List<Activity> activities) {
    final activity = task.activityId != null
        ? activities.firstWhere((a) => a.id == task.activityId, orElse: () => activities.first)
        : null;
    final color = activity != null ? Color(activity.color) : AppTheme.primaryGlow;
    final iconData = activity != null
        ? (AppTheme.activityIcons[activity.icon] ?? Icons.category_rounded)
        : Icons.task_alt_rounded;

    final timeStr = task.reminderTime != null ? DateFormat('jm').format(task.reminderTime!) : 'Untimed Task';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppTheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(iconData, color: color, size: 20),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: task.isCompleted ? AppTheme.textMuted : AppTheme.textPrimary,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(timeStr, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.primaryGlow.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(
                task.recurrenceType.toUpperCase(),
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryGlow),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            task.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: task.isCompleted ? Colors.greenAccent : AppTheme.textMuted,
          ),
          onPressed: () {
            ref.read(taskControllerProvider.notifier).toggleTask(task);
          },
        ),
        onTap: () => _showTaskDetailsDialog(context, ref, task, activity, activities),
      ),
    );
  }

  void _showTaskDetailsDialog(BuildContext context, WidgetRef ref, DayTask task, Activity? activity, List<Activity> activities) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.task_alt_rounded, color: activity != null ? Color(activity.color) : AppTheme.primaryGlow),
            const SizedBox(width: 8),
            Expanded(child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activity != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('Category: ${activity.name}', style: TextStyle(color: Color(activity.color), fontWeight: FontWeight.bold)),
              ),
            Text('Recurrence: ${task.recurrenceType}', style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text('Time: ${task.reminderTime != null ? DateFormat('jm').format(task.reminderTime!) : 'Untimed'}', style: const TextStyle(color: AppTheme.textSecondary)),
            if (task.notes != null && task.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes: ${task.notes}', style: const TextStyle(color: AppTheme.textMuted)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(taskControllerProvider.notifier).deleteTask(task.id);
            },
            child: const Text('Delete Task', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => UnifiedEntryDialog(activities: activities, existingTask: task),
              );
            },
            child: const Text('Edit'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGlow),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _AppointmentFormDialog extends StatefulWidget {
  final List<Activity> activities;
  final Appointment? appointment;
  final void Function(
    String title,
    String? notes,
    String? activityId,
    DateTime startTime,
    int durationMinutes,
    String recurrenceType,
    List<int> recurrenceDays,
  ) onSave;

  const _AppointmentFormDialog({
    required this.activities,
    this.appointment,
    required this.onSave,
  });

  @override
  State<_AppointmentFormDialog> createState() => _AppointmentFormDialogState();
}

class _AppointmentFormDialogState extends State<_AppointmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _notes;
  late String? _selectedActivityId;
  late DateTime _startTime;
  late int _durationMinutes;
  late String _recurrenceType;
  late List<int> _recurrenceDays;

  @override
  void initState() {
    super.initState();
    final appt = widget.appointment;
    _title = appt?.title ?? '';
    _notes = appt?.notes ?? '';
    _selectedActivityId = appt?.activityId;
    _startTime = appt?.startTime ?? DateTime.now().add(const Duration(minutes: 30));
    _durationMinutes = appt?.durationMinutes ?? 60;
    _recurrenceType = appt?.recurrenceType ?? 'once';
    _recurrenceDays = appt?.recurrenceDays != null
        ? List<int>.from(jsonDecode(appt!.recurrenceDays!))
        : [];
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) {
      setState(() {
        _startTime = DateTime(
          date.year, date.month, date.day,
          _startTime.hour, _startTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (time != null) {
      setState(() {
        _startTime = DateTime(
          _startTime.year,
          _startTime.month,
          _startTime.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Schedule Appointment'),
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _title,
              decoration: const InputDecoration(
                labelText: 'Meeting or Course Title',
                hintText: 'e.g. English Course, Sprint Meeting',
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
              onSaved: (val) => _title = val!.trim(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes / Details (Optional)',
                hintText: 'e.g. Chapter 3, Zoom link, or agenda notes...',
              ),
              onSaved: (val) => _notes = val != null ? val.trim() : '',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              decoration: const InputDecoration(labelText: 'Linked Activity'),
              value: _selectedActivityId,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded, color: AppTheme.textMuted, size: 18),
                      const SizedBox(width: 8),
                      Text('None (Free Block / Alarm)'),
                    ],
                  ),
                ),
                ...widget.activities.map((a) {
                  return DropdownMenuItem<String?>(
                    value: a.id,
                    child: Row(
                      children: [
                        Icon(AppTheme.activityIcons[a.icon] ?? Icons.category_rounded, color: Color(a.color), size: 18),
                        const SizedBox(width: 8),
                        Text(a.name),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() => _selectedActivityId = val);
              },
            ),
            const SizedBox(height: 16),
            // Date + Time pickers
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    subtitle: Text(
                      DateFormat('EEE, MMM d yyyy').format(_startTime),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    trailing: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryGlow),
                    onTap: () => _selectDate(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Time', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    subtitle: Text(
                      DateFormat('h:mm a').format(_startTime),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    trailing: const Icon(Icons.access_time_rounded, color: AppTheme.primaryGlow),
                    onTap: () => _selectTime(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Duration (Minutes)', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            DropdownButton<int>(
              value: _durationMinutes,
              isExpanded: true,
              underline: Container(height: 1, color: AppTheme.border),
              items: [15, 30, 45, 60, 90, 120, 180].map((m) {
                return DropdownMenuItem(value: m, child: Text('$m minutes'));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _durationMinutes = val);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Recurrence'),
              value: _recurrenceType,
              items: const [
                DropdownMenuItem(value: 'once', child: Text('Once (One-off)')),
                DropdownMenuItem(value: 'weekly', child: Text('Custom Days of Week')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly (Repeating)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _recurrenceType = val;
                    if (val != 'weekly') {
                      _recurrenceDays.clear();
                    }
                  });
                }
              },
            ),
            if (_recurrenceType == 'weekly') ...[
              const SizedBox(height: 16),
              const Text('Select Days', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildDayChip(1, 'Mon'),
                  _buildDayChip(2, 'Tue'),
                  _buildDayChip(3, 'Wed'),
                  _buildDayChip(4, 'Thu'),
                  _buildDayChip(5, 'Fri'),
                  _buildDayChip(6, 'Sat'),
                  _buildDayChip(7, 'Sun'),
                ],
              ),
            ],
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
              if (_recurrenceType == 'weekly' && _recurrenceDays.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select at least one day for weekly recurrence!')),
                );
                return;
              }
              widget.onSave(
                _title,
                _notes.isNotEmpty ? _notes : null,
                _selectedActivityId,
                _startTime,
                _durationMinutes,
                _recurrenceType,
                _recurrenceDays,
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Save', style: TextStyle(color: AppTheme.primaryGlow, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildDayChip(int weekday, String label) {
    final isSelected = _recurrenceDays.contains(weekday);
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          if (val) {
            _recurrenceDays.add(weekday);
          } else {
            _recurrenceDays.remove(weekday);
          }
        });
      },
      selectedColor: AppTheme.primaryGlow.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryGlow,
    );
  }
}
