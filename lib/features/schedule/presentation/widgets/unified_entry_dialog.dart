import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/features/schedule/application/schedule_providers.dart';
import 'package:tracker_time/features/planner/application/planner_providers.dart';

enum EntryType { appointment, task }

class UnifiedEntryDialog extends ConsumerStatefulWidget {
  final List<Activity> activities;
  final Appointment? existingAppointment;
  final DayTask? existingTask;

  const UnifiedEntryDialog({
    super.key,
    required this.activities,
    this.existingAppointment,
    this.existingTask,
  });

  @override
  ConsumerState<UnifiedEntryDialog> createState() => _UnifiedEntryDialogState();
}

class _UnifiedEntryDialogState extends ConsumerState<UnifiedEntryDialog> {
  final _formKey = GlobalKey<FormState>();

  late EntryType _selectedType;
  late TextEditingController _titleController;
  late TextEditingController _notesController;

  String? _selectedActivityId;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  int _durationMinutes = 30;

  // Planner section for tasks
  String _selectedBlockId = 'block-morning';

  // Recurrence
  String _recurrenceType = 'once'; // 'once', 'daily', 'weekly', 'monthly'
  final Set<int> _selectedDays = {1}; // 1=Mon, 7=Sun

  @override
  void initState() {
    super.initState();
    if (widget.existingTask != null) {
      _selectedType = EntryType.task;
      final task = widget.existingTask!;
      _titleController = TextEditingController(text: task.title);
      _notesController = TextEditingController(text: task.notes ?? '');
      _selectedActivityId = task.activityId;
      _selectedBlockId = task.blockId;
      _startDate = DateTime.tryParse(task.date) ?? DateTime.now();
      _startTime = task.reminderTime != null
          ? TimeOfDay.fromDateTime(task.reminderTime!)
          : const TimeOfDay(hour: 9, minute: 0);
      _durationMinutes = task.estimatedMinutes;
      _recurrenceType = task.recurrenceType;
      if (task.recurrenceDays != null) {
        try {
          final List<dynamic> parsed = jsonDecode(task.recurrenceDays!);
          _selectedDays.clear();
          _selectedDays.addAll(parsed.cast<int>());
        } catch (_) {}
      }
    } else {
      _selectedType = EntryType.appointment;
      final appt = widget.existingAppointment;
      _titleController = TextEditingController(text: appt?.title ?? '');
      _notesController = TextEditingController(text: appt?.notes ?? '');
      _selectedActivityId = appt?.activityId;
      final now = appt?.startTime ?? DateTime.now();
      _startDate = DateTime(now.year, now.month, now.day);
      _startTime = TimeOfDay.fromDateTime(now);
      _durationMinutes = appt?.durationMinutes ?? 30;
      _recurrenceType = appt?.recurrenceType ?? 'once';
      if (appt?.recurrenceDays != null) {
        try {
          final List<dynamic> parsed = jsonDecode(appt!.recurrenceDays!);
          _selectedDays.clear();
          _selectedDays.addAll(parsed.cast<int>());
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(allBlocksProvider);
    final blocks = blocksAsync.valueOrNull ?? [];

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.existingAppointment != null || widget.existingTask != null
            ? 'Edit Entry'
            : 'New Entry',
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Entry Type Segmented Switch
              Center(
                child: SegmentedButton<EntryType>(
                  segments: const [
                    ButtonSegment<EntryType>(
                      value: EntryType.appointment,
                      label: Text('Appointment'),
                      icon: Icon(Icons.event_rounded, size: 16),
                    ),
                    ButtonSegment<EntryType>(
                      value: EntryType.task,
                      label: Text('Task'),
                      icon: Icon(Icons.task_alt_rounded, size: 16),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (Set<EntryType> newSelection) {
                    setState(() {
                      _selectedType = newSelection.first;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: _selectedType == EntryType.appointment ? 'Appointment Title' : 'Task Title',
                  prefixIcon: const Icon(Icons.edit_rounded, color: AppTheme.primaryGlow, size: 20),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Title required' : null,
              ),
              const SizedBox(height: 12),

              // Activity Category
              DropdownButtonFormField<String>(
                value: _selectedActivityId,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Activity Category',
                  prefixIcon: Icon(Icons.category_rounded, color: AppTheme.primaryGlow, size: 20),
                ),
                items: widget.activities.map((act) {
                  return DropdownMenuItem<String>(
                    value: act.id,
                    child: Row(
                      children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(color: Color(act.color), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(act.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedActivityId = val),
              ),
              const SizedBox(height: 12),

              // Section dropdown for Tasks
              if (_selectedType == EntryType.task && blocks.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: blocks.any((b) => b.id == _selectedBlockId) ? _selectedBlockId : blocks.first.id,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Planner Section',
                    prefixIcon: Icon(Icons.view_agenda_rounded, color: AppTheme.primaryGlow, size: 20),
                  ),
                  items: blocks.map((b) {
                    return DropdownMenuItem<String>(
                      value: b.id,
                      child: Text(b.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedBlockId = val);
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Date Picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryGlow, size: 20),
                title: const Text('Start Date', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                subtitle: Text(
                  DateFormat('EEEE, MMM d, yyyy').format(_startDate),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),

              // Time Picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_rounded, color: AppTheme.primaryGlow, size: 20),
                title: Text(
                  _selectedType == EntryType.appointment ? 'Start Time' : 'Time (Optional)',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                subtitle: Text(
                  _startTime.format(context),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _startTime,
                  );
                  if (picked != null) setState(() => _startTime = picked);
                },
              ),

              // Duration
              Row(
                children: [
                  const Icon(Icons.timer_rounded, color: AppTheme.primaryGlow, size: 20),
                  const SizedBox(width: 12),
                  const Text('Duration:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<int>(
                      value: _durationMinutes,
                      isExpanded: true,
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15 min')),
                        DropdownMenuItem(value: 30, child: Text('30 min')),
                        DropdownMenuItem(value: 45, child: Text('45 min')),
                        DropdownMenuItem(value: 60, child: Text('1 hour')),
                        DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                        DropdownMenuItem(value: 120, child: Text('2 hours')),
                        DropdownMenuItem(value: 180, child: Text('3 hours')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _durationMinutes = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Recurrence Section
              const Text('Recurrence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRecurrenceChip('once', 'Once', Icons.event_rounded),
                  _buildRecurrenceChip('daily', 'Daily', Icons.today_rounded),
                  _buildRecurrenceChip('weekly', 'Weekly', Icons.date_range_rounded),
                  _buildRecurrenceChip('monthly', 'Monthly', Icons.calendar_month_rounded),
                ],
              ),

              if (_recurrenceType == 'weekly') ...[
                const SizedBox(height: 12),
                const Text('Repeat on:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (int day = 1; day <= 7; day++)
                      FilterChip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][day - 1]),
                        selected: _selectedDays.contains(day),
                        selectedColor: AppTheme.primaryGlow,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _selectedDays.contains(day) ? Colors.white : AppTheme.textSecondary,
                        ),
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              _selectedDays.add(day);
                            } else if (_selectedDays.length > 1) {
                              _selectedDays.remove(day);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  prefixIcon: Icon(Icons.notes_rounded, color: AppTheme.primaryGlow, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGlow),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final startDateTime = DateTime(
      _startDate.year, _startDate.month, _startDate.day,
      _startTime.hour, _startTime.minute,
    );

    final recurrenceDaysJson = _recurrenceType == 'weekly'
        ? jsonEncode(_selectedDays.toList())
        : null;

    if (_selectedType == EntryType.appointment) {
      final appt = Appointment(
        id: widget.existingAppointment?.id ?? const Uuid().v4(),
        activityId: _selectedActivityId,
        title: _titleController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        startTime: startDateTime,
        durationMinutes: _durationMinutes,
        recurrenceType: _recurrenceType,
        recurrenceDays: recurrenceDaysJson,
        isEnabled: true,
        isArchived: false,
        createdAt: widget.existingAppointment?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.existingAppointment != null) {
        await ref.read(appointmentControllerProvider.notifier).updateAppointment(appt);
      } else {
        await ref.read(appointmentControllerProvider.notifier).createAppointment(
          title: appt.title,
          notes: appt.notes,
          activityId: appt.activityId,
          startTime: appt.startTime,
          durationMinutes: appt.durationMinutes,
          recurrenceType: appt.recurrenceType,
          recurrenceDays: _selectedDays.toList(),
        );
      }
    } else {
      final dateStr = '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';
      final task = DayTask(
        id: widget.existingTask?.id ?? const Uuid().v4(),
        blockId: _selectedBlockId,
        activityId: _selectedActivityId,
        date: dateStr,
        title: _titleController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        isCompleted: widget.existingTask?.isCompleted ?? false,
        sortOrder: widget.existingTask?.sortOrder ?? 0,
        recurrenceType: _recurrenceType,
        recurrenceDays: recurrenceDaysJson,
        estimatedMinutes: _durationMinutes,
        reminderTime: startDateTime,
        createdAt: widget.existingTask?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.existingTask != null) {
        await ref.read(taskControllerProvider.notifier).updateTask(task);
      } else {
        await ref.read(taskControllerProvider.notifier).insertTask(task);
      }
    }

    if (mounted) Navigator.pop(context);
  }

  Widget _buildRecurrenceChip(String type, String label, IconData icon) {
    final isSelected = _recurrenceType == type;
    return ChoiceChip(
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : AppTheme.textSecondary),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : AppTheme.textSecondary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryGlow,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? AppTheme.primaryGlow : AppTheme.border),
      ),
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        setState(() => _recurrenceType = type);
      },
    );
  }
}
