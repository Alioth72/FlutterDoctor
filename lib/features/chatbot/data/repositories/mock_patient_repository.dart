import '../../domain/models/patient_profile.dart';
import '../../domain/repositories/patient_repository.dart';

/// In-memory mock patient repository pre-loaded with the user's Rajesh Sharma schema.
/// Enables immediate local testing of allergy guards, prescription explainers, and ward assistants.
class MockPatientRepository implements PatientRepository {
  PatientProfile _activeProfile;

  MockPatientRepository({PatientProfile? initialProfile})
      : _activeProfile = initialProfile ?? PatientProfile.demoRajeshSharma();

  @override
  Future<PatientProfile?> getActivePatientProfile({String? patientId}) async {
    // Simulate negligible in-memory latency
    await Future.delayed(const Duration(milliseconds: 50));
    return _activeProfile;
  }

  @override
  Future<bool> updatePatientVitals({
    required String patientId,
    required Map<String, dynamic> vitals,
  }) async {
    final vSummary = 'BP: ${vitals['bp'] ?? '138/88'} | SpO2: ${vitals['spo2'] ?? '98%'} | Temp: ${vitals['temp'] ?? '98.4 °F'} | Pulse: ${vitals['pulse'] ?? '76 bpm'}';
    _activeProfile = PatientProfile(
      patientId: _activeProfile.patientId,
      userId: _activeProfile.userId,
      medicalRecordNumber: _activeProfile.medicalRecordNumber,
      name: _activeProfile.name,
      bloodGroup: _activeProfile.bloodGroup,
      allergies: _activeProfile.allergies,
      emergencyContact: _activeProfile.emergencyContact,
      activeAppointment: _activeProfile.activeAppointment,
      doctorName: _activeProfile.doctorName,
      room: _activeProfile.room,
      appointmentStatus: _activeProfile.appointmentStatus,
      diagnosis: _activeProfile.diagnosis,
      vitals: vSummary,
      biometrics: _activeProfile.biometrics,
      familyHistory: _activeProfile.familyHistory,
      prescriptions: _activeProfile.prescriptions,
    );
    return true;
  }
}
