import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tracker_time/core/db/database.dart';
import '../domain/activity_repository.dart';
import '../infrastructure/activity_repository_impl.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ActivityRepositoryImpl(db);
});

final activeActivitiesProvider = StreamProvider<List<Activity>>((ref) {
  return ref.watch(activityRepositoryProvider).watchActiveActivities();
});

final allActivitiesProvider = StreamProvider<List<Activity>>((ref) {
  return ref.watch(activityRepositoryProvider).watchAllActivities();
});
class ActivityController extends StateNotifier<AsyncValue<void>> {
  final ActivityRepository _repository;

  ActivityController(this._repository) : super(const AsyncData(null));

  Future<void> createActivity({
    required String name,
    required int color,
    required String icon,
    int? weeklyGoalMinutes,
    bool isLimit = false,
    bool enforceLimit = false,
    bool isWeeklyFocus = true,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      final activity = Activity(
        id: const Uuid().v4(),
        name: name,
        color: color,
        icon: icon,
        weeklyGoalMinutes: weeklyGoalMinutes,
        isLimit: isLimit,
        enforceLimit: enforceLimit,
        isWeeklyFocus: isWeeklyFocus,
        isArchived: false,
        isDeleted: false,
        createdAt: now,
        updatedAt: now,
      );
      await _repository.insertActivity(activity);
    });
  }

  Future<void> updateActivity(Activity activity) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.updateActivity(activity.copyWith(updatedAt: DateTime.now()));
    });
  }

  Future<void> archiveActivity(String id, bool archive) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.archiveActivity(id, archive);
    });
  }

  Future<void> deleteActivity(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteActivity(id);
    });
  }
}

final activityControllerProvider = StateNotifierProvider<ActivityController, AsyncValue<void>>((ref) {
  final repo = ref.watch(activityRepositoryProvider);
  return ActivityController(repo);
});
