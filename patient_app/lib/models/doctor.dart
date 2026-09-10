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
}
