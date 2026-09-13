import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/localization/app_strings.dart';
import '../services/localization/sarvam_translation_service.dart';

/// Manages active application language across all 22 Official Scheduled Indian Languages.
/// Notifies listening widgets instantaneously without requiring app restart.
class LanguageProvider extends ChangeNotifier {
  static const String _prefKey = 'patient_app_selected_language';
  String _currentLanguageCode = 'en';
  bool _isInitialized = false;

  String get currentLanguageCode => _currentLanguageCode;
  LanguageInfo get currentLanguage => AppLanguages.getByCode(_currentLanguageCode);
  bool get isInitialized => _isInitialized;

  List<LanguageInfo> get supportedLanguages => AppLanguages.supportedLanguages;

  Future<void> init() async {
    if (_isInitialized) return;
    await SarvamTranslationService.init();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      if (savedCode != null && savedCode.isNotEmpty) {
        _currentLanguageCode = savedCode;
      }
    } catch (e) {
      debugPrint('[LanguageProvider] Init note: $e');
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Instantly look up layout-stable localized string
  String tr(String key) {
    return AppStrings.get(key, _currentLanguageCode);
  }

  /// Dynamic translation using Sarvam AI with local cache fallback
  Future<String> translateDynamic(String text) async {
    return SarvamTranslationService.translate(
      text,
      targetLanguageCode: _currentLanguageCode,
    );
  }

  /// Changes the active language and notifies all UI screens immediately
  Future<void> setLanguage(String code) async {
    if (_currentLanguageCode == code) return;

    _currentLanguageCode = code;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (e) {
      debugPrint('[LanguageProvider] Save preference note: $e');
    }
  }
}
