// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doctor_app/data/appointment_repository.dart';
import 'package:doctor_app/main.dart';

void main() {
  testWidgets('only the front appointment can be joined', (tester) async {
    await tester.pumpWidget(
      DoctorApp(
        repository: MockAppointmentRepository(),
        firestore: null,
        firebaseError: 'not configured for test',
      ),
    );
    await tester.pumpAndSettle();

    final buttons = tester
        .widgetList<FilledButton>(find.widgetWithText(FilledButton, 'Join'))
        .toList();
    expect(buttons, hasLength(2));
    expect(buttons.first.onPressed, isNotNull);
    expect(buttons.last.onPressed, isNull);
  });
}
