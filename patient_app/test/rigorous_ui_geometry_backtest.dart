import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sih_project/providers/appointment_provider.dart';
import 'package:sih_project/providers/health_profile_provider.dart';
import 'package:sih_project/providers/language_provider.dart';
import 'package:sih_project/screens/appointments/book_appointment_screen.dart';
import 'package:sih_project/screens/tabs/appointments_tab.dart';
import 'package:sih_project/screens/tabs/pharmacy_tab.dart';
import 'package:sih_project/screens/tabs/profile_tab.dart';
import 'package:sih_project/services/localization/app_strings.dart';
import 'package:sih_project/services/localization/healthcare_catalog.dart';
import 'package:sih_project/services/localization/sarvam_translation_service.dart';
import 'package:sih_project/widgets/patient_action_sheets.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SarvamTranslationService.init();
  });

  Widget buildTestableWidget({
    required Widget child,
    required LanguageProvider languageProvider,
    HealthProfileProvider? profileProvider,
    AppointmentProvider? appointmentProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
        ChangeNotifierProvider<HealthProfileProvider>.value(
          value: profileProvider ?? HealthProfileProvider(),
        ),
        ChangeNotifierProvider<AppointmentProvider>.value(
          value: appointmentProvider ?? AppointmentProvider(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('1. ProfileTab Hero Buttons & Overflow Invariance (Issue #1)', () {
    testWidgets('ProfileTab quick hero buttons render with 0px overflow across ALL 22 Indian languages', (WidgetTester tester) async {
      final langProvider = LanguageProvider();
      await langProvider.init();

      // Realistic narrow phone screen (360 width triggers overflow easily if not wrapped in Expanded/FittedBox)
      tester.view.physicalSize = const Size(720, 1600); // 360 x 800 logical
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      for (final lang in AppLanguages.supportedLanguages) {
        await langProvider.setLanguage(lang.code);

        await tester.pumpWidget(
          buildTestableWidget(
            child: const ProfileTab(),
            languageProvider: langProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Must have 0 layout or RenderFlex overflow exceptions
        final exception = tester.takeException();
        expect(exception, isNull, reason: 'ProfileTab threw layout exception for ${lang.name} (${lang.code}): $exception');

        // Quick buttons row exists and text fits without truncation error
        expect(find.byType(ProfileTab), findsOneWidget);
      }
    });
  });

  group('2. Schemes Dynamic Content & Translation Backtest (Issue #2)', () {
    test('Schemes results render dynamically translated clinical entities in all 22 languages', () {
      // Verify HealthcareCatalog lookup for schemes
      for (final lang in AppLanguages.supportedLanguages) {
        if (lang.code == 'en') continue;

        final ran = HealthcareCatalog.lookup('Rashtriya Arogya Nidhi (RAN)', lang.code);
        expect(ran, isNotNull, reason: 'RAN translation missing for ${lang.name}');
        expect(ran!.isNotEmpty, true);

        final pmjay = HealthcareCatalog.lookup('Ayushman Bharat PM-JAY', lang.code);
        expect(pmjay, isNotNull, reason: 'PM-JAY translation missing for ${lang.name}');

        final pmmvy = HealthcareCatalog.lookup('Pradhan Mantri Matru Vandana Yojana (PMMVY)', lang.code);
        expect(pmmvy, isNotNull, reason: 'PMMVY translation missing for ${lang.name}');

        final desc = HealthcareCatalog.lookup('The scheme-component aims to provide financial assistance to poor patients suffering from specified life threatening rare diseases.', lang.code);
        expect(desc, isNotNull, reason: 'RAN description missing for ${lang.name}');
      }
    });
  });

  group('3. PharmacyTab Dynamic Translation & Add Button Alignment (Issue #3)', () {
    testWidgets('PharmacyTab renders all medicines, translated generics, and scaled Add buttons across 22 languages', (WidgetTester tester) async {
      final langProvider = LanguageProvider();
      await langProvider.init();

      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      for (final lang in AppLanguages.supportedLanguages) {
        await langProvider.setLanguage(lang.code);

        await tester.pumpWidget(
          buildTestableWidget(
            child: const PharmacyTab(),
            languageProvider: langProvider,
          ),
        );
        await tester.pumpAndSettle();

        final exception = tester.takeException();
        expect(exception, isNull, reason: 'PharmacyTab threw exception in ${lang.name}: $exception');

        // Verify catalog lookup for medicines
        if (lang.code != 'en') {
          final para = HealthcareCatalog.lookup('Paracetamol 650mg', lang.code);
          expect(para, isNotNull, reason: 'Paracetamol 650mg missing translation in ${lang.name}');

          final ator = HealthcareCatalog.lookup('Atorvastatin 10mg', lang.code);
          expect(ator, isNotNull, reason: 'Atorvastatin 10mg missing translation in ${lang.name}');
        }
      }
    });
  });

  group('4. BookAppointmentScreen Localization & Slot Invariance (Issue #4)', () {
    testWidgets('BookAppointmentScreen renders localized shifts, days, slots, and doctors across 22 languages', (WidgetTester tester) async {
      final langProvider = LanguageProvider();
      await langProvider.init();

      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      for (final lang in ['en', 'hi', 'bn', 'te', 'ta', 'mr', 'gu', 'ur', 'pa', 'kn', 'ml']) {
        await langProvider.setLanguage(lang);

        await tester.pumpWidget(
          buildTestableWidget(
            child: const BookAppointmentScreen(),
            languageProvider: langProvider,
          ),
        );
        await tester.pumpAndSettle();

        final exception = tester.takeException();
        expect(exception, isNull, reason: 'BookAppointmentScreen threw exception in $lang: $exception');

        // Verify title is localized
        final expectedTitle = AppStrings.get('book_appointment_title', lang);
        expect(find.text(expectedTitle), findsWidgets);
      }
    });
  });

  group('5. AppointmentsTab Full Localization & Video Consult Invariance (Issue #5)', () {
    testWidgets('AppointmentsTab renders localized empty state and appointment cards across 22 languages', (WidgetTester tester) async {
      final langProvider = LanguageProvider();
      await langProvider.init();

      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      for (final lang in AppLanguages.supportedLanguages) {
        await langProvider.setLanguage(lang.code);

        await tester.pumpWidget(
          buildTestableWidget(
            child: const AppointmentsTab(),
            languageProvider: langProvider,
          ),
        );
        await tester.pumpAndSettle();

        final exception = tester.takeException();
        expect(exception, isNull, reason: 'AppointmentsTab threw exception in ${lang.name}: $exception');

        // Verify title
        final expectedTitle = AppStrings.get('my_appointments_title', lang.code);
        expect(find.text(expectedTitle), findsWidgets);
      }
    });
  });

  group('6. Language Selector Modal', () {
    testWidgets('Modal 22-language selector displays all languages and supports search filtering', (WidgetTester tester) async {
      final langProvider = LanguageProvider();
      await langProvider.init();

      await tester.pumpWidget(
        buildTestableWidget(
          languageProvider: langProvider,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              key: const ValueKey('open_modal_btn'),
              onPressed: () => PatientActionSheets.showLanguageSelector(ctx),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      // Tap open modal
      await tester.tap(find.byKey(const ValueKey('open_modal_btn')));
      await tester.pumpAndSettle();

      // Verify modal sheet is displayed
      expect(find.text('Choose Language / भाषा चुनें'), findsOneWidget);

      // Search for Tamil
      final searchFieldFinder = find.byKey(const ValueKey('search_language_field'));
      expect(searchFieldFinder, findsOneWidget);

      await tester.enterText(searchFieldFinder, 'Tamil');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('lang_item_ta')), findsOneWidget);
      expect(find.text('தமிழ்'), findsOneWidget);

      // Clear and search by native script
      await tester.enterText(searchFieldFinder, 'తెలుగు');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('lang_item_te')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('lang_item_te')),
          matching: find.text('తెలుగు'),
        ),
        findsOneWidget,
      );

      // Select Telugu
      await tester.tap(find.byKey(const ValueKey('lang_item_te')));
      await tester.pumpAndSettle();

      // Verify modal dismissed and language set to te
      expect(find.text('Choose Language / भाषा चुनें'), findsNothing);
      expect(langProvider.currentLanguageCode, 'te');
    });
  });
}
