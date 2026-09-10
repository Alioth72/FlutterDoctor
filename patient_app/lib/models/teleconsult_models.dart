enum TeleconsultStatus { waiting, inCall, completed, missed }

class ConsentRecord {
  const ConsentRecord({
    required this.appointmentId,
    required this.confirmedAt,
    required this.isDoctor,
  });

  final String appointmentId;
  final DateTime confirmedAt;
  final bool isDoctor;

  Map<String, dynamic> toJson() => {
        'appointmentId': appointmentId,
        'confirmedAt': confirmedAt.toIso8601String(),
        'isDoctor': isDoctor,
      };

  factory ConsentRecord.fromJson(Map<String, dynamic> json) => ConsentRecord(
        appointmentId: json['appointmentId'] as String,
        confirmedAt: DateTime.parse(json['confirmedAt'] as String),
        isDoctor: json['isDoctor'] as bool? ?? false,
      );
}

class CallLog {
  CallLog({
    required this.appointmentId,
    this.startedAt,
    this.endedAt,
    this.hadError = false,
    this.errorMessage,
    this.avgBpm,
    this.bpmSampleCount = 0,
  });

  final String appointmentId;
  DateTime? startedAt;
  DateTime? endedAt;
  bool hadError;
  String? errorMessage;
  double? avgBpm;
  int bpmSampleCount;

  Duration? get duration => startedAt != null && endedAt != null
      ? endedAt!.difference(startedAt!)
      : null;

  Map<String, dynamic> toJson() => {
        'appointmentId': appointmentId,
        'startedAt': startedAt?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'durationSeconds': duration?.inSeconds,
        'hadError': hadError,
        'errorMessage': errorMessage,
        'avgBpm': avgBpm,
        'bpmSampleCount': bpmSampleCount,
      };
}

class BpmSample {
  const BpmSample({
    required this.timestamp,
    required this.bpm,
    required this.confidence,
  });

  final DateTime timestamp;
  final double bpm;
  final double confidence;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'bpm': bpm,
        'confidence': confidence,
      };
}

class PrescriptionItem {
  PrescriptionItem({
    this.drugName = '',
    this.dosage = '',
    this.duration = '',
  });

  String drugName;
  String dosage;
  String duration;

  Map<String, dynamic> toJson() => {
        'drugName': drugName,
        'dosage': dosage,
        'duration': duration,
      };
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

  Map<String, dynamic> toJson() => {
        'appointmentId': appointmentId,
        'notes': notes,
        'prescriptionItems': prescriptionItems.map((e) => e.toJson()).toList(),
        'referralNeeded': referralNeeded,
        'referralReason': referralReason,
        'referralFacility': referralFacility,
        'avgBpm': avgBpm,
        'minBpm': minBpm,
        'maxBpm': maxBpm,
        'bpmSampleCount': bpmSampleCount,
      };
}
