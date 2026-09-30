import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sih_project/models/appointment.dart';
import 'package:sih_project/models/government_scheme.dart';
import 'package:sih_project/models/health_profile.dart';
import 'package:sih_project/providers/appointment_provider.dart';
import 'package:sih_project/providers/health_profile_provider.dart';
import 'package:sih_project/providers/language_provider.dart';
import 'package:sih_project/providers/schemes_provider.dart';
import 'package:sih_project/screens/appointments/appointment_receipt_screen.dart';
import 'package:sih_project/screens/appointments/book_appointment_screen.dart';
import 'package:sih_project/screens/family/family_data_screen.dart';
import 'package:sih_project/screens/medical_history_screen.dart';
import 'package:sih_project/screens/request_asha_visit_screen.dart';
import 'package:sih_project/screens/schemes/eligibility_form_screen.dart';
import 'package:sih_project/screens/schemes/scheme_detail_screen.dart';
import 'package:sih_project/screens/schemes/schemes_results_screen.dart';
import 'package:sih_project/screens/tabs/appointments_tab.dart';
import 'package:sih_project/screens/tabs/home_tab.dart';
import 'package:sih_project/screens/tabs/pharmacy_tab.dart';
import 'package:sih_project/screens/tabs/profile_tab.dart';
import 'package:sih_project/services/localization/sarvam_translation_service.dart';
import 'package:sih_project/widgets/patient_action_sheets.dart';

