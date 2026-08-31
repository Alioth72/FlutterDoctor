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

  /// Remove stored HealthProfile (e.g. on logout/reset)
  Future<bool> clearProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_profileKey);
    } catch (e) {
      return false;
    }
  }
}
