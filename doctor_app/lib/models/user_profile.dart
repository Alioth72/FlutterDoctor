import 'user_role.dart';
import '../theme/app_assets.dart';
import 'hospital_admin_repository.dart';

class UserProfile {
  final String? userId;
  final String? patientId;
  final String? staffProfileId;
  final String? externalAuthId;
  final String phone;
  final String? phoneE164;
  final String name;
  final String qualification;
  final String designation;
  final String profileImagePath;
  final UserRole role;
  final String hospitalId;
  final String hospitalName;
  final String password;
  final String? token;
  final String? medicalRecordNumber;
  final String? bloodGroup;
  final String? licenseNumber;
  final List<String>? specialties;
  final String? chamber;
  final String? shiftTiming;
  final String? department;

  UserProfile({
    this.userId,
    this.patientId,
    this.staffProfileId,
    this.externalAuthId,
    required this.phone,
    this.phoneE164,
    required this.name,
    this.qualification = 'Healthcare Specialist',
    this.designation = 'Staff Member',
    this.profileImagePath = AppAssets.doctorProfile,
    required this.role,
    this.hospitalId = 'hosp_1',
    this.hospitalName = 'Ashwini Central Hospital',
    this.password = '1',
    this.token,
    this.medicalRecordNumber,
    this.bloodGroup,
    this.licenseNumber,
    this.specialties,
    this.chamber,
    this.shiftTiming,
    this.department,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json, {String? sessionToken}) {
    final rawRole = (json['role'] as String? ?? 'doctor').toLowerCase();
    UserRole role;
    if (rawRole == 'doctor') {
      role = UserRole.doctor;
    } else if (rawRole == 'nurse' || rawRole == 'worker' || rawRole == 'volunteer') {
      role = UserRole.worker;
    } else if (rawRole == 'admin') {
      role = UserRole.admin;
    } else {
      role = UserRole.patient;
    }

    final phoneStr = (json['phone_e164'] ?? json['phone'] ?? '').toString();
    final cleanPhone = phoneStr.replaceAll(RegExp(r'\D'), '');

    final availability = json['availability'] is Map ? json['availability'] as Map : {};
    final profileData = json['profile_data'] is Map ? json['profile_data'] as Map : {};

    List<String>? specialtiesList;
    if (json['specialties'] is List) {
      specialtiesList = (json['specialties'] as List).map((e) => e.toString()).toList();
    }

    final licenseNum = json['license_number']?.toString();
    final chamberVal = availability['chamber']?.toString() ?? profileData['chamber']?.toString();
    final shiftVal = availability['shift']?.toString() ?? profileData['shift']?.toString();
    final deptVal = (specialtiesList != null && specialtiesList.isNotEmpty)
        ? specialtiesList.first
        : (availability['department']?.toString() ?? profileData['department']?.toString() ?? 'General Medicine');

    String qual = json['qualification']?.toString() ?? 'Healthcare Specialist';
    String desig = json['designation']?.toString() ?? 'Staff Member';
    String img = AppAssets.logo;

    if (role == UserRole.doctor) {
      if (availability['qualification'] != null && availability['qualification'].toString().isNotEmpty) {
        qual = availability['qualification'].toString();
      } else if (profileData['qualification'] != null && profileData['qualification'].toString().isNotEmpty) {
        qual = profileData['qualification'].toString();
      } else if (specialtiesList != null && specialtiesList.isNotEmpty) {
        qual = 'MBBS, MD (${specialtiesList.join(', ')})';
      } else if (json['qualification'] != null && json['qualification'].toString().isNotEmpty) {
        qual = json['qualification'].toString();
      } else {
        qual = 'MBBS, MD (General Medicine)';
      }

      if (availability['designation'] != null && availability['designation'].toString().isNotEmpty) {
        desig = availability['designation'].toString();
      } else if (profileData['designation'] != null && profileData['designation'].toString().isNotEmpty) {
        desig = profileData['designation'].toString();
      } else if (specialtiesList != null && specialtiesList.isNotEmpty) {
        desig = 'Senior Consultant - ${specialtiesList.first}';
      } else if (json['designation'] != null && json['designation'].toString().isNotEmpty) {
        desig = json['designation'].toString();
      } else {
        desig = 'Senior Consultant Physician';
      }
      img = AppAssets.doctorProfile;
    } else if (role == UserRole.worker) {
      qual = json['qualification']?.toString() ?? 'ANM / Healthcare Specialist';
      desig = json['designation']?.toString() ?? 'Primary Field Healthcare Worker';
      img = AppAssets.logo;
    } else if (role == UserRole.admin) {
      qual = json['qualification']?.toString() ?? 'Hospital Administrator';
      desig = json['designation']?.toString() ?? 'Hospital IT Administration';
      img = AppAssets.logo;
    } else if (role == UserRole.patient) {
      qual = 'Registered Patient';
      desig = 'Patient (ID: ${json['medical_record_number'] ?? 'New'})';
      img = AppAssets.logo;
    }

    return UserProfile(
      userId: json['user_id']?.toString(),
      patientId: json['patient_id']?.toString(),
      staffProfileId: json['staff_profile_id']?.toString(),
      externalAuthId: json['external_auth_id']?.toString(),
      phone: cleanPhone.isNotEmpty ? cleanPhone : phoneStr,
      phoneE164: phoneStr,
      name: json['full_name']?.toString() ?? json['name']?.toString() ?? 'User',
      qualification: qual,
      designation: desig,
      profileImagePath: img,
      role: role,
      hospitalId: json['hospital_id']?.toString() ?? 'hosp_1',
      hospitalName: json['hospital_name']?.toString() ?? 'Ashwini Central Hospital',
      password: '1',
      token: sessionToken ?? json['token']?.toString(),
      medicalRecordNumber: json['medical_record_number']?.toString(),
      bloodGroup: json['blood_group']?.toString(),
      licenseNumber: licenseNum,
      specialties: specialtiesList,
      chamber: chamberVal,
      shiftTiming: shiftVal,
      department: deptVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'patient_id': patientId,
      'staff_profile_id': staffProfileId,
      'external_auth_id': externalAuthId,
      'phone': phone,
      'phone_e164': phoneE164,
      'full_name': name,
      'role': role.name,
      'token': token,
      'medical_record_number': medicalRecordNumber,
      'blood_group': bloodGroup,
      'license_number': licenseNumber,
      'specialties': specialties,
      'chamber': chamber,
      'shift_timing': shiftTiming,
      'department': department,
      'qualification': qualification,
      'designation': designation,
      'hospital_id': hospitalId,
      'hospital_name': hospitalName,
    };
  }

  /// Mock database records fallback
  static final Map<String, UserProfile> dbRecords = {
    '1234567890': UserProfile(
      userId: 'd7b4e3f1-2856-4c91-9e8a-729938b81001',
      staffProfileId: 'c1111111-2856-4c91-9e8a-729938b81001',
      externalAuthId: 'auth|staff|1234567890',
      phone: '1234567890',
      name: 'Dr. Rajesh V. Sharma',
      qualification: 'MBBS, MD (General Medicine), FACC',
      designation: 'Senior Consultant Physician & Cardiologist',
      profileImagePath: AppAssets.doctorProfile,
      role: UserRole.doctor,
      hospitalId: 'hosp_1',
      hospitalName: 'Ashwini Central Hospital',
      password: '1',
      licenseNumber: 'NMC-2008-048291',
    ),
    '2345678901': UserProfile(
      phone: '2345678901',
      name: 'Admin Vikram Sethi',
      qualification: 'M.Tech, CISSP (Health IT)',
      designation: 'Hospital Administrator',
      profileImagePath: AppAssets.logo,
      role: UserRole.admin,
      hospitalId: 'hosp_1',
      hospitalName: 'Ashwini Central Hospital',
      password: '1',
    ),
    '3456789012': UserProfile(
      userId: 'd7b4e3f1-2856-4c91-9e8a-729938b82001',
      phone: '3456789012',
      name: 'Worker Sunita Devi',
      qualification: 'ANM / Healthcare Specialist',
      designation: 'Primary Field Healthcare Worker',
      profileImagePath: AppAssets.logo,
      role: UserRole.worker,
      hospitalId: 'hosp_1',
      hospitalName: 'Ashwini Central Hospital',
      password: '1',
    ),
    '3456789013': UserProfile(
      userId: 'd7b4e3f1-2856-4c91-9e8a-729938b82002',
      phone: '3456789013',
      name: 'Worker Anita Sharma',
      qualification: 'GNM / Certified Community Health Officer',
      designation: 'Field Community Health Worker',
      profileImagePath: AppAssets.logo,
      role: UserRole.worker,
      hospitalId: 'hosp_1',
      hospitalName: 'Ashwini Central Hospital',
      password: '1',
    ),
  };

  /// Find user profile dynamically from repository or fallback
  static UserProfile? findProfile(String phone) {
    final cleaned = phone.trim().replaceAll(RegExp(r'\D'), '');

    if (dbRecords.containsKey(cleaned)) {
      return dbRecords[cleaned];
    }

    final entity = HospitalAdminRepository.findStaffOrAdminByPhone(cleaned);
    if (entity != null) {
      if (entity is HospitalDetailInfo) {
        return UserProfile(
          userId: entity.id,
          phone: entity.adminPhone,
          name: entity.adminName,
          qualification: 'Hospital System Administrator',
          designation: 'Hospital Chief Administrator',
          profileImagePath: AppAssets.logo,
          role: UserRole.admin,
          hospitalId: entity.id,
          hospitalName: entity.name,
          password: entity.adminPassword,
        );
      } else if (entity is HospitalAdminStaffDoctor) {
        return UserProfile(
          userId: entity.id,
          phone: entity.phone,
          name: entity.name,
          qualification: entity.qualification,
          designation: entity.designation,
          profileImagePath: AppAssets.doctorProfile,
          role: UserRole.doctor,
          hospitalId: entity.hospitalId,
          hospitalName: entity.hospitalName,
          password: entity.password,
        );
      } else if (entity is HospitalAdminStaffWorker) {
        return UserProfile(
          userId: entity.id,
          phone: entity.phone,
          name: entity.name,
          qualification: entity.qualification,
          designation: entity.designation,
          profileImagePath: AppAssets.logo,
          role: UserRole.worker,
          hospitalId: entity.hospitalId,
          hospitalName: entity.hospitalName,
          password: entity.password,
        );
      }
    }
    return null;
  }
}
