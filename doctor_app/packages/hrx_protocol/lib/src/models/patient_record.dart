import 'dart:convert';
import '../protocol/constants.dart';

/// Patient identity model for HRX QR exchange.
class PatientRecord {
  final String patientRef;
  final String patientId;
  final String name;
  final String dateOfBirth;
  final String gender;
  final String bloodGroup;
  final String phone;
  final List<String> visitIds;
  final Map<String, dynamic> extra;

  const PatientRecord({
    required this.patientRef,
    required this.patientId,
    required this.name,
    this.dateOfBirth = '',
    this.gender = '',
    this.bloodGroup = '',
    this.phone = '',
    this.visitIds = const [],
    this.extra = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'patient_ref': patientRef,
      'patient_id': patientId,
      'name': name,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'blood_group': bloodGroup,
      'phone': phone,
      'visits': visitIds,
      if (extra.isNotEmpty) 'extra': extra,
    };
  }

  factory PatientRecord.fromMap(Map<dynamic, dynamic> map) {
    return PatientRecord(
      patientRef: (map['patient_ref'] ?? map['patientRef'] ?? '').toString(),
      patientId: (map['patient_id'] ?? map['patientId'] ?? '').toString(),
      name: (map['name'] ?? 'Unknown Patient').toString(),
      dateOfBirth: (map['date_of_birth'] ?? map['dateOfBirth'] ?? '').toString(),
      gender: (map['gender'] ?? '').toString(),
      bloodGroup: (map['blood_group'] ?? map['bloodGroup'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      visitIds: (map['visits'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      extra: (map['extra'] is Map) ? Map<String, dynamic>.from(map['extra'] as Map) : const {},
    );
  }

  PatientRecord copyWith({
    String? patientRef,
    String? patientId,
    String? name,
    String? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? phone,
    List<String>? visitIds,
    Map<String, dynamic>? extra,
  }) {
    return PatientRecord(
      patientRef: patientRef ?? this.patientRef,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      phone: phone ?? this.phone,
      visitIds: visitIds ?? this.visitIds,
      extra: extra ?? this.extra,
    );
  }

  /// Compact QR representation for Patient Identity QR.
  /// When [compact] is true, generates ultra-lightweight pipe-delimited string (60-70 chars, QR Version 3).
  String toQrString({bool compact = true}) {
    if (compact) {
      return toCompactQrString();
    }
    final payload = {
      'protocol': HrxConstants.magicString,
      'version': HrxConstants.protocolVersion,
      'type': 'PATIENT',
      'patient_ref': patientRef,
      'patient_id': patientId,
      'name': name,
      'gender': gender,
      'blood_group': bloodGroup,
      'phone': phone,
    };
    return jsonEncode(payload);
  }

  /// High-density pipe-delimited compact string representation (RFC/Tokenized):
  /// Format: `HRX:P|1|<patientRef>|<patientId>|<name>|<gender>|<bloodGroup>|<phone>`
  String toCompactQrString() {
    return 'HRX:P|${HrxConstants.protocolVersion}|$patientRef|$patientId|$name|$gender|$bloodGroup|$phone';
  }

  /// Factory parser from QR string (supports both compact pipe-delimited and JSON formats).
  static PatientRecord? fromQrString(String qrString) {
    try {
      final trimmed = qrString.trim();
      if (trimmed.startsWith('HRX:P|')) {
        final parts = trimmed.split('|');
        if (parts.length >= 8) {
          return PatientRecord(
            patientRef: parts[2],
            patientId: parts[3],
            name: parts[4],
            gender: parts[5],
            bloodGroup: parts[6],
            phone: parts[7],
          );
        }
      }
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return PatientRecord.fromMap(decoded);
      }
    } catch (_) {}
    return null;
  }

  @override
  String toString() => 'PatientRecord($patientRef, $name, ID: $patientId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientRecord &&
          runtimeType == other.runtimeType &&
          patientRef == other.patientRef &&
          patientId == other.patientId;

  @override
  int get hashCode => patientRef.hashCode ^ patientId.hashCode;
}
