import '../models/patient_record.dart';

/// Abstract Patient Repository interface.
abstract class PatientRepository {
  Future<PatientRecord?> getPatient(String patientRef);
  Future<List<PatientRecord>> getAllPatients();
}

/// Local in-memory demo patient repository for Phase 1 offline demonstration.
class LocalPatientRepository implements PatientRepository {
  static final LocalPatientRepository instance = LocalPatientRepository._internal();
  LocalPatientRepository._internal();

  final Map<String, PatientRecord> _patients = {
    'P-7A92F81C': const PatientRecord(
      patientRef: 'P-7A92F81C',
      patientId: 'ASH-PT-1234',
      name: 'Vikram Malhotra',
      dateOfBirth: '1984-06-15',
      gender: 'Male',
      bloodGroup: 'B+',
      phone: '9876501234',
      visitIds: ['V1001', 'V1002', 'V1003', 'V1004', 'V1005'],
      extra: {
        'location': 'New Delhi, Delhi',
        'emergency_contact': '+91 9811223344',
        'abha_id': 'vikram.malhotra@abdm',
      },
    ),
  };

  @override
  Future<PatientRecord?> getPatient(String patientRef) async {
    if (_patients.containsKey(patientRef)) {
      return _patients[patientRef];
    }
    for (final p in _patients.values) {
      if (p.patientId.toLowerCase() == patientRef.toLowerCase() ||
          p.patientRef.toLowerCase() == patientRef.toLowerCase()) {
        return p;
      }
    }
    return null;
  }

  void savePatient(PatientRecord patient) {
    _patients[patient.patientRef] = patient;
  }

  @override
  Future<List<PatientRecord>> getAllPatients() async {
    return _patients.values.toList();
  }

  /// Default demo patient record
  static const PatientRecord defaultPatient = PatientRecord(
    patientRef: 'P-7A92F81C',
    patientId: 'ASH-PT-1234',
    name: 'Vikram Malhotra',
    dateOfBirth: '1984-06-15',
    gender: 'Male',
    bloodGroup: 'B+',
    phone: '9876501234',
    visitIds: ['V1001', 'V1002', 'V1003', 'V1004', 'V1005'],
    extra: {
      'location': 'New Delhi, Delhi',
      'emergency_contact': '+91 9811223344',
      'abha_id': 'vikram.malhotra@abdm',
    },
  );
}
