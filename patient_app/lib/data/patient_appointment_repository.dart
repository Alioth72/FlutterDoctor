import 'package:flutter/foundation.dart';

import '../models/patient_appointment.dart';
import '../models/patient_call_log.dart';

abstract class PatientAppointmentRepository {
  Future<List<PatientAppointment>> getTodaysAppointments();

  Future<void> saveCallLog(PatientCallLog log);

  Future<void> updateAppointmentStatus(
    String appointmentId,
    PatientAppointmentStatus status,
  );
}

class MockPatientAppointmentRepository implements PatientAppointmentRepository {
  final List<PatientAppointment> _appointments = [
    PatientAppointment(
      id: 'apt_001',
      patientName: 'Ramesh Kumar',
      doctorName: 'Dr. Ananya Sharma',
      doctorSpecialty: 'General Medicine',
      reason: 'Persistent cough, mild fever for 3 days',
      scheduledTime: DateTime.now(),
    ),
  ];

  @override
  Future<List<PatientAppointment>> getTodaysAppointments() async =>
      _appointments;

  @override
  Future<void> saveCallLog(PatientCallLog log) async {
    debugPrint(
      'Patient call log: ${log.appointmentId}, duration: ${log.duration}, '
      'error: ${log.hadError}',
    );
  }

  @override
  Future<void> updateAppointmentStatus(
    String appointmentId,
    PatientAppointmentStatus status,
  ) async {
    final appointment = _appointments.firstWhere(
      (item) => item.id == appointmentId,
    );
    appointment.status = status;
  }
}
