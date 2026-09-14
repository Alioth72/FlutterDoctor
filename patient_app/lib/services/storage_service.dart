import '../models/family_member.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_profile.dart';

class StorageService {
  static const String _profileKey = 'patient_health_profile_v1';

  /// Save HealthProfile to SharedPreferences
  Future<bool> saveProfile(HealthProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(profile.toJson());
      return await prefs.setString(_profileKey, jsonString);
    } catch (e) {
      return false;
    }
  }

  /// Retrieve saved HealthProfile from SharedPreferences
  Future<HealthProfile?> getProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_profileKey);
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return HealthProfile.fromJson(jsonMap);
    } catch (e) {
      return null;
    }
  }

  static const String _authTokenKey = 'patient_auth_token_v1';
  static const String _patientIdKey = 'patient_id_v1';

  /// Save JWT auth token to SharedPreferences
  Future<bool> saveAuthToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_authTokenKey, token);
    } catch (e) {
      return false;
    }
  }

  /// Retrieve saved JWT auth token
  Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_authTokenKey);
    } catch (e) {
      return null;
    }
  }

  /// Clear stored auth token
  Future<bool> clearAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authTokenKey);
      await prefs.remove(_patientIdKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Save patient ID to SharedPreferences
  Future<bool> savePatientId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_patientIdKey, id);
    } catch (e) {
      return false;
    }
  }

  /// Retrieve saved patient ID
  Future<String?> getPatientId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_patientIdKey);
    } catch (e) {
      return null;
    }
  }

  /// Remove stored HealthProfile (e.g. on logout/reset)
  Future<bool> clearProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileKey);
      await prefs.remove(_authTokenKey);
      await prefs.remove(_patientIdKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  static const String _familyMembersKey = 'patient_family_members_v1';

  /// Save Family Members list to SharedPreferences
  Future<bool> saveFamilyMembers(List<FamilyMember> members) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = jsonEncode(members.map((m) => m.toJson()).toList());
      return await prefs.setString(_familyMembersKey, listJson);
    } catch (e) {
      return false;
    }
  }

  /// Retrieve saved Family Members from SharedPreferences
  Future<List<FamilyMember>> getFamilyMembers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_familyMembersKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => FamilyMember.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

}
