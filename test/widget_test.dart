import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/features/activity/infrastructure/activity_repository_impl.dart';
import 'package:tracker_time/features/session/infrastructure/session_repository_impl.dart';

void main() {
  late AppDatabase db;
  late ActivityRepositoryImpl activityRepo;
  late SessionRepositoryImpl sessionRepo;

  setUp(() {
    // Open in-memory SQLite database for test isolation
    db = AppDatabase(NativeDatabase.memory());
    activityRepo = ActivityRepositoryImpl(db);
    sessionRepo = SessionRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Create Activity & uniqueness verification', () async {
    final now = DateTime.now();
    final act1 = Activity(
      id: 'act-1',
      name: 'English Learning',
      color: 0xff8b5cf6,
      icon: 'book',
      weeklyGoalMinutes: 300,
      isLimit: false,
      enforceLimit: false,
      isWeeklyFocus: true,
      isArchived: false,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );

    // Insert successful
    await activityRepo.insertActivity(act1);
    
    final fetched = await activityRepo.getActivityById('act-1');
    expect(fetched, isNotNull);
    expect(fetched!.name, equals('English Learning'));

    // Inserting activity with same name should trigger unique constraint exception
    final act2 = Activity(
      id: 'act-2',
      name: 'English Learning', // Duplicate name!
      color: 0xff10b981,
      icon: 'code',
      weeklyGoalMinutes: 120,
      isLimit: false,
      enforceLimit: false,
      isWeeklyFocus: true,
      isArchived: false,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );

    expect(
      () => activityRepo.insertActivity(act2),
      throwsException,
    );
  });

  test('Prevent deletion of activity if sessions exist', () async {
    final now = DateTime.now();
    
    // Create activity
    final act = Activity(
      id: 'act-code',
      name: 'Coding',
      color: 0xff06b6d4,
      icon: 'code',
      weeklyGoalMinutes: 600,
      isLimit: false,
      enforceLimit: false,
      isWeeklyFocus: true,
      isArchived: false,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );
    await activityRepo.insertActivity(act);

    // Log a session for this activity
    final session = Session(
      id: 'sess-1',
      activityId: 'act-code',
      startTime: now.subtract(const Duration(minutes: 60)),
      endTime: now,
      durationMinutes: 60,
      deviceId: 'device-test',
      notes: 'Worked on database tests',
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );
    await sessionRepo.insertManualSession(session);

    // Try deleting activity (should fail with exception since sessions exist)
    expect(
      () => activityRepo.deleteActivity('act-code'),
      throwsA(isA<Exception>()),
    );
  });

  test('Auto-stop previous active timer', () async {
    final now = DateTime.now();
    
    // Create activities
    final act1 = Activity(
      id: 'act-1',
      name: 'English',
      color: 0xff8b5cf6,
      icon: 'book',
      isLimit: false,
      enforceLimit: false,
      isWeeklyFocus: true,
      isArchived: false,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );
    final act2 = Activity(
      id: 'act-2',
      name: 'Coding',
      color: 0xff06b6d4,
      icon: 'code',
      isLimit: false,
      enforceLimit: false,
      isWeeklyFocus: true,
      isArchived: false,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );
    await activityRepo.insertActivity(act1);
    await activityRepo.insertActivity(act2);

    // 1. Start Session 1 (English)
    await sessionRepo.startSession(
      id: 'sess-english',
      activityId: 'act-1',
      deviceId: 'device-test',
      notes: 'Studying vocabulary',
    );

    var active = await sessionRepo.getActiveSession();
    expect(active, isNotNull);
    expect(active!.id, equals('sess-english'));
    expect(active.endTime, isNull);

    // Simulate passage of time by updating start time of first session in DB
    // to verify duration math when stopped.
    final fakeStart = DateTime.now().subtract(const Duration(minutes: 45));
    await (db.update(db.sessions)..where((t) => t.id.equals('sess-english'))).write(
      SessionsCompanion(startTime: Value(fakeStart)),
    );

    // 2. Start Session 2 (Coding) - this should automatically stop Session 1
    await sessionRepo.startSession(
      id: 'sess-coding',
      activityId: 'act-2',
      deviceId: 'device-test',
      notes: 'Refactoring Drift layers',
    );

    // Session 2 is now active
    active = await sessionRepo.getActiveSession();
    expect(active, isNotNull);
    expect(active!.id, equals('sess-coding'));

    // Session 1 should be stopped and duration calculated (should be around 45 mins)
    final stoppedSession1 = await (db.select(db.sessions)..where((t) => t.id.equals('sess-english'))).getSingle();
    expect(stoppedSession1.endTime, isNotNull);
    expect(stoppedSession1.durationMinutes, equals(45));
  });
}
