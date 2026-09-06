enum PatientAppointmentStatus { ready, inCall, completed, missed }

class PatientAppointment {
  final String id;
  final String patientName;
  final String doctorName;
  final String doctorSpecialty;
  final String reason;
  final DateTime scheduledTime;
  PatientAppointmentStatus status;

  PatientAppointment({
    required this.id,
    required this.patientName,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.reason,
    required this.scheduledTime,
    this.status = PatientAppointmentStatus.ready,
  });
}
