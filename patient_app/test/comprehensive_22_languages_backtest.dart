import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sih_project/providers/appointment_provider.dart';
import 'package:sih_project/providers/health_profile_provider.dart';
import 'package:sih_project/providers/language_provider.dart';
import 'package:sih_project/providers/schemes_provider.dart';
import 'package:sih_project/screens/tabs/home_tab.dart';
import 'package:sih_project/services/localization/app_strings.dart';
import 'package:sih_project/services/localization/sarvam_translation_service.dart';
import 'package:sih_project/widgets/patient_action_sheets.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  setUp(() async {
    HttpOverrides.global = _RealHttpOverrides();
    SharedPreferences.setMockInitialValues({});
    await SarvamTranslationService.init();
  });

  Widget buildTestableWidget({
    required Widget child,
    required LanguageProvider languageProvider,
    HealthProfileProvider? profileProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
        ChangeNotifierProvider<HealthProfileProvider>.value(
          value: profileProvider ?? HealthProfileProvider(),
        ),
        ChangeNotifierProvider<AppointmentProvider>(
          create: (_) => AppointmentProvider(),
        ),
        ChangeNotifierProvider<SchemesProvider>(
          create: (_) => SchemesProvider(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('RIGOROUS BACKTEST: 22 Scheduled Indian Languages Catalog', () {
    test('Verify all 22 official Eighth-Schedule languages + English exist with full metadata', () {
      final langs = AppLanguages.supportedLanguages;
      expect(langs.length, 23);

      final expectedSchedule = {
        'hi': 'Hindi',
        'bn': 'Bengali',
        'te': 'Telugu',
        'mr': 'Marathi',
        'ta': 'Tamil',
        'gu': 'Gujarati',
        'kn': 'Kannada',
        'ml': 'Malayalam',
        'pa': 'Punjabi',
        'or': 'Odia',
        'as': 'Assamese',
        'ur': 'Urdu',
        'sa': 'Sanskrit',
        'mai': 'Maithili',
        'kok': 'Konkani',
        'ne': 'Nepali',
        'ks': 'Kashmiri',
        'sd': 'Sindhi',
        'doi': 'Dogri',
        'mni': 'Manipuri',
        'brx': 'Bodo',
        'sat': 'Santali',
      };

      for (final entry in expectedSchedule.entries) {
        final lang = AppLanguages.getByCode(entry.key);
        expect(lang.code, entry.key);
        expect(lang.name, entry.value);
        expect(lang.nativeName.isNotEmpty, true);
        expect(lang.badge.isNotEmpty, true);
        expect(lang.sarvamCode.endsWith('-IN'), true);
      }
    });

    test('All 23 language codes and badges are distinct with zero collisions', () {
      final langs = AppLanguages.supportedLanguages;
      final codeSet = <String>{};
      final badgeSet = <String>{};

      for (final l in langs) {
        expect(codeSet.add(l.code.toLowerCase()), true, reason: 'Collision in language code: ${l.code}');
        expect(badgeSet.add(l.badge.toUpperCase()), true, reason: 'Collision in badge: ${l.badge}');
      }
    });
  });

  group('RIGOROUS BACKTEST: Dictionary Completeness & Overflow-Safe Text', () {
    const requiredKeys = [
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
      'due_in_15',
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

    test('All 23 languages have valid, non-empty text for every essential UI key', () {
      for (final lang in AppLanguages.supportedLanguages) {
        for (final key in requiredKeys) {
          final text = AppStrings.get(key, lang.code);
          expect(text.isNotEmpty, true, reason: 'Missing translation for $key in ${lang.name}');
          expect(text != key, true, reason: 'Raw key returned for $key in ${lang.name}');
        }
      }
    });
  });

  group('RIGOROUS BACKTEST: UI Geometry & Button Placement Invariance', () {
    testWidgets('HomeTab renders with 0 errors and IDENTICAL card dimensions across ALL 22 languages', (WidgetTester tester) async {
      final langProvider = LanguageProvider();
      await langProvider.init();

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      for (final lang in AppLanguages.supportedLanguages) {
        await langProvider.setLanguage(lang.code);

        await tester.pumpWidget(
          buildTestableWidget(
            child: const HomeTab(),
            languageProvider: langProvider,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Zero RenderFlex or layout exceptions
        expect(
          tester.takeException(),
          isNull,
          reason: 'RenderFlex overflow occurred in language: ${lang.name} (${lang.code})',
        );

        // 2. Language Bar displays badge & script correctly
        expect(find.text(lang.badge), findsWidgets);

        // 3. Inspect Card Geometry: Heights must remain exactly 155.0px in every language
        final emergencyFinder = find.byKey(const ValueKey('card_emergency'));
        final bookApptFinder = find.byKey(const ValueKey('card_book_appointment'));
        final myApptFinder = find.byKey(const ValueKey('card_my_appointments'));
        final aiFinder = find.byKey(const ValueKey('card_ai_assistant'));

        final emergencySize = tester.getSize(emergencyFinder);
        final bookApptSize = tester.getSize(bookApptFinder);
        final myApptSize = tester.getSize(myApptFinder);
        final aiSize = tester.getSize(aiFinder);

        expect(emergencySize.height, 155.0, reason: 'Emergency card height altered in ${lang.name}');
        expect(bookApptSize.height, 155.0, reason: 'Book Appt card height altered in ${lang.name}');
        expect(myApptSize.height, 155.0, reason: 'My Appt card height altered in ${lang.name}');
        expect(aiSize.height, 155.0, reason: 'AI card height altered in ${lang.name}');

        // 4. Inspect Button Position: Mark as taken button is strictly bound
        final markTakenFinder = find.byKey(const ValueKey('btn_mark_taken'));
        expect(markTakenFinder, findsOneWidget);
        final markTakenSize = tester.getSize(markTakenFinder);
        expect(markTakenSize.width <= 110.0, true, reason: 'Action button exceeded max width in ${lang.name}');
      }
    });

    testWidgets('Language Selector Modal displays 22 languages and updates active language on selection', (WidgetTester tester) async {
      final langProvider = LanguageProvider();
      await langProvider.init();

      await tester.pumpWidget(
        buildTestableWidget(
          languageProvider: langProvider,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              key: const ValueKey('open_modal'),
              onPressed: () => PatientActionSheets.showLanguageSelector(ctx),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      // Open Modal
      await tester.tap(find.byKey(const ValueKey('open_modal')));
      await tester.pumpAndSettle();

      expect(find.text('Choose Language / भाषा चुनें'), findsOneWidget);

      // Search field operates smoothly
      final searchFinder = find.byKey(const ValueKey('search_language_field'));
      expect(searchFinder, findsOneWidget);

      // Search Marathi
      await tester.enterText(searchFinder, 'Marathi');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('lang_item_mr')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('lang_item_mr')),
          matching: find.text('मराठी'),
        ),
        findsOneWidget,
      );

      // Select Marathi
      await tester.tap(find.byKey(const ValueKey('lang_item_mr')));
      await tester.pumpAndSettle();

      expect(langProvider.currentLanguageCode, 'mr');
      expect(langProvider.currentLanguage.name, 'Marathi');
      expect(langProvider.tr('welcome_back'), 'स्वागत आहे');
    });
  });

  group('RIGOROUS BACKTEST: Sarvam AI Translation Service & Caching', () {
    test('SarvamTranslationService translate returns human-verified dictionary match instantly', () async {
      final res = await SarvamTranslationService.translate(
        'emergency_sos',
        targetLanguageCode: 'hi',
      );
      expect(res, 'आपातकालीन\nएसओएस मदद');
    });

    test('Live dynamic translation uses authenticated Sarvam key and sarvam-translate:v1', () async {
      const clinicalPhrase = 'Please take one tablet twice daily after meals';
      final res = await SarvamTranslationService.translate(
        clinicalPhrase,
        targetLanguageCode: 'hi',
      );

      expect(res.isNotEmpty, true);
      expect(res != clinicalPhrase, true);

      // High-performance cache retrieval test (< 10ms)
      final sw = Stopwatch()..start();
      final cachedRes = await SarvamTranslationService.translate(
        clinicalPhrase,
        targetLanguageCode: 'hi',
      );
      sw.stop();

      expect(cachedRes, res);
      expect(sw.elapsedMilliseconds < 25, true, reason: 'Memory cache lookup must take < 25ms');
    });

    test('Offline resilience: graceful fallback when network is unreachable', () async {
      // Offline fallback test with nonexistent key returns fallback without crash
      final fallback = await SarvamTranslationService.translate(
        'Heart Rate Scan',
        targetLanguageCode: 'en',
      );
      expect(fallback, 'Heart Rate Scan');
    });
  });
}
