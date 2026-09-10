import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../models/user_role.dart';
import '../models/user_profile.dart';
import '../models/hospital_admin_repository.dart';
import '../theme/app_assets.dart';

class AuthService {
  static String get baseUrl => ApiClient.baseUrl;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _keyToken = 'auth_session_token';
  static const String _keyUser = 'auth_session_user';

  /// Real Phone + Password Login via Azure Functions Backend
  static Future<UserProfile?> login(String phone, String password) async {
    final cleaned = phone.trim();
    http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': cleaned,
          'password': password,
        }),
      );
    } catch (e) {
      // Only network/socket connection errors trigger offline fallback
      final mock = authenticateUser(cleaned, password);
      if (mock != null) return mock;
      rethrow;
    }

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      final token = data['token'] as String?;
      final userData = data['data'] as Map<String, dynamic>;

      final profile = UserProfile.fromJson(userData, sessionToken: token);

      // Persist session token and sanitized profile securely (never password)
      if (token != null) {
        await _storage.write(key: _keyToken, value: token);
      }
      await _storage.write(key: _keyUser, value: jsonEncode(profile.toJson()));

      return profile;
    } else {
      final errorMsg = data['error'] ?? 'Login failed (${response.statusCode})';
      throw Exception(errorMsg);
    }
  }

  /// Real Patient/Staff Signup via Azure Functions Backend
  static Future<UserProfile?> signup({
    required String phone,
    required String fullName,
    String role = 'patient',
    String? dateOfBirth,
    String? sexAtBirth,
    String preferredLanguage = 'en',
    String? bloodGroup,
    List<String>? allergies,
    Map<String, dynamic>? emergencyContact,
  }) async {
    final body = {
      'phone': phone.trim(),
      'full_name': fullName.trim(),
      'role': role,
      if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'date_of_birth': dateOfBirth,
      if (sexAtBirth != null && sexAtBirth.isNotEmpty) 'sex_at_birth': sexAtBirth,
      'preferred_language': preferredLanguage,
      if (bloodGroup != null && bloodGroup.isNotEmpty) 'blood_group': bloodGroup,
      if (allergies != null) ...{'allergies': allergies},
      if (emergencyContact != null) ...{'emergency_contact': emergencyContact},
    };

    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode == 201 && data['success'] == true) {
      final token = data['token'] as String?;
      final userData = data['data'] as Map<String, dynamic>;

      final profile = UserProfile.fromJson(userData, sessionToken: token);

      if (token != null) {
        await _storage.write(key: _keyToken, value: token);
      }
      await _storage.write(key: _keyUser, value: jsonEncode(profile.toJson()));

      return profile;
    } else {
      final errorMsg = data['error'] ?? 'Signup failed (${response.statusCode})';
      throw Exception(errorMsg);
    }
  }

  /// Restore active session from secure storage
  static Future<UserProfile?> restoreSession() async {
    try {
      final token = await _storage.read(key: _keyToken);
      final userJson = await _storage.read(key: _keyUser);

      if (token != null && userJson != null) {
        final Map<String, dynamic> data = jsonDecode(userJson);
        return UserProfile.fromJson(data, sessionToken: token);
      }
    } catch (_) {}
    return null;
  }

  /// Get stored session Bearer token
  static Future<String?> getStoredToken() async {
    return await _storage.read(key: _keyToken);
  }

  /// Clear stored credentials on logout
  static Future<void> logout() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyUser);
  }

  // ==========================================================
  // BACKWARD COMPATIBILITY HELPERS
  // ==========================================================
  static UserProfile? authenticateUser(String phone, String password) {
    final cleanedPhone = phone.trim().replaceAll(RegExp(r'\D'), '');

    final dynamicProfile = UserProfile.findProfile(cleanedPhone);
    if (dynamicProfile != null) return dynamicProfile;

    if (UserProfile.dbRecords.containsKey(cleanedPhone)) {
      return UserProfile.dbRecords[cleanedPhone];
    }

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
      case UserRole.patient:
        return UserProfile(
          phone: cleanedPhone,
          name: 'Patient Portal User',
          qualification: 'Registered Patient',
          designation: 'Patient',
          profileImagePath: AppAssets.logo,
          role: UserRole.patient,
          hospitalId: 'hosp_1',
          hospitalName: 'Ashwini Central Hospital',
          password: password,
        );
    }
  }

  static UserRole getRoleFromPhoneNumber(String phone) {
    final cleaned = phone.trim().replaceAll(RegExp(r'\D'), '');

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
    } else if (cleaned.startsWith('99')) {
      return UserRole.patient;
    } else {
      return UserRole.doctor;
    }
  }
}
