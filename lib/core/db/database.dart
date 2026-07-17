import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:drift/drift.dart' show Value;
export 'package:drift/drift.dart' show Constant;

part 'database.g.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().customConstraint('UNIQUE NOT NULL')();
  IntColumn get color => integer()();
  TextColumn get icon => text()();
  IntColumn get weeklyGoalMinutes => integer().nullable()();
  BoolColumn get isLimit => boolean().withDefault(const Constant(false))();
  BoolColumn get enforceLimit => boolean().withDefault(const Constant(false))();
  BoolColumn get isWeeklyFocus => boolean().withDefault(const Constant(true))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get activityId => text().references(Activities, #id)();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(0))();
  IntColumn get targetDurationMinutes => integer().nullable()();
  TextColumn get deviceId => text()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Appointments extends Table {
  TextColumn get id => text()();
  TextColumn get activityId => text().nullable().references(Activities, #id)();
  TextColumn get title => text()();
  DateTimeColumn get startTime => dateTime()();
  IntColumn get durationMinutes => integer()();
  TextColumn get recurrenceType => text()(); // 'once', 'weekly', 'monthly'
  TextColumn get recurrenceDays => text().nullable()(); // JSON list e.g. '[1, 4]'
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Activities, Sessions, Appointments])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        // Enforce foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(activities, activities.isLimit);
          await m.addColumn(activities, activities.enforceLimit);
        }
        if (from < 3) {
          await m.addColumn(sessions, sessions.targetDurationMinutes);
        }
        if (from < 4) {
          await m.addColumn(activities, activities.isWeeklyFocus);
        }
        if (from < 5) {
          await m.createTable(appointments);
        }
        if (from < 6) {
          await customStatement('ALTER TABLE appointments RENAME TO appointments_old');
          await m.createTable(appointments);
          await customStatement(
            'INSERT INTO appointments (id, activity_id, title, start_time, duration_minutes, recurrence_type, recurrence_days, is_enabled, created_at, updated_at) '
            'SELECT id, activity_id, title, start_time, duration_minutes, recurrence_type, recurrence_days, is_enabled, created_at, updated_at FROM appointments_old'
          );
          await customStatement('DROP TABLE appointments_old');
        }
        if (from < 7) {
          await m.addColumn(appointments, appointments.isArchived);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'tracker_time.db'));
    return NativeDatabase.createInBackground(file);
  });
}
