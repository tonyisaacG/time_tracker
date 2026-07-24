import 'dart:io';
import 'package:flutter/material.dart' show Color;
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
  TextColumn get notes => text().nullable()();
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

class DayBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('tasks_todo'))();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class DayTasks extends Table {
  TextColumn get id => text()();
  TextColumn get blockId => text().references(DayBlocks, #id)();
  TextColumn get activityId => text().nullable().references(Activities, #id)();
  TextColumn get date => text()(); // 'YYYY-MM-DD'
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get recurrenceType => text().withDefault(const Constant('once'))();
  TextColumn get recurrenceDays => text().nullable()();
  IntColumn get estimatedMinutes => integer().withDefault(const Constant(30))();
  DateTimeColumn get reminderTime => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}


@DriftDatabase(tables: [Activities, Sessions, Appointments, DayBlocks, DayTasks])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        // Enforce foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
        // Self-healing: Fix any corrupted string timestamps from previous v8 migration attempt
        try {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          await customStatement("UPDATE day_blocks SET created_at = $nowMs WHERE typeof(created_at) = 'text'");
          await customStatement("UPDATE day_blocks SET updated_at = $nowMs WHERE typeof(updated_at) = 'text'");
          await customStatement("UPDATE day_tasks SET created_at = $nowMs WHERE typeof(created_at) = 'text'");
          await customStatement("UPDATE day_tasks SET updated_at = $nowMs WHERE typeof(updated_at) = 'text'");
        } catch (_) {}
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
        if (from < 8) {
          await m.createTable(dayBlocks);
          await m.createTable(dayTasks);
          // Seed 3 default day blocks (Drift stores DateTime as ms since epoch)
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          await customStatement(
            "INSERT OR IGNORE INTO day_blocks (id, name, icon, color, sort_order, is_archived, created_at, updated_at) VALUES "
            "('block-morning', 'الصباح', 'sunrise', ${const Color(0xfff59e0b).value}, 0, 0, $nowMs, $nowMs), "
            "('block-work',    'وقت العمل', 'work', ${const Color(0xff3b82f6).value}, 1, 0, $nowMs, $nowMs), "
            "('block-evening', 'المساء',   'sleep_relax', ${const Color(0xff8b5cf6).value}, 2, 0, $nowMs, $nowMs)"
          );
        }
        if (from < 9) {
          await m.addColumn(dayTasks, dayTasks.reminderTime);
        }
        if (from < 10) {
          await m.addColumn(appointments, appointments.notes);
          await m.addColumn(dayTasks, dayTasks.notes);
        }
        if (from < 11) {
          await m.addColumn(dayTasks, dayTasks.recurrenceType);
          await m.addColumn(dayTasks, dayTasks.recurrenceDays);
          await m.addColumn(dayTasks, dayTasks.estimatedMinutes);
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
