import 'package:drift/drift.dart';
import 'package:tracker_time/core/db/database.dart';
import '../domain/activity_repository.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  final AppDatabase _db;

  ActivityRepositoryImpl(this._db);

  @override
  Stream<List<Activity>> watchAllActivities() {
    return (_db.select(_db.activities)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  @override
  Stream<List<Activity>> watchActiveActivities() {
    return (_db.select(_db.activities)
          ..where((t) => t.isDeleted.equals(false) & t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  @override
  Future<Activity?> getActivityById(String id) {
    return (_db.select(_db.activities)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  @override
  Future<void> insertActivity(Activity activity) {
    return _db.into(_db.activities).insert(activity);
  }

  @override
  Future<void> updateActivity(Activity activity) {
    return _db.update(_db.activities).replace(activity);
  }

  @override
  Future<void> archiveActivity(String id, bool archive) {
    return (_db.update(_db.activities)..where((t) => t.id.equals(id))).write(
      ActivitiesCompanion(
        isArchived: Value(archive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<bool> hasSessions(String id) async {
    final query = _db.select(_db.sessions)
      ..where((t) => t.activityId.equals(id) & t.isDeleted.equals(false))
      ..limit(1);
    final results = await query.get();
    return results.isNotEmpty;
  }

  @override
  Future<bool> deleteActivity(String id) async {
    // Rule: Activity cannot be deleted if sessions exist.
    final hasExistingSessions = await hasSessions(id);
    if (hasExistingSessions) {
      throw Exception("Cannot delete activity because it has associated tracked sessions. Try archiving it instead.");
    }
    
    // Perform soft delete
    final count = await (_db.update(_db.activities)..where((t) => t.id.equals(id))).write(
      ActivitiesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return count > 0;
  }
}
