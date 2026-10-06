
class HospitalAdminStaffDoctor {
  final String id;
  String name;
  String phone;
  String password;
  String department;
  String qualification;
  String designation;
  int experienceYears;
  String chamberNo;
  String hospitalId;
  String hospitalName;
  bool isOnDuty;
  String shiftTiming;
  String email;
  String? licenseNumber;

  HospitalAdminStaffDoctor({
    required this.id,
    required this.name,
    required this.phone,
    required this.password,
    required this.department,
    required this.qualification,
    required this.designation,
    required this.experienceYears,
    required this.chamberNo,
    required this.hospitalId,
    required this.hospitalName,
    this.isOnDuty = true,
    required this.shiftTiming,
    required this.email,
    this.licenseNumber,
  });
}

class HospitalAdminStaffWorker {
  final String id;
  String name;
  String phone;
  String password;
  String qualification;
  String designation;
  String assignedWard;
  String hospitalId;
  String hospitalName;
  bool isOnDuty;
  String shiftTiming;
  String email;

  HospitalAdminStaffWorker({
    required this.id,
    required this.name,
    required this.phone,
    required this.password,
    required this.qualification,
    required this.designation,
    required this.assignedWard,
    required this.hospitalId,
    required this.hospitalName,
    this.isOnDuty = true,
    required this.shiftTiming,
    required this.email,
  });
}

class HospitalAdminPatient {
  final String id;
  String name;
  String phone;
  String password; // PIN or portal access password
  int age;
  String gender;
  String diagnosis;
  String department;
  String hospitalId;
  String hospitalName;
  String roomNo;
  String bedNo;
  bool isAdmitted;
  String assignedDoctor;
  String? assignedDoctorUserId;
  String admissionDate;
  String? forwardedToDoctor;
  String? forwardSpecialty;
  String? forwardReason;
  String? forwardDate;
  String? urgency;
  Map<String, String>? vitals;
  String? medicalRecordNumber;
  String? bloodGroup;

  HospitalAdminPatient({
    required this.id,
    required this.name,
    required this.phone,
    required this.password,
    required this.age,
    required this.gender,
    required this.diagnosis,
    required this.department,
    required this.hospitalId,
    required this.hospitalName,
    required this.roomNo,
    required this.bedNo,
    this.isAdmitted = false,
    required this.assignedDoctor,
    this.assignedDoctorUserId,
    required this.admissionDate,
    this.forwardedToDoctor,
    this.forwardSpecialty,
    this.forwardReason,
    this.forwardDate,
    this.urgency,
    this.vitals,
    this.medicalRecordNumber,
    this.bloodGroup,
  });
}

class HospitalShiftItem {
  final String id;
  String staffId;
  String staffName;
  String staffRole; // 'Doctor' or 'Worker'
  String hospitalId;
  String department;
  String roomOrWard;
  DateTime date;
  String timeSlot; // '08:00 AM - 02:00 PM', etc.
  String status; // 'Active', 'Scheduled', 'Completed'

  HospitalShiftItem({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.staffRole,
    required this.hospitalId,
    required this.department,
    required this.roomOrWard,
    required this.date,
    required this.timeSlot,
    this.status = 'Active',
  });
}

class HospitalDetailInfo {
  final String id;
  final String name;
  final String branch;
  final String address;
  final String contactPhone;
  final String emergencyHotline;
  final String adminName;
  final String adminPhone;
  final String adminPassword;
  final String licenseNumber;
  final List<String> departments;
  final int totalBeds;
  final int occupiedBeds;

  HospitalDetailInfo({
    required this.id,
    required this.name,
    required this.branch,
    required this.address,
    required this.contactPhone,
    required this.emergencyHotline,
    required this.adminName,
    required this.adminPhone,
    required this.adminPassword,
    required this.licenseNumber,
    required this.departments,
    required this.totalBeds,
    required this.occupiedBeds,
  });
}

