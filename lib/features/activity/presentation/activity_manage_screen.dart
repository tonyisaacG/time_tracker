import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/features/session/application/session_providers.dart';
import '../application/activity_providers.dart';

class ActivityManageScreen extends ConsumerStatefulWidget {
  const ActivityManageScreen({super.key});

  @override
  ConsumerState<ActivityManageScreen> createState() => _ActivityManageScreenState();
}

class _ActivityManageScreenState extends ConsumerState<ActivityManageScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(_showArchived ? allActivitiesProvider : activeActivitiesProvider);

    // Watch for mutation errors/loading states
    ref.listen<AsyncValue<void>>(activityControllerProvider, (previous, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xffef4444),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Activities'),
        actions: [
          Row(
            children: [
              const Text(
                'Show Archived',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              Switch(
                value: _showArchived,
                onChanged: (val) {
                  setState(() {
                    _showArchived = val;
                  });
                },
                activeColor: AppTheme.primaryGlow,
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: activitiesAsync.when(
        data: (activities) {
          if (activities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_rounded,
                    size: 64,
                    color: AppTheme.textMuted.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showArchived ? 'No archived activities' : 'No activities yet',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_showArchived)
                    ElevatedButton.icon(
                      onPressed: () => _showActivityForm(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Activity'),
                    ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 180,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final act = activities[index];
              return _buildActivityCard(context, act);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGlow)),
        error: (err, stack) => Center(
          child: Text(
            'Error loading activities: $err',
            style: const TextStyle(color: Color(0xffef4444)),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showActivityForm(context),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, Activity act) {
    final color = Color(act.color);
    final iconData = AppTheme.activityIcons[act.icon] ?? Icons.category_rounded;
    final hours = act.weeklyGoalMinutes != null ? (act.weeklyGoalMinutes! / 60.0).toStringAsFixed(1) : '0';
    String goalText = 'No Target Set';
    if (act.weeklyGoalMinutes != null) {
      if (act.isLimit) {
        goalText = act.enforceLimit ? 'Limit: ${hours}h/wk (Forced)' : 'Limit: ${hours}h/wk';
      } else {
        goalText = 'Goal: ${hours}h/wk';
      }
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showActivityForm(context, activity: act),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.4), width: 1.5),
                    ),
                    child: Icon(iconData, color: color, size: 24),
                  ),
                  const Spacer(),
                  if (!act.isArchived) ...[
                    GestureDetector(
                      onTap: () {}, // Stop event bubbling to Card InkWell
                      child: Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: act.isWeeklyFocus,
                          activeColor: color,
                          onChanged: (val) {
                            ref.read(activityControllerProvider.notifier).updateActivity(
                              act.copyWith(isWeeklyFocus: val),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (act.isArchived)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Archived',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                act.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      goalText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notes_rounded, color: AppTheme.textSecondary, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'View Session Notes',
                        onPressed: () => _showNotesHistory(context, act),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xffef4444), size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmDelete(context, act),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotesHistory(BuildContext context, Activity act) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _ActivityNotesBottomSheet(activity: act);
      },
    );
  }

  void _confirmDelete(BuildContext context, Activity act) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Activity?'),
          content: Text('Are you sure you want to delete "${act.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(activityControllerProvider.notifier).deleteActivity(act.id);
              },
              child: const Text('Delete', style: TextStyle(color: Color(0xffef4444))),
            ),
          ],
        );
      },
    );
  }

  void _showActivityForm(BuildContext context, {Activity? activity}) {
    showDialog(
      context: context,
      builder: (context) {
        return _ActivityFormDialog(
          activity: activity,
          onSave: (name, colorValue, iconKey, goalMinutes, isLimit, enforceLimit, isWeeklyFocus, isArchived) {
            final controller = ref.read(activityControllerProvider.notifier);
            if (activity == null) {
              controller.createActivity(
                name: name,
                color: colorValue,
                icon: iconKey,
                weeklyGoalMinutes: goalMinutes,
                isLimit: isLimit,
                enforceLimit: enforceLimit,
                isWeeklyFocus: isWeeklyFocus,
              );
            } else {
              controller.updateActivity(
                activity.copyWith(
                  name: name,
                  color: colorValue,
                  icon: iconKey,
                  weeklyGoalMinutes: Value(goalMinutes),
                  isLimit: isLimit,
                  enforceLimit: enforceLimit,
                  isWeeklyFocus: isWeeklyFocus,
                  isArchived: isArchived,
                ),
              );
            }
          },
        );
      },
    );
  }
}

