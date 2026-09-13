enum AppointmentMode {
  qr,
  teleconsultation,
}

class MedicineItem {
  final String name;
  final String dosage;
  final String duration;
  final String closestClinic;

  MedicineItem({
    required this.name,
    required this.dosage,
    required this.duration,
    required this.closestClinic,
  });
}

class InpatientProcedureItem {
  final String title;
  final String timing;
  final String instructions;
  final String category; // 'Injection', 'IV Drip', 'Nursing Care'

  InpatientProcedureItem({
    required this.title,
    required this.timing,
    required this.instructions,
    required this.category,
  });
}

class AppointmentItem {
  final String id;
  final String appointmentNo;
  final String patientName;
  final int age;
  final String gender;
  final String timing;
  final String paymentStatus;
  final bool isPaid;
  final AppointmentMode mode;
  final List<String> patientHistory;
  double heightCm;
  double weightKg;
  String familyHistory;
  String diagnosis;
  List<MedicineItem> medicines;
  final bool isAdmitted;
  final String? roomNo;
  String? dietarySuggestions;
  List<InpatientProcedureItem>? inpatientSchedules;
  bool _isCompleted;
  bool get isCompleted => _isCompleted || status.toLowerCase() == 'completed';
  set isCompleted(bool val) => _isCompleted = val;
  String status;
  final String? patientId;
  final String? medicalRecordNumber;
  final String? bloodGroup;
  final String? patientPhone;
  final String? doctorName;
  final Map<String, dynamic>? clinicalData;
  final List<String>? allergies;
  final Map<String, dynamic>? emergencyContact;
  final Map<String, dynamic>? notes;
  final String? appointmentType;
  final String? reason;

  AppointmentItem({
    required this.id,
    required this.appointmentNo,
    required this.patientName,
    required this.age,
    required this.gender,
    required this.timing,
    required this.paymentStatus,
    required this.isPaid,
    required this.mode,
    required this.patientHistory,
    required this.heightCm,
    required this.weightKg,
    required this.familyHistory,
    required this.diagnosis,
    required this.medicines,
    this.isAdmitted = false,
    this.roomNo,
    this.dietarySuggestions,
    this.inpatientSchedules,
    bool isCompleted = false,
    this.status = 'confirmed',
    this.patientId,
    this.medicalRecordNumber,
    this.bloodGroup,
    this.patientPhone,
    this.doctorName,
    this.clinicalData,
    this.allergies,
    this.emergencyContact,
    this.notes,
    this.appointmentType,
    this.reason,
  }) : _isCompleted = isCompleted;
}
