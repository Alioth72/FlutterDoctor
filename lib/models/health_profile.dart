/// Represents the patient's health profile.
/// Tier 1 contains basic onboarding details.
/// Tier 2 will contain scheme eligibility & extended medical details.
class HealthProfile {
  final String name;
  final int age;
  final String gender;
  final String phoneNumber;
  final DateTime createdAt;
  
  /// Extensible hook for Tier 2 scheme eligibility fields 
  /// (e.g. incomeGroup, category, state, chronicConditions, etc.)
  final Map<String, dynamic>? tier2Data;

  HealthProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.phoneNumber,
    DateTime? createdAt,
    this.tier2Data,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a copy with updated fields
  HealthProfile copyWith({
    String? name,
    int? age,
    String? gender,
    String? phoneNumber,
    DateTime? createdAt,
    Map<String, dynamic>? tier2Data,
  }) {
    return HealthProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      tier2Data: tier2Data ?? this.tier2Data,
    );
  }

  /// Convert model to JSON map for persistence
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt.toIso8601String(),
      'tier2Data': tier2Data,
    };
  }

  /// Create model instance from JSON map
  factory HealthProfile.fromJson(Map<String, dynamic> json) {
    return HealthProfile(
      name: json['name'] as String,
      age: (json['age'] as num).toInt(),
      gender: json['gender'] as String,
      phoneNumber: json['phoneNumber'] as String,
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
    return 'HealthProfile(name: $name, age: $age, gender: $gender, phoneNumber: $phoneNumber)';
  }
}
