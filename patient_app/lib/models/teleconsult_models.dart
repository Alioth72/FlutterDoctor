enum AppointmentStatus { waiting, inCall, completed, missed }

class Appointment {
  Appointment({
    required this.id,
    required this.patientName,
    required this.patientAge,
    required this.chiefComplaint,
    required this.scheduledTime,
    required this.queuePosition,
    this.status = AppointmentStatus.waiting,
  });

  final String id;
  final String patientName;
  final int patientAge;
  final String chiefComplaint;
  final DateTime scheduledTime;
  final int queuePosition;
  AppointmentStatus status;
}

class ConsentRecord {
  ConsentRecord({
    required this.appointmentId,
    required this.confirmedAt,
    required this.isDoctor,
  });

  final String appointmentId;
  final DateTime confirmedAt;
  final bool isDoctor;
}

class CallLog {
  CallLog({required this.appointmentId, this.hadError = false});

  final String appointmentId;
  DateTime? startedAt;
  DateTime? endedAt;
  bool hadError;

  Duration? get duration => startedAt != null && endedAt != null
      ? endedAt!.difference(startedAt!)
      : null;
}

class BpmSample {
  BpmSample({
    required this.timestamp,
    required this.bpm,
    required this.confidence,
  });

  final DateTime timestamp;
  final double bpm;
  final double confidence;
}

class PrescriptionItem {
  PrescriptionItem({this.drugName = '', this.dosage = '', this.duration = ''});

  String drugName;
  String dosage;
  String duration;
}

class ConsultationNote {
  ConsultationNote({
    required this.appointmentId,
    this.notes = '',
    List<PrescriptionItem>? prescriptionItems,
    this.referralNeeded = false,
    this.referralReason,
    this.referralFacility,
    this.avgBpm,
    this.minBpm,
    this.maxBpm,
    this.bpmSampleCount,
  }) : prescriptionItems = prescriptionItems ?? <PrescriptionItem>[];

  final String appointmentId;
  String notes;
  List<PrescriptionItem> prescriptionItems;
  bool referralNeeded;
  String? referralReason;
  String? referralFacility;
  double? avgBpm;
  double? minBpm;
  double? maxBpm;
  int? bpmSampleCount;
}
