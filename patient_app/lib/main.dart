import 'package:flutter/material.dart';

import 'data/patient_appointment_repository.dart';
import 'screens/patient_home_screen.dart';

void main() {
  runApp(const PatientTeleconsultApp());
}

class PatientTeleconsultApp extends StatefulWidget {
  const PatientTeleconsultApp({super.key});

  @override
  State<PatientTeleconsultApp> createState() => _PatientTeleconsultAppState();
}

class _PatientTeleconsultAppState extends State<PatientTeleconsultApp> {
  late final PatientAppointmentRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = MockPatientAppointmentRepository();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF365F91),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Patient Teleconsult',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFDCE3EB)),
          ),
        ),
      ),
      home: PatientHomeScreen(repository: _repository),
    );
  }
}
