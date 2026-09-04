import 'package:flutter/material.dart';

import 'data/appointment_repository.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const DoctorTeleconsultApp());
}

class DoctorTeleconsultApp extends StatefulWidget {
  const DoctorTeleconsultApp({super.key});

  @override
  State<DoctorTeleconsultApp> createState() => _DoctorTeleconsultAppState();
}

class _DoctorTeleconsultAppState extends State<DoctorTeleconsultApp> {
  late final AppointmentRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = MockAppointmentRepository();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF006C67),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Doctor Teleconsult',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7F7),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFDDE5E4)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: DashboardScreen(
        repository: _repository,
        doctorName: 'Dr. Ananya Sharma',
      ),
    );
  }
}
