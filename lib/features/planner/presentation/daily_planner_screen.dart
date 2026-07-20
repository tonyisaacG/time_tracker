import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/core/providers/navigation_provider.dart';
import 'package:tracker_time/features/activity/application/activity_providers.dart';
import 'package:tracker_time/features/session/application/timer_providers.dart';
import '../application/planner_providers.dart';
import '../domain/planner_repository.dart';
import 'block_manage_screen.dart';

class DailyPlannerScreen extends ConsumerStatefulWidget {
  const DailyPlannerScreen({super.key});

  @override
  ConsumerState<DailyPlannerScreen> createState() => _DailyPlannerScreenState();
}

class _DailyPlannerScreenState extends ConsumerState<DailyPlannerScreen> {
  late final PageController _pageController;
  // Use a base date to anchor page offsets
  final DateTime _baseDate = DateTime(2026, 1, 1);

  @override
  void initState() {
    super.initState();
    final selected = ref.read(plannerSelectedDateProvider);
    final initialPage = selected.difference(_baseDate).inDays;
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  void _navigateDay(int delta) {
    final current = ref.read(plannerSelectedDateProvider);
    final next = current.add(Duration(days: delta));
    ref.read(plannerSelectedDateProvider.notifier).state = next;
    final page = next.difference(_baseDate).inDays;
    _pageController.animateToPage(page,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(plannerSelectedDateProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _DateNavigator(
          date: selectedDate,
          onPrev: () => _navigateDay(-1),
          onNext: () => _navigateDay(1),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppTheme.primaryGlow),
            tooltip: 'إدارة البلوكات',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BlockManageScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) {
          final newDate = _baseDate.add(Duration(days: page));
          ref.read(plannerSelectedDateProvider.notifier).state = newDate;
        },
        itemBuilder: (context, page) {
          final pageDate = _baseDate.add(Duration(days: page));
          return _DayPlannerPage(dateStr: _formatDate(pageDate));
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date Navigator Header
// ─────────────────────────────────────────────────────────────────────────────

class _DateNavigator extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _DateNavigator({required this.date, required this.onPrev, required this.onNext});

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'اليوم — ${DateFormat('d MMM').format(date)}';
    if (d == today.add(const Duration(days: 1))) return 'غداً — ${DateFormat('d MMM').format(date)}';
    if (d == today.subtract(const Duration(days: 1))) return 'أمس — ${DateFormat('d MMM').format(date)}';
    return DateFormat('EEE، d MMMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
          color: AppTheme.primaryGlow,
          onPressed: onPrev,
          tooltip: 'اليوم السابق',
        ),
        Flexible(
          child: Text(
            _label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 28),
          color: AppTheme.primaryGlow,
          onPressed: onNext,
          tooltip: 'اليوم التالي',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day Page — shows all blocks with their tasks
// ─────────────────────────────────────────────────────────────────────────────

class _DayPlannerPage extends ConsumerWidget {
  final String dateStr;

  const _DayPlannerPage({required this.dateStr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, _) {
        // Watch the global planner provider (filtered by selected date)
        // We use a workaround by watching the repo directly per date
        final repoProvider = ref.watch(plannerRepositoryProvider);
        return StreamBuilder<List<BlockWithTasks>>(
          stream: repoProvider.watchBlocksWithTasks(dateStr),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
            }
            final blocks = snapshot.data ?? [];
            if (blocks.isEmpty) {
              return _EmptyBlocksPlaceholder(dateStr: dateStr);
            }
            return ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 8),
              itemCount: blocks.length,
              itemBuilder: (context, i) => _BlockCard(
                blockWithTasks: blocks[i],
                dateStr: dateStr,
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyBlocksPlaceholder extends StatelessWidget {
  final String dateStr;
  const _EmptyBlocksPlaceholder({required this.dateStr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.view_day_rounded, size: 64, color: AppTheme.textMuted.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('لا توجد بلوكات بعد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('اضغط ⚙ لإضافة وإدارة البلوكات', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Block Card
// ─────────────────────────────────────────────────────────────────────────────

class _BlockCard extends ConsumerWidget {
  final BlockWithTasks blockWithTasks;
  final String dateStr;

  const _BlockCard({required this.blockWithTasks, required this.dateStr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final block = blockWithTasks.block;
    final tasks = blockWithTasks.tasks;
    final blockColor = Color(block.color);
    final icon = AppTheme.activityIcons[block.icon] ?? Icons.wb_sunny_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Block header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: blockColor.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(left: BorderSide(color: blockColor, width: 3)),
            ),
            child: Row(
              children: [
                Icon(icon, color: blockColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    block.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: blockColor,
                    ),
                  ),
                ),
                // Completion progress badge
                if (tasks.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: blockColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${blockWithTasks.completedCount}/${blockWithTasks.totalCount}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: blockColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Add task button
                InkWell(
                  onTap: () => _showAddTaskSheet(context, ref, block),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 18, color: blockColor),
                        const SizedBox(width: 4),
                        Text('إضافة', style: TextStyle(fontSize: 12, color: blockColor, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tasks list
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'لا توجد مهام — اضغط إضافة',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted.withOpacity(0.7), fontStyle: FontStyle.italic),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                child: child,
              ),
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                final ids = tasks.map((t) => t.id).toList();
                final moved = ids.removeAt(oldIndex);
                ids.insert(newIndex, moved);
                ref.read(taskControllerProvider.notifier).reorderTasks(block.id, dateStr, ids);
              },
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _TaskTile(key: ValueKey(task.id), task: task, blockColor: blockColor, dateStr: dateStr);
              },
            ),
        ],
      ),
    );
  }

  void _showAddTaskSheet(BuildContext context, WidgetRef ref, DayBlock block) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddTaskSheet(block: block, dateStr: dateStr),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Tile
// ─────────────────────────────────────────────────────────────────────────────

class _TaskTile extends ConsumerWidget {
  final DayTask task;
  final Color blockColor;
  final String dateStr;

  const _TaskTile({
    super.key,
    required this.task,
    required this.blockColor,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(activeActivitiesProvider).valueOrNull ?? [];
    final linkedActivity = task.activityId != null
        ? activities.where((a) => a.id == task.activityId).firstOrNull
        : null;

    final hasReminder = task.reminderTime != null;
    final timeFormatted = hasReminder ? DateFormat('h:mm a').format(task.reminderTime!) : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: GestureDetector(
        onTap: () => ref.read(taskControllerProvider.notifier).toggleTask(task),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: task.isCompleted ? blockColor : Colors.transparent,
            border: Border.all(
              color: task.isCompleted ? blockColor : AppTheme.textMuted,
              width: 2,
            ),
          ),
          child: task.isCompleted
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : null,
        ),
      ),
      title: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          fontSize: 14,
          color: task.isCompleted ? AppTheme.textMuted : AppTheme.textPrimary,
          decoration: task.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
          decorationColor: AppTheme.textMuted,
        ),
        child: Text(task.title),
      ),
      subtitle: (task.notes != null && task.notes!.isNotEmpty) || hasReminder
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.notes != null && task.notes!.isNotEmpty)
                    Text(
                      task.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (hasReminder) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          size: 12,
                          color: task.isCompleted ? AppTheme.textMuted : AppTheme.primaryGlow,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeFormatted!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: task.isCompleted ? AppTheme.textMuted : AppTheme.primaryGlow,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            )
          : null,
      // Activity launch button
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (linkedActivity != null)
            GestureDetector(
              onTap: () async {
                await ref.read(timerControllerProvider.notifier).startTimer(
                  linkedActivity.id,
                  notes: 'من الخطة: ${task.title}',
                );
                ref.read(navigationProvider.notifier).state = 0; // Switch to Timer tab
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(linkedActivity.color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(linkedActivity.color).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppTheme.activityIcons[linkedActivity.icon] ?? Icons.play_arrow_rounded,
                      size: 14,
                      color: Color(linkedActivity.color),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      linkedActivity.name,
                      style: TextStyle(fontSize: 11, color: Color(linkedActivity.color), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 4),
          // Drag handle
          Icon(Icons.drag_handle_rounded, color: AppTheme.textMuted.withOpacity(0.5), size: 20),
        ],
      ),
      onLongPress: () => _showTaskOptions(context, ref),
    );
  }

  void _showTaskOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppTheme.primaryGlow),
              title: const Text('تعديل المهمة', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppTheme.surface,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  builder: (_) => _AddTaskSheet(
                    block: DayBlock(
                      id: task.blockId,
                      name: '',
                      icon: 'tasks_todo',
                      color: blockColor.value,
                      sortOrder: 0,
                      isArchived: false,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                    dateStr: dateStr,
                    task: task,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('حذف المهمة', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(taskControllerProvider.notifier).deleteTask(task.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Task Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddTaskSheet extends ConsumerStatefulWidget {
  final DayBlock block;
  final String dateStr;
  final DayTask? task;

  const _AddTaskSheet({required this.block, required this.dateStr, this.task});

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  String? _selectedActivityId;
  TimeOfDay? _reminderTimeOfDay;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t?.title ?? '');
    _notesController = TextEditingController(text: t?.notes ?? '');
    _selectedActivityId = t?.activityId;
    if (t?.reminderTime != null) {
      _reminderTimeOfDay = TimeOfDay.fromDateTime(t!.reminderTime!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTimeOfDay ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _reminderTimeOfDay = time);
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final notes = _notesController.text.trim();

    DateTime? reminderDateTime;
    if (_reminderTimeOfDay != null) {
      final parts = widget.dateStr.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        reminderDateTime = DateTime(
          year,
          month,
          day,
          _reminderTimeOfDay!.hour,
          _reminderTimeOfDay!.minute,
        );
      }
    }

    final now = DateTime.now();
    final existing = widget.task;

    if (existing != null) {
      final updated = existing.copyWith(
        title: title,
        notes: Value(notes.isNotEmpty ? notes : null),
        activityId: Value(_selectedActivityId),
        reminderTime: Value(reminderDateTime),
        updatedAt: now,
      );
      ref.read(taskControllerProvider.notifier).updateTask(updated);
    } else {
      final task = DayTask(
        id: const Uuid().v4(),
        blockId: widget.block.id,
        activityId: _selectedActivityId,
        date: widget.dateStr,
        title: title,
        notes: notes.isNotEmpty ? notes : null,
        isCompleted: false,
        sortOrder: 999,
        reminderTime: reminderDateTime,
        completedAt: null,
        createdAt: now,
        updatedAt: now,
      );
      ref.read(taskControllerProvider.notifier).insertTask(task);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final activities = ref.watch(activeActivitiesProvider).valueOrNull ?? [];
    final blockColor = Color(widget.block.color);
    final isEditing = widget.task != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // Title
            Row(
              children: [
                Icon(AppTheme.activityIcons[widget.block.icon] ?? Icons.wb_sunny_rounded, color: blockColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'تعديل المهمة' : 'إضافة مهمة — ${widget.block.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Task title input
            TextField(
              controller: _titleController,
              autofocus: !isEditing,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'عنوان المهمة',
                hintText: 'اكتب المهمة...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: blockColor, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            // Notes input
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'ملاحظات / تفاصيل إضافية (اختياري)',
                hintText: 'مثال: قائمة الخطوات، تفاصيل أو روابط...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: blockColor, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            // Reminder Notification Row
            Container(
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryGlow, size: 20),
                title: const Text('تذكير بالإشعار', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                subtitle: Text(
                  _reminderTimeOfDay != null
                      ? DateFormat('h:mm a').format(DateTime(2026, 1, 1, _reminderTimeOfDay!.hour, _reminderTimeOfDay!.minute))
                      : 'بدون تذكير',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _reminderTimeOfDay != null ? AppTheme.primaryGlow : AppTheme.textMuted,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_reminderTimeOfDay != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                        onPressed: () => setState(() => _reminderTimeOfDay = null),
                        tooltip: 'إلغاء التذكير',
                      ),
                    IconButton(
                      icon: const Icon(Icons.access_time_rounded, color: AppTheme.primaryGlow),
                      onPressed: _pickReminderTime,
                      tooltip: 'اختيار الوقت',
                    ),
                  ],
                ),
                onTap: _pickReminderTime,
              ),
            ),
            const SizedBox(height: 12),
            // Activity link (optional)
            DropdownButtonFormField<String?>(
              value: _selectedActivityId,
              decoration: InputDecoration(
                labelText: 'ربط بنشاط (اختياري)',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
              ),
              dropdownColor: AppTheme.surface,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('بدون ربط', style: TextStyle(color: AppTheme.textMuted)),
                ),
                ...activities.map((a) => DropdownMenuItem<String?>(
                  value: a.id,
                  child: Row(
                    children: [
                      Icon(AppTheme.activityIcons[a.icon] ?? Icons.category_rounded, color: Color(a.color), size: 18),
                      const SizedBox(width: 8),
                      Text(a.name, style: const TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                )),
              ],
              onChanged: (val) => setState(() => _selectedActivityId = val),
            ),
            const SizedBox(height: 20),
            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blockColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _save,
                child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة المهمة', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
