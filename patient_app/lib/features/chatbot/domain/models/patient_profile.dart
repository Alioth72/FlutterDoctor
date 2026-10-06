/// Represents a single active or past prescription for a patient.
class PatientPrescription {
  final String medicine;
  final String dosage;
  final String frequency;
  final String duration;
  final String status;

  const PatientPrescription({
    required this.medicine,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.status = 'active',
  });

  factory PatientPrescription.fromJson(Map<String, dynamic> json) {
    return PatientPrescription(
      medicine: json['medicine']?.toString() ?? '',
      dosage: json['dosage']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine': medicine,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'status': status,
    };
  }

  @override
  String toString() =>
      '$medicine — Dosage: $dosage, Frequency: $frequency, Duration: $duration ($status)';
}

/// Models the complete patient clinical record (EHR) matching the hospital database schema.
class PatientProfile {
  final String patientId;
  final String? userId;
  final String? medicalRecordNumber;
  final String name;
  final String bloodGroup;
  final List<String> allergies;
  final String? emergencyContact;
  final String? activeAppointment;
  final String? doctorName;
  final String? room;
  final String? appointmentStatus;
  final String? diagnosis;
  final String? vitals;
  final String? biometrics;
  final String? familyHistory;
  final List<PatientPrescription> prescriptions;

  const PatientProfile({
    required this.patientId,
    this.userId,
    this.medicalRecordNumber,
    required this.name,
    required this.bloodGroup,
    this.allergies = const [],
    this.emergencyContact,
    this.activeAppointment,
    this.doctorName,
    this.room,
    this.appointmentStatus,
    this.diagnosis,
    this.vitals,
    this.biometrics,
    this.familyHistory,
    this.prescriptions = const [],
  });

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    List<String> parsedAllergies = [];
    if (json['allergies'] is List) {
      parsedAllergies = (json['allergies'] as List).map((e) => e.toString()).toList();
    } else if (json['allergies'] is String && json['allergies'].toString().isNotEmpty) {
      parsedAllergies = [json['allergies'].toString()];
    }

    List<PatientPrescription> parsedPrescriptions = [];
    if (json['prescriptions'] is List) {
      parsedPrescriptions = (json['prescriptions'] as List).map((item) {
        if (item is Map<String, dynamic>) {
          return PatientPrescription.fromJson(item);
        } else if (item is String) {
          return PatientPrescription(
            medicine: item,
            dosage: '',
            frequency: '',
            duration: '',
          );
        }
        return PatientPrescription.fromJson({});
      }).toList();
    }

    String? doctor;
    String? wardRoom;
    String? status;
    String? apptText;

    if (json['active_appointment'] is Map<String, dynamic>) {
      final apptMap = json['active_appointment'] as Map<String, dynamic>;
      doctor = apptMap['doctor_name']?.toString();
      wardRoom = apptMap['room']?.toString();
      status = apptMap['status']?.toString();
      apptText = 'In-Clinic with $doctor | Status: $status | Room: $wardRoom';
    } else if (json['active_appointment'] is String) {
      apptText = json['active_appointment'].toString();
      doctor = json['doctor_name']?.toString();
      wardRoom = json['room']?.toString();
      status = json['appointment_status']?.toString();
    }

    String? vitalsSummary;
    if (json['vitals'] is Map<String, dynamic>) {
      final v = json['vitals'] as Map<String, dynamic>;
      vitalsSummary = 'BP: ${v['bp'] ?? 'N/A'} | SpO2: ${v['spo2'] ?? 'N/A'} | Temp: ${v['temp'] ?? 'N/A'} | Pulse: ${v['pulse'] ?? 'N/A'}';
    } else if (json['vitals'] is String) {
      vitalsSummary = json['vitals'].toString();
    }

    String? biometricsSummary;
    if (json['biometrics'] is Map<String, dynamic>) {
      final b = json['biometrics'] as Map<String, dynamic>;
      biometricsSummary = 'Height: ${b['height'] ?? 'N/A'} | Weight: ${b['weight'] ?? 'N/A'}';
    } else if (json['biometrics'] is String) {
      biometricsSummary = json['biometrics'].toString();
    }

    return PatientProfile(
      patientId: json['patient_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      medicalRecordNumber: json['medical_record_number']?.toString(),
      name: json['name']?.toString() ?? 'Unknown Patient',
      bloodGroup: json['blood_group']?.toString() ?? 'Unknown',
      allergies: parsedAllergies,
      emergencyContact: json['emergency_contact']?.toString(),
      activeAppointment: apptText ?? json['active_appointment']?.toString(),
      doctorName: doctor ?? json['doctor_name']?.toString(),
      room: wardRoom ?? json['room']?.toString(),
      appointmentStatus: status ?? json['status']?.toString(),
      diagnosis: json['diagnosis']?.toString(),
      vitals: vitalsSummary,
      biometrics: biometricsSummary,
      familyHistory: json['family_history']?.toString(),
      prescriptions: parsedPrescriptions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient_id': patientId,
      'user_id': userId,
      'medical_record_number': medicalRecordNumber,
      'name': name,
      'blood_group': bloodGroup,
      'allergies': allergies,
      'emergency_contact': emergencyContact,
      'active_appointment': activeAppointment,
      'doctor_name': doctorName,
      'room': room,
      'appointment_status': appointmentStatus,
      'diagnosis': diagnosis,
      'vitals': vitals,
      'biometrics': biometrics,
      'family_history': familyHistory,
      'prescriptions': prescriptions.map((p) => p.toJson()).toList(),
    };
  }

  /// Default mock profile modeled directly from the user's hospital database schema.
  static PatientProfile demoRajeshSharma() {
    return const PatientProfile(
      patientId: '14-2026-4512-8821',
      userId: 'd7b4e3f1-2856-4c91-9e8a-729938b84001',
      medicalRecordNumber: '14-2026-4512-8821',
      name: 'Rajesh Sharma',
      bloodGroup: 'B+',
      allergies: ['Penicillin'],
      emergencyContact: 'Sita Sharma (Spouse) - +919988776650',
      activeAppointment:
          'In-Clinic with Dr. Rajesh V. Sharma (NMC-2008-048291) | Status: queued | Room: IPD Ward 304 - Bed 12',
      doctorName: 'Dr. Rajesh V. Sharma',
      room: 'IPD Ward 304 - Bed 12',
      appointmentStatus: 'queued',
      diagnosis: 'Acute Rhinitis & Mild Fever',
      vitals: 'BP: 138/88 mmHg | SpO2: 98% | Temp: 98.4 °F | Pulse: 76 bpm',
      biometrics: 'Height: 172 cm | Weight: 74 kg',
      familyHistory: 'Father: Type 2 Diabetes, Mother: Hypertension',
      prescriptions: [
        PatientPrescription(
          medicine: 'Amoxicillin 500mg',
          dosage: '500mg',
          frequency: '1-0-0 after breakfast',
          duration: '5 days',
          status: 'active',
        ),
        PatientPrescription(
          medicine: 'Cetirizine 10mg',
          dosage: '10mg',
          frequency: '0-0-1 before sleep',
          duration: '5 days',
          status: 'active',
        ),
      ],
    );
  }
}
