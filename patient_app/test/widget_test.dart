import 'package:sih_project/screens/tabs/appointments_tab.dart';
import 'package:sih_project/screens/appointments/video_consultation_screen.dart';
import 'package:sih_project/models/family_member.dart';
import 'package:sih_project/screens/family/family_data_screen.dart';
import 'package:sih_project/widgets/patient_drawer.dart';
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

      // On landing page, tap Sign Up to navigate to Signup form
      if (find.text('Sign Up').evaluate().isNotEmpty) {
        await tester.tap(find.text('Sign Up'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Create Health Profile'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      await tester.ensureVisible(find.text('Continue'));
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

      // On landing page, tap Sign Up to navigate to Signup form
      if (find.text('Sign Up').evaluate().isNotEmpty) {
        await tester.tap(find.text('Sign Up'));
        await tester.pumpAndSettle();
      }

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Sneha Reddy');
      await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '29');
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number'), '9123456789');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'pass1234');

      await tester.ensureVisible(find.text('Continue'));
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

    testWidgets('Login tab validates and authenticates patient into Dashboard', (WidgetTester tester) async {
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
            home: SignupScreen(initialTabIndex: 0),
          ),
        ),
      );

      // Transition to Login if on landing
      if (find.text('Log In').evaluate().isNotEmpty && find.text('Patient Login').evaluate().isEmpty) {
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Patient Login'), findsOneWidget);
      expect(find.text('Log In to Ashwini'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Vikram Malhotra');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mobile Number'), '9876501234');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'mypass123');

      await tester.ensureVisible(find.text('Log In to Ashwini'));
      await tester.tap(find.text('Log In to Ashwini'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
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

  group('Family Health Sync & Drawer Header Tests', () {
    test('FamilyMember model serializes and deserializes correctly', () {
      final member = FamilyMember(
        id: 'FAM-1234',
        name: 'Pooja Malhotra',
        patientId: '14-4512-8821-9012',
        relation: 'Spouse',
        syncedAt: DateTime(2026, 9, 8),
      );

      final json = member.toJson();
      expect(json['id'], 'FAM-1234');
      expect(json['name'], 'Pooja Malhotra');
      expect(json['patientId'], '14-4512-8821-9012');
      expect(json['relation'], 'Spouse');

      final deserialized = FamilyMember.fromJson(json);
      expect(deserialized.id, 'FAM-1234');
      expect(deserialized.name, 'Pooja Malhotra');
      expect(deserialized.patientId, '14-4512-8821-9012');
      expect(deserialized.relation, 'Spouse');
    });

    testWidgets('PatientDrawer displays Profile header covering top with Patient ID and phone', (WidgetTester tester) async {
      final profileProvider = HealthProfileProvider();
      final profile = HealthProfile(
        name: 'Vikram Malhotra',
        age: 32,
        gender: 'Male',
        phoneNumber: '9876501234',
        patientId: '14-1234-5678-9012',
      );
      await profileProvider.signup(profile);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: profileProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              drawer: PatientDrawer(),
              body: Center(child: Text('Home')),
            ),
          ),
        ),
      );

      // Open drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Top Ashwini card is gone
      expect(find.text('Central Hospital & Patient Care'), findsNothing);

      // Profile card covers top with Patient ID, QR Card, and phone
      expect(find.text('QR Card'), findsOneWidget);
      expect(find.text('Vikram Malhotra'), findsOneWidget);
      expect(find.text('+91 9876501234'), findsOneWidget);
      expect(find.text('ID: 14-1234-5678-9012'), findsOneWidget);
      expect(find.text('FAMILY DATA'), findsOneWidget);
    });

    testWidgets('FamilyDataScreen allows adding and syncing family member', (WidgetTester tester) async {
      final profileProvider = HealthProfileProvider();
      final profile = HealthProfile(
        name: 'Vikram Malhotra',
        age: 32,
        gender: 'Male',
        phoneNumber: '9876501234',
        patientId: '14-1234-5678-9012',
      );
      await profileProvider.signup(profile);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: profileProvider),
          ],
          child: const MaterialApp(
            home: FamilyDataScreen(),
          ),
        ),
      );

      expect(find.text('Family Health Data'), findsOneWidget);
      expect(find.text('14-1234-5678-9012'), findsOneWidget);

      // Tap Add Member
      await tester.tap(find.text('Add Member'));
      await tester.pumpAndSettle();

      expect(find.text('Sync Family Member'), findsOneWidget);

      // Fill Name and Patient ID
      await tester.enterText(find.widgetWithText(TextFormField, 'Family Member Name'), 'Pooja Malhotra');
      await tester.enterText(find.widgetWithText(TextFormField, 'Member Patient ID'), '14-4512-8821-9012');

      // Submit
      await tester.tap(find.text('Sync & Link Family Member'));
      await tester.pumpAndSettle();

      expect(find.text('Pooja Malhotra'), findsOneWidget);
      expect(find.text('ID: 14-4512-8821-9012'), findsOneWidget);
      expect(find.text('Synced'), findsOneWidget);
    });
  });


  group('Online / Offline Appointment & Video Connect Tests', () {
    test('Appointment model handles appointmentType and isOnline correctly', () {
      final onlineApt = Appointment(
        id: 'APT-ON-101',
        tokenNumber: 'Token #01',
        doctorId: 'doc_1',
        doctorName: 'Dr. Ananya Sharma',
        doctorSpecialty: 'Cardiology',
        hospitalName: 'Ashwini Central Hospital',
        patientName: 'Piyush Patient',
        patientPhone: '9876501234',
        appointmentDate: 'Wed, 09 Sep 2026',
        timeSlot: '10:00 AM',
        appointmentType: 'Online',
        bookedAt: DateTime.now(),
      );

      expect(onlineApt.isOnline, true);
      final json = onlineApt.toJson();
      expect(json['appointmentType'], 'Online');

      final fromJson = Appointment.fromJson(json);
      expect(fromJson.isOnline, true);
      expect(fromJson.appointmentType, 'Online');

      final offlineApt = Appointment(
        id: 'APT-OFF-102',
        tokenNumber: 'Token #02',
        doctorId: 'doc_2',
        doctorName: 'Dr. Rajesh Verma',
        doctorSpecialty: 'Orthopedics',
        hospitalName: 'Ashwini Central Hospital',
        patientName: 'Piyush Patient',
        patientPhone: '9876501234',
        appointmentDate: 'Wed, 09 Sep 2026',
        timeSlot: '11:00 AM',
        appointmentType: 'Offline',
        bookedAt: DateTime.now(),
      );

      expect(offlineApt.isOnline, false);
      expect(offlineApt.toJson()['appointmentType'], 'Offline');
    });

    testWidgets('AppointmentReceiptScreen displays Connect button for Online appointments', (WidgetTester tester) async {
      final onlineApt = Appointment(
        id: 'APT-ON-999',
        tokenNumber: 'Token #09',
        doctorId: 'doc_1',
        doctorName: 'Dr. Ananya Sharma',
        doctorSpecialty: 'General Physician',
        hospitalName: 'Ashwini Central Hospital',
        patientName: 'Aarav Patel',
        patientPhone: '9123456789',
        appointmentDate: 'Thu, 10 Sep 2026',
        timeSlot: '02:00 PM',
        appointmentType: 'Online',
        bookedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentReceiptScreen(appointment: onlineApt),
        ),
      );

      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('Connect with Doctor (Video Call)'), findsOneWidget);

      // Scroll and Tap Connect button to verify VideoConsultationScreen opens
      await tester.ensureVisible(find.text('Connect with Doctor (Video Call)'));
      await tester.tap(find.text('Connect with Doctor (Video Call)'));
      await tester.pumpAndSettle();

      expect(find.byType(VideoConsultationScreen), findsOneWidget);
      expect(find.text('Dr. Ananya Sharma'), findsOneWidget);
      expect(find.textContaining('LIVE'), findsOneWidget);
      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);

      // Cleanly end call so VideoConsultationScreen Timer.periodic is cancelled
      await tester.tap(find.byIcon(Icons.call_end_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End Call'));
      await tester.pumpAndSettle();
    });

    testWidgets('AppointmentReceiptScreen does not display Connect button for Offline appointments', (WidgetTester tester) async {
      final offlineApt = Appointment(
        id: 'APT-OFF-888',
        tokenNumber: 'Token #14',
        doctorId: 'doc_1',
        doctorName: 'Dr. Ananya Sharma',
        doctorSpecialty: 'General Physician',
        hospitalName: 'Ashwini Central Hospital',
        patientName: 'Aarav Patel',
        patientPhone: '9123456789',
        appointmentDate: 'Thu, 10 Sep 2026',
        timeSlot: '03:00 PM',
        appointmentType: 'Offline',
        bookedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentReceiptScreen(appointment: offlineApt),
        ),
      );

      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('Connect with Doctor (Video Call)'), findsNothing);
      expect(find.textContaining('Please arrive at the hospital counter'), findsOneWidget);
    });

    testWidgets('AppointmentsTab shows Connect Video Consultation button for online appointments', (WidgetTester tester) async {
      final appointmentProvider = AppointmentProvider();
      final doctor = MockDoctorService().getDoctorById('doc_1')!;
      final patient = HealthProfile(
        name: 'Online Patient',
        age: 30,
        gender: 'Female',
        phoneNumber: '9876543210',
      );

      await tester.runAsync(() async {
        await appointmentProvider.bookAppointment(
          doctor: doctor,
          patient: patient,
          appointmentDate: 'Fri, 11 Sep 2026',
          timeSlot: '10:00 AM',
          appointmentType: 'Online',
        );
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: appointmentProvider),
          ],
          child: const MaterialApp(
            home: AppointmentsTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('Connect Video Consultation'), findsOneWidget);
    });

    testWidgets('AppointmentReceiptScreen Go to My Appointments button navigates to AppointmentsTab', (WidgetTester tester) async {
      final appointmentProvider = AppointmentProvider();
      final doctor = MockDoctorService().getDoctorById('doc_1')!;
      final patient = HealthProfile(
        name: 'Test Patient',
        age: 28,
        gender: 'Male',
        phoneNumber: '9876543210',
      );

      late Appointment appt;
      await tester.runAsync(() async {
        appt = await appointmentProvider.bookAppointment(
          doctor: doctor,
          patient: patient,
          appointmentDate: 'Fri, 11 Sep 2026',
          timeSlot: '11:00 AM',
          appointmentType: 'Online',
        );
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: appointmentProvider),
          ],
          child: MaterialApp(
            home: AppointmentReceiptScreen(appointment: appt),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final goToAppointmentsBtn = find.text('Go to My Appointments');
      expect(goToAppointmentsBtn, findsOneWidget);

      await tester.tap(goToAppointmentsBtn);
      await tester.pumpAndSettle();

      // Verify that AppointmentsTab is now displayed with My Appointments title
      expect(find.text('My Appointments'), findsOneWidget);
      expect(find.byType(AppointmentsTab), findsOneWidget);
    });
  });
}

