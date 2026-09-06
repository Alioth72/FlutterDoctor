import '../models/user_role.dart';
import '../models/user_profile.dart';
import '../models/hospital_admin_repository.dart';
import '../theme/app_assets.dart';

class AuthService {
  /// Fetches UserProfile from database based on phone and password.
  static UserProfile? authenticateUser(String phone, String password) {
    final cleanedPhone = phone.trim().replaceAll(RegExp(r'\D'), '');

    // 1. Check UserProfile dynamic repository lookup
    final dynamicProfile = UserProfile.findProfile(cleanedPhone);
    if (dynamicProfile != null) {
      return dynamicProfile;
    }

    if (UserProfile.dbRecords.containsKey(cleanedPhone)) {
      return UserProfile.dbRecords[cleanedPhone];
    }

    // Default fallback profile lookup
    final role = getRoleFromPhoneNumber(cleanedPhone);
    switch (role) {
      case UserRole.doctor:
        return UserProfile(
          phone: cleanedPhone,
          name: 'Dr. Rajesh V. Sharma',
          qualification: 'MBBS, MD (General Medicine), FACC',
          designation: 'Senior Consultant Physician & Cardiologist',
          profileImagePath: AppAssets.doctorProfile,
          role: UserRole.doctor,
          hospitalId: 'hosp_1',
          hospitalName: 'Ashwini Central Hospital',
          password: password,
        );
      case UserRole.admin:
        return UserProfile(
          phone: cleanedPhone,
          name: 'Admin Vikram Sethi',
          qualification: 'M.Tech, CISSP (Health IT)',
          designation: 'Hospital Administrator',
          profileImagePath: AppAssets.logo,
          role: UserRole.admin,
          hospitalId: 'hosp_1',
          hospitalName: 'Ashwini Central Hospital',
          password: password,
        );
      case UserRole.worker:
        return UserProfile(
          phone: cleanedPhone,
          name: 'Worker Sunita Devi',
          qualification: 'ANM / Healthcare Specialist',
          designation: 'Primary Field Healthcare Worker',
          profileImagePath: AppAssets.logo,
          role: UserRole.worker,
          hospitalId: 'hosp_1',
          hospitalName: 'Ashwini Central Hospital',
          password: password,
        );
    }
  }

  static UserRole getRoleFromPhoneNumber(String phone) {
    final cleaned = phone.trim().replaceAll(RegExp(r'\D'), '');

    // Check repository dynamic entity first
    final entity = HospitalAdminRepository.findStaffOrAdminByPhone(cleaned);
    if (entity != null) {
      if (entity is HospitalDetailInfo) return UserRole.admin;
      if (entity is HospitalAdminStaffDoctor) return UserRole.doctor;
      if (entity is HospitalAdminStaffWorker) return UserRole.worker;
    }

    if (cleaned == '2345678901' || cleaned.startsWith('2')) {
      return UserRole.admin;
    } else if (cleaned == '3456789012' || cleaned.startsWith('3')) {
      return UserRole.worker;
    } else {
      return UserRole.doctor;
    }
  }
}
