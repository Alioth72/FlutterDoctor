class Doctor {
  final String id;
  final String name;
  final String specialty;
  final String qualification;
  final String hospital;
  final int experienceYears;
  final double rating;
  final int consultationFee; // Set to 0 for now as requested
  final List<int> availableDaysOfWeek; // 1 = Mon, 7 = Sun
  final List<String> availableTimeSlots;

  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.qualification,
    required this.hospital,
    required this.experienceYears,
    required this.rating,
    this.consultationFee = 0,
    required this.availableDaysOfWeek,
    required this.availableTimeSlots,
  });

  /// Check if the doctor is available on a given DateTime
  bool isAvailableOn(DateTime date) {
    return availableDaysOfWeek.contains(date.weekday);
  }

  /// Parse live Doctor representation from backend /staff/doctors
  factory Doctor.fromDatabaseJson(Map<String, dynamic> json) {
    final avail = json['availability'] is Map ? json['availability'] as Map : {};
    final specs = json['specialties'] is List ? json['specialties'] as List : [];
    final specialty = specs.isNotEmpty ? specs.first.toString() : 'General Physician';
    final chamber = avail['chamber']?.toString() ?? 'Ashwini Central Hospital';
    final qualification = avail['qualification']?.toString() ?? (specs.length > 1 ? specs.sublist(1).join(', ') : 'MBBS, MD');
    final experience = (avail['experience_years'] as num?)?.toInt() ?? 8;

    return Doctor(
      id: json['user_id'] as String? ?? json['id'] as String? ?? '',
      name: json['full_name'] as String? ?? json['name'] as String? ?? 'Doctor',
      specialty: specialty,
      qualification: qualification,
      hospital: chamber.contains('Ashwini') ? chamber : 'Ashwini Central Hospital • $chamber',
      experienceYears: experience,
      rating: 4.9,
      consultationFee: 0,
      availableDaysOfWeek: const [1, 2, 3, 4, 5, 6],
      availableTimeSlots: const [
        '09:00 AM',
        '10:00 AM',
        '11:00 AM',
        '12:00 PM',
        '02:00 PM',
        '03:00 PM',
        '04:00 PM',
      ],
    );
  }
}

/// Represents a live 30-minute doctor scheduling slot with capacity tracking
class DoctorAvailabilitySlot {
  final String slotTime;
  final String timeLabel;
  final int capacity;
  final int bookedCount;
  final int remainingSpots;
  final String status; // 'available', 'fast_filling', 'full'
  final bool isBookable;
  final bool isPast;

  const DoctorAvailabilitySlot({
    required this.slotTime,
    required this.timeLabel,
    this.capacity = 3,
    required this.bookedCount,
    required this.remainingSpots,
    required this.status,
    required this.isBookable,
    this.isPast = false,
  });

  bool get isFull => remainingSpots <= 0 || status.toLowerCase() == 'full';

  String get capacityText {
    if (isPast) return 'Past slot';
    if (isFull) return 'FULL';
    if (remainingSpots == 1) return '1 spot left';
    return '$remainingSpots spots available';
  }

  factory DoctorAvailabilitySlot.fromJson(Map<String, dynamic> json) {
    final cap = (json['capacity'] as num?)?.toInt() ?? 3;
    final booked = (json['booked_count'] as num?)?.toInt() ?? 0;
    final remaining = (json['remaining_spots'] as num?)?.toInt() ?? (cap - booked);
    final stat = json['status']?.toString().toLowerCase() ?? (remaining <= 0 ? 'full' : 'available');
    final isBook = json['is_bookable'] as bool? ?? (remaining > 0);
    final past = json['is_past'] as bool? ?? false;

    return DoctorAvailabilitySlot(
      slotTime: json['slot_time']?.toString() ?? '09:00 AM',
      timeLabel: json['time_label']?.toString() ?? json['slot_time']?.toString() ?? '09:00 AM',
      capacity: cap,
      bookedCount: booked,
      remainingSpots: remaining,
      status: stat,
      isBookable: isBook,
      isPast: past,
    );
  }
}
