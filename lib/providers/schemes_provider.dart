import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/government_scheme.dart';
import '../models/scheme_eligibility_profile.dart';
import '../services/scheme_api_service.dart';

class SchemesProvider with ChangeNotifier {
  static const String _storageKeyProfile = 'schemes_eligibility_profile';
  static const String _storageKeyCachedResults = 'schemes_cached_results';

  final SchemeApiService _apiService;

  SchemeEligibilityProfile? _profile;
  EligibilityCheckResult? _results;
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedFilter = 'all'; // all, likely_eligible, verification_required, likely_not_eligible

  SchemesProvider({SchemeApiService? apiService})
      : _apiService = apiService ?? SchemeApiService() {
    loadSavedProfile();
  }

  SchemeEligibilityProfile? get profile => _profile;
  EligibilityCheckResult? get results => _results;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasProfile => _profile != null;
  String get selectedFilter => _selectedFilter;

  List<GovernmentScheme> get filteredSchemes {
    if (_results == null) return [];
    if (_selectedFilter == 'likely_eligible') {
      return _results!.schemes.where((s) => s.evaluation.status == 'likely_eligible').toList();
    } else if (_selectedFilter == 'verification_required') {
      return _results!.schemes.where((s) => s.evaluation.status == 'verification_required').toList();
    } else if (_selectedFilter == 'likely_not_eligible') {
      return _results!.schemes.where((s) => s.evaluation.status == 'likely_not_eligible').toList();
    }
    return _results!.schemes;
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  /// Initialize and load saved profile from local storage
  Future<void> loadSavedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString(_storageKeyProfile);
      if (profileJson != null) {
        _profile = SchemeEligibilityProfile.fromJson(jsonDecode(profileJson) as Map<String, dynamic>);
        
        // Load cached results or re-fetch
        final cachedResultsJson = prefs.getString(_storageKeyCachedResults);
        if (cachedResultsJson != null) {
          _results = EligibilityCheckResult.fromJson(jsonDecode(cachedResultsJson) as Map<String, dynamic>);
        } else {
          await evaluateEligibility(_profile!);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved schemes profile: $e');
    }
  }

  /// Save new or updated profile and evaluate schemes
  Future<void> saveProfileAndEvaluate(SchemeEligibilityProfile newProfile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = newProfile;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKeyProfile, jsonEncode(newProfile.toJson()));

      // Evaluate schemes via API
      final checkResult = await _apiService.checkEligibility(newProfile);
      _results = checkResult;

      // Cache results
      // (Optional simple cache)
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to evaluate schemes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh / Recalculate
  Future<void> evaluateEligibility(SchemeEligibilityProfile profile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _results = await _apiService.checkEligibility(profile);
    } catch (e) {
      _errorMessage = 'Error fetching eligibility: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch scheme details
  Future<SchemeDetail> fetchSchemeDetail(String schemeId) async {
    return await _apiService.getSchemeDetail(schemeId, profile: _profile);
  }

  /// AI Explainer
  Future<AiExplanation> explainWithAi(String schemeId, {String? question}) async {
    return await _apiService.explainWithAi(schemeId, profile: _profile, question: question);
  }

  /// Clear profile (allows testing the first-time form again)
  Future<void> clearSchemesProfile() async {
    _profile = null;
    _results = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKeyProfile);
    await prefs.remove(_storageKeyCachedResults);
    notifyListeners();
  }
}
