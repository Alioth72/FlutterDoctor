import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/appointment_repository.dart';
import 'firebase_options.dart';
import 'screens/patient_home_screen.dart';

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
    PatientApp(
      repository: MockAppointmentRepository(),
      firestore: firestore,
      firebaseError: firebaseError,
    ),
  );
}

class PatientApp extends StatelessWidget {
  const PatientApp({
    required this.repository,
    required this.firestore,
    required this.firebaseError,
    super.key,
  });

  final AppointmentRepository repository;
  final FirebaseFirestore? firestore;
  final String? firebaseError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swasthya Connect Patient',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087E8B)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F8F8),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
      ),
      home: PatientHomeScreen(
        repository: repository,
        firestore: firestore,
        firebaseError: firebaseError,
      ),
    );
  }
}