class HospitalAdminRepository {
  static final List<HospitalDetailInfo> _hospitals = [
    HospitalDetailInfo(
      id: 'hosp_1',
      name: 'Ashwini Central Hospital',
      branch: 'Super-Speciality Block',
      address: 'Sector 14, Main Institutional Area, New Delhi',
      contactPhone: '+91 11 2658 8500',
      emergencyHotline: '1066 / +91 11 2658 9999',
      adminName: 'Admin Vikram Sethi',
      adminPhone: '2345678901',
      adminPassword: '1',
      licenseNumber: 'DEL-HOSP-2024-8891',
      departments: [
        'Cardiology',
        'Intensive Care (ICU)',
        'General Medicine',
        'Emergency & Trauma',
        'Pulmonology',
        'Neurology',
        'Orthopedics',
        'Pediatrics',
      ],
      totalBeds: 240,
      occupiedBeds: 184,
    ),
    HospitalDetailInfo(
      id: 'hosp_2',
      name: 'AIIMS New Delhi',
      branch: 'Cardio-Thoracic & Neurosciences Centre',
      address: 'Ansari Nagar East, New Delhi - 110029',
      contactPhone: '+91 11 2658 8700',
      emergencyHotline: '102 / +91 11 2659 3333',
      adminName: 'Admin Priya Singhal',
      adminPhone: '2345678902',
      adminPassword: '1',
      licenseNumber: 'AIIMS-ND-GOV-001',
      departments: ['Cardiology', 'ICU', 'General Medicine', 'Neurology', 'Emergency'],
      totalBeds: 500,
      occupiedBeds: 462,
    ),
    HospitalDetailInfo(
      id: 'hosp_3',
      name: 'Metro Healthcare OPD',
      branch: 'Consultant Clinical Annex',
      address: 'Ring Road, South City, New Delhi',
      contactPhone: '+91 11 4100 2200',
      emergencyHotline: '+91 11 4100 9911',
      adminName: 'Admin Ramesh Nair',
      adminPhone: '2345678903',
      adminPassword: '1',
      licenseNumber: 'METRO-OPD-7721',
      departments: ['General Medicine', 'Cardiology', 'Pulmonology', 'Dermatology'],
      totalBeds: 80,
      occupiedBeds: 45,
    ),
    HospitalDetailInfo(
      id: 'hosp_4',
      name: 'Apollo Multi-Speciality',
      branch: 'Sarita Vihar Wing',
      address: 'Mathura Road, New Delhi',
      contactPhone: '+91 11 2692 5858',
      emergencyHotline: '1066',
      adminName: 'Admin Sneha Kapoor',
      adminPhone: '2345678904',
      adminPassword: '1',
      licenseNumber: 'APOLLO-SV-4402',
      departments: ['ICU', 'Cardiology', 'Emergency', 'Orthopedics'],
      totalBeds: 350,
      occupiedBeds: 290,
    ),
  ];

  static final List<HospitalAdminStaffDoctor> _doctors = [
    HospitalAdminStaffDoctor(
      id: 'd7b4e3f1-2856-4c91-9e8a-729938b81001',
      name: 'Dr. Rajesh V. Sharma',
      phone: '1234567890',
      password: '1',
      department: 'Cardiology',
      qualification: 'MBBS, MD (General Medicine), FACC',
      designation: 'Senior Consultant Cardiologist',
      experienceYears: 16,
      chamberNo: 'Chamber 104, OPD Block A',
      hospitalId: 'hosp_1',
      hospitalName: 'Ashwini Central Hospital',
      isOnDuty: true,
      shiftTiming: '08:00 AM - 02:00 PM',
      email: 'rajesh.sharma@ashwinihospital.org',
      licenseNumber: 'NMC-2008-048291',
    ),
    HospitalAdminStaffDoctor(
      id: 'd7b4e3f1-2856-4c91-9e8a-729938b81002',
      name: 'Dr. Ananya Iyer',
      phone: '9876543210',
      password: '1',
      department: 'Neurology',
      qualification: 'MBBS, DM (Neurology), AIIMS',
      designation: 'Chief Consultant Neurologist',
      experienceYears: 14,
      chamberNo: 'Chamber 208, Neuro Wing',
      hospitalId: 'hosp_1',
      hospitalName: 'Ashwini Central Hospital',
      isOnDuty: true,
      shiftTiming: '09:00 AM - 03:00 PM',
      email: 'ananya.iyer@ashwinihospital.org',
      licenseNumber: 'NMC-2010-062819',
    ),
    HospitalAdminStaffDoctor(
      id: '2dfef2f1-ecae-4ece-aed1-cf102412ea20',
      name: 'Dr. Mayank',
      phone: '7303470204',
      password: '1',
      department: 'Orthopedics',
      qualification: 'MBBS, MS (Orthopedics)',
      designation: 'Senior Orthopedic Surgeon',
      experienceYears: 8,
      chamberNo: 'Chamber 115, Trauma Block',
      hospitalId: 'hosp_1',
      hospitalName: 'Ashwini Central Hospital',
      isOnDuty: true,
      shiftTiming: '08:00 AM - 02:00 PM',
      email: 'mayank@ashwinihospital.org',
      licenseNumber: 'NMC-2016-083912',
    ),
  ];

