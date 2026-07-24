import 'package:tracker_time/core/db/database.dart';

/// Pairs a DayBlock with its tasks for a specific date.
class BlockWithTasks {
  final DayBlock block;
  final List<DayTask> tasks;

  const BlockWithTasks({required this.block, required this.tasks});

  int get completedCount => tasks.where((t) => t.isCompleted).length;
  int get totalCount => tasks.length;
  bool get isEmpty => tasks.isEmpty;
}

abstract class PlannerRepository {
  /// Stream of all non-archived blocks with their tasks for [dateStr] (YYYY-MM-DD).
  Stream<List<BlockWithTasks>> watchBlocksWithTasks(String dateStr);

  /// Stream of all tasks within a specific date range (inclusive).
  Stream<List<DayTask>> watchTasksForDateRange(String startStr, String endStr);

  /// Stream of all tasks for management screen.
  Stream<List<DayTask>> watchAllTasks();

  /// Stream of all blocks (including archived) for management screen.
  Stream<List<DayBlock>> watchAllBlocks();

  // ── Block operations ──
  Future<void> insertBlock(DayBlock block);
  Future<void> updateBlock(DayBlock block);
  Future<void> archiveBlock(String id);
  Future<void> unarchiveBlock(String id);
  Future<void> deleteBlock(String id);
  Future<void> reorderBlocks(List<String> orderedIds);

  // ── Task operations ──
  Future<void> insertTask(DayTask task);
  Future<void> updateTask(DayTask task);
  Future<void> toggleTask(String id);
  Future<void> deleteTask(String id);
  Future<void> reorderTasks(String blockId, String dateStr, List<String> orderedIds);
}
