import 'package:tracker_time/core/db/database.dart';

abstract class AppointmentRepository {
  Stream<List<Appointment>> watchAllAppointments();
  Future<List<Appointment>> getAllAppointments();
  Future<Appointment?> getAppointmentById(String id);
  Future<void> insertAppointment(Appointment appointment);
  Future<void> updateAppointment(Appointment appointment);
  Future<void> deleteAppointment(String id);
}
