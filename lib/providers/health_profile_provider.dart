import 'package:flutter/foundation.dart';
import '../models/health_profile.dart';
import '../services/storage_service.dart';

class HealthProfileProvider with ChangeNotifier {
  final StorageService _storageService;
  HealthProfile? _profile;
  bool _isInitialized = false;
  bool _isLoading = false;

  HealthProfileProvider({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  HealthProfile? get profile => _profile;
  bool get isOnboarded => _profile != null;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  /// Load profile from local storage during app initialization
  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    _profile = await _storageService.getProfile();
    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  /// Save newly entered or updated HealthProfile
  Future<bool> saveProfile(HealthProfile profile) async {
    _isLoading = true;
    notifyListeners();

    final success = await _storageService.saveProfile(profile);
    if (success) {
      _profile = profile;
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// Clear profile (for test reset / logout)
  Future<bool> clearProfile() async {
    _isLoading = true;
    notifyListeners();

    final success = await _storageService.clearProfile();
    if (success) {
      _profile = null;
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }
}
