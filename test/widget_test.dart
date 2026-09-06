import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sih_project/models/appointment.dart';
import 'package:sih_project/models/health_profile.dart';
import 'package:sih_project/models/scheme_eligibility_profile.dart';
import 'package:sih_project/providers/appointment_provider.dart';
import 'package:sih_project/providers/health_profile_provider.dart';
import 'package:sih_project/providers/schemes_provider.dart';
import 'package:sih_project/services/mock_doctor_service.dart';
import 'package:sih_project/screens/appointments/appointment_receipt_screen.dart';
import 'package:sih_project/screens/appointments/book_appointment_screen.dart';
import 'package:sih_project/screens/home_screen.dart';
import 'package:sih_project/screens/schemes/eligibility_form_screen.dart';
import 'package:sih_project/screens/schemes/scheme_detail_screen.dart';
import 'package:sih_project/screens/schemes/schemes_results_screen.dart';
import 'package:sih_project/screens/signup_screen.dart';
import 'package:sih_project/screens/tabs/schemes_tab.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Model Serialization Tests', () {
    test('HealthProfile converts to and from JSON correctly', () {
      final profile = HealthProfile(
        name: 'Aarav Patel',
        age: 32,
        gender: 'Male',
        phoneNumber: '9876543210',
      );

      final json = profile.toJson();
      expect(json['name'], 'Aarav Patel');
      expect(json['age'], 32);
      expect(json['gender'], 'Male');
      expect(json['phoneNumber'], '9876543210');

      final deserialized = HealthProfile.fromJson(json);
      expect(deserialized.name, 'Aarav Patel');
      expect(deserialized.age, 32);
      expect(deserialized.gender, 'Male');
      expect(deserialized.phoneNumber, '9876543210');
    });

    test('SchemeEligibilityProfile converts to and from JSON correctly', () {
      const schemeProfile = SchemeEligibilityProfile(
        age: 22,
        state: 'Delhi',
        incomeRange: '1 - 2.5 Lakh',
        gender: 'Female',
      );

      final json = schemeProfile.toJson();
      expect(json['age'], 22);
      expect(json['state'], 'Delhi');
      expect(json['income_range'], '1 - 2.5 Lakh');
      expect(json['gender'], 'Female');

      final deserialized = SchemeEligibilityProfile.fromJson(json);
      expect(deserialized.age, 22);
      expect(deserialized.state, 'Delhi');
      expect(deserialized.summaryText, 'Age: 22 • Delhi • 1 - 2.5 Lakh income');
    });

    test('Appointment converts to and from JSON correctly with 0 fee', () {
      final appointment = Appointment(
        id: 'APT-12345',
        tokenNumber: 'Token #01',
        doctorId: 'doc_1',
        doctorName: 'Dr. Ananya Sharma',
        doctorSpecialty: 'General Physician',
        hospitalName: 'City Civil Hospital',
        patientName: 'Mayank Kumar',
        patientPhone: '9876543210',
        appointmentDate: 'Wed, 02 Sep 2026',
        timeSlot: '10:00 AM',
        consultationFee: 0,
        bookedAt: DateTime.now(),
      );

      final json = appointment.toJson();
      expect(json['id'], 'APT-12345');
      expect(json['tokenNumber'], 'Token #01');
      expect(json['consultationFee'], 0);

      final deserialized = Appointment.fromJson(json);
      expect(deserialized.id, 'APT-12345');
      expect(deserialized.doctorName, 'Dr. Ananya Sharma');
      expect(deserialized.consultationFee, 0);
    });
  });

  group('Signup and Dashboard Tests', () {
    testWidgets('SignupScreen validates required fields on Continue', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => HealthProfileProvider()),
            ChangeNotifierProvider(create: (_) => AppointmentProvider()),
            ChangeNotifierProvider(create: (_) => SchemesProvider()),
          ],
          child: const MaterialApp(
            home: SignupScreen(),
          ),
        ),
      );

      expect(find.text('Create Health Profile'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Please enter your age'), findsOneWidget);
      expect(find.text('Please select your gender'), findsOneWidget);
      expect(find.text('Please enter your phone number'), findsOneWidget);
    });

    testWidgets('Filling Signup form navigates to Wireframe Dashboard', (WidgetTester tester) async {
      final profileProvider = HealthProfileProvider();
      final appointmentProvider = AppointmentProvider();
      final schemesProvider = SchemesProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: profileProvider),
            ChangeNotifierProvider.value(value: appointmentProvider),
            ChangeNotifierProvider.value(value: schemesProvider),
          ],
          child: const MaterialApp(
            home: SignupScreen(),
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Sneha Reddy');
      await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '29');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number'), '9123456789');

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('NEWS FLASH'), findsOneWidget);
      expect(find.text('REMINDER'), findsOneWidget);
      expect(find.text('Buy\nMedicines'), findsOneWidget);
      expect(find.text('AI\nAssistant'), findsOneWidget);
      expect(find.text('EMERGENCY'), findsOneWidget);
      expect(find.text('LANG'), findsOneWidget);
      expect(find.text('CONTACT\nDOCTOR'), findsOneWidget);
      expect(find.text('VOICE'), findsOneWidget);
      expect(find.text('Measure Live Heart Rate'), findsOneWidget);
    });
  });

  group('Government Schemes Module Tests', () {
    testWidgets('First time Schemes tab shows Eligibility Form', (WidgetTester tester) async {
      final schemesProvider = SchemesProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: schemesProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SchemesTab()),
          ),
        ),
      );

      expect(find.byType(EligibilityFormScreen), findsOneWidget);
      expect(find.text('Find Government Health Benefits'), findsOneWidget);
      expect(find.text('Tell us a little about yourself so we can find schemes you may be eligible for.'), findsOneWidget);
      expect(find.text('Find My Schemes'), findsOneWidget);
      expect(find.text('Your information is used to find relevant government health benefits.'), findsOneWidget);
    });

    testWidgets('Submitting Eligibility Form saves profile and displays Schemes Results', (WidgetTester tester) async {
      final schemesProvider = SchemesProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: schemesProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SchemesTab()),
          ),
        ),
      );

      // Enter age
      await tester.enterText(find.widgetWithText(TextFormField, 'Your Age *'), '22');

      // Tap Find My Schemes
      await tester.tap(find.text('Find My Schemes'));
      await tester.pumpAndSettle();

      // Verify Schemes Results Screen
      expect(find.byType(SchemesResultsScreen), findsOneWidget);
      expect(find.text('Based on your profile'), findsOneWidget);
      expect(find.text('Government Health Benefits'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      expect(find.textContaining('🟢 You May Be Eligible'), findsWidgets);
    });

    testWidgets('Tapping View Details opens SchemeDetailScreen', (WidgetTester tester) async {
      final schemesProvider = SchemesProvider();
      await schemesProvider.saveProfileAndEvaluate(
        const SchemeEligibilityProfile(age: 25, state: 'Delhi', incomeRange: '< 1 Lakh'),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: schemesProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SchemesTab()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SchemesResultsScreen), findsOneWidget);
      final viewDetailsButton = find.text('View Details').first;
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      expect(find.byType(SchemeDetailScreen), findsOneWidget);
      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.text('BENEFITS'), findsOneWidget);
      expect(find.text('DOCUMENTS REQUIRED'), findsOneWidget);
      expect(find.text('HOW TO APPLY'), findsOneWidget);
      expect(find.text('Apply / Official Website →'), findsOneWidget);
    });
  });

  group('Appointment Booking & Receipt Flow Tests', () {
    testWidgets('Booking an appointment generates online receipt with Token and 0 fee', (WidgetTester tester) async {
      final profileProvider = HealthProfileProvider();
      final appointmentProvider = AppointmentProvider();
      final schemesProvider = SchemesProvider();

      await profileProvider.saveProfile(
        HealthProfile(
          name: 'Rahul Sharma',
          age: 30,
          gender: 'Male',
          phoneNumber: '9876543210',
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: profileProvider),
            ChangeNotifierProvider.value(value: appointmentProvider),
            ChangeNotifierProvider.value(value: schemesProvider),
          ],
          child: const MaterialApp(
            home: BookAppointmentScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify doctors list loaded
      expect(find.text('Available Doctors'), findsOneWidget);
      expect(find.text('Dr. Ananya Sharma'), findsOneWidget);

      // Pick a time slot
      final slotFinder = find.text('09:00 AM');
      await tester.ensureVisible(slotFinder);
      await tester.tap(slotFinder);
      await tester.pumpAndSettle();

      // Tap confirm booking
      final confirmButtonFinder = find.byType(FilledButton);
      await tester.tap(confirmButtonFinder);
      await tester.pumpAndSettle();

      // Verify Receipt Screen
      expect(find.byType(AppointmentReceiptScreen), findsOneWidget);
      expect(find.text('Appointment Confirmed!'), findsOneWidget);
      expect(find.text('Token #01'), findsOneWidget);
      expect(find.text('Dr. Ananya Sharma'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('₹0 (Free Consultation)'), findsOneWidget);
    });

    test('Latest appointment booked is sorted first at the top of the appointments list', () async {
      final appointmentProvider = AppointmentProvider();
      final doctors = await MockDoctorService().getDoctors();
      final doctor = doctors.first;
      final patient = HealthProfile(name: 'Test Patient', age: 25, gender: 'Male', phoneNumber: '9876543210');

      // Book first appointment
      final apt1 = await appointmentProvider.bookAppointment(
        doctor: doctor,
        patient: patient,
        appointmentDate: 'Wed, 02 Sep 2026',
        timeSlot: '09:00 AM',
      );

      // Wait 10ms so timestamps differ
      await Future.delayed(const Duration(milliseconds: 10));

      // Book second appointment (later)
      final apt2 = await appointmentProvider.bookAppointment(
        doctor: doctor,
        patient: patient,
        appointmentDate: 'Thu, 03 Sep 2026',
        timeSlot: '11:00 AM',
      );

      final list = appointmentProvider.appointments;
      expect(list.length, 2);
      expect(list.first.id, apt2.id, reason: 'Latest booked appointment (apt2) should be at index 0');
      expect(list.last.id, apt1.id, reason: 'Earlier appointment (apt1) should be after the latest one');
    });
  });
}
