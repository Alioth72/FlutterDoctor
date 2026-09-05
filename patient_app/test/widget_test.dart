// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:patient_app/data/appointment_repository.dart';
import 'package:patient_app/main.dart';

void main() {
  testWidgets('consent gates joining the patient call', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PatientApp(
        repository: MockAppointmentRepository(),
        firestore: null,
        firebaseError: 'not configured for test',
      ),
    );
    await tester.pumpAndSettle();

    final joinButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Join call'),
    );
    expect(joinButton.onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    final enabledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Join call'),
    );
    expect(enabledButton.onPressed, isNotNull);
  });
}
