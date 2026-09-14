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
  final String appointmentType; // Online, Offline, or home_visit
  final DateTime bookedAt;
  final Map<String, dynamic>? notes;

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
    this.appointmentType = 'Offline',
    required this.bookedAt,
    this.notes,
  });

  bool get isOnline =>
      appointmentType.toLowerCase() == 'online' ||
      appointmentType.toLowerCase() == 'telehealth';

  bool get isAshaVisit =>
      appointmentType.toLowerCase() == 'home_visit' ||
      (notes != null && notes!['request_type'] == 'asha_visit');

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
      'appointmentType': appointmentType,
      'bookedAt': bookedAt.toIso8601String(),
      'notes': notes,
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
      appointmentType: json['appointmentType'] as String? ?? 'Offline',
      bookedAt: json['bookedAt'] != null
          ? DateTime.tryParse(json['bookedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      notes: json['notes'] is Map ? Map<String, dynamic>.from(json['notes'] as Map) : null,
    );
  }

  /// Factory constructor to parse live Azure Function PostgreSQL appointment schema
  factory Appointment.fromDatabaseJson(Map<String, dynamic> json) {
    final notes = json['notes'] is Map ? json['notes'] as Map : {};
    final tokenNo = notes['appointment_no']?.toString() ??
        (json['tokenNumber'] as String? ?? 'Token #01');

    final startStr = json['scheduled_start'] as String?;
    DateTime scheduledDate = DateTime.now();
    if (startStr != null) {
      scheduledDate = DateTime.tryParse(startStr)?.toLocal() ?? DateTime.now();
    }

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dayOfWeek = dayNames[scheduledDate.weekday - 1];
    final dayNum = scheduledDate.day.toString().padLeft(2, '0');
    final monthName = monthNames[scheduledDate.month - 1];
    final year = scheduledDate.year;
    final formattedDate = '$dayOfWeek, $dayNum $monthName $year';

    final hour = scheduledDate.hour;
    final minute = scheduledDate.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final formattedTime = '${formattedHour.toString().padLeft(2, '0')}:$minute $period';

    final rawStatus = (json['status'] as String? ?? 'confirmed').toLowerCase();
    String normalizedStatus;
    switch (rawStatus) {
      case 'in_progress':
        normalizedStatus = 'In Progress';
        break;
      case 'completed':
        normalizedStatus = 'Completed';
        break;
      case 'cancelled':
        normalizedStatus = 'Cancelled';
        break;
      case 'queued':
        normalizedStatus = 'Queued';
        break;
      case 'no_show':
        normalizedStatus = 'No Show';
        break;
      case 'confirmed':
      default:
        normalizedStatus = 'Confirmed';
        break;
    }

    final rawType = (json['appointment_type'] as String? ?? 'clinic').toLowerCase();
    final normalizedType = (rawType == 'telehealth' || rawType == 'online')
        ? 'telehealth'
        : (rawType == 'home_visit' ? 'home_visit' : 'clinic');

    int parsedFee = 0;
    final rawFee = notes['consultation_fee'] ?? json['consultation_fee'];
    if (rawFee is num) {
      parsedFee = rawFee.toInt();
    } else if (rawFee is String) {
      parsedFee = int.tryParse(rawFee.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    final finalDate = (notes['appointment_date']?.toString().isNotEmpty ?? false)
        ? notes['appointment_date'].toString()
        : formattedDate;
    final finalSlot = (notes['slot_time']?.toString().isNotEmpty ?? false)
        ? notes['slot_time'].toString()
        : formattedTime;

    return Appointment(
      id: json['appointment_id'] as String? ?? json['id'] as String? ?? '',
      tokenNumber: tokenNo,
      doctorId: json['provider_user_id'] as String? ?? json['doctorId'] as String? ?? '',
      doctorName: json['doctor_name'] as String? ?? json['doctorName'] as String? ?? (normalizedType == 'home_visit' ? 'ASHA Health Worker' : 'Dr. Rajesh V. Sharma'),
      doctorSpecialty: json['doctor_specialty'] as String? ?? json['doctorSpecialty'] as String? ?? notes['doctor_specialty']?.toString() ?? (normalizedType == 'home_visit' ? 'Community Health Care' : 'General Physician'),
      hospitalName: json['facility_name'] as String? ?? json['hospitalName'] as String? ?? (normalizedType == 'home_visit' ? 'Village Health Post' : 'Ashwini Central Hospital'),
      patientName: json['patient_name'] as String? ?? json['patientName'] as String? ?? '',
      patientPhone: json['patient_phone'] as String? ?? json['patientPhone'] as String? ?? '',
      appointmentDate: finalDate,
      timeSlot: finalSlot,
      reason: json['reason'] as String? ?? json['mr_diagnosis'] as String? ?? 'General Consultation',
      consultationFee: parsedFee,
      status: normalizedStatus,
      appointmentType: normalizedType,
      bookedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      notes: notes is Map<String, dynamic> ? notes : Map<String, dynamic>.from(notes),
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
