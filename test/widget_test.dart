import 'package:flutter_test/flutter_test.dart';
import 'package:sih_project/main.dart';

void main() {
  testWidgets('App renders clean initial dashboard widget', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
