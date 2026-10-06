import '../models/patient_record.dart';
import '../models/visit_record.dart';

class HrxDecodeResult {
  final bool success;
  final bool isPatient;
  final bool isVisit;
  final bool isEmergencyHistory;
  final PatientRecord? patient;
  final VisitRecord? visit;
  final List<VisitRecord>? visits;
  final Map<String, dynamic> metadata;
  final String? errorMessage;

  HrxDecodeResult({
    required this.success,
    this.isPatient = false,
    this.isVisit = false,
    this.isEmergencyHistory = false,
    this.patient,
    this.visit,
    this.visits,
    this.metadata = const {},
    this.errorMessage,
  });
}