  static final List<HospitalAdminStaffWorker> _workers = [
    HospitalAdminStaffWorker(
      id: 'd7b4e3f1-2856-4c91-9e8a-729938b82001',
      name: 'Worker Sunita Devi',
      phone: '3456789012',
      password: '1',
      qualification: 'ANM / Healthcare Specialist (10+ Yrs)',
      designation: 'Primary Field Healthcare Worker',
      assignedWard: 'Ward A & Field Primary Health Unit',
      hospitalId: 'hosp_1',
      hospitalName: 'Ashwini Central Hospital',
      isOnDuty: true,
      shiftTiming: '07:30 AM - 03:30 PM',
      email: 'sunita.devi@ashwinihospital.org',
    ),
    HospitalAdminStaffWorker(
      id: 'd7b4e3f1-2856-4c91-9e8a-729938b82002',
      name: 'Worker Anita Sharma',
      phone: '3456789013',
      password: '1',
      qualification: 'GNM / Certified Community Health Officer',
      designation: 'Community Health Field Officer',
      assignedWard: 'OPD Annex & Community Field Outreach',
      hospitalId: 'hosp_1',
      hospitalName: 'Ashwini Central Hospital',
      isOnDuty: true,
      shiftTiming: '08:00 AM - 04:00 PM',
      email: 'anita.sharma@ashwinihospital.org',
    ),
  ];

  static final List<HospitalAdminPatient> _patients = [
    HospitalAdminPatient(
      id: '14-2026-4512-8821',
      name: 'Rajesh Sharma',
      phone: '9988776655',
      password: '1234',
      age: 45,
      gender: 'Male',
      diagnosis: 'Essential Hypertension & Angina Pectoris',
      department: 'Cardiology',
      hospitalId: 'hosp_1',
      hospitalName: 'Ashwini Central Hospital',
      roomNo: 'Room C-101',
      bedNo: 'Bed 1',
      isAdmitted: true,
      assignedDoctor: 'Dr. Rajesh V. Sharma',
      assignedDoctorUserId: 'd7b4e3f1-2856-4c91-9e8a-729938b81001',
      admissionDate: '02 Sep 2026',
      medicalRecordNumber: '14-2026-4512-8821',
      vitals: {'BP': '138/88', 'Pulse': '76 bpm', 'SpO2': '98%', 'Temp': '98.4 F'},
    ),
    HospitalAdminPatient(
      id: '14-2026-8821-3309',
      name: 'Priya Verma',
      phone: '9977665544',
      password: '1234',
      age: 32,
      gender: 'Female',
      diagnosis: 'Acute Bronchial Asthma with Exertional Dyspnea',
      department: 'Pulmonology',
      hospitalId: 'hosp_1',
      hospitalName: 'Ashwini Central Hospital',
      roomNo: 'Room C-102',
      bedNo: 'Bed 2',
      isAdmitted: true,
      assignedDoctor: 'Dr. Rajesh V. Sharma',
      assignedDoctorUserId: 'd7b4e3f1-2856-4c91-9e8a-729938b81001',
      admissionDate: '04 Sep 2026',
      medicalRecordNumber: '14-2026-8821-3309',
      vitals: {'BP': '118/74', 'Pulse': '88 bpm', 'SpO2': '95%', 'Temp': '98.6 F'},
    ),
  ];

