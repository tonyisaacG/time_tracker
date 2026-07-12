import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
      
      final activities = await db.select(db.activities).get();
      final sessions = await db.select(db.sessions).get();

      final exportMap = {
        'activities': activities.map((a) => {
          'id': a.id,
          'name': a.name,
          'color': a.color,
          'icon': a.icon,
          'weeklyGoalMinutes': a.weeklyGoalMinutes,
          'isLimit': a.isLimit,
          'enforceLimit': a.enforceLimit,
          'isWeeklyFocus': a.isWeeklyFocus,
          'isArchived': a.isArchived,
          'isDeleted': a.isDeleted,
          'createdAt': a.createdAt.toIso8601String(),
          'updatedAt': a.updatedAt.toIso8601String(),
        }).toList(),
        'sessions': sessions.map((s) => {
          'id': s.id,
          'activityId': s.activityId,
          'startTime': s.startTime.toIso8601String(),
          'endTime': s.endTime?.toIso8601String(),
          'durationMinutes': s.durationMinutes,
          'deviceId': s.deviceId,
          'notes': s.notes,
          'isDeleted': s.isDeleted,
          'createdAt': s.createdAt.toIso8601String(),
          'updatedAt': s.updatedAt.toIso8601String(),
        }).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportMap);
      
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: jsonString));

      // Save to file in documents
      final directory = await getApplicationDocumentsDirectory();
      final file = File(p.join(directory.path, 'time_tracker_backup.json'));
      await file.writeAsString(jsonString);

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Export Successful!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Data has been copied to your system clipboard.'),
                  const SizedBox(height: 12),
                  const Text('2. Backup file saved to disk:'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      file.path,
                      style: const TextStyle(fontSize: 11, fontFamily: 'Courier', color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Awesome'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export: $e'), backgroundColor: const Color(0xffef4444)),
      );
    }
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
