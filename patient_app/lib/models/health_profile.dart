/// Represents the patient's health profile.
/// Tier 1 contains basic onboarding details.
/// Tier 2 contains scheme eligibility & extended medical details.
class HealthProfile {
  final String name;
  final int age;
  final String gender;
  final String phoneNumber;
  /// Standardized 14-digit Health ID in XX-XXXX-XXXX-XXXX format
  final String patientId;
  /// Internal PostgreSQL database UUID (e.g. b0843210-91ab-4ef1-bb74-001928475002)
  final String? backendPatientId;
  final String? password;
  final String location;
  final String residenceType; // 'Urban' or 'Rural'
  final DateTime createdAt;
  
  /// Extensible hook for Tier 2 scheme eligibility fields 
  /// (e.g. incomeGroup, category, state, chronicConditions, etc.)
  final Map<String, dynamic>? tier2Data;

  /// Generates a standardized 14-digit Health ID in XX-XXXX-XXXX-XXXX format
  /// based deterministically on the phone number or fallback seed.
  static String formatDeterministicHealthId(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      final ten = digits.substring(digits.length - 10);
      final check = (ten.hashCode.abs() % 90 + 10).toString().padLeft(2, '0');
      final raw14 = '91$ten$check';
      return '${raw14.substring(0, 2)}-${raw14.substring(2, 6)}-${raw14.substring(6, 10)}-${raw14.substring(10, 14)}';
    }
    return '14-8832-4512-9018';
  }

  /// Formats and validates a 14-digit Health ID (XX-XXXX-XXXX-XXXX).
  /// If candidate is already in 14-digit format (hyphenated or raw digits), formats it.
  /// Rejects UUIDs (length 36, contains hex letters), legacy prefixes, and invalid IDs.
  static String resolveHealthId({
    String? raw,
    String? tier2Mrn,
    String phone = '',
  }) {
    String? tryFormat(String? candidate) {
      if (candidate == null) return null;
      final trimmed = candidate.trim();
      // Must NOT contain hex letters from UUIDs (e.g. 'b0843210-91ab-4ef1-bb74-001928475002')
      if (trimmed.contains(RegExp(r'[a-zA-Z]'))) {
        return null;
      }
      // Exact match for 14-digit hyphenated format: XX-XXXX-XXXX-XXXX
      if (RegExp(r'^\d{2}-\d{4}-\d{4}-\d{4}$').hasMatch(trimmed)) {
        return trimmed;
      }
      // Exact 14 digits unhyphenated
      final digits = trimmed.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 14) {
        return '${digits.substring(0, 2)}-${digits.substring(2, 6)}-${digits.substring(6, 10)}-${digits.substring(10, 14)}';
      }
      return null;
    }

    final fromMrn = tryFormat(tier2Mrn);
    if (fromMrn != null) return fromMrn;

    final fromRaw = tryFormat(raw);
    if (fromRaw != null) return fromRaw;

    return formatDeterministicHealthId(phone);
  }

  /// True if patientId follows the standard 14-digit format: XX-XXXX-XXXX-XXXX
  bool get isStandardHealthId =>
      RegExp(r'^\d{2}-\d{4}-\d{4}-\d{4}$').hasMatch(patientId);

  HealthProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.phoneNumber,
    String? patientId,
    String? backendPatientId,
    this.password,
    this.location = 'New Delhi, Delhi',
    this.residenceType = 'Rural',
    DateTime? createdAt,
    this.tier2Data,
  })  : patientId = resolveHealthId(
          raw: patientId,
          tier2Mrn: tier2Data?['medical_record_number'] as String?,
          phone: phoneNumber,
        ),
        backendPatientId = backendPatientId ?? (
          (patientId != null && (patientId.length > 20 || patientId.contains(RegExp(r'[a-fA-F]'))))
              ? patientId
              : (tier2Data?['patient_uuid'] as String?)
        ),
        createdAt = createdAt ?? DateTime.now();

  /// Create a copy with updated fields
  HealthProfile copyWith({
    String? name,
    int? age,
    String? gender,
    String? phoneNumber,
    String? patientId,
    String? backendPatientId,
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
      backendPatientId: backendPatientId ?? this.backendPatientId,
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
      'backendPatientId': backendPatientId,
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
    final rawId = json['patientId'] as String?;
    final backendId = (json['backendPatientId'] as String?) ?? (json['patient_uuid'] as String?);
    final tier2 = json['tier2Data'] != null
        ? Map<String, dynamic>.from(json['tier2Data'] as Map)
        : null;
    final mrn = tier2?['medical_record_number'] as String?;

    return HealthProfile(
      name: json['name'] as String? ?? 'Patient',
      age: (json['age'] as num?)?.toInt() ?? 25,
      gender: json['gender'] as String? ?? 'Other',
      phoneNumber: phone,
      patientId: mrn ?? rawId,
      backendPatientId: backendId,
      password: json['password'] as String?,
      location: json['location'] as String? ?? 'New Delhi, Delhi',
      residenceType: json['residenceType'] as String? ?? json['residence_type'] as String? ?? 'Rural',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      tier2Data: tier2,
    );
  }

  @override
  String toString() {
    return 'HealthProfile(name: $name, id: $patientId, age: $age, gender: $gender, phoneNumber: $phoneNumber, location: $location)';
  }
}
