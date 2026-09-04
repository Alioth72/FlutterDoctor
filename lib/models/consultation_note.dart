class PrescriptionItem {
  String drugName;
  String dosage;
  String duration;

  PrescriptionItem({this.drugName = '', this.dosage = '', this.duration = ''});
}

class ConsultationNote {
  final String appointmentId;
  String notes;
  List<PrescriptionItem> prescriptionItems;
  bool referralNeeded;
  String? referralReason;
  String? referralFacility;

  ConsultationNote({
    required this.appointmentId,
    this.notes = '',
    List<PrescriptionItem>? prescriptionItems,
    this.referralNeeded = false,
    this.referralReason,
    this.referralFacility,
  }) : prescriptionItems = prescriptionItems ?? [];
}
