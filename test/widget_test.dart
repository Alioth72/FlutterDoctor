import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sih_project/models/appointment.dart';
import 'package:sih_project/models/health_profile.dart';
import 'package:sih_project/providers/appointment_provider.dart';
import 'package:sih_project/providers/health_profile_provider.dart';
import 'package:sih_project/screens/appointments/appointment_receipt_screen.dart';
import 'package:sih_project/screens/appointments/book_appointment_screen.dart';
import 'package:sih_project/screens/home_screen.dart';
import 'package:sih_project/screens/signup_screen.dart';

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

  group('Signup and Onboarding Flow Tests', () {
    testWidgets('SignupScreen validates required fields on Continue', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => HealthProfileProvider()),
            ChangeNotifierProvider(create: (_) => AppointmentProvider()),
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

    testWidgets('Filling Signup form navigates to HomeScreen', (WidgetTester tester) async {
      final profileProvider = HealthProfileProvider();
      final appointmentProvider = AppointmentProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: profileProvider),
            ChangeNotifierProvider.value(value: appointmentProvider),
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
      expect(find.text('Sneha Reddy'), findsOneWidget);
      expect(find.text('29 yrs'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
    });

    testWidgets('HomeScreen bottom navigation switches tabs', (WidgetTester tester) async {
      final profileProvider = HealthProfileProvider();
      final appointmentProvider = AppointmentProvider();

      await profileProvider.saveProfile(
        HealthProfile(
          name: 'Vikram Singh',
          age: 45,
          gender: 'Male',
          phoneNumber: '9876543210',
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: profileProvider),
            ChangeNotifierProvider.value(value: appointmentProvider),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      expect(find.text('Patient Home'), findsOneWidget);
      expect(find.text('Vikram Singh'), findsOneWidget);

      // Switch to Appointments tab
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Appointments'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('No Appointments Yet'), findsOneWidget);

      // Switch to Schemes tab
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Schemes'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Government Health Schemes Shell'), findsOneWidget);

      // Switch to Profile tab
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profile'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Personal Information'), findsOneWidget);
    });
  });

  group('Appointment Booking & Receipt Flow Tests', () {
    testWidgets('Booking an appointment generates online receipt with Token and 0 fee', (WidgetTester tester) async {
      final profileProvider = HealthProfileProvider();
      final appointmentProvider = AppointmentProvider();

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
  });
}
