import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sih_project/providers/language_provider.dart';
import 'package:sih_project/services/localization/app_strings.dart';
import 'package:sih_project/widgets/dynamic_translated_text.dart';
import 'package:sih_project/widgets/hold_to_speak_overlay.dart';
import 'package:sih_project/widgets/speakable.dart';
import 'package:provider/provider.dart';

void main() {
  group('1-Second Hold-to-Speak (Speakable) Tests', () {
    testWidgets('Speakable does NOT trigger on quick tap (< 1000ms)', (tester) async {
      bool speechTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Speakable(
              text: 'Ayushman Bharat Scheme',
              onSpeechTriggered: () {
                speechTriggered = true;
              },
              child: const ElevatedButton(
                onPressed: null,
                child: Text('Click Me'),
              ),
            ),
          ),
        ),
      );

      // Tap down and up quickly (200ms)
      final gesture = await tester.startGesture(tester.getCenter(find.byType(ElevatedButton)));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 1000));

      expect(speechTriggered, isFalse);
    });

    testWidgets('Speakable triggers on full 1-second (1000ms) hold', (tester) async {
      bool speechTriggered = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Speakable(
                text: 'Ayushman Bharat Health Protection',
                holdDuration: const Duration(milliseconds: 1000),
                onSpeechTriggered: () {
                  speechTriggered = true;
                },
                child: const ElevatedButton(
                  onPressed: null,
                  child: Text('Hold Me'),
                ),
              ),
            ),
          ),
        ),
      );

      // Start gesture and hold for 1050ms
      final gesture = await tester.startGesture(tester.getCenter(find.byType(ElevatedButton)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(speechTriggered, isFalse); // not yet 1000ms

      await tester.pump(const Duration(milliseconds: 550));
      expect(speechTriggered, isTrue); // reached 1000ms!

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      HoldToSpeakOverlay.dismiss();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('DynamicTranslatedText has Speakable enabled by default', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DynamicTranslatedText(
                text: 'Pradhan Mantri Jan Arogya Yojana',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Speakable), findsOneWidget);
      expect(find.text('Pradhan Mantri Jan Arogya Yojana'), findsOneWidget);
    });

    testWidgets('AppLanguages prioritizes 11 voice-supported languages at top', (tester) async {
      expect(AppLanguages.voiceSupported11Languages.length, equals(11));
      expect(AppLanguages.voiceSupported11Languages.map((l) => l.code).toList(), [
        'en', 'hi', 'bn', 'te', 'mr', 'ta', 'gu', 'kn', 'ml', 'pa', 'or'
      ]);

      // Check top 11 of supportedLanguages matches voiceSupported11Languages
      final top11 = AppLanguages.supportedLanguages.take(11).map((l) => l.code).toList();
      expect(top11, equals([
        'en', 'hi', 'bn', 'te', 'mr', 'ta', 'gu', 'kn', 'ml', 'pa', 'or'
      ]));
    });

    testWidgets('HoldToSpeakOverlay shows and dismisses smoothly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    HoldToSpeakOverlay.show(
                      context,
                      text: 'Test Scheme Details',
                      languageCode: 'hi',
                      languageName: 'Hindi',
                    );
                  },
                  child: const Text('Show Overlay'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Overlay'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Reading aloud...'), findsOneWidget);
      expect(find.text('Test Scheme Details'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);

      // Tap Stop button
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      expect(find.text('Reading aloud...'), findsNothing);
    });
  });
}
