import '../models/doctor.dart';
import 'patient_database_service.dart';

class MockDoctorService {
  static List<Doctor>? _cachedLiveDoctors;

  static final List<Doctor> _doctors = [
    const Doctor(
      id: 'd7b4e3f1-2856-4c91-9e8a-729938b81001',
      name: 'Dr. Rajesh V. Sharma',
      specialty: 'Cardiology',
      qualification: 'MBBS, MD, DM (Cardiology)',
      hospital: 'Ashwini Central Hospital • Executive Chamber 104, Block A',
      experienceYears: 16,
      rating: 4.9,
      consultationFee: 0,
      availableDaysOfWeek: [1, 2, 3, 4, 5, 6], // Mon - Sat
      availableTimeSlots: [
        '08:00 AM',
        '08:30 AM',
        '09:00 AM',
        '09:30 AM',
        '10:00 AM',
        '10:30 AM',
        '11:00 AM',
        '11:30 AM',
        '12:00 PM',
        '12:30 PM',
        '01:00 PM',
        '01:30 PM',
      ],
      registrationNumber: 'NMC-2008-048291',
    ),
    const Doctor(
      id: 'd73f9fb2-c526-4134-ade9-370cd844310c',
      name: 'Dr. Mayank Kumar',
      specialty: 'Orthopedics',
      qualification: 'MBBS, MS (Orthopedics)',
      hospital: 'Ashwini Central Hospital • Chamber 700',
      experienceYears: 8,
      rating: 4.9,
      consultationFee: 0,
      availableDaysOfWeek: [1, 2, 3, 4, 5, 6],
      availableTimeSlots: [
        '08:00 AM',
        '08:30 AM',
        '09:00 AM',
        '09:30 AM',
        '10:00 AM',
        '10:30 AM',
        '11:00 AM',
        '11:30 AM',
        '12:00 PM',
        '12:30 PM',
        '01:00 PM',
        '01:30 PM',
        '02:00 PM',
        '02:30 PM',
      ],
      registrationNumber: 'NMC-2016-083912',
    ),
    const Doctor(
      id: '27e15e98-c7a1-4314-ae7b-bce893daa826',
      name: 'Dr. Faaiz Hussain',
      specialty: 'Cardiology',
      qualification: 'MBBS, MD',
      hospital: 'Ashwini Central Hospital • Chamber 108',
      experienceYears: 8,
      rating: 4.8,
      consultationFee: 0,
      availableDaysOfWeek: [1, 2, 3, 4, 5, 6],
      availableTimeSlots: [
        '08:00 AM',
        '08:30 AM',
        '09:00 AM',
        '09:30 AM',
        '10:00 AM',
        '10:30 AM',
        '11:00 AM',
        '11:30 AM',
        '12:00 PM',
        '12:30 PM',
        '01:00 PM',
        '01:30 PM',
      ],
      registrationNumber: 'NMC-2016-074921',
    ),
    const Doctor(
      id: '21072aa5-91a2-489d-a1fd-f6a2910e31cf',
      name: 'Dr. Aarushi Anand',
      specialty: 'Cardiology',
      qualification: 'MBBS, MD (Cardiology)',
      hospital: 'Ashwini Central Hospital • Chamber 108',
      experienceYears: 8,
      rating: 4.9,
      consultationFee: 0,
      availableDaysOfWeek: [1, 2, 3, 4, 5, 6],
      availableTimeSlots: [
        '08:00 AM',
        '08:30 AM',
        '09:00 AM',
        '09:30 AM',
        '10:00 AM',
        '10:30 AM',
        '11:00 AM',
        '11:30 AM',
        '12:00 PM',
        '12:30 PM',
        '01:00 PM',
        '01:30 PM',
      ],
      registrationNumber: 'NMC-2016-092814',
    ),
    const Doctor(
      id: 'acceab8c-e033-4e7b-b3dc-d1399a912730',
      name: 'Dr. Meera N. Deshmukh',
      specialty: 'Pediatrics',
      qualification: 'MBBS, MD (Pediatrics), DNB',
      hospital: 'Ashwini Central Hospital • Chamber 205, Child Care Unit',
      experienceYears: 14,
      rating: 4.9,
      consultationFee: 0,
      availableDaysOfWeek: [1, 2, 3, 4, 5],
      availableTimeSlots: [
        '10:00 AM',
        '10:30 AM',
        '11:00 AM',
        '11:30 AM',
        '12:00 PM',
        '12:30 PM',
        '02:00 PM',
        '02:30 PM',
        '03:00 PM',
        '03:30 PM',
        '04:00 PM',
        '04:30 PM',
      ],
      registrationNumber: 'NMC-2010-051829',
    ),
    const Doctor(
      id: '3d0c6879-9155-4bd6-8576-57a64db702a3',
      name: 'Dr. Sunil K. Nambiar',
      specialty: 'Pulmonology',
      qualification: 'MBBS, MD (Pulmonology)',
      hospital: 'Ashwini Central Hospital • Chamber 114, Trauma Wing',
      experienceYears: 12,
      rating: 4.8,
      consultationFee: 0,
      availableDaysOfWeek: [1, 2, 3, 4, 5, 6],
      availableTimeSlots: [
        '09:00 AM',
        '09:30 AM',
        '10:00 AM',
        '10:30 AM',
        '11:00 AM',
        '11:30 AM',
        '01:00 PM',
        '01:30 PM',
        '02:00 PM',
        '02:30 PM',
        '03:00 PM',
        '03:30 PM',
      ],
      registrationNumber: 'NMC-2012-067823',
    ),
    const Doctor(
      id: 'd7b4e3f1-2856-4c91-9e8a-729938b81002',
      name: 'Dr. Ananya Iyer',
      specialty: 'Neurology',
      qualification: 'MBBS, DM (Neurology)',
      hospital: 'Ashwini Central Hospital • Chamber 208, Neuro Wing',
      experienceYears: 10,
      rating: 4.8,
      consultationFee: 0,
      availableDaysOfWeek: [1, 2, 3, 4, 5, 6],
      availableTimeSlots: [
        '09:00 AM',
        '09:30 AM',
        '10:00 AM',
        '10:30 AM',
        '11:00 AM',
        '11:30 AM',
        '01:00 PM',
        '01:30 PM',
        '02:00 PM',
        '02:30 PM',
      ],
      registrationNumber: 'NMC-2014-062819',
    ),
  ];

