/// Represents the patient's health profile.
/// Tier 1 contains basic onboarding details.
/// Tier 2 contains scheme eligibility & extended medical details.
class HealthProfile {
  final String name;
  final int age;
  final String gender;
  final String phoneNumber;
  final String patientId;
  final String? password;
  final String location;
  final String residenceType; // 'Urban' or 'Rural'
  final DateTime createdAt;
  
  /// Extensible hook for Tier 2 scheme eligibility fields 
  /// (e.g. incomeGroup, category, state, chronicConditions, etc.)
  final Map<String, dynamic>? tier2Data;

  HealthProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.phoneNumber,
    String? patientId,
    this.password,
    this.location = 'New Delhi, Delhi',
    this.residenceType = 'Rural',
    DateTime? createdAt,
    this.tier2Data,
  })  : patientId = patientId ??
            (phoneNumber.length >= 4
                ? 'ASH-PT-${phoneNumber.substring(phoneNumber.length - 4)}'
                : 'ASH-PT-1001'),
        createdAt = createdAt ?? DateTime.now();

  /// Create a copy with updated fields
  HealthProfile copyWith({
    String? name,
    int? age,
    String? gender,
    String? phoneNumber,
    String? patientId,
    String? password,
    String? location,
    String? residenceType,
    DateTime? createdAt,
    Map<String, dynamic>? tier2Data,
  }) {
    return HealthProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      patientId: patientId ?? this.patientId,
      password: password ?? this.password,
      location: location ?? this.location,
      residenceType: residenceType ?? this.residenceType,
      createdAt: createdAt ?? this.createdAt,
      tier2Data: tier2Data ?? this.tier2Data,
    );
  }

  /// Blood group, usually stored in tier2Data. Defaults to 'B+' if unspecified.
  String get bloodGroup =>
      tier2Data?['blood_group']?.toString() ??
      tier2Data?['bloodGroup']?.toString() ??
      'B+';

  /// Date of birth formatted as YYYY-MM-DD.
  /// Computed from age or extracted from tier2Data.
  String get dateOfBirth {
    final dob = tier2Data?['date_of_birth']?.toString() ??
        tier2Data?['dateOfBirth']?.toString();
    if (dob != null && dob.trim().isNotEmpty) {
      return dob.trim();
    }
    final birthYear = DateTime.now().year - age;
    return '$birthYear-01-01';
  }

  /// Convert model to JSON map for persistence and database payloads
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'phoneNumber': phoneNumber,
      'patientId': patientId,
      'password': password,
      'location': location,
      'residenceType': residenceType,
      'createdAt': createdAt.toIso8601String(),
      'tier2Data': tier2Data,
    };
  }

  /// Create model instance from JSON map
  factory HealthProfile.fromJson(Map<String, dynamic> json) {
    final phone = json['phoneNumber'] as String? ?? '';
    return HealthProfile(
      name: json['name'] as String? ?? 'Patient',
      age: (json['age'] as num?)?.toInt() ?? 25,
      gender: json['gender'] as String? ?? 'Other',
      phoneNumber: phone,
      patientId: json['patientId'] as String?,
      password: json['password'] as String?,
      location: json['location'] as String? ?? 'New Delhi, Delhi',
      residenceType: json['residenceType'] as String? ?? json['residence_type'] as String? ?? 'Rural',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      tier2Data: json['tier2Data'] != null
          ? Map<String, dynamic>.from(json['tier2Data'] as Map)
          : null,
    );
  }

  @override
  String toString() {
    return 'HealthProfile(name: $name, id: $patientId, age: $age, gender: $gender, phoneNumber: $phoneNumber, location: $location)';
  }
}