import 'package:sih_project/services/local_scheme_engine.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  setUp(() async {
    HttpOverrides.global = _RealHttpOverrides();
    SharedPreferences.setMockInitialValues({});
    SarvamTranslationService.bypassNetworkCallsForTesting = true;
    await SarvamTranslationService.init();
    await LocalSchemeEngine.ensureInitialized();
  });

  tearDown(() {
    SarvamTranslationService.bypassNetworkCallsForTesting = false;
  });

  Widget buildTestableWidget({
    required Widget child,
    required LanguageProvider languageProvider,
    HealthProfileProvider? profileProvider,
    AppointmentProvider? appointmentProvider,
    SchemesProvider? schemesProvider,
    double textScale = 1.0,
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
        ChangeNotifierProvider<SchemesProvider>.value(
          value: schemesProvider ?? SchemesProvider(),
        ),
      ],
      child: MaterialApp(
        builder: (context, widget) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: widget!,
          );
        },
        home: Scaffold(body: child),
      ),
    );
  }

  final testSizes = [
    const Size(320, 568), // iPhone SE / Ultra compact
    const Size(360, 640), // Standard Android compact
    const Size(390, 844), // iPhone 12/13/14
  ];

  final testLanguages = ['en', 'hi', 'ta', 'te', 'bn'];

  group('AUDIT: Pixel Overflows on Tabs', () {
    for (final size in testSizes) {
      for (final lang in testLanguages) {
        testWidgets('HomeTab at ${size.width}x${size.height} in $lang has 0 overflows', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final langProvider = LanguageProvider();
          await langProvider.setLanguage(lang);

          await tester.pumpWidget(
            buildTestableWidget(
              child: const Scaffold(body: HomeTab()),
              languageProvider: langProvider,
            ),
          );
          await tester.pumpAndSettle(); await tester.pump(const Duration(milliseconds: 50));

          expect(tester.takeException(), isNull);
        });

        testWidgets('AppointmentsTab at ${size.width}x${size.height} in $lang has 0 overflows', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final langProvider = LanguageProvider();
          await langProvider.setLanguage(lang);

          await tester.pumpWidget(
            buildTestableWidget(
              child: const Scaffold(body: AppointmentsTab()),
              languageProvider: langProvider,
            ),
          );
          await tester.pumpAndSettle(); await tester.pump(const Duration(milliseconds: 50));

          expect(tester.takeException(), isNull);
        });

        testWidgets('PharmacyTab at ${size.width}x${size.height} in $lang has 0 overflows', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final langProvider = LanguageProvider();
          await langProvider.setLanguage(lang);

          await tester.pumpWidget(
            buildTestableWidget(
              child: const Scaffold(body: PharmacyTab()),
              languageProvider: langProvider,
            ),
          );
          await tester.pumpAndSettle(); await tester.pump(const Duration(milliseconds: 50));

          expect(tester.takeException(), isNull);
        });

        testWidgets('ProfileTab at ${size.width}x${size.height} in $lang has 0 overflows', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final langProvider = LanguageProvider();
          await langProvider.setLanguage(lang);

          await tester.pumpWidget(
            buildTestableWidget(
              child: const Scaffold(body: ProfileTab()),
              languageProvider: langProvider,
            ),
          );
          await tester.pumpAndSettle(); await tester.pump(const Duration(milliseconds: 50));

          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('AUDIT: Pixel Overflows on Flow Screens', () {
    for (final size in [const Size(320, 568), const Size(360, 640)]) {
      for (final lang in ['en', 'hi']) {
        testWidgets('BookAppointmentScreen at ${size.width}x${size.height} in $lang has 0 overflows', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final langProvider = LanguageProvider();
          await langProvider.setLanguage(lang);

          await tester.pumpWidget(
            buildTestableWidget(
              child: const BookAppointmentScreen(),
              languageProvider: langProvider,
            ),
          );
          await tester.pumpAndSettle(); await tester.pump(const Duration(milliseconds: 50));

          expect(tester.takeException(), isNull);
        });

        testWidgets('AppointmentReceiptScreen at ${size.width}x${size.height} in $lang has 0 overflows', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final langProvider = LanguageProvider();
          await langProvider.setLanguage(lang);

          final mockAppt = Appointment(
            id: 'test_appt_1',
            doctorId: 'doc_1',
            doctorName: 'Dr. Rajesh V. Sharma',
            doctorSpecialty: 'Cardiology (Interventional)',
            hospitalName: 'Ashwini Central Hospital • Executive Chamber 104, Block A',
            appointmentDate: 'Mon, 12 Oct 2026',
            timeSlot: '10:00 AM - 10:30 AM',
            appointmentType: 'Online',
            patientName: 'Patient Test With A Very Long Name For Overflow Verification',
            patientPhone: '+91 9876543210',
            tokenNumber: 'A-42-VIP',
            consultationFee: 0,
            status: 'Confirmed',
            bookedAt: DateTime(2026, 10, 12, 10, 0),
          );

          await tester.pumpWidget(
            buildTestableWidget(
              child: AppointmentReceiptScreen(appointment: mockAppt),
              languageProvider: langProvider,
            ),
          );
          await tester.pumpAndSettle(); await tester.pump(const Duration(milliseconds: 50));

          expect(tester.takeException(), isNull);
        });

        testWidgets('SchemesResultsScreen at ${size.width}x${size.height} in $lang has 0 overflows', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final langProvider = LanguageProvider();
          await langProvider.setLanguage(lang);

          await tester.pumpWidget(
            buildTestableWidget(
              child: const SchemesResultsScreen(),
              languageProvider: langProvider,
            ),
          );
          await tester.pumpAndSettle(); await tester.pump(const Duration(milliseconds: 50));

          expect(tester.takeException(), isNull);
        });

        testWidgets('EligibilityFormScreen at ${size.width}x${size.height} in $lang has 0 overflows', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final langProvider = LanguageProvider();
          await langProvider.setLanguage(lang);

          await tester.pumpWidget(
            buildTestableWidget(
              child: const EligibilityFormScreen(),
              languageProvider: langProvider,
            ),
          );
          await tester.pumpAndSettle(); await tester.pump(const Duration(milliseconds: 50));

          expect(tester.takeException(), isNull);
        });

        testWidgets('MedicalHistoryScreen at ${size.width}x${size.height} in $lang has 0 overflows', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final langProvider = LanguageProvider();
          await langProvider.setLanguage(lang);

          await tester.pumpWidget(
            buildTestableWidget(
              child: const MedicalHistoryScreen(),
              languageProvider: langProvider,
            ),
          );
          await tester.pumpAndSettle(); await tester.pump(const Duration(milliseconds: 50));

          expect(tester.takeException(), isNull);
        });

        testWidgets('FamilyDataScreen at ${size.width}x${size.height} in $lang has 0 overflows', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final langProvider = LanguageProvider();
          await langProvider.setLanguage(lang);

          await tester.pumpWidget(
            buildTestableWidget(
              child: const FamilyDataScreen(),
              languageProvider: langProvider,
            ),
          );
          await tester.pumpAndSettle(); await tester.pump(const Duration(milliseconds: 50));

          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
