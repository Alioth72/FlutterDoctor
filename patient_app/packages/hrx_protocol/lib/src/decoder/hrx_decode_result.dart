import '../models/patient_record.dart';
import '../models/visit_record.dart';

class HrxDecodeResult {
  final bool success;
  final bool isPatient;
  final bool isVisit;
  final PatientRecord? patient;
  final VisitRecord? visit;
  final Map<String, dynamic> metadata;
  final String? errorMessage;

  HrxDecodeResult({
    required this.success,
    this.isPatient = false,
    this.isVisit = false,
    this.patient,
    this.visit,
    this.metadata = const {},
    this.errorMessage,
  });
}