  static final List<HospitalShiftItem> _shifts = [
    HospitalShiftItem(
      id: 'sh_1',
      staffId: 'doc_1',
      staffName: 'Dr. Rajesh V. Sharma',
      staffRole: 'Doctor',
      hospitalId: 'hosp_1',
      department: 'Cardiology',
      roomOrWard: 'Chamber 104 / Cardiac Bay',
      date: DateTime.now(),
      timeSlot: 'Morning (08:00 AM - 02:00 PM)',
      status: 'Active',
    ),
    HospitalShiftItem(
      id: 'sh_2',
      staffId: 'doc_2',
      staffName: 'Dr. Ananya Iyer',
      staffRole: 'Doctor',
      hospitalId: 'hosp_1',
      department: 'Neurology',
      roomOrWard: 'Chamber 208, Neuro Wing',
      date: DateTime.now(),
      timeSlot: 'Morning (09:00 AM - 03:00 PM)',
      status: 'Active',
    ),
    HospitalShiftItem(
      id: 'sh_3',
      staffId: 'doc_3',
      staffName: 'Dr. Rohan Kapoor',
      staffRole: 'Doctor',
      hospitalId: 'hosp_1',
      department: 'Pulmonology',
      roomOrWard: 'Chamber 302, Chest Clinic',
      date: DateTime.now(),
      timeSlot: 'Evening (02:00 PM - 08:00 PM)',
      status: 'Scheduled',
    ),
    HospitalShiftItem(
      id: 'sh_4',
      staffId: 'work_1',
      staffName: 'Worker Sunita Devi',
      staffRole: 'Worker',
      hospitalId: 'hosp_1',
      department: 'General & Field Health',
      roomOrWard: 'Ward A & Field Clinic',
      date: DateTime.now(),
      timeSlot: 'Morning (07:30 AM - 03:30 PM)',
      status: 'Active',
    ),
    HospitalShiftItem(
      id: 'sh_5',
      staffId: 'work_2',
      staffName: 'Worker Manoj Kumar',
      staffRole: 'Worker',
      hospitalId: 'hosp_1',
      department: 'Community Outreach',
      roomOrWard: 'OPD Annex & Mobile Field',
      date: DateTime.now(),
      timeSlot: 'Morning (08:00 AM - 04:00 PM)',
      status: 'Active',
    ),
    HospitalShiftItem(
      id: 'sh_6',
      staffId: 'work_3',
      staffName: 'Worker Reena Kumari',
      staffRole: 'Worker',
      hospitalId: 'hosp_1',
      department: 'Maternal Care',
      roomOrWard: 'Maternity Field Unit',
      date: DateTime.now(),
      timeSlot: 'Evening (02:00 PM - 10:00 PM)',
      status: 'Scheduled',
    ),
  ];

  // --- QUERY METHODS SCOPED BY HOSPITAL ---

  static HospitalDetailInfo getHospitalDetails(String hospitalId) {
    return _hospitals.firstWhere(
      (h) => h.id == hospitalId,
      orElse: () => _hospitals.first,
    );
  }

  static List<HospitalAdminStaffDoctor> getDoctors(String hospitalId) {
    return _doctors.where((d) => d.hospitalId == hospitalId).toList();
  }

  static List<HospitalAdminStaffDoctor> getAllDoctors() {
    return List.unmodifiable(_doctors);
  }

  static List<HospitalAdminStaffWorker> getWorkers(String hospitalId) {
    return _workers.where((w) => w.hospitalId == hospitalId).toList();
  }

  static List<HospitalAdminPatient> getPatients(String hospitalId) {
    return _patients.where((p) => p.hospitalId == hospitalId).toList();
  }

