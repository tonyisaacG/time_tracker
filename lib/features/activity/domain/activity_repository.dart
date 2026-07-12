import 'package:tracker_time/core/db/database.dart';

abstract class ActivityRepository {
  Stream<List<Activity>> watchAllActivities();
  Stream<List<Activity>> watchActiveActivities();
  Future<Activity?> getActivityById(String id);
  Future<void> insertActivity(Activity activity);
  Future<void> updateActivity(Activity activity);
  Future<void> archiveActivity(String id, bool archive);
  Future<bool> deleteActivity(String id);
  Future<bool> hasSessions(String id);
}
