import 'package:flutter/foundation.dart';

import '../../models/appointment_model.dart';
import '../../services/api_client.dart';
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

/// Adapts the full doctor application's appointment and Azure API to the
/// standalone teleconsult screens.
class DoctorAppointmentRepository implements AppointmentRepository {
  DoctorAppointmentRepository(this.source)
    : appointment = Appointment(
        id: source.id,
        patientName: source.patientName,
        patientAge: source.age,
        chiefComplaint: source.diagnosis.trim().isNotEmpty
            ? source.diagnosis
            : source.patientHistory.isNotEmpty
            ? source.patientHistory.first
            : 'General consultation',
        scheduledTime: DateTime.now(),
        queuePosition: 1,
        status: _fromApiStatus(source.status),
      );

  final AppointmentItem source;
  final Appointment appointment;

  static AppointmentStatus _fromApiStatus(String value) {
    return switch (value.toLowerCase()) {
      'in_progress' => AppointmentStatus.inCall,
      'completed' => AppointmentStatus.completed,
      'no_show' => AppointmentStatus.missed,
      _ => AppointmentStatus.waiting,
    };
  }

  static String _toApiStatus(AppointmentStatus value) {
    return switch (value) {
      AppointmentStatus.waiting => 'confirmed',
      AppointmentStatus.inCall => 'in_progress',
      AppointmentStatus.completed => 'completed',
      AppointmentStatus.missed => 'no_show',
    };
  }

  Future<void> _update({
    String? status,
    Map<String, dynamic>? notes,
    List<Map<String, dynamic>>? prescriptions,
  }) async {
    final result = await ApiClient.updateAppointment(
      appointmentId: source.id,
      status: status,
      notes: notes,
      prescriptions: prescriptions,
    );
    if (result['success'] != true) {
      debugPrint('Teleconsult API sync deferred: ${result['error']}');
    }
  }

  @override
  Future<Appointment> getAppointment(String id) async {
    if (id != appointment.id) throw StateError('Unknown appointment: $id');
    return appointment;
  }

  @override
  Future<List<Appointment>> getTodaysQueue() async => <Appointment>[
    appointment,
  ];

  @override
  Future<void> recordConsent(ConsentRecord record) => _update(
    notes: <String, dynamic>{
      'teleconsult_doctor_consent_at': record.confirmedAt.toIso8601String(),
    },
  );

  @override
  Future<void> saveCallLog(CallLog log) => _update(
    notes: <String, dynamic>{
      'teleconsult_call': <String, dynamic>{
        'started_at': log.startedAt?.toIso8601String(),
        'ended_at': log.endedAt?.toIso8601String(),
        'duration_seconds': log.duration?.inSeconds,
        'had_error': log.hadError,
      },
    },
  );

  @override
  Future<void> saveConsultationNote(ConsultationNote note) => _update(
    notes: <String, dynamic>{
      'teleconsultation': <String, dynamic>{
        'clinical_notes': note.notes,
        'referral_needed': note.referralNeeded,
        'referral_reason': note.referralReason,
        'referral_facility': note.referralFacility,
        'bpm_summary': <String, dynamic>{
          'average': note.avgBpm,
          'minimum': note.minBpm,
          'maximum': note.maxBpm,
          'sample_count': note.bpmSampleCount,
          'screening_estimate_only': true,
        },
      },
    },
    prescriptions: note.prescriptionItems
        .map(
          (item) => <String, dynamic>{
            'medication_name': item.drugName,
            'dosage': item.dosage,
            'duration': item.duration,
          },
        )
        .toList(growable: false),
  );

  @override
  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus status,
  ) async {
    if (appointmentId != appointment.id) {
      throw StateError('Unknown appointment: $appointmentId');
    }
    appointment.status = status;
    source.status = _toApiStatus(status);
    source.isCompleted = status == AppointmentStatus.completed;
    await _update(status: source.status);
  }
}