  static List<HospitalShiftItem> getShifts(String hospitalId) {
    return _shifts.where((s) => s.hospitalId == hospitalId).toList();
  }

  // --- ADMIN ACTIONS: ADD & REMOVE ---

  static void addDoctor(HospitalAdminStaffDoctor doc) {
    _doctors.removeWhere((d) => d.id == doc.id || d.phone == doc.phone);
    _doctors.insert(0, doc);
  }

  static void updateDoctor(HospitalAdminStaffDoctor doc) {
    final idx = _doctors.indexWhere((d) => d.id == doc.id || d.phone == doc.phone);
    if (idx != -1) {
      _doctors[idx] = doc;
    } else {
      _doctors.insert(0, doc);
    }
  }

  static void syncLiveDoctors(List<HospitalAdminStaffDoctor> liveDoctors, String hospitalId) {
    _doctors.removeWhere((d) => d.hospitalId == hospitalId);
    _doctors.insertAll(0, liveDoctors);
  }

  static void syncLivePatients(List<HospitalAdminPatient> livePatients, String hospitalId) {
    _patients.removeWhere((p) => p.hospitalId == hospitalId);
    _patients.insertAll(0, livePatients);
  }

  static void removeDoctor(String docId) {
    _doctors.removeWhere((d) => d.id == docId);
    _shifts.removeWhere((s) => s.staffId == docId);
  }

  static void addWorker(HospitalAdminStaffWorker worker) {
    _workers.removeWhere((w) => w.id == worker.id || w.phone == worker.phone);
    _workers.insert(0, worker);
  }

  static void removeWorker(String workerId) {
    _workers.removeWhere((w) => w.id == workerId);
    _shifts.removeWhere((s) => s.staffId == workerId);
  }

  static void addPatient(HospitalAdminPatient patient) {
    _patients.removeWhere((p) => p.id == patient.id);
    _patients.insert(0, patient);
  }

  static void removePatient(String patientId) {
    _patients.removeWhere((p) => p.id == patientId);
  }

  static void toggleStaffDuty(String staffId, bool isDoctor) {
    if (isDoctor) {
      final index = _doctors.indexWhere((d) => d.id == staffId);
      if (index != -1) {
        _doctors[index].isOnDuty = !_doctors[index].isOnDuty;
      }
    } else {
      final index = _workers.indexWhere((w) => w.id == staffId);
      if (index != -1) {
        _workers[index].isOnDuty = !_workers[index].isOnDuty;
      }
    }
  }

  static void addShift(HospitalShiftItem shift) {
    _shifts.insert(0, shift);
  }

  static void removeShift(String shiftId) {
    _shifts.removeWhere((s) => s.id == shiftId);
  }

  // --- WORKER ACTION: FORWARD PATIENT TO SPECIALIST DOCTOR ---

  static void forwardPatientToDoctor({
    required String patientId,
    required String targetDoctorId,
    required String targetDoctorName,
    required String specialty,
    required String reason,
    required String urgency,
    required String forwardedByWorker,
  }) {
    final index = _patients.indexWhere((p) => p.id == patientId);
    if (index != -1) {
      _patients[index].forwardedToDoctor = targetDoctorName;
      _patients[index].forwardSpecialty = specialty;
      _patients[index].forwardReason = reason;
      _patients[index].urgency = urgency;
      _patients[index].forwardDate = 'Today, Just Now (${urgency.toUpperCase()})';
      _patients[index].assignedDoctor = targetDoctorName;
    }
  }

  // --- AUTHENTICATION LOOKUP ---

  static dynamic findStaffOrAdminByPhone(String phone) {
    final cleaned = phone.trim().replaceAll(RegExp(r'\D'), '');

    // 1. Check Admins
    for (final h in _hospitals) {
      if (h.adminPhone == cleaned) {
        return h;
      }
    }
    // 2. Check Doctors
    for (final d in _doctors) {
      if (d.phone == cleaned) {
        return d;
      }
    }
    // 3. Check Workers
    for (final w in _workers) {
      if (w.phone == cleaned) {
        return w;
      }
    }
    return null;
  }
}
