import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:uuid/uuid.dart';
import 'package:tracker_time/core/utils/device_id.dart';
import '../domain/session_repository.dart';
import 'timer_providers.dart';

final allSessionsProvider = StreamProvider<List<Session>>((ref) {
  return ref.watch(sessionRepositoryProvider).watchAllSessions();
});

class SessionController extends StateNotifier<AsyncValue<void>> {
  final SessionRepository _repository;
  final Ref _ref;

  SessionController(this._repository, this._ref) : super(const AsyncData(null));

  Future<void> createManualSession({
    required String activityId,
    required DateTime startTime,
    required int durationMinutes,
    String? notes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final deviceId = await _ref.read(deviceIdProvider.future);
      final now = DateTime.now();
      final session = Session(
        id: const Uuid().v4(),
        activityId: activityId,
        startTime: startTime,
        endTime: startTime.add(Duration(minutes: durationMinutes)),
        durationMinutes: durationMinutes,
        deviceId: deviceId,
        notes: notes,
        isDeleted: false,
        createdAt: now,
        updatedAt: now,
      );
      await _repository.insertManualSession(session);
    });
  }

  Future<void> updateSession(Session session) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.updateSession(session.copyWith(updatedAt: DateTime.now()));
    });
  }

  Future<void> deleteSession(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteSession(id);
    });
  }
}

final sessionControllerProvider = StateNotifierProvider<SessionController, AsyncValue<void>>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return SessionController(repo, ref);
});
