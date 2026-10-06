import '../models/patient_record.dart';
import '../models/visit_record.dart';
import 'local_visit_repository.dart';

class LocalPatientRepository {
  LocalPatientRepository._();
  static final LocalPatientRepository instance = LocalPatientRepository._();

  static final PatientRecord defaultPatient = PatientRecord(
    patientRef: 'P-7A92F81C',
    patientId: '14-1234-5678-9012',
    name: 'Vikram Malhotra',
    phone: '9876501234',
    bloodGroup: 'B+',
    gender: 'Male',
    dateOfBirth: '1984-06-15',
    visitIds: ['V1001', 'V1002', 'V1003', 'V1004', 'V1005'],
  );

  static List<VisitRecord> get defaultVisits => LocalVisitRepository.demoVisits;

  Future<PatientRecord?> getPatient(String patientRef) async {
    return defaultPatient;
  }
}
