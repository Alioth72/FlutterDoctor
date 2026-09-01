class Appointment {
  final String id;
  final String tokenNumber;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String hospitalName;
  final String patientName;
  final String patientPhone;
  final String appointmentDate; // e.g. "Wed, 02 Sep 2026"
  final String timeSlot; // e.g. "10:30 AM"
  final String reason;
  final int consultationFee;
  final String status; // Confirmed, Completed, Cancelled
  final DateTime bookedAt;

  const Appointment({
    required this.id,
    required this.tokenNumber,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.hospitalName,
    required this.patientName,
    required this.patientPhone,
    required this.appointmentDate,
    required this.timeSlot,
    this.reason = 'General Consultation',
    this.consultationFee = 0,
    this.status = 'Confirmed',
    required this.bookedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tokenNumber': tokenNumber,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'doctorSpecialty': doctorSpecialty,
      'hospitalName': hospitalName,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'appointmentDate': appointmentDate,
      'timeSlot': timeSlot,
      'reason': reason,
      'consultationFee': consultationFee,
      'status': status,
      'bookedAt': bookedAt.toIso8601String(),
    };
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String,
      tokenNumber: json['tokenNumber'] as String? ?? 'Token #01',
      doctorId: json['doctorId'] as String,
      doctorName: json['doctorName'] as String,
      doctorSpecialty: json['doctorSpecialty'] as String,
      hospitalName: json['hospitalName'] as String,
      patientName: json['patientName'] as String,
      patientPhone: json['patientPhone'] as String,
      appointmentDate: json['appointmentDate'] as String,
      timeSlot: json['timeSlot'] as String,
      reason: json['reason'] as String? ?? 'General Consultation',
      consultationFee: (json['consultationFee'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'Confirmed',
      bookedAt: json['bookedAt'] != null
          ? DateTime.tryParse(json['bookedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  DateTime get scheduledDateTime {
    try {
      final clean = appointmentDate.replaceAll(',', '').trim();
      final parts = clean.split(' ');
      // Format: "Wed 02 Sep 2026" -> parts: ["Wed", "02", "Sep", "2026"]
      if (parts.length >= 4) {
        final day = int.tryParse(parts[1]) ?? 1;
        const months = {
          'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
          'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
        };
        final month = months[parts[2]] ?? 1;
        final year = int.tryParse(parts[3]) ?? DateTime.now().year;

        int hour = 9;
        int minute = 0;
        if (timeSlot.isNotEmpty) {
          final tParts = timeSlot.split(' ');
          final hm = tParts[0].split(':');
          hour = int.tryParse(hm[0]) ?? 9;
          minute = int.tryParse(hm[1]) ?? 0;
          if (tParts.length > 1 && tParts[1].toUpperCase() == 'PM' && hour < 12) {
            hour += 12;
          } else if (tParts.length > 1 && tParts[1].toUpperCase() == 'AM' && hour == 12) {
            hour = 0;
          }
        }
        return DateTime(year, month, day, hour, minute);
      }
    } catch (_) {}
    return bookedAt;
  }
}
