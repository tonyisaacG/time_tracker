import 'package:drift/drift.dart';
import 'package:tracker_time/core/db/database.dart';
import '../domain/planner_repository.dart';

class PlannerRepositoryImpl implements PlannerRepository {
  final AppDatabase _db;

  PlannerRepositoryImpl(this._db);

  // ─────────────────────────────────────────────
  // Streams
  // ─────────────────────────────────────────────

  @override
  Stream<List<BlockWithTasks>> watchBlocksWithTasks(String dateStr) {
    // Watch blocks (non-archived), ordered by sortOrder
    final blocksStream = (_db.select(_db.dayBlocks)
          ..where((b) => b.isArchived.equals(false))
          ..orderBy([(b) => OrderingTerm.asc(b.sortOrder)]))
        .watch();

    // Watch tasks for the given date, ordered by sortOrder
    final tasksStream = (_db.select(_db.dayTasks)
          ..where((t) => t.date.equals(dateStr))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();

    return blocksStream.asyncExpand((blocks) {
      return tasksStream.map((tasks) {
        return blocks.map((block) {
          final blockTasks = tasks.where((t) => t.blockId == block.id).toList();
          return BlockWithTasks(block: block, tasks: blockTasks);
        }).toList();
      });
    });
  }

  @override
  Stream<List<DayBlock>> watchAllBlocks() {
    return (_db.select(_db.dayBlocks)
          ..orderBy([(b) => OrderingTerm.asc(b.sortOrder)]))
        .watch();
  }

  // ─────────────────────────────────────────────
  // Block Operations
  // ─────────────────────────────────────────────

  @override
  Future<void> insertBlock(DayBlock block) async {
    await _db.into(_db.dayBlocks).insert(block);
  }

  @override
  Future<void> updateBlock(DayBlock block) async {
    await _db.update(_db.dayBlocks).replace(block);
  }

  @override
  Future<void> archiveBlock(String id) async {
    await (_db.update(_db.dayBlocks)..where((b) => b.id.equals(id))).write(
      DayBlocksCompanion(isArchived: const Value(true), updatedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> unarchiveBlock(String id) async {
    await (_db.update(_db.dayBlocks)..where((b) => b.id.equals(id))).write(
      DayBlocksCompanion(isArchived: const Value(false), updatedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> deleteBlock(String id) async {
    // Check if any tasks reference this block
    final tasks = await (_db.select(_db.dayTasks)..where((t) => t.blockId.equals(id))).get();
    if (tasks.isNotEmpty) {
      throw Exception('Cannot delete block with existing tasks. Archive it instead.');
    }
    await (_db.delete(_db.dayBlocks)..where((b) => b.id.equals(id))).go();
  }

  @override
  Future<void> reorderBlocks(List<String> orderedIds) async {
    for (int i = 0; i < orderedIds.length; i++) {
      await (_db.update(_db.dayBlocks)..where((b) => b.id.equals(orderedIds[i]))).write(
        DayBlocksCompanion(sortOrder: Value(i), updatedAt: Value(DateTime.now())),
      );
    }
  }

  // ─────────────────────────────────────────────
  // Task Operations
  // ─────────────────────────────────────────────

  @override
  Future<void> insertTask(DayTask task) async {
    await _db.into(_db.dayTasks).insert(task);
  }

  @override
  Future<void> updateTask(DayTask task) async {
    await _db.update(_db.dayTasks).replace(task);
  }

  @override
  Future<void> toggleTask(String id) async {
    final task = await (_db.select(_db.dayTasks)..where((t) => t.id.equals(id))).getSingle();
    final nowCompleted = !task.isCompleted;
    await (_db.update(_db.dayTasks)..where((t) => t.id.equals(id))).write(
      DayTasksCompanion(
        isCompleted: Value(nowCompleted),
        completedAt: Value(nowCompleted ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteTask(String id) async {
    await (_db.delete(_db.dayTasks)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> reorderTasks(String blockId, String dateStr, List<String> orderedIds) async {
    for (int i = 0; i < orderedIds.length; i++) {
      await (_db.update(_db.dayTasks)..where((t) => t.id.equals(orderedIds[i]))).write(
        DayTasksCompanion(sortOrder: Value(i), updatedAt: Value(DateTime.now())),
      );
    }
  }
}
