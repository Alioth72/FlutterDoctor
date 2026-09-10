/// Model representing a synced family member.
class FamilyMember {
  final String id;
  final String name;
  final String patientId;
  final String relation;
  final int? age;
  final String? gender;
  final DateTime syncedAt;
  final bool isSynced;

  const FamilyMember({
    required this.id,
    required this.name,
    required this.patientId,
    required this.relation,
    this.age,
    this.gender,
    required this.syncedAt,
    this.isSynced = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'patientId': patientId,
      'relation': relation,
      'age': age,
      'gender': gender,
      'syncedAt': syncedAt.toIso8601String(),
      'isSynced': isSynced,
    };
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String? ?? 'FAM-${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      relation: json['relation'] as String? ?? 'Family Member',
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      syncedAt: json['syncedAt'] != null
          ? DateTime.tryParse(json['syncedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isSynced: json['isSynced'] as bool? ?? true,
    );
  }
}
