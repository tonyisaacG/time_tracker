import 'package:tracker_time/core/db/database.dart';

abstract class SessionRepository {
  Stream<List<Session>> watchAllSessions();
  Stream<Session?> watchActiveSession();
  Future<Session?> getActiveSession();
  Future<List<Session>> getSessionsForPeriod(DateTime start, DateTime end);
  Future<void> startSession({
    required String id,
    required String activityId,
    required String deviceId,
    String? notes,
    int? targetDurationMinutes,
  });
  Future<void> stopActiveSession({String? notes});
  Future<void> insertManualSession(Session session);
  Future<void> updateSession(Session session);
  Future<void> deleteSession(String id);
}
