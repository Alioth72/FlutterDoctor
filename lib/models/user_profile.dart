import 'user_role.dart';
import '../theme/app_assets.dart';
import 'hospital_admin_repository.dart';

class UserProfile {
  final String phone;
  final String name;
  final String qualification;
  final String designation;
  final String profileImagePath;
  final UserRole role;
  final String hospitalId;
  final String hospitalName;
  final String password;

  UserProfile({
    required this.phone,
    required this.name,
    required this.qualification,
    required this.designation,
    required this.profileImagePath,
    required this.role,
    this.hospitalId = 'hosp_1',
    this.hospitalName = 'Ashwini Central Hospital',
    this.password = '1',
  });

  /// Mock database records
  static final Map<String, UserProfile> dbRecords = {
    '1234567890': UserProfile(
      phone: '1234567890',
      name: 'Dr. Rajesh V. Sharma',
      qualification: 'MBBS, MD (General Medicine), FACC',
      designation: 'Senior Consultant Physician & Cardiologist',
      profileImagePath: AppAssets.doctorProfile,
      role: UserRole.doctor,
      hospitalId: 'hosp_1',
      hospitalName: 'Ashwini Central Hospital',
      password: '1',
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
    '2345678902': UserProfile(
      phone: '2345678902',
      name: 'Admin Priya Singhal',
      qualification: 'MBA (Hospital Administration), AIIMS',
      designation: 'Chief Medical Administrator',
      profileImagePath: AppAssets.logo,
      role: UserRole.admin,
      hospitalId: 'hosp_2',
      hospitalName: 'AIIMS New Delhi',
      password: '1',
    ),
    '3456789012': UserProfile(
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
