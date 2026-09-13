import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sih_project/providers/language_provider.dart';
import 'package:sih_project/services/localization/app_strings.dart';
import 'package:sih_project/services/localization/healthcare_catalog.dart';
import 'package:sih_project/services/localization/sarvam_translation_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SarvamTranslationService.init();
  });

  group('1. Indian Languages Catalog Tests', () {
    test('Catalog contains all 22 Official Scheduled Indian Languages + English', () {
      final languages = AppLanguages.supportedLanguages;
      expect(languages.length, 23);

      final expectedCodes = [
        'en', 'hi', 'bn', 'te', 'mr', 'ta', 'gu', 'kn', 'ml', 'pa',
        'or', 'as', 'ur', 'sa', 'mai', 'kok', 'ne', 'ks', 'sd', 'doi',
        'mni', 'brx', 'sat',
      ];

      for (final code in expectedCodes) {
        final lang = AppLanguages.getByCode(code);
        expect(lang.code, code);
        expect(lang.name.isNotEmpty, true, reason: '$code name should not be empty');
        expect(lang.nativeName.isNotEmpty, true, reason: '$code nativeName should not be empty');
        expect(lang.badge.isNotEmpty, true, reason: '$code badge should not be empty');
        expect(lang.sarvamCode.endsWith('-IN'), true, reason: '$code sarvamCode should end with -IN');
      }
    });

    test('All language codes and badges are distinct and unique', () {
      final languages = AppLanguages.supportedLanguages;
      final codes = languages.map((l) => l.code.toLowerCase()).toSet();
      expect(codes.length, languages.length, reason: 'Duplicate language codes found');

      final badges = languages.map((l) => l.badge.toUpperCase()).toSet();
      expect(badges.length, languages.length, reason: 'Duplicate language badges found');
    });

    test('AppLanguages.getByCode returns default English on unknown code', () {
      final unknown = AppLanguages.getByCode('xyz_unknown');
      expect(unknown.code, 'en');
      expect(unknown.name, 'English');
    });
  });

  group('2. AppStrings Dictionary & Layout-Safe Fallbacks', () {
    final coreKeys = [
      'portal_title',
      'welcome_back',
      'patient_badge',
      'app_language',
      'change_language',
      'choose_language',
      'search_language',
      'nav_home',
      'nav_pharmacy',
      'nav_schemes',
      'nav_profile',
      'reminder',
      'mark_as_taken',
      'consultation_sub',
      'book_appointment',
      'schedule_sub',
      'my_appointments',
      'instant_ai_sub',
      'ai_assistant',
      'immediate_sub',
      'emergency',
      'patient_vitals',
      'live_vitals',
      'measure_heart_rate',
      'pulse_scan_sub',
    ];

    test('Every core UI key returns valid text for every single language', () {
      for (final lang in AppLanguages.supportedLanguages) {
        for (final key in coreKeys) {
          final translated = AppStrings.get(key, lang.code);
          expect(
            translated.isNotEmpty,
            true,
            reason: 'Language ${lang.name} ($lang.code) returned empty string for key $key',
          );
          expect(
            translated != key,
            true,
            reason: 'Language ${lang.name} ($lang.code) returned key itself instead of translated string for key $key',
          );
        }
      }
    });

    test('Dictionary gracefully falls back to English for unlocalized dynamic key', () {
      final fallback = AppStrings.get('welcome_back', 'unknown_code');
      expect(fallback, 'WELCOME BACK');
    });

    test('Dictionary returns the raw key if not found in English', () {
      final missing = AppStrings.get('non_existent_key_12345', 'hi');
      expect(missing, 'non_existent_key_12345');
    });
  });

  group('3. LanguageProvider State & Reactivity', () {
    test('Initializes with default English and allows instant switching', () async {
      final provider = LanguageProvider();
      await provider.init();

      expect(provider.currentLanguageCode, 'en');
      expect(provider.currentLanguage.name, 'English');
      expect(provider.tr('welcome_back'), 'WELCOME BACK');

      // Switch to Hindi
      await provider.setLanguage('hi');
      expect(provider.currentLanguageCode, 'hi');
      expect(provider.currentLanguage.name, 'Hindi');
      expect(provider.currentLanguage.nativeName, 'हिन्दी');
      expect(provider.tr('welcome_back'), 'स्वागत है');
      expect(provider.tr('book_appointment'), 'अपॉइंटमेंट\nबुक करें');

      // Switch to Tamil
      await provider.setLanguage('ta');
      expect(provider.currentLanguageCode, 'ta');
      expect(provider.currentLanguage.name, 'Tamil');
      expect(provider.currentLanguage.nativeName, 'தமிழ்');
      expect(provider.tr('welcome_back'), 'நல்வரவு');

      // Switch to Bengali
      await provider.setLanguage('bn');
      expect(provider.currentLanguageCode, 'bn');
      expect(provider.currentLanguage.name, 'Bengali');
      expect(provider.currentLanguage.nativeName, 'বাংলা');
      expect(provider.tr('welcome_back'), 'স্বাগতম');
    });

    test('Language preference persists across provider initialization', () async {
      SharedPreferences.setMockInitialValues({
        'patient_app_selected_language': 'te',
      });

      final provider = LanguageProvider();
      await provider.init();

      expect(provider.currentLanguageCode, 'te');
      expect(provider.currentLanguage.name, 'Telugu');
      expect(provider.currentLanguage.nativeName, 'తెలుగు');
      expect(provider.tr('welcome_back'), 'స్వాగతం');
    });
  });

  group('4. Sarvam AI Translation Service Live & Cache Tests', () {
    test('SarvamTranslationService translate returns English text as-is', () async {
      final res = await SarvamTranslationService.translate(
        'Doctor Appointment',
        targetLanguageCode: 'en',
      );
      expect(res, 'Doctor Appointment');
    });

    test('SarvamTranslationService utilizes dictionary match before network call', () async {
      final res = await SarvamTranslationService.translate(
        'welcome_back',
        targetLanguageCode: 'hi',
      );
      expect(res, 'स्वागत है');
    });

    test('Live Sarvam AI API translation with authenticated key or graceful fallback', () async {
      // Dynamic sentence not in pre-bundled dictionary
      const dynamicPhrase = 'Your prescription is ready for pickup';
      final translated = await SarvamTranslationService.translate(
        dynamicPhrase,
        targetLanguageCode: 'hi',
      );

      // Verify non-empty response
      expect(translated.isNotEmpty, true);

      // Second call should hit the cache instantly
      final stopwatch = Stopwatch()..start();
      final cachedResult = await SarvamTranslationService.translate(
        dynamicPhrase,
        targetLanguageCode: 'hi',
      );
      stopwatch.stop();

      expect(cachedResult, translated);
      expect(stopwatch.elapsedMilliseconds < 50, true, reason: 'Cached lookup should take < 50ms');
    });
  });

  group('5. Zero English Remainder: Patient Names, Brand, Medicines & Modals', () {
    test('Patient names, brand, and medicines translate into native scripts across all 22 Indian languages', () {
      final scheduledLangs = AppLanguages.supportedLanguages.where((l) => l.code != 'en');

      for (final lang in scheduledLangs) {
        // 1. Patient Names
        final vikram = HealthcareCatalog.lookup('Vikram Malhotra', lang.code);
        expect(vikram, isNotNull, reason: 'Vikram Malhotra missing in ${lang.name}');
        expect(vikram, isNot('Vikram Malhotra'), reason: 'Vikram Malhotra was not translated in ${lang.name}');

        final sarah = HealthcareCatalog.lookup('Sarah Jenkins', lang.code);
        expect(sarah, isNotNull, reason: 'Sarah Jenkins missing in ${lang.name}');
        expect(sarah, isNot('Sarah Jenkins'), reason: 'Sarah Jenkins was not translated in ${lang.name}');

        // 2. Brand Name Ashwini
        final ashwini = HealthcareCatalog.lookup('Ashwini', lang.code);
        expect(ashwini, isNotNull, reason: 'Ashwini missing in ${lang.name}');
        expect(ashwini, isNot('Ashwini'), reason: 'Ashwini was not translated in ${lang.name}');

        // 3. Medicine Reminder
        final paracetamol = HealthcareCatalog.lookup('Paracetamol 500mg', lang.code);
        expect(paracetamol, isNotNull, reason: 'Paracetamol 500mg missing in ${lang.name}');
        expect(paracetamol, isNot('Paracetamol 500mg'), reason: 'Paracetamol 500mg was not translated in ${lang.name}');

        // 4. Emergency SOS Modal Strings
        final emTitle = AppStrings.get('emergency_title', lang.code);
        expect(emTitle, isNot('EMERGENCY ESCALATION'), reason: 'emergency_title untranslated in ${lang.name}');

        final emCall = AppStrings.get('emergency_call_btn', lang.code);
        expect(emCall, isNot('CALL 108 AMBULANCE (SOS)'), reason: 'emergency_call_btn untranslated in ${lang.name}');

        // 5. AI Health Assistant Modal Strings
        final aiTitle = AppStrings.get('ai_assistant_title', lang.code);
        expect(aiTitle, isNot('AI Health Assistant'), reason: 'ai_assistant_title untranslated in ${lang.name}');

        final aiGreeting = AppStrings.get('ai_greeting_msg', lang.code);
        expect(aiGreeting.startsWith('Namaste! Describe your symptoms'), isFalse, reason: 'ai_greeting_msg untranslated in ${lang.name}');

        // 6. Contact Doctor & Voice Modal Strings
        final contactDoc = AppStrings.get('contact_doctor_title', lang.code);
        expect(contactDoc, isNot('Contact On-Duty Doctor'), reason: 'contact_doctor_title untranslated in ${lang.name}');

        final voiceTitle = AppStrings.get('voice_listening_title', lang.code);
        expect(voiceTitle, isNot('Listening in your language...'), reason: 'voice_listening_title untranslated in ${lang.name}');
      }
    });
  });
}
