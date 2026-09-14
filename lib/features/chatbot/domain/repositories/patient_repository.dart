import '../models/patient_profile.dart';

/// Contract for fetching and updating patient EHR context from local mocks or Azure Cloud.
abstract class PatientRepository {
  /// Retrieves the active patient profile (e.g. from Azure database or session).
  Future<PatientProfile?> getActivePatientProfile({String? patientId});

  /// Updates or logs new patient clinical vitals back to the database.
  Future<bool> updatePatientVitals({
    required String patientId,
    required Map<String, dynamic> vitals,
  });
}
