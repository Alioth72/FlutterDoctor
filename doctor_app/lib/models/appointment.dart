enum AppointmentStatus { waiting, inCall, completed, missed }

class Appointment {
  final String id;
  final String patientName;
  final int patientAge;
  final String chiefComplaint;
  final DateTime scheduledTime;
  final int queuePosition;
  AppointmentStatus status;

  Appointment({
    required this.id,
    required this.patientName,
    required this.patientAge,
    required this.chiefComplaint,
    required this.scheduledTime,
    required this.queuePosition,
    this.status = AppointmentStatus.waiting,
  });
}
