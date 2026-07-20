import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/core/services/notification_service.dart';
import '../domain/appointment_repository.dart';
import '../infrastructure/appointment_repository_impl.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AppointmentRepositoryImpl(db);
});

final allAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  return ref.watch(appointmentRepositoryProvider).watchAllAppointments();
});

final activeAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  return ref.watch(appointmentRepositoryProvider).watchActiveAppointments();
});

final archivedAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  return ref.watch(appointmentRepositoryProvider).watchArchivedAppointments();
});

class AppointmentController extends StateNotifier<AsyncValue<void>> {
  final AppointmentRepository _repository;
  final NotificationService _notificationService = NotificationService();

  AppointmentController(this._repository) : super(const AsyncData(null));

  Future<void> createAppointment({
    required String title,
    String? notes,
    String? activityId,
    required DateTime startTime,
    required int durationMinutes,
    required String recurrenceType,
    required List<int> recurrenceDays,
    bool isEnabled = true,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      final id = const Uuid().v4();
      final appt = Appointment(
        id: id,
        activityId: activityId,
        title: title,
        notes: notes,
        startTime: startTime,
        durationMinutes: durationMinutes,
        recurrenceType: recurrenceType,
        recurrenceDays: recurrenceDays.isNotEmpty ? jsonEncode(recurrenceDays) : null,
        isEnabled: isEnabled,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.insertAppointment(appt);

      if (isEnabled) {
        await _notificationService.scheduleAppointment(
          id: id,
          title: title,
          body: 'Scheduled session starts now!',
          startTime: startTime,
          recurrenceType: recurrenceType,
          recurrenceDays: recurrenceDays,
        );
      }
    });
  }

  Future<void> updateAppointment(Appointment appt) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final updated = appt.copyWith(updatedAt: DateTime.now());
      await _repository.updateAppointment(updated);

      if (updated.isEnabled && !updated.isArchived) {
        final List<int> days = updated.recurrenceDays != null
            ? List<int>.from(jsonDecode(updated.recurrenceDays!))
            : [];
        await _notificationService.scheduleAppointment(
          id: updated.id,
          title: updated.title,
          body: 'Scheduled session starts now!',
          startTime: updated.startTime,
          recurrenceType: updated.recurrenceType,
          recurrenceDays: days,
        );
      } else {
        await _notificationService.cancelNotification(updated.id);
      }
    });
  }

  Future<void> toggleEnabled(Appointment appt, bool enabled) async {
    await updateAppointment(appt.copyWith(isEnabled: enabled));
  }

  Future<void> toggleArchived(Appointment appt, bool archived) async {
    await updateAppointment(appt.copyWith(isArchived: archived));
  }

  Future<void> deleteAppointment(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteAppointment(id);
      await _notificationService.cancelNotification(id);
    });
  }
}

final appointmentControllerProvider = StateNotifierProvider<AppointmentController, AsyncValue<void>>((ref) {
  final repo = ref.watch(appointmentRepositoryProvider);
  return AppointmentController(repo);
});
