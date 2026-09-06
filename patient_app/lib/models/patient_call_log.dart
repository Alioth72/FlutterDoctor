class PatientCallLog {
  final String appointmentId;
  DateTime? startedAt;
  DateTime? endedAt;
  bool hadError;

  PatientCallLog({required this.appointmentId, this.hadError = false});

  Duration? get duration => startedAt != null && endedAt != null
      ? endedAt!.difference(startedAt!)
      : null;
}
