import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/core/services/notification_service.dart';
import '../domain/planner_repository.dart';
import '../infrastructure/planner_repository_impl.dart';

// ── Repository Provider ──────────────────────────────────────────────────────

final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PlannerRepositoryImpl(db);
});

// ── Selected Date ────────────────────────────────────────────────────────────

final plannerSelectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

// ── Blocks + Tasks for Selected Date ─────────────────────────────────────────

String _formatDate(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

final plannerDayProvider = StreamProvider<List<BlockWithTasks>>((ref) {
  final date = ref.watch(plannerSelectedDateProvider);
  final repo = ref.watch(plannerRepositoryProvider);
  return repo.watchBlocksWithTasks(_formatDate(date));
});

// ── All Blocks (for management screen) ───────────────────────────────────────

final allBlocksProvider = StreamProvider<List<DayBlock>>((ref) {
  return ref.watch(plannerRepositoryProvider).watchAllBlocks();
});

// ── Block Controller ──────────────────────────────────────────────────────────

class BlockController extends StateNotifier<AsyncValue<void>> {
  final PlannerRepository _repo;

  BlockController(this._repo) : super(const AsyncData(null));

  Future<void> insertBlock(DayBlock block) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.insertBlock(block));
  }

  Future<void> updateBlock(DayBlock block) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.updateBlock(block));
  }

  Future<void> toggleArchive(DayBlock block) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() =>
        block.isArchived ? _repo.unarchiveBlock(block.id) : _repo.archiveBlock(block.id));
  }

  Future<void> deleteBlock(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.deleteBlock(id));
  }

  Future<void> reorderBlocks(List<String> orderedIds) async {
    state = await AsyncValue.guard(() => _repo.reorderBlocks(orderedIds));
  }
}

final blockControllerProvider =
    StateNotifierProvider<BlockController, AsyncValue<void>>((ref) {
  return BlockController(ref.watch(plannerRepositoryProvider));
});

// ── Task Controller ───────────────────────────────────────────────────────────

class TaskController extends StateNotifier<AsyncValue<void>> {
  final PlannerRepository _repo;
  final NotificationService _notificationService = NotificationService();

  TaskController(this._repo) : super(const AsyncData(null));

  Future<void> insertTask(DayTask task) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.insertTask(task);
      if (task.reminderTime != null && !task.isCompleted) {
        await _notificationService.scheduleTaskReminder(
          id: task.id,
          title: task.title,
          reminderTime: task.reminderTime!,
        );
      }
    });
  }

  Future<void> updateTask(DayTask task) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.updateTask(task);
      if (task.reminderTime != null && !task.isCompleted) {
        await _notificationService.scheduleTaskReminder(
          id: task.id,
          title: task.title,
          reminderTime: task.reminderTime!,
        );
      } else {
        await _notificationService.cancelTaskReminder(task.id);
      }
    });
  }

  Future<void> toggleTask(DayTask task) async {
    state = await AsyncValue.guard(() async {
      await _repo.toggleTask(task.id);
      final nowCompleted = !task.isCompleted;
      if (nowCompleted) {
        await _notificationService.cancelTaskReminder(task.id);
      } else if (task.reminderTime != null && task.reminderTime!.isAfter(DateTime.now())) {
        await _notificationService.scheduleTaskReminder(
          id: task.id,
          title: task.title,
          reminderTime: task.reminderTime!,
        );
      }
    });
  }

  Future<void> deleteTask(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.deleteTask(id);
      await _notificationService.cancelTaskReminder(id);
    });
  }

  Future<void> reorderTasks(String blockId, String dateStr, List<String> ids) async {
    state = await AsyncValue.guard(() => _repo.reorderTasks(blockId, dateStr, ids));
  }
}

final taskControllerProvider =
    StateNotifierProvider<TaskController, AsyncValue<void>>((ref) {
  return TaskController(ref.watch(plannerRepositoryProvider));
});
