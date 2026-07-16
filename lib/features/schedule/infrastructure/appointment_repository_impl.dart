import 'package:drift/drift.dart';
import 'package:tracker_time/core/db/database.dart';
import '../domain/appointment_repository.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  final AppDatabase _db;

  AppointmentRepositoryImpl(this._db);

  @override
  Stream<List<Appointment>> watchAllAppointments() {
    return (_db.select(_db.appointments)
          ..orderBy([(t) => OrderingTerm(expression: t.startTime)]))
        .watch();
  }

  @override
  Future<List<Appointment>> getAllAppointments() {
    return (_db.select(_db.appointments)
          ..orderBy([(t) => OrderingTerm(expression: t.startTime)]))
        .get();
  }

  @override
  Future<Appointment?> getAppointmentById(String id) {
    return (_db.select(_db.appointments)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<void> insertAppointment(Appointment appointment) {
    return _db.into(_db.appointments).insert(appointment);
  }

  @override
  Future<void> updateAppointment(Appointment appointment) {
    return _db.update(_db.appointments).replace(appointment);
  }

  @override
  Future<void> deleteAppointment(String id) {
    return (_db.delete(_db.appointments)..where((t) => t.id.equals(id))).go();
  }
}
