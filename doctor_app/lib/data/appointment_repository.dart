import 'package:flutter/foundation.dart';

import '../models/teleconsult_models.dart';

abstract class AppointmentRepository {
  Future<List<Appointment>> getTodaysQueue();
  Future<Appointment> getAppointment(String id);
  Future<void> recordConsent(ConsentRecord record);
  Future<void> saveCallLog(CallLog log);
  Future<void> saveConsultationNote(ConsultationNote note);
  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus status,
  );
}

class MockAppointmentRepository implements AppointmentRepository {
  MockAppointmentRepository()
    : _appointments = <String, Appointment>{
        'apt_001': Appointment(
          id: 'apt_001',
          patientName: 'Asha Devi',
          patientAge: 42,
          chiefComplaint: 'Recurring headache and dizziness',
          scheduledTime: DateTime.now().add(const Duration(minutes: 10)),
          queuePosition: 1,
        ),
        'apt_002': Appointment(
          id: 'apt_002',
          patientName: 'Ramesh Kumar',
          patientAge: 58,
          chiefComplaint: 'Diabetes follow-up',
          scheduledTime: DateTime.now().add(const Duration(minutes: 30)),
          queuePosition: 2,
        ),
      };
  final Map<String, Appointment> _appointments;

  @override
  Future<Appointment> getAppointment(String id) async {
    final appointment = _appointments[id];
    if (appointment == null) throw StateError('Unknown appointment: $id');
    return appointment;
  }

  @override
  Future<List<Appointment>> getTodaysQueue() async =>
      _appointments.values.toList()
        ..sort((a, b) => a.queuePosition.compareTo(b.queuePosition));

  @override
  Future<void> recordConsent(ConsentRecord record) async {
    debugPrint(
      'Mock consent: ${record.appointmentId}, doctor=${record.isDoctor}, at=${record.confirmedAt}',
    );
  }

  @override
  Future<void> saveCallLog(CallLog log) async {
    debugPrint(
      'Mock call log: ${log.appointmentId}, duration=${log.duration}, error=${log.hadError}',
    );
  }

  @override
  Future<void> saveConsultationNote(ConsultationNote note) async {
    debugPrint(
      'Mock consultation saved: ${note.appointmentId}, prescriptions=${note.prescriptionItems.length}',
    );
  }

  @override
  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus status,
  ) async {
    final appointment = await getAppointment(appointmentId);
    appointment.status = status;
    debugPrint('Mock appointment status: $appointmentId -> ${status.name}');
  }
}
