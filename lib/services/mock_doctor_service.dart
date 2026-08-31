import '../models/doctor.dart';

class MockDoctorService {
  static final List<Doctor> _doctors = [
    const Doctor(
      id: 'doc_1',
      name: 'Dr. Ananya Sharma',
      specialty: 'General Physician',
      qualification: 'MBBS, MD (Internal Medicine)',
      hospital: 'City Civil Hospital, Block A',
      experienceYears: 12,
      rating: 4.8,
      consultationFee: 0,
      availableDaysOfWeek: [1, 2, 3, 4, 5, 6], // Mon - Sat
      availableTimeSlots: [
        '09:00 AM',
        '09:30 AM',
        '10:00 AM',
        '10:30 AM',
        '11:30 AM',
        '02:00 PM',
        '03:00 PM',
        '04:30 PM',
      ],
    ),
    const Doctor(
      id: 'doc_2',
      name: 'Dr. Rajesh Verma',
      specialty: 'Cardiologist',
      qualification: 'MBBS, DM (Cardiology)',
      hospital: 'District Multi-Speciality Hospital',
      experienceYears: 16,
      rating: 4.9,
      consultationFee: 0,
      availableDaysOfWeek: [1, 3, 5], // Mon, Wed, Fri
      availableTimeSlots: [
        '10:00 AM',
        '11:00 AM',
        '12:00 PM',
        '03:00 PM',
        '04:00 PM',
        '05:00 PM',
      ],
    ),
    const Doctor(
      id: 'doc_3',
      name: 'Dr. Priya Nair',
      specialty: 'Pediatrician (Child Specialist)',
      qualification: 'MBBS, DCH, DNB (Pediatrics)',
      hospital: 'Mother & Child Community Health Centre',
      experienceYears: 9,
      rating: 4.7,
      consultationFee: 0,
      availableDaysOfWeek: [1, 2, 3, 4, 5], // Mon - Fri
      availableTimeSlots: [
        '09:30 AM',
        '10:30 AM',
        '11:30 AM',
        '02:30 PM',
        '03:30 PM',
      ],
    ),
    const Doctor(
      id: 'doc_4',
      name: 'Dr. Suresh Mehta',
      specialty: 'Orthopedic Surgeon',
      qualification: 'MBBS, MS (Orthopedics)',
      hospital: 'Apex Trauma & Joint Care Centre',
      experienceYears: 14,
      rating: 4.8,
      consultationFee: 0,
      availableDaysOfWeek: [2, 4, 6], // Tue, Thu, Sat
      availableTimeSlots: [
        '10:00 AM',
        '11:30 AM',
        '02:00 PM',
        '03:30 PM',
        '05:00 PM',
      ],
    ),
    const Doctor(
      id: 'doc_5',
      name: 'Dr. Kavita Deshmukh',
      specialty: 'Gynecologist & Obstetrician',
      qualification: 'MBBS, MS (OBG)',
      hospital: 'Govt Maternity & Women Hospital',
      experienceYears: 11,
      rating: 4.9,
      consultationFee: 0,
      availableDaysOfWeek: [1, 2, 3, 5, 6], // Mon, Tue, Wed, Fri, Sat
      availableTimeSlots: [
        '09:00 AM',
        '10:00 AM',
        '11:00 AM',
        '01:30 PM',
        '02:30 PM',
        '04:00 PM',
      ],
    ),
    const Doctor(
      id: 'doc_6',
      name: 'Dr. Amitav Sen',
      specialty: 'Dermatologist',
      qualification: 'MBBS, MD (Dermatology)',
      hospital: 'Skin & Allergy Care Dispensary',
      experienceYears: 8,
      rating: 4.6,
      consultationFee: 0,
      availableDaysOfWeek: [1, 3, 4, 6], // Mon, Wed, Thu, Sat
      availableTimeSlots: [
        '10:30 AM',
        '11:30 AM',
        '03:00 PM',
        '04:00 PM',
      ],
    ),
  ];

  /// Get all registered doctors
  Future<List<Doctor>> getDoctors({String? specialty}) async {
    // Simulated short network delay
    await Future.delayed(const Duration(milliseconds: 100));
    if (specialty == null || specialty.isEmpty || specialty == 'All') {
      return _doctors;
    }
    return _doctors
        .where((d) => d.specialty.toLowerCase().contains(specialty.toLowerCase()))
        .toList();
  }

  /// Get unique specialty categories
  List<String> getSpecialties() {
    final set = <String>{'All'};
    for (final doc in _doctors) {
      set.add(doc.specialty.split(' (')[0]);
    }
    return set.toList();
  }

  /// Get a single doctor by ID
  Doctor? getDoctorById(String id) {
    try {
      return _doctors.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}