class _ActivityFormDialog extends StatefulWidget {
  final Activity? activity;
  final void Function(
    String name,
    int colorValue,
    String iconKey,
    int? goalMinutes,
    bool isLimit,
    bool enforceLimit,
    bool isWeeklyFocus,
    bool isArchived,
  ) onSave;

  const _ActivityFormDialog({
    this.activity,
    required this.onSave,
  });

  @override
  State<_ActivityFormDialog> createState() => _ActivityFormDialogState();
}

class _ActivityFormDialogState extends State<_ActivityFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late int _selectedColorVal;
  late String _selectedIconKey;
  late bool _hasGoal;
  late double _goalHours;
  late bool _isLimit;
  late bool _enforceLimit;
  late bool _isWeeklyFocus;
  late bool _isArchived;

  @override
  void initState() {
    super.initState();
    final act = widget.activity;
    _name = act?.name ?? '';
    _selectedColorVal = act?.color ?? AppTheme.activityColors[0].value;
    _selectedIconKey = act?.icon ?? AppTheme.activityIcons.keys.first;
    _hasGoal = act?.weeklyGoalMinutes != null;
    _goalHours = act?.weeklyGoalMinutes != null ? (act!.weeklyGoalMinutes! / 60.0) : 5.0;
    _isLimit = act?.isLimit ?? false;
    _enforceLimit = act?.enforceLimit ?? false;
    _isWeeklyFocus = act?.isWeeklyFocus ?? true;
    _isArchived = act?.isArchived ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.activity != null;

    return AlertDialog(
      scrollable: true,
      title: Text(isEdit ? 'Edit Activity' : 'New Activity'),
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(
                labelText: 'Activity Name',
                hintText: 'e.g. English, Coding, Exercise',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
              onSaved: (val) => _name = val!.trim(),
            ),
            const SizedBox(height: 16),
            const Text('Color Preset', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppTheme.activityColors.map((col) {
                final isSelected = col.value == _selectedColorVal;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColorVal = col.value;
                    });
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: col.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Activity Icon', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    _showIconPickerBottomSheet(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppTheme.activityIcons[_selectedIconKey] ?? Icons.category_rounded,
                          color: Color(_selectedColorVal),
                        ),
                        const SizedBox(width: 8),
                        const Text('Change...', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: _hasGoal,
                  activeColor: AppTheme.primaryGlow,
                  onChanged: (val) {
                    setState(() {
                      _hasGoal = val ?? false;
                    });
                  },
                ),
                const Text('Set Weekly Target / Limit', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            if (_hasGoal) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Target')),
                      selected: !_isLimit,
                      selectedColor: Color(_selectedColorVal).withOpacity(0.25),
                      labelStyle: TextStyle(
                        color: !_isLimit ? Color(_selectedColorVal) : AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _isLimit = !selected;
                          if (!_isLimit) {
                            _enforceLimit = false;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Limit')),
                      selected: _isLimit,
                      selectedColor: Color(_selectedColorVal).withOpacity(0.25),
                      labelStyle: TextStyle(
                        color: _isLimit ? Color(_selectedColorVal) : AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _isLimit = selected;
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_isLimit) ...[
                Row(
                  children: [
                    Checkbox(
                      value: _enforceLimit,
                      activeColor: Color(_selectedColorVal),
                      onChanged: (val) {
                        setState(() {
                          _enforceLimit = val ?? false;
                        });
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Enforce limit (Force-stop active timer)',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isLimit 
                        ? 'Limit: ${_goalHours.toStringAsFixed(1)} hours/week'
                        : 'Target: ${_goalHours.toStringAsFixed(1)} hours/week',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  Text(
                    '(${(_goalHours * 60).round()} mins)',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
              Slider(
                value: _goalHours,
                min: 0.5,
                max: 40.0,
                divisions: 79,
                activeColor: Color(_selectedColorVal),
                inactiveColor: AppTheme.border,
                onChanged: (val) {
                  setState(() {
                    _goalHours = val;
                  });
                },
              ),
            ],
            const SizedBox(height: 12),
            const Divider(color: AppTheme.border),
            Row(
              children: [
                Checkbox(
                  value: _isWeeklyFocus,
                  activeColor: AppTheme.primaryGlow,
                  onChanged: (val) {
                    setState(() {
                      _isWeeklyFocus = val ?? true;
                    });
                  },
                ),
                const Expanded(
                  child: Text('Focus on this activity this week', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (isEdit) ...[
              Row(
                children: [
                  Checkbox(
                    value: _isArchived,
                    activeColor: AppTheme.primaryGlow,
                    onChanged: (val) {
                      setState(() {
                        _isArchived = val ?? false;
                      });
                    },
                  ),
                  const Expanded(
                    child: Text('Archive Activity', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
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
              final goalMinutes = _hasGoal ? (_goalHours * 60).round() : null;
              widget.onSave(
                _name,
                _selectedColorVal,
                _selectedIconKey,
                goalMinutes,
                _isLimit && _hasGoal,
                _enforceLimit && _hasGoal && _isLimit,
                _isWeeklyFocus,
                _isArchived,
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Save', style: TextStyle(color: AppTheme.primaryGlow, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _showIconPickerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Select Icon',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: AppTheme.activityIcons.length,
                        itemBuilder: (context, index) {
                          final entry = AppTheme.activityIcons.entries.elementAt(index);
                          final isSelected = entry.key == _selectedIconKey;
                          final iconColor = isSelected ? Color(_selectedColorVal) : AppTheme.textSecondary;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedIconKey = entry.key;
                              });
                              setDialogState(() {
                                // Redraw modal highlight
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? Color(_selectedColorVal).withOpacity(0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Color(_selectedColorVal) : AppTheme.border,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(entry.value, color: iconColor, size: 24),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ActivityNotesBottomSheet extends ConsumerWidget {
  final Activity activity;

  const _ActivityNotesBottomSheet({required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(allSessionsProvider);
    final color = Color(activity.color);

    return SafeArea(
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
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    AppTheme.activityIcons[activity.icon] ?? Icons.category_rounded,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Text(
                        'Session History & Notes Log',
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
            const SizedBox(height: 16),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350),
              child: sessionsAsync.when(
                data: (sessions) {
                  final filtered = sessions.where((s) => s.activityId == activity.id && s.endTime != null && !s.isDeleted).toList();
                  filtered.sort((a, b) => b.startTime.compareTo(a.startTime));

                  if (filtered.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No tracked sessions for this activity yet.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    );
                  }

                  final totalMinutes = filtered.fold(0, (sum, s) => sum + s.durationMinutes);
                  final totalHoursStr = (totalMinutes / 60.0).toStringAsFixed(1);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Total tracked: ${totalHoursStr}h (${totalMinutes} mins)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: color),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final session = filtered[index];
                            final dateStr = DateFormat('EEE, MMM d, y').format(session.startTime);
                            final timeStr = DateFormat('jm').format(session.startTime);
                            final durationStr = '${session.durationMinutes}m';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '$dateStr at $timeStr',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                        ),
                                        Text(
                                          durationStr,
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      (session.notes != null && session.notes!.trim().isNotEmpty)
                                          ? session.notes!
                                          : 'No notes entered for this session',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: (session.notes != null && session.notes!.trim().isNotEmpty)
                                            ? AppTheme.textPrimary
                                            : AppTheme.textMuted,
                                        fontStyle: (session.notes != null && session.notes!.trim().isNotEmpty)
                                            ? FontStyle.normal
                                            : FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading notes: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
