import 'package:flutter/foundation.dart';
import '../models/health_profile.dart';
import '../models/family_member.dart';
import '../services/storage_service.dart';
import '../services/patient_database_service.dart';

class HealthProfileProvider with ChangeNotifier {
  final StorageService _storageService;
  final PatientDatabaseService _dbService;

  HealthProfile? _profile;
  List<FamilyMember> _familyMembers = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  HealthProfileProvider({
    StorageService? storageService,
    PatientDatabaseService? dbService,
  })  : _storageService = storageService ?? StorageService(),
        _dbService = dbService ?? PatientDatabaseService();

  HealthProfile? get profile => _profile;
  List<FamilyMember> get familyMembers => List.unmodifiable(_familyMembers);
  bool get isOnboarded => _profile != null;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Current user location (fallback to New Delhi, Delhi if none set)
  String get currentLocation =>
      _profile?.location ?? 'New Delhi, Delhi';

  /// Load profile and family members from local storage
  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    _profile = await _storageService.getProfile();
    _familyMembers = await _storageService.getFamilyMembers();

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();

    // Asynchronously refresh live profile from Azure backend if authenticated
    try {
      final token = await _storageService.getAuthToken();
      if (token != null && token.isNotEmpty) {
        final liveProfile = await _dbService.fetchMyProfile();
        if (liveProfile != null) {
          _profile = liveProfile;
          await _storageService.saveProfile(liveProfile);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[HealthProfileProvider] Silent live profile refresh: $e');
    }
  }

  /// Open Database Integration: Login
  /// Authenticates with backend/database endpoint and initializes patient session
  Future<bool> login({
    required String name,
    required String phoneNumber,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loggedInProfile = await _dbService.loginUser(
        name: name,
        phoneNumber: phoneNumber,
        password: password,
      );

      _profile = loggedInProfile;
      await _storageService.saveProfile(loggedInProfile);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[HealthProfileProvider] Login error: $e');
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Open Database Integration: Signup
  /// Registers patient in database endpoint and saves profile
  Future<bool> signup(HealthProfile profile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final saved = await _dbService.registerUser(profile);
      _profile = saved;
      await _storageService.saveProfile(saved);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[HealthProfileProvider] Signup error: $e');
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update Location: updates state, dispatches database endpoint, and persists
  Future<bool> updateLocation(String newLocation) async {
    if (_profile != null) {
      _profile = _profile!.copyWith(location: newLocation);
      await _storageService.saveProfile(_profile!);
      notifyListeners();

      // Fire and forget / non-blocking call to open database endpoint
      _dbService.updateUserLocation(
        phoneNumber: _profile!.phoneNumber,
        newLocation: newLocation,
      );
      return true;
    }
    return false;
  }

  /// Link & Sync a Family Member via Patient ID and Name
  /// Open Database Endpoint integration with fallback local storage
  Future<bool> syncFamilyMember({
    required String name,
    required String memberPatientId,
    required String relation,
  }) async {
    _isLoading = true;
    notifyListeners();

    final currentId = _profile?.patientId ?? '14-8832-4512-9018';
    final syncedMember = await _dbService.syncFamilyMember(
      currentPatientId: currentId,
      name: name.trim(),
      memberPatientId: memberPatientId.trim(),
      relation: relation.trim(),
    );

    if (syncedMember != null) {
      // Avoid duplicate IDs
      _familyMembers.removeWhere((m) => m.patientId.toUpperCase() == syncedMember.patientId.toUpperCase());
      _familyMembers.insert(0, syncedMember);
      await _storageService.saveFamilyMembers(_familyMembers);
    }

    _isLoading = false;
    notifyListeners();
    return syncedMember != null;
  }

  /// Remove / Unlink Family Member
  Future<bool> removeFamilyMember(String memberId) async {
    final currentId = _profile?.patientId ?? '14-8832-4512-9018';
    _familyMembers.removeWhere((m) => m.id == memberId);
    await _storageService.saveFamilyMembers(_familyMembers);
    notifyListeners();

    _dbService.removeFamilyMember(
      currentPatientId: currentId,
      memberId: memberId,
    );
    return true;
  }

  /// Update HealthProfile in local state and persistence
  Future<bool> updateProfile(HealthProfile updated) async {
    _profile = updated;
    await _storageService.saveProfile(updated);
    notifyListeners();
    return true;
  }

  /// Save newly entered or updated HealthProfile (retained for backward compatibility)
  Future<bool> saveProfile(HealthProfile profile) async {
    return signup(profile);
  }

  /// Clear profile (for test reset / logout)
  Future<bool> clearProfile() async {
    _isLoading = true;
    notifyListeners();

    final success = await _storageService.clearProfile();
    await _storageService.clearAuthToken();
    if (success) {
      _profile = null;
      _familyMembers = [];
      await _storageService.saveFamilyMembers([]);
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }
}
