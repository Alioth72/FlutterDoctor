import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/data/patient_appointment_repository.dart';
import 'package:patient_app/models/patient_appointment.dart';
import 'package:patient_app/models/patient_call_log.dart';
import 'package:patient_app/screens/patient_call_ended_screen.dart';
import 'package:patient_app/screens/patient_home_screen.dart';

void main() {
  testWidgets('patient can open the ready consultation details', (
    tester,
  ) async {
    final repository = _FakePatientRepository();

    await tester.pumpWidget(
      MaterialApp(home: PatientHomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dr. Ananya Sharma'), findsOneWidget);
    final joinButton = find.byKey(const ValueKey('join_apt_001'));
    expect(tester.widget<FilledButton>(joinButton).onPressed, isNotNull);

    await tester.tap(joinButton);
    await tester.pumpAndSettle();

    expect(find.text('Consultation details'), findsOneWidget);
    expect(find.text('General Medicine'), findsOneWidget);
    expect(
      find.text('Persistent cough, mild fever for 3 days'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('join_call')), findsOneWidget);
  });

  testWidgets('call-ended screen displays duration and returns home', (
    tester,
  ) async {
    final repository = _FakePatientRepository();
    final callLog = PatientCallLog(appointmentId: 'apt_001')
      ..startedAt = DateTime(2026, 9, 7, 10)
      ..endedAt = DateTime(2026, 9, 7, 10, 4, 12);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PatientCallEndedScreen(
                    appointment: repository.appointments.first,
                    callLog: callLog,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('4:12'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('done')));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });
}

class _FakePatientRepository implements PatientAppointmentRepository {
  final appointments = [
    PatientAppointment(
      id: 'apt_001',
      patientName: 'Ramesh Kumar',
      doctorName: 'Dr. Ananya Sharma',
      doctorSpecialty: 'General Medicine',
      reason: 'Persistent cough, mild fever for 3 days',
      scheduledTime: DateTime(2026, 9, 7, 10),
    ),
  ];

  @override
  Future<List<PatientAppointment>> getTodaysAppointments() async =>
      appointments;

  @override
  Future<void> saveCallLog(PatientCallLog log) async {}

  @override
  Future<void> updateAppointmentStatus(
    String appointmentId,
    PatientAppointmentStatus status,
  ) async {
    appointments.firstWhere((item) => item.id == appointmentId).status = status;
  }
}