  /// Get all registered doctors (prefers live Azure database, falls back to local)
  Future<List<Doctor>> getDoctors({String? specialty}) async {
    try {
      if (_cachedLiveDoctors == null || _cachedLiveDoctors!.isEmpty) {
        final live = await PatientDatabaseService().fetchDoctors();
        if (live.isNotEmpty) {
          _cachedLiveDoctors = live;
        }
      }
    } catch (_) {}

    final list = (_cachedLiveDoctors != null && _cachedLiveDoctors!.isNotEmpty)
        ? _cachedLiveDoctors!
        : _doctors;

    if (specialty == null || specialty.isEmpty || specialty == 'All') {
      return list;
    }
    return list
        .where((d) => d.specialty.toLowerCase().contains(specialty.toLowerCase()))
        .toList();
  }

  /// Get unique specialty categories
  List<String> getSpecialties() {
    final list = (_cachedLiveDoctors != null && _cachedLiveDoctors!.isNotEmpty)
        ? _cachedLiveDoctors!
        : _doctors;

    final set = <String>{'All'};
    for (final doc in list) {
      set.add(doc.specialty.split(' (')[0].split(' •')[0]);
    }
    return set.toList();
  }

  /// Get a single doctor by ID
  Doctor? getDoctorById(String id) {
    final list = (_cachedLiveDoctors != null && _cachedLiveDoctors!.isNotEmpty)
        ? _cachedLiveDoctors!
        : _doctors;
    try {
      return list.firstWhere(
        (d) => d.id == id,
        orElse: () {
          if (id == 'doc_1' || id == 'doc_cardio') return list.first;
          throw StateError('Doctor not found');
        },
      );
    } catch (_) {
      return null;
    }
  }
}
