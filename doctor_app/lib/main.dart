import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/appointment_repository.dart';
import 'firebase_options.dart';
import 'screens/doctor_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseFirestore? firestore;
  String? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firestore = FirebaseFirestore.instance;
  } catch (error) {
    firebaseError = error.toString();
  }
  runApp(
    DoctorApp(
      repository: MockAppointmentRepository(),
      firestore: firestore,
      firebaseError: firebaseError,
    ),
  );
}

class DoctorApp extends StatelessWidget {
  const DoctorApp({
    required this.repository,
    required this.firestore,
    required this.firebaseError,
    super.key,
  });
  final AppointmentRepository repository;
  final FirebaseFirestore? firestore;
  final String? firebaseError;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Swasthya Connect Doctor',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF315C9B)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
    ),
    home: DoctorDashboardScreen(
      repository: repository,
      firestore: firestore,
      firebaseError: firebaseError,
    ),
  );
}
