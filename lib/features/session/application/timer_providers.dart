import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/core/utils/device_id.dart';
import '../domain/session_repository.dart';
import '../infrastructure/session_repository_impl.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SessionRepositoryImpl(db);
});

final deviceIdProvider = FutureProvider<String>((ref) async {
  return DeviceIdUtil.getOrCreateDeviceId();
});

final activeSessionProvider = StreamProvider<Session?>((ref) {
  return ref.watch(sessionRepositoryProvider).watchActiveSession();
});

final activeSessionDurationProvider = StreamProvider<Duration>((ref) {
  final activeSession = ref.watch(activeSessionProvider).valueOrNull;
  if (activeSession == null) {
    return Stream.value(Duration.zero);
  }
  return _timerStream(activeSession.startTime, activeSession.targetDurationMinutes);
});

Stream<Duration> _timerStream(DateTime start, int? targetDurationMinutes) async* {
  if (targetDurationMinutes != null) {
    final targetDuration = Duration(minutes: targetDurationMinutes);
    Duration remaining() {
      final elapsed = DateTime.now().difference(start);
      final rem = targetDuration - elapsed;
      return rem.isNegative ? Duration.zero : rem;
    }
    yield remaining();
    yield* Stream.periodic(const Duration(seconds: 1), (_) => remaining());
  } else {
    yield DateTime.now().difference(start);
    yield* Stream.periodic(const Duration(seconds: 1), (_) {
      return DateTime.now().difference(start);
    });
  }
}

class TimerController extends StateNotifier<AsyncValue<void>> {
  final SessionRepository _repository;
  final Ref _ref;

  TimerController(this._repository, this._ref) : super(const AsyncData(null));

  Future<void> startTimer(String activityId, {String? notes, int? targetDurationMinutes}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final deviceId = await _ref.read(deviceIdProvider.future);
      final id = const Uuid().v4();
      await _repository.startSession(
        id: id,
        activityId: activityId,
        deviceId: deviceId,
        notes: notes,
        targetDurationMinutes: targetDurationMinutes,
      );
    });
  }

  Future<void> stopTimer({String? notes}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.stopActiveSession(notes: notes);
    });
  }

  Future<void> updateSession(Session session) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.updateSession(session);
    });
  }
}

final timerControllerProvider = StateNotifierProvider<TimerController, AsyncValue<void>>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return TimerController(repo, ref);
});
