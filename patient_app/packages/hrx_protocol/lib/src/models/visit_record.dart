class DiagnosisItem {
  final String code;
  final String name;

  DiagnosisItem({required this.code, required this.name});

  factory DiagnosisItem.fromJson(Map<String, dynamic> json) {
    return DiagnosisItem(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
  };
}

class MedicationItem {
  final String name;
  final String strength;
  final String dose;
  final String frequency;
  final String duration;
  final String durationUnit;
  final String instructions;

  MedicationItem({
    required this.name,
    this.strength = '',
    this.dose = '',
    this.frequency = '',
    this.duration = '',
    this.durationUnit = '',
    this.instructions = '',
  });

  factory MedicationItem.fromJson(Map<String, dynamic> json) {
    return MedicationItem(
      name: json['name'] ?? '',
      strength: json['strength'] ?? '',
      dose: json['dose'] ?? '',
      frequency: json['frequency'] ?? '',
      duration: json['duration']?.toString() ?? '',
      durationUnit: json['duration_unit'] ?? json['durationUnit'] ?? '',
      instructions: json['instructions'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'strength': strength,
    'dose': dose,
    'frequency': frequency,
    'duration': duration,
    'duration_unit': durationUnit,
    'instructions': instructions,
  };
}

class FollowUpInfo {
  final bool required;
  final String date;

  FollowUpInfo({required this.required, required this.date});

  factory FollowUpInfo.fromJson(Map<String, dynamic> json) {
    return FollowUpInfo(
      required: json['required'] == true,
      date: json['date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'required': required,
    'date': date,
  };
}

class VisitRecord {
  final String visitId;
  final String patientRef;
  final String doctorName;
  final String facilityName;
  final String timestamp;
  final List<String> chiefComplaints;
  final List<String> symptoms;
  final List<DiagnosisItem> diagnosis;
  final Map<String, dynamic> vitals;
  final List<MedicationItem> medications;
  final List<dynamic> labTests;
  final List<String> allergies;
  final List<String> advice;
  final FollowUpInfo followUp;
  final String notes;

  VisitRecord({
    required this.visitId,
    required this.patientRef,
    required this.doctorName,
    required this.facilityName,
    required this.timestamp,
    required this.chiefComplaints,
    required this.symptoms,
    required this.diagnosis,
    required this.vitals,
    required this.medications,
    required this.labTests,
    this.allergies = const [],
    required this.advice,
    required this.followUp,
    required this.notes,
  });

  factory VisitRecord.fromJson(Map<String, dynamic> json) {
    return VisitRecord(
      visitId: json['visit_id'] ?? json['visitId'] ?? '',
      patientRef: json['patient_ref'] ?? json['patientRef'] ?? '',
      doctorName: json['doctor_name'] ?? json['doctorName'] ?? '',
      facilityName: json['facility_name'] ?? json['facilityName'] ?? json['facility_ref'] ?? '',
      timestamp: json['timestamp'] ?? json['date'] ?? '',
      chiefComplaints: List<String>.from(json['chief_complaints'] ?? json['chiefComplaints'] ?? []),
      symptoms: List<String>.from(json['symptoms'] ?? []),
      diagnosis: (json['diagnosis'] as List? ?? []).map((d) {
        if (d is Map<String, dynamic>) {
          return DiagnosisItem.fromJson(d);
        } else {
          return DiagnosisItem(code: '', name: d.toString());
        }
      }).toList(),
      vitals: Map<String, dynamic>.from(json['vitals'] ?? {}),
      medications: (json['medications'] as List? ?? []).map((m) {
        if (m is Map<String, dynamic>) {
          return MedicationItem.fromJson(m);
        } else {
          return MedicationItem(name: m.toString());
        }
      }).toList(),
      labTests: List<dynamic>.from(json['lab_tests'] ?? json['labTests'] ?? []),
      allergies: List<String>.from(json['allergies'] ?? []),
      advice: List<String>.from(json['advice'] ?? []),
      followUp: json['follow_up'] is Map<String, dynamic>
          ? FollowUpInfo.fromJson(json['follow_up'])
          : json['followUp'] is Map<String, dynamic>
              ? FollowUpInfo.fromJson(json['followUp'])
              : FollowUpInfo(required: false, date: ''),
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'visit_id': visitId,
    'patient_ref': patientRef,
    'doctor_name': doctorName,
    'facility_name': facilityName,
    'timestamp': timestamp,
    'chief_complaints': chiefComplaints,
    'symptoms': symptoms,
    'diagnosis': diagnosis.map((d) => d.toJson()).toList(),
    'vitals': vitals,
    'medications': medications.map((m) => m.toJson()).toList(),
    'lab_tests': labTests,
    'allergies': allergies,
    'advice': advice,
    'follow_up': followUp.toJson(),
    'notes': notes,
  };
}
