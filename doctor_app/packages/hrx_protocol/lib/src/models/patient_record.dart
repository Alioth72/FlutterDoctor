class PatientRecord {
  final String patientRef;
  final String patientId;
  final String name;
  final String phone;
  final String bloodGroup;
  final String gender;
  final String dateOfBirth;
  final List<String> visitIds;

  PatientRecord({
    required this.patientRef,
    required this.patientId,
    required this.name,
    required this.phone,
    required this.bloodGroup,
    required this.gender,
    required this.dateOfBirth,
    this.visitIds = const [],
  });

  factory PatientRecord.fromJson(Map<String, dynamic> json) {
    return PatientRecord(
      patientRef: json['patient_ref'] ?? json['patientRef'] ?? json['ref'] ?? '',
      patientId: json['patient_id'] ?? json['patientId'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? json['ph'] ?? '',
      bloodGroup: json['blood_group'] ?? json['bloodGroup'] ?? json['bg'] ?? '',
      gender: json['gender'] ?? json['gen'] ?? '',
      dateOfBirth: json['date_of_birth'] ?? json['dateOfBirth'] ?? json['dob'] ?? '',
      visitIds: List<String>.from(json['visit_ids'] ?? json['visitIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient_ref': patientRef,
      'patient_id': patientId,
      'name': name,
      'phone': phone,
      'blood_group': bloodGroup,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'visit_ids': visitIds,
    };
  }
}
