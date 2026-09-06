import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../models/call_log.dart';
import '../models/consent_record.dart';
import '../models/consultation_note.dart';

abstract class AppointmentRepository {
  Future<List<Appointment>> getTodaysQueue();
  Future<void> recordConsent(ConsentRecord record);
  Future<void> saveCallLog(CallLog log);
  Future<void> saveConsultationNote(ConsultationNote note);
  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus status,
  );
}

class MockAppointmentRepository implements AppointmentRepository {
  final List<Appointment> _appointments = [
    Appointment(
      id: 'apt_001',
      patientName: 'Ramesh Kumar',
      patientAge: 45,
      chiefComplaint: 'Persistent cough, mild fever for 3 days',
      scheduledTime: DateTime.now(),
      queuePosition: 1,
    ),
    Appointment(
      id: 'apt_002',
      patientName: 'Sunita Devi',
      patientAge: 32,
      chiefComplaint: 'Follow-up: hypertension check',
      scheduledTime: DateTime.now().add(const Duration(minutes: 15)),
      queuePosition: 2,
    ),
  ];

  @override
  Future<List<Appointment>> getTodaysQueue() async => _appointments;

  @override
  Future<void> recordConsent(ConsentRecord record) async {
    debugPrint(
      'Consent recorded: ${record.appointmentId} at '
      '${record.doctorConfirmedAt}',
    );
  }

  @override
  Future<void> saveCallLog(CallLog log) async {
    debugPrint(
      'Call log: ${log.appointmentId}, duration: ${log.duration}, '
      'error: ${log.hadError}',
    );
  }

  @override
  Future<void> saveConsultationNote(ConsultationNote note) async {
    debugPrint('Note saved for ${note.appointmentId}: ${note.notes}');
  }

  @override
  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus status,
  ) async {
    final appointment = _appointments.firstWhere(
      (item) => item.id == appointmentId,
    );
    appointment.status = status;
  }
}
