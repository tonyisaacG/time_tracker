import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/features/activity/application/activity_providers.dart';
import '../application/schedule_providers.dart';
import 'weekly_timeline_view.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}


class _ScheduleScreenState extends ConsumerState<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  bool _showArchived = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(_showArchived ? archivedAppointmentsProvider : activeAppointmentsProvider);
    final activitiesAsync = ref.watch(activeActivitiesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Show archived toggle — only visible on the List tab
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) {
              if (_tabController.index != 0) return const SizedBox.shrink();
              return Row(
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
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryGlow,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryGlow,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.list_rounded, size: 18), text: 'List'),
            Tab(icon: Icon(Icons.grid_view_rounded, size: 18), text: 'Timeline'),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) {
          // Only show FAB on the list tab
          if (_tabController.index != 0) return const SizedBox.shrink();
          return FloatingActionButton(
            backgroundColor: AppTheme.primaryGlow,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add_rounded),
            onPressed: () {
              activitiesAsync.whenData((activities) {
                _showAppointmentForm(context, ref, activities);
              });
            },
          );
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 0: List ──────────────────────────────────────────────────
          appointmentsAsync.when(
          data: (appointments) {
            if (appointments.isEmpty) {
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
                      _showArchived ? 'No archived schedules' : 'No scheduled meetings or courses',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    if (!_showArchived)
                      const Text(
                        'Tap the button below to schedule reminders.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                final appt = appointments[index];
                return _buildAppointmentCard(context, ref, appt);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        ),

          // ── Tab 1: Timeline ──────────────────────────────────────────────
          const WeeklyTimelineView(),
        ],
      ),
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
