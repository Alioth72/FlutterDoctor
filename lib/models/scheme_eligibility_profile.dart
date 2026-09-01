class SchemeEligibilityProfile {
  final int age;
  final String state;
  final String incomeRange;
  final String? gender;
  final String? occupation;
  final String? socialCategory;
  final String? disability;
  final String? maritalStatus;
  final String? ruralUrban;

  const SchemeEligibilityProfile({
    required this.age,
    required this.state,
    required this.incomeRange,
    this.gender,
    this.occupation,
    this.socialCategory,
    this.disability,
    this.maritalStatus,
    this.ruralUrban,
  });

  String get summaryText {
    return 'Age: $age • $state • $incomeRange income';
  }

  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'state': state,
      'income_range': incomeRange,
      'gender': gender,
      'occupation': occupation,
      'category': socialCategory,
      'disability': disability,
      'marital_status': maritalStatus,
      'residence_type': ruralUrban,
    };
  }

  factory SchemeEligibilityProfile.fromJson(Map<String, dynamic> json) {
    return SchemeEligibilityProfile(
      age: (json['age'] as num).toInt(),
      state: json['state'] as String? ?? 'Delhi',
      incomeRange: json['income_range'] as String? ?? json['incomeRange'] as String? ?? '1 - 2.5 Lakh',
      gender: json['gender'] as String?,
      occupation: json['occupation'] as String?,
      socialCategory: json['category'] as String? ?? json['socialCategory'] as String?,
      disability: json['disability'] as String?,
      maritalStatus: json['marital_status'] as String? ?? json['maritalStatus'] as String?,
      ruralUrban: json['residence_type'] as String? ?? json['ruralUrban'] as String?,
    );
  }
}
