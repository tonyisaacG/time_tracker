import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';
import '../application/planner_providers.dart';

class BlockManageScreen extends ConsumerWidget {
  const BlockManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(allBlocksProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('إدارة البلوكات', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGlow,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('بلوك جديد'),
        onPressed: () => _showBlockForm(context, ref),
      ),
      body: blocksAsync.when(
        data: (blocks) {
          if (blocks.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.view_day_rounded, size: 64, color: AppTheme.textMuted),
                  SizedBox(height: 16),
                  Text('لا توجد بلوكات', style: TextStyle(fontSize: 18, color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('اضغط + لإضافة بلوك جديد', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          final active = blocks.where((b) => !b.isArchived).toList();
          final archived = blocks.where((b) => b.isArchived).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              if (active.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 8, bottom: 8),
                  child: Text('البلوكات النشطة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                ),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final ids = active.map((b) => b.id).toList();
                    final moved = ids.removeAt(oldIndex);
                    ids.insert(newIndex, moved);
                    ref.read(blockControllerProvider.notifier).reorderBlocks(ids);
                  },
                  itemCount: active.length,
                  itemBuilder: (ctx, i) => _BlockTile(
                    key: ValueKey(active[i].id),
                    block: active[i],
                    showEdit: true,
                    onEdit: () => _showBlockForm(context, ref, block: active[i]),
                  ),
                ),
              ],
              if (archived.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 16, bottom: 8),
                  child: Text('البلوكات المؤرشفة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                ),
                ...archived.map((b) => _BlockTile(
                  key: ValueKey(b.id),
                  block: b,
                  showEdit: false,
                  onEdit: () {},
                )),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  void _showBlockForm(BuildContext context, WidgetRef ref, {DayBlock? block}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _BlockFormSheet(block: block),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Block Tile
// ─────────────────────────────────────────────────────────────────────────────

class _BlockTile extends ConsumerWidget {
  final DayBlock block;
  final bool showEdit;
  final VoidCallback onEdit;

  const _BlockTile({super.key, required this.block, required this.showEdit, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(block.color);
    final icon = AppTheme.activityIcons[block.icon] ?? Icons.view_day_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          block.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: block.isArchived ? AppTheme.textMuted : AppTheme.textPrimary,
            fontSize: 15,
          ),
        ),
        subtitle: block.isArchived
            ? const Text('مؤرشف', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showEdit)
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.textSecondary),
                onPressed: onEdit,
              ),
            IconButton(
              icon: Icon(
                block.isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                size: 18,
                color: AppTheme.textMuted,
              ),
              tooltip: block.isArchived ? 'استعادة' : 'أرشفة',
              onPressed: () => ref.read(blockControllerProvider.notifier).toggleArchive(block),
            ),
            if (showEdit)
              ReorderableDragStartListener(
                index: 0,
                child: const Icon(Icons.drag_handle_rounded, color: AppTheme.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Block Form Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _BlockFormSheet extends ConsumerStatefulWidget {
  final DayBlock? block;
  const _BlockFormSheet({this.block});

  @override
  ConsumerState<_BlockFormSheet> createState() => _BlockFormSheetState();
}

class _BlockFormSheetState extends ConsumerState<_BlockFormSheet> {
  late final TextEditingController _nameController;
  late int _selectedColor;
  late String _selectedIcon;

  static const List<String> _iconOptions = [
    'sunrise', 'work', 'sleep_relax', 'exercise', 'reading_deep',
    'programming_computer', 'coffee', 'tasks_todo', 'brain', 'heart',
  ];

  // Map sunrise to a valid icon or fallback
  static IconData _getIcon(String key) {
    const extra = <String, IconData>{
      'sunrise': Icons.wb_sunny_rounded,
    };
    return extra[key] ?? AppTheme.activityIcons[key] ?? Icons.wb_sunny_rounded;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.block?.name ?? '');
    _selectedColor = widget.block?.color ?? AppTheme.activityColors[0].value;
    _selectedIcon = widget.block?.icon ?? 'sunrise';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final now = DateTime.now();
    final existing = widget.block;

    if (existing != null) {
      final updated = existing.copyWith(name: name, color: _selectedColor, icon: _selectedIcon, updatedAt: now);
      ref.read(blockControllerProvider.notifier).updateBlock(updated);
    } else {
      final block = DayBlock(
        id: const Uuid().v4(),
        name: name,
        icon: _selectedIcon,
        color: _selectedColor,
        sortOrder: 999,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );
      ref.read(blockControllerProvider.notifier).insertBlock(block);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
          ),
          Text(
            widget.block == null ? 'إضافة بلوك جديد' : 'تعديل البلوك',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 20),
          // Name
          TextField(
            controller: _nameController,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'اسم البلوك',
              hintText: 'مثال: الصباح، بعد العمل...',
              filled: true, fillColor: AppTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
            ),
          ),
          const SizedBox(height: 16),
          // Color picker
          const Text('اللون', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: AppTheme.activityColors.map((c) {
              final isSelected = _selectedColor == c.value;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = c.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2.5),
                    boxShadow: isSelected ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8)] : [],
                  ),
                  child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Icon picker
          const Text('الأيقونة', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: _iconOptions.map((key) {
              final isSelected = _selectedIcon == key;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? Color(_selectedColor).withOpacity(0.2) : AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? Color(_selectedColor) : AppTheme.border, width: 1.5),
                  ),
                  child: Icon(_getIcon(key), size: 22, color: isSelected ? Color(_selectedColor) : AppTheme.textMuted),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(_selectedColor),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _save,
              child: Text(widget.block == null ? 'إضافة البلوك' : 'حفظ التغييرات',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
