/// Strongly typed diagnosis entry.
class DiagnosisItem {
  final String code;
  final String name;

  const DiagnosisItem({required this.code, required this.name});

  Map<String, dynamic> toMap() => {'code': code, 'name': name};
  Map<String, dynamic> toCompactMap() => {'c': code, 'n': name};

  factory DiagnosisItem.fromMap(Map<dynamic, dynamic> map) {
    return DiagnosisItem(
      code: (map['c'] ?? map['code'] ?? '').toString(),
      name: (map['n'] ?? map['name'] ?? '').toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiagnosisItem &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          name == other.name;

  @override
  int get hashCode => code.hashCode ^ name.hashCode;

  @override
  String toString() => '$name ($code)';
}

/// Strongly typed medication prescription entry.
class MedicationItem {
  final String name;
  final String strength;
  final String dose;
  final String frequency;
  final int duration;
  final String durationUnit;
  final String route;
  final String instructions;

  const MedicationItem({
    required this.name,
    this.strength = '',
    this.dose = '',
    this.frequency = '',
    this.duration = 0,
    this.durationUnit = 'days',
    this.route = 'oral',
    this.instructions = '',
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'strength': strength,
        'dose': dose,
        'frequency': frequency,
        'duration': duration,
        'duration_unit': durationUnit,
        'route': route,
        'instructions': instructions,
      };

  Map<String, dynamic> toCompactMap() => {
        'n': name,
        if (strength.isNotEmpty) 's': strength,
        if (dose.isNotEmpty) 'ds': dose,
        if (frequency.isNotEmpty) 'fq': frequency,
        if (duration > 0) 'du': duration,
        if (durationUnit != 'days' && durationUnit.isNotEmpty) 'u': durationUnit,
        if (route != 'oral' && route.isNotEmpty) 'r': route,
        if (instructions.isNotEmpty) 'in': instructions,
      };

  factory MedicationItem.fromMap(Map<dynamic, dynamic> map) {
    return MedicationItem(
      name: (map['n'] ?? map['name'] ?? '').toString(),
      strength: (map['s'] ?? map['strength'] ?? '').toString(),
      dose: (map['ds'] ?? map['dose'] ?? '').toString(),
      frequency: (map['fq'] ?? map['frequency'] ?? '').toString(),
      duration: () {
        final val = map['du'] ?? map['duration'];
        if (val is num) return val.toInt();
        return int.tryParse(val?.toString() ?? '0') ?? 0;
      }(),
      durationUnit: (map['u'] ?? map['duration_unit'] ?? 'days').toString(),
      route: (map['r'] ?? map['route'] ?? 'oral').toString(),
      instructions: (map['in'] ?? map['instructions'] ?? '').toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicationItem &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          strength == other.strength &&
          frequency == other.frequency &&
          duration == other.duration;

  @override
  int get hashCode =>
      name.hashCode ^ strength.hashCode ^ frequency.hashCode ^ duration.hashCode;

  @override
  String toString() => '$name $strength ($frequency for $duration $durationUnit)';
}

/// Strongly typed follow-up recommendation.
class FollowUpInfo {
  final bool required;
  final String date;
  final String instructions;

  const FollowUpInfo({
    this.required = false,
    this.date = '',
    this.instructions = '',
  });

  Map<String, dynamic> toMap() => {
        'required': required,
        'date': date,
        'instructions': instructions,
      };

  Map<String, dynamic> toCompactMap() => {
        'rq': required,
        if (date.isNotEmpty) 'dt': date,
        if (instructions.isNotEmpty) 'in': instructions,
      };

  factory FollowUpInfo.fromMap(Map<dynamic, dynamic> map) {
    return FollowUpInfo(
      required: map['rq'] == true || map['required'] == true,
      date: (map['dt'] ?? map['date'] ?? '').toString(),
      instructions: (map['in'] ?? map['instructions'] ?? '').toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowUpInfo &&
          runtimeType == other.runtimeType &&
          required == other.required &&
          date == other.date;

  @override
  int get hashCode => required.hashCode ^ date.hashCode;
}

/// Complete strongly-typed medical visit record for offline QR exchange.
class VisitRecord {
  final String visitId;
  final String patientRef;
  final String doctorRef;
  final String doctorName;
  final String facilityRef;
  final String facilityName;
  final String timestamp; // ISO 8601 string e.g. "2026-09-13T10:30:00Z"
  final List<String> chiefComplaints;
  final List<String> symptoms;
  final List<DiagnosisItem> diagnosis;
  final Map<String, dynamic> vitals;
  final List<MedicationItem> medications;
  final List<String> labTests;
  final List<String> procedures;
  final List<String> allergies;
  final List<String> advice;
  final FollowUpInfo followUp;
  final String notes;
  final Map<String, dynamic> extra;

  const VisitRecord({
    required this.visitId,
    required this.patientRef,
    this.doctorRef = '',
    this.doctorName = '',
    this.facilityRef = '',
    this.facilityName = '',
    required this.timestamp,
    this.chiefComplaints = const [],
    this.symptoms = const [],
    this.diagnosis = const [],
    this.vitals = const {},
    this.medications = const [],
    this.labTests = const [],
    this.procedures = const [],
    this.allergies = const [],
    this.advice = const [],
    this.followUp = const FollowUpInfo(),
    this.notes = '',
    this.extra = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'visit_id': visitId,
      'patient_ref': patientRef,
      'doctor_ref': doctorRef,
      'doctor_name': doctorName,
      'facility_ref': facilityRef,
      'facility_name': facilityName,
      'timestamp': timestamp,
      'chief_complaints': chiefComplaints,
      'symptoms': symptoms,
      'diagnosis': diagnosis.map((d) => d.toMap()).toList(),
      'vitals': vitals,
      'medications': medications.map((m) => m.toMap()).toList(),
      'lab_tests': labTests,
      'procedures': procedures,
      'allergies': allergies,
      'advice': advice,
      'follow_up': followUp.toMap(),
      'notes': notes,
      if (extra.isNotEmpty) 'extra': extra,
    };
  }

  /// Compact map representation for minimal CBOR serialization footprint (RFC/Tokenized).
  Map<String, dynamic> toCompactMap() {
    return {
      'v': visitId,
      'p': patientRef,
      if (doctorRef.isNotEmpty) 'dr': doctorRef,
      if (doctorName.isNotEmpty) 'dn': doctorName,
      if (facilityRef.isNotEmpty) 'fr': facilityRef,
      if (facilityName.isNotEmpty) 'fn': facilityName,
      't': timestamp,
      if (chiefComplaints.isNotEmpty) 'cc': chiefComplaints,
      if (symptoms.isNotEmpty) 'sy': symptoms,
      if (diagnosis.isNotEmpty) 'dg': diagnosis.map((d) => d.toCompactMap()).toList(),
      if (vitals.isNotEmpty) 'vt': vitals,
      if (medications.isNotEmpty) 'm': medications.map((m) => m.toCompactMap()).toList(),
      if (labTests.isNotEmpty) 'lt': labTests,
      if (procedures.isNotEmpty) 'pr': procedures,
      if (allergies.isNotEmpty) 'al': allergies,
      if (advice.isNotEmpty) 'ad': advice,
      if (followUp.required) 'fl': followUp.toCompactMap(),
      if (notes.isNotEmpty) 'nt': notes,
      if (extra.isNotEmpty) 'extra': extra,
    };
  }

  /// Distilled high-density clinical summary for offline QR transmission.
  /// Strips unconstrained narrative essays, duplicate symptoms, and verbose notes
  /// to keep the payload ~180-220 bytes, enabling a truly chunky, instantly scannable
  /// QR code (QR v8-10 vs previous v19) with 3.6x fewer micro-dots.
  Map<String, dynamic> toDistilledMap() {
    // 1. Shorten facility name (primary segment before comma or dash)
    String shortFacility = facilityName;
    if (shortFacility.contains(',')) {
      shortFacility = shortFacility.split(',').first.trim();
    } else if (shortFacility.contains(' - ')) {
      shortFacility = shortFacility.split(' - ').first.trim();
    }

    // 2. Date only YYYY-MM-DD
    final dateStr = timestamp.contains('T') ? timestamp.split('T').first : timestamp;

    // 3. Distill diagnoses to concise 'code:name' or 'name' strings (max 2)
    final distilledDg = diagnosis.take(2).map((d) {
      if (d.code.isNotEmpty) {
        return '${d.code}:${d.name}';
      }
      return d.name;
    }).toList();

    // 4. Distill vitals to core measurements with concise 2-character keys
    final distilledVt = <String, dynamic>{};
    for (final entry in vitals.entries) {
      final k = entry.key.toLowerCase();
      if (k.contains('press') || k == 'bp') {
        distilledVt['bp'] = entry.value;
      } else if (k.contains('pulse') || k == 'hr' || k == 'heart_rate') {
        distilledVt['p'] = entry.value;
      } else if (k.contains('temp')) {
        distilledVt['t'] = entry.value;
      } else if (k.contains('spo2') || k.contains('o2') || k.contains('oxygen')) {
        distilledVt['o2'] = entry.value;
      } else if (k.contains('weight') || k == 'wt') {
        distilledVt['wt'] = entry.value;
      } else if (k.contains('sugar') || k.contains('glu') || k.contains('hba1c')) {
        distilledVt['glu'] = entry.value;
      }
    }

    // 5. Distill medications to concise strings e.g. "Name Strength (Frequency)" (max 3)
    final distilledM = medications.take(3).map((m) {
      final buf = StringBuffer(m.name);
      if (m.strength.isNotEmpty) buf.write(' ${m.strength}');
      if (m.frequency.isNotEmpty) buf.write(' (${m.frequency})');
      return buf.toString().trim();
    }).toList();

    // 6. Distill primary advice (first item, truncated to 45 chars if necessary)
    String? shortAdvice;
    if (advice.isNotEmpty) {
      shortAdvice = advice.first.trim();
      if (shortAdvice.length > 50) {
        shortAdvice = '${shortAdvice.substring(0, 47)}...';
      }
    }

    return {
      'v': visitId,
      'p': patientRef,
      if (doctorName.isNotEmpty) 'dn': doctorName,
      if (shortFacility.isNotEmpty) 'fn': shortFacility,
      't': dateStr,
      if (distilledDg.isNotEmpty) 'dg': distilledDg,
      if (distilledVt.isNotEmpty) 'vt': distilledVt,
      if (distilledM.isNotEmpty) 'm': distilledM,
      if (shortAdvice != null && shortAdvice.isNotEmpty) 'ad': shortAdvice,
      if (allergies.isNotEmpty) 'al': allergies.take(2).toList(),
    };
  }

  VisitRecord copyWith({
    String? visitId,
    String? patientRef,
    String? doctorRef,
    String? doctorName,
    String? facilityRef,
    String? facilityName,
    String? timestamp,
    List<String>? chiefComplaints,
    List<String>? symptoms,
    List<DiagnosisItem>? diagnosis,
    Map<String, dynamic>? vitals,
    List<MedicationItem>? medications,
    List<String>? labTests,
    List<String>? procedures,
    List<String>? allergies,
    List<String>? advice,
    FollowUpInfo? followUp,
    String? notes,
    Map<String, dynamic>? extra,
  }) {
    return VisitRecord(
      visitId: visitId ?? this.visitId,
      patientRef: patientRef ?? this.patientRef,
      doctorRef: doctorRef ?? this.doctorRef,
      doctorName: doctorName ?? this.doctorName,
      facilityRef: facilityRef ?? this.facilityRef,
      facilityName: facilityName ?? this.facilityName,
      timestamp: timestamp ?? this.timestamp,
      chiefComplaints: chiefComplaints ?? this.chiefComplaints,
      symptoms: symptoms ?? this.symptoms,
      diagnosis: diagnosis ?? this.diagnosis,
      vitals: vitals ?? this.vitals,
      medications: medications ?? this.medications,
      labTests: labTests ?? this.labTests,
      procedures: procedures ?? this.procedures,
      allergies: allergies ?? this.allergies,
      advice: advice ?? this.advice,
      followUp: followUp ?? this.followUp,
      notes: notes ?? this.notes,
      extra: extra ?? this.extra,
    );
  }

  static MedicationItem _parseMedicationString(String raw) {
    final trimmed = raw.trim();
    final regex = RegExp(r'^(.+?)(?:\s+(\d+(?:\.\d+)?\s*(?:mg|g|ml|mcg|IU|%)))?(?:\s*\((.*?)\))?$');
    final match = regex.firstMatch(trimmed);
    if (match != null) {
      final name = match.group(1)?.trim() ?? trimmed;
      final strength = match.group(2)?.trim() ?? '';
      final frequency = match.group(3)?.trim() ?? '';
      return MedicationItem(
        name: name,
        strength: strength,
        dose: '1 unit',
        frequency: frequency.isNotEmpty ? frequency : 'As directed',
        duration: 30,
        durationUnit: 'days',
      );
    }
    return MedicationItem(
      name: trimmed,
      dose: '1 unit',
      frequency: 'As directed',
    );
  }

  factory VisitRecord.fromMap(Map<dynamic, dynamic> map) {
    return VisitRecord(
      visitId: (map['v'] ?? map['visit_id'] ?? map['visitId'] ?? '').toString(),
      patientRef: (map['p'] ?? map['patient_ref'] ?? map['patientRef'] ?? '').toString(),
      doctorRef: (map['dr'] ?? map['doctor_ref'] ?? map['doctorRef'] ?? '').toString(),
      doctorName: (map['dn'] ?? map['doctor_name'] ?? map['doctorName'] ?? '').toString(),
      facilityRef: (map['fr'] ?? map['facility_ref'] ?? map['facilityRef'] ?? '').toString(),
      facilityName: (map['fn'] ?? map['facility_name'] ?? map['facilityName'] ?? '').toString(),
      timestamp: (map['t'] ?? map['timestamp'] ?? DateTime.now().toIso8601String()).toString(),
      chiefComplaints: () {
        final raw = map['cc'] ?? map['chief_complaints'];
        if (raw is List) {
          return raw.map<String>((e) => e.toString()).toList();
        }
        return const <String>[];
      }(),
      symptoms: () {
        final raw = map['sy'] ?? map['symptoms'];
        if (raw is List) {
          return raw.map<String>((e) => e.toString()).toList();
        }
        return const <String>[];
      }(),
      diagnosis: () {
        final raw = map['dg'] ?? map['diagnosis'];
        if (raw is List) {
          return raw.map<DiagnosisItem>((e) {
            if (e is Map) return DiagnosisItem.fromMap(e);
            final str = e.toString().trim();
            if (str.contains(':')) {
              final idx = str.indexOf(':');
              final code = str.substring(0, idx).trim();
              final name = str.substring(idx + 1).trim();
              return DiagnosisItem(code: code, name: name);
            }
            return DiagnosisItem(code: '', name: str);
          }).toList();
        }
        return const <DiagnosisItem>[];
      }(),
      vitals: () {
        final raw = (map['vt'] ?? map['vitals']);
        if (raw is! Map) return const <String, dynamic>{};
        final normalized = <String, dynamic>{};
        for (final entry in raw.entries) {
          final k = entry.key.toString().toLowerCase();
          if (k == 'bp' || k == 'blood_pressure') {
            normalized['blood_pressure'] = entry.value;
          } else if (k == 'p' || k == 'pulse' || k == 'hr') {
            normalized['pulse'] = entry.value;
          } else if (k == 't' || k == 'temp' || k == 'temperature') {
            normalized['temperature'] = entry.value;
          } else if (k == 'o2' || k == 'spo2') {
            normalized['spo2'] = entry.value;
          } else if (k == 'wt' || k == 'weight') {
            normalized['weight'] = entry.value;
          } else if (k == 'glu' || k == 'glucose') {
            normalized['glucose'] = entry.value;
          } else {
            normalized[entry.key.toString()] = entry.value;
          }
        }
        return normalized;
      }(),
      medications: () {
        final raw = map['m'] ?? map['medications'];
        if (raw is List) {
          return raw.map<MedicationItem>((e) {
            if (e is Map) return MedicationItem.fromMap(e);
            return _parseMedicationString(e.toString());
          }).toList();
        }
        return const <MedicationItem>[];
      }(),
      labTests: () {
        final raw = map['lt'] ?? map['lab_tests'];
        if (raw is List) {
          return raw.map<String>((e) => e.toString()).toList();
        }
        return const <String>[];
      }(),
      procedures: () {
        final raw = map['pr'] ?? map['procedures'];
        if (raw is List) {
          return raw.map<String>((e) => e.toString()).toList();
        }
        return const <String>[];
      }(),
      allergies: () {
        final raw = map['al'] ?? map['allergies'];
        if (raw is List) {
          return raw.map<String>((e) => e.toString()).toList();
        }
        return const <String>[];
      }(),
      advice: () {
        final raw = map['ad'] ?? map['advice'];
        if (raw is List) {
          return raw.map<String>((e) => e.toString()).toList();
        }
        if (raw is String && raw.trim().isNotEmpty) {
          return <String>[raw.trim()];
        }
        return const <String>[];
      }(),
      followUp: (map['fl'] ?? map['follow_up']) is Map
          ? FollowUpInfo.fromMap((map['fl'] ?? map['follow_up']) as Map)
          : const FollowUpInfo(),
      notes: (map['nt'] ?? map['notes'] ?? '').toString(),
      extra: (map['extra'] is Map)
          ? Map<String, dynamic>.from(map['extra'] as Map)
          : const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisitRecord &&
          runtimeType == other.runtimeType &&
          visitId == other.visitId &&
          patientRef == other.patientRef &&
          timestamp == other.timestamp;

  @override
  int get hashCode => visitId.hashCode ^ patientRef.hashCode ^ timestamp.hashCode;

  @override
  String toString() => 'VisitRecord($visitId for $patientRef on $timestamp)';
}
