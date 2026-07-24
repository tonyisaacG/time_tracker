import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/features/session/application/timer_providers.dart';
import 'package:tracker_time/features/activity/application/activity_providers.dart';
import 'package:tracker_time/features/session/application/session_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceIdAsync = ref.watch(deviceIdProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Synchronization'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sync_rounded, color: AppTheme.primaryGlow),
                      SizedBox(width: 10),
                      Text(
                        'Local-First Sync State',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Time Investment Tracker stores all data locally. In Phase 3, you will be able to synchronize your desktop and mobile clients securely across your local network.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'LOCAL DEVICE IDENTIFIER',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 4),
                  deviceIdAsync.when(
                    data: (id) => Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Text(
                              id,
                              style: const TextStyle(fontSize: 12, fontFamily: 'Courier', color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: AppTheme.primaryGlow, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Device ID copied to clipboard')),
                            );
                          },
                        ),
                      ],
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (err, stack) => Text('Error loading device ID: $err'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('Data Ownership'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: Color(0xff10b981)),
                  title: const Text('Export Backup (JSON)'),
                  subtitle: const Text('Save your activities and sessions to a JSON file'),
                  onTap: () => _exportData(context, ref),
                ),
                const Divider(color: AppTheme.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.upload_rounded, color: AppTheme.primaryGlow),
                  title: const Text('Import Backup (JSON)'),
                  subtitle: const Text('Restore records from a pasted JSON code or dump'),
                  onTap: () => _showImportDialog(context, ref),
                ),
                const Divider(color: AppTheme.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Color(0xffef4444)),
                  title: const Text('Reset Database', style: TextStyle(color: Color(0xffef4444))),
                  subtitle: const Text('Clear all logged time and activities permanently'),
                  onTap: () => _confirmReset(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Time Investment Tracker v1.0.0 • Local First',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(databaseProvider);

      // ── Collect all tables ─────────────────────────────────────────────
      final activities   = await db.select(db.activities).get();
      final sessions     = await db.select(db.sessions).get();
      final appointments = await db.select(db.appointments).get();
      final dayBlocks    = await db.select(db.dayBlocks).get();
      final dayTasks     = await db.select(db.dayTasks).get();

      final exportMap = {
        'exportedAt': DateTime.now().toIso8601String(),
        'version': 2,
        'activities': activities.map((a) => {
          'id': a.id, 'name': a.name, 'color': a.color, 'icon': a.icon,
          'weeklyGoalMinutes': a.weeklyGoalMinutes,
          'isLimit': a.isLimit, 'enforceLimit': a.enforceLimit,
          'isWeeklyFocus': a.isWeeklyFocus, 'isArchived': a.isArchived,
          'isDeleted': a.isDeleted,
          'createdAt': a.createdAt.toIso8601String(),
          'updatedAt': a.updatedAt.toIso8601String(),
        }).toList(),
        'sessions': sessions.map((s) => {
          'id': s.id, 'activityId': s.activityId,
          'startTime': s.startTime.toIso8601String(),
          'endTime': s.endTime?.toIso8601String(),
          'durationMinutes': s.durationMinutes,
          'targetDurationMinutes': s.targetDurationMinutes,
          'deviceId': s.deviceId, 'notes': s.notes,
          'isDeleted': s.isDeleted,
          'createdAt': s.createdAt.toIso8601String(),
          'updatedAt': s.updatedAt.toIso8601String(),
        }).toList(),
        'appointments': appointments.map((a) => {
          'id': a.id, 'activityId': a.activityId,
          'title': a.title, 'notes': a.notes,
          'startTime': a.startTime.toIso8601String(),
          'durationMinutes': a.durationMinutes,
          'recurrenceType': a.recurrenceType,
          'recurrenceDays': a.recurrenceDays,
          'isEnabled': a.isEnabled, 'isArchived': a.isArchived,
          'createdAt': a.createdAt.toIso8601String(),
          'updatedAt': a.updatedAt.toIso8601String(),
        }).toList(),
        'dayBlocks': dayBlocks.map((b) => {
          'id': b.id, 'name': b.name, 'icon': b.icon, 'color': b.color,
          'sortOrder': b.sortOrder, 'isArchived': b.isArchived,
          'createdAt': b.createdAt.toIso8601String(),
          'updatedAt': b.updatedAt.toIso8601String(),
        }).toList(),
        'dayTasks': dayTasks.map((t) => {
          'id': t.id, 'blockId': t.blockId, 'activityId': t.activityId,
          'date': t.date, 'title': t.title, 'notes': t.notes,
          'isCompleted': t.isCompleted, 'sortOrder': t.sortOrder,
          'reminderTime': t.reminderTime?.toIso8601String(),
          'completedAt': t.completedAt?.toIso8601String(),
          'createdAt': t.createdAt.toIso8601String(),
          'updatedAt': t.updatedAt.toIso8601String(),
        }).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportMap);
      final timestamp  = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final fileName   = 'TimeTracker_backup_$timestamp.json';

      // ── Save to Downloads folder (visible on phone) ────────────────────
      File? savedFile;
      String? savedPath;

      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          try {
            // Android 10+ needs no permission; Android ≤9 will throw FileSystemException
            savedFile = File(p.join(downloadsDir.path, fileName));
            await savedFile.writeAsString(jsonString);
            savedPath = savedFile.path;
          } on FileSystemException {
            // Android 9 and below: request WRITE_EXTERNAL_STORAGE and retry
            final status = await Permission.storage.request();
            if (status.isGranted) {
              savedFile = File(p.join(downloadsDir.path, fileName));
              await savedFile.writeAsString(jsonString);
              savedPath = savedFile.path;
            }
          }
        }
      }

      // Fallback: app documents directory (always works)
      if (savedFile == null) {
        final dir = await getApplicationDocumentsDirectory();
        savedFile = File(p.join(dir.path, fileName));
        await savedFile.writeAsString(jsonString);
        savedPath = savedFile.path;
      }

      // Also copy to clipboard for convenience
      await Clipboard.setData(ClipboardData(text: jsonString));

      if (context.mounted) {
        _showExportSuccessDialog(
          context,
          filePath: savedPath!,
          activities: activities.length,
          sessions: sessions.length,
          appointments: appointments.length,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e'), backgroundColor: const Color(0xffef4444)),
        );
      }
    }
  }

  void _showExportSuccessDialog(
    BuildContext context, {
    required String filePath,
    required int activities,
    required int sessions,
    required int appointments,
  }) {
    final isDownloads = filePath.contains('/Download') || filePath.contains('/Downloads');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xff10b981), size: 24),
            SizedBox(width: 10),
            Text('Backup Saved!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xff10b981).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xff10b981).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  _statRow(Icons.category_rounded, '$activities activities'),
                  _statRow(Icons.timer_rounded, '$sessions sessions'),
                  _statRow(Icons.calendar_today_rounded, '$appointments appointments'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isDownloads ? '📂 Saved to Downloads folder:' : '📂 Saved to:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                filePath,
                style: const TextStyle(fontSize: 11, fontFamily: 'Courier', color: AppTheme.textSecondary),
              ),
            ),
            if (isDownloads) ...[
              const SizedBox(height: 8),
              const Text(
                'Open your phone\'s Files app → Downloads to find the backup file.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              '✓ Also copied to clipboard.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xff10b981)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return _ImportDialog(
          onImport: (jsonString) async {
            try {
              final data = jsonDecode(jsonString) as Map<String, dynamic>;
              final actsJson = data['activities'] as List<dynamic>? ?? [];
              final sessionsJson = data['sessions'] as List<dynamic>? ?? [];

              final db = ref.read(databaseProvider);

              await db.transaction(() async {
                // Clear existing
                await db.delete(db.sessions).go();
                await db.delete(db.activities).go();

                // Restore activities
                for (final actVal in actsJson) {
                  final actMap = actVal as Map<String, dynamic>;
                  await db.into(db.activities).insert(
                    Activity(
                      id: actMap['id'] as String,
                      name: actMap['name'] as String,
                      color: actMap['color'] as int,
                      icon: actMap['icon'] as String,
                      weeklyGoalMinutes: actMap['weeklyGoalMinutes'] as int?,
                      isLimit: actMap['isLimit'] as bool? ?? false,
                      enforceLimit: actMap['enforceLimit'] as bool? ?? false,
                      isWeeklyFocus: actMap['isWeeklyFocus'] as bool? ?? true,
                      isArchived: actMap['isArchived'] as bool? ?? false,
                      isDeleted: actMap['isDeleted'] as bool? ?? false,
                      createdAt: DateTime.parse(actMap['createdAt'] as String),
                      updatedAt: DateTime.parse(actMap['updatedAt'] as String),
                    ),
                  );
                }

                // Restore sessions
                for (final sVal in sessionsJson) {
                  final sMap = sVal as Map<String, dynamic>;
                  await db.into(db.sessions).insert(
                    Session(
                      id: sMap['id'] as String,
                      activityId: sMap['activityId'] as String,
                      startTime: DateTime.parse(sMap['startTime'] as String),
                      endTime: sMap['endTime'] != null ? DateTime.parse(sMap['endTime'] as String) : null,
                      durationMinutes: sMap['durationMinutes'] as int,
                      deviceId: sMap['deviceId'] as String,
                      notes: sMap['notes'] as String?,
                      isDeleted: sMap['isDeleted'] as bool? ?? false,
                      createdAt: DateTime.parse(sMap['createdAt'] as String),
                      updatedAt: DateTime.parse(sMap['updatedAt'] as String),
                    ),
                  );
                }
              });

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup restored successfully!'), backgroundColor: Color(0xff10b981)),
                );
              }
            } catch (e) {
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Restore Failed'),
                    content: Text('Error decoding backup JSON: $e'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                    ],
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Database?', style: TextStyle(color: Color(0xffef4444))),
          content: const Text('This will delete all your activities, targets, and tracked sessions permanently. This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final db = ref.read(databaseProvider);
                await db.transaction(() async {
                  await db.delete(db.sessions).go();
                  await db.delete(db.activities).go();
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All data has been cleared.')),
                  );
                }
              },
              child: const Text('Delete Everything', style: TextStyle(color: Color(0xffef4444))),
            ),
          ],
        );
      },
    );
  }
}

class _ImportDialog extends StatefulWidget {
  final Future<void> Function(String jsonString) onImport;

  const _ImportDialog({required this.onImport});

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _controller = TextEditingController();
  bool _importing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Backup JSON'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Paste your exported backup JSON text below. This will overwrite all current data.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 8,
            style: const TextStyle(fontSize: 11, fontFamily: 'Courier'),
            decoration: const InputDecoration(
              hintText: '{\n  "activities": [...],\n  "sessions": [...]\n}',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        TextButton(
          onPressed: _importing
              ? null
              : () async {
                  if (_controller.text.trim().isEmpty) return;
                  setState(() {
                    _importing = true;
                  });
                  await widget.onImport(_controller.text.trim());
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
          child: _importing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Restore Data', style: TextStyle(color: AppTheme.primaryGlow, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
