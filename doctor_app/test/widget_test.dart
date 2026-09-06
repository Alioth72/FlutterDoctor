import 'package:doctor_app/data/appointment_repository.dart';
import 'package:doctor_app/models/appointment.dart';
import 'package:doctor_app/models/call_log.dart';
import 'package:doctor_app/models/consent_record.dart';
import 'package:doctor_app/models/consultation_note.dart';
import 'package:doctor_app/screens/dashboard_screen.dart';
import 'package:doctor_app/screens/post_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('only the first waiting appointment can be joined', (
    tester,
  ) async {
    final repository = _FakeRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(repository: repository, doctorName: 'Dr. Test'),
      ),
    );
    await tester.pumpAndSettle();

    final firstJoin = tester.widget<FilledButton>(
      find.byKey(const ValueKey('join_apt_001')),
    );
    final secondJoin = tester.widget<FilledButton>(
      find.byKey(const ValueKey('join_apt_002')),
    );
    expect(firstJoin.onPressed, isNotNull);
    expect(secondJoin.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('join_apt_001')));
    await tester.pumpAndSettle();

    expect(find.text('Ramesh Kumar'), findsOneWidget);
    expect(find.text('45 years'), findsOneWidget);
    final startButton = find.byKey(const ValueKey('start_consultation'));
    expect(tester.widget<FilledButton>(startButton).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('consent_checkbox')));
    await tester.pump();
    expect(tester.widget<FilledButton>(startButton).onPressed, isNotNull);
  });

  testWidgets('post-call form adds rows, reveals referral, and saves', (
    tester,
  ) async {
    final repository = _FakeRepository();
    final callLog = CallLog(appointmentId: 'apt_001')
      ..startedAt = DateTime(2026, 9, 4, 10)
      ..endedAt = DateTime(2026, 9, 4, 10, 3, 5);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PostCallScreen(
                      appointment: repository.appointments.first,
                      callLog: callLog,
                      repository: repository,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('3:05'), findsOneWidget);
    expect(find.byKey(const ValueKey('drug_name_0')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('clinical_notes')),
      'Patient is stable.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('drug_name_0')),
      'Paracetamol',
    );

    await tester.ensureVisible(find.byKey(const ValueKey('add_prescription')));
    await tester.tap(find.byKey(const ValueKey('add_prescription')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drug_name_1')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('drug_name_1')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('referral_toggle')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('referral_toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('referral_reason')), findsOneWidget);
    expect(find.byKey(const ValueKey('referral_facility')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('save_consultation')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('save_consultation')));
    await tester.pumpAndSettle();

    expect(repository.savedNote?.notes, 'Patient is stable.');
    expect(
      repository.savedNote?.prescriptionItems.first.drugName,
      'Paracetamol',
    );
    expect(repository.savedNote?.referralNeeded, isTrue);
    expect(repository.appointments.first.status, AppointmentStatus.completed);
  });
}

class _FakeRepository implements AppointmentRepository {
  final appointments = [
    Appointment(
      id: 'apt_001',
      patientName: 'Ramesh Kumar',
      patientAge: 45,
      chiefComplaint: 'Persistent cough',
      scheduledTime: DateTime(2026, 9, 4, 10),
      queuePosition: 1,
    ),
    Appointment(
      id: 'apt_002',
      patientName: 'Sunita Devi',
      patientAge: 32,
      chiefComplaint: 'Hypertension follow-up',
      scheduledTime: DateTime(2026, 9, 4, 10, 15),
      queuePosition: 2,
    ),
  ];
  ConsultationNote? savedNote;

  @override
  Future<List<Appointment>> getTodaysQueue() async => appointments;

  @override
  Future<void> recordConsent(ConsentRecord record) async {}

  @override
  Future<void> saveCallLog(CallLog log) async {}

  @override
  Future<void> saveConsultationNote(ConsultationNote note) async {
    savedNote = note;
  }

  @override
  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus status,
  ) async {
    appointments.firstWhere((item) => item.id == appointmentId).status = status;
  }
}
