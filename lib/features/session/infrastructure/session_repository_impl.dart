import 'package:drift/drift.dart';
import 'package:tracker_time/core/db/database.dart';
import '../domain/session_repository.dart';

class SessionRepositoryImpl implements SessionRepository {
  final AppDatabase _db;

  SessionRepositoryImpl(this._db);

  @override
  Stream<List<Session>> watchAllSessions() {
    return (_db.select(_db.sessions)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.startTime, mode: OrderingMode.desc)]))
        .watch();
  }

  @override
  Stream<Session?> watchActiveSession() {
    return (_db.select(_db.sessions)
          ..where((t) => t.endTime.isNull() & t.isDeleted.equals(false))
          ..limit(1))
        .watchSingleOrNull();
  }

  @override
  Future<Session?> getActiveSession() {
    return (_db.select(_db.sessions)
          ..where((t) => t.endTime.isNull() & t.isDeleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<List<Session>> getSessionsForPeriod(DateTime start, DateTime end) {
    return (_db.select(_db.sessions)
          ..where((t) => t.startTime.isBetweenValues(start, end) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.startTime, mode: OrderingMode.desc)]))
        .get();
  }

  @override
  Future<void> startSession({
    required String id,
    required String activityId,
    required String deviceId,
    String? notes,
    int? targetDurationMinutes,
  }) async {
    await _db.transaction(() async {
      // 1. Enforce rule: "Only one active timer can exist at a time."
      // Auto-stop any existing running session
      final active = await getActiveSession();
      if (active != null) {
        await _stopSessionInternal(active, DateTime.now(), null);
      }

      // 2. Start the new timer
      final now = DateTime.now();
      await _db.into(_db.sessions).insert(
        SessionsCompanion.insert(
          id: id,
          activityId: activityId,
          startTime: now,
          endTime: const Value.absent(),
          durationMinutes: const Value(0),
          targetDurationMinutes: Value(targetDurationMinutes),
          deviceId: deviceId,
          notes: Value(notes),
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  @override
  Future<void> stopActiveSession({String? notes}) async {
    final active = await getActiveSession();
    if (active != null) {
      await _stopSessionInternal(active, DateTime.now(), notes);
    }
  }

  Future<void> _stopSessionInternal(Session session, DateTime endTime, String? finalNotes) async {
    final start = session.startTime;
    final diffSeconds = endTime.difference(start).inSeconds;
    int durationMinutes = (diffSeconds / 60.0).round();
    
    // Enforce positive duration: "Duration must be greater than zero."
    if (durationMinutes <= 0) {
      durationMinutes = 1;
    }

    final notesValue = finalNotes != null ? Value(finalNotes) : Value(session.notes);

    await (_db.update(_db.sessions)..where((t) => t.id.equals(session.id))).write(
      SessionsCompanion(
        endTime: Value(endTime),
        durationMinutes: Value(durationMinutes),
        notes: notesValue,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> insertManualSession(Session session) async {
    if (session.durationMinutes <= 0) {
      throw Exception("Session duration must be greater than zero.");
    }
    await _db.into(_db.sessions).insert(session);
  }

  @override
  Future<void> updateSession(Session session) async {
    if (session.durationMinutes <= 0) {
      throw Exception("Session duration must be greater than zero.");
    }
    await _db.update(_db.sessions).replace(session);
  }

  @override
  Future<void> deleteSession(String id) async {
    // Perform soft delete
    await (_db.update(_db.sessions)..where((t) => t.id.equals(id))).write(
      SessionsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
