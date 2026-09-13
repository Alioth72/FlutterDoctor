// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const apiKey = 'sk_r8oy8ofr_iIrWH1PKWxuEZZnRkp3Eca2s';

  group('Rigorous Sarvam API Model & Language Matrix Backtest', () {
    test('Verify API key validity against Sarvam Translation Endpoint', () async {
      final response = await http.post(
        Uri.parse('https://api.sarvam.ai/translate'),
        headers: {
          'Content-Type': 'application/json',
          'api-subscription-key': apiKey,
        },
        body: jsonEncode({
          'input': 'Emergency medical services',
          'source_language_code': 'en-IN',
          'target_language_code': 'hi-IN',
          'speaker_gender': 'Male',
          'mode': 'formal',
          'model': 'mayura:v1',
        }),
      );

      expect(response.statusCode, 200, reason: 'Sarvam API should accept valid subscription key');
      final data = jsonDecode(response.body);
      expect(data['translated_text'], isNotNull);
      final translation = data['translated_text'] as String;
      expect(translation.isNotEmpty, true);
      print('✓ [Sarvam API Live Test] hi-IN translation: "$translation"');
    });

    test('Test translation capabilities across major Indic language families', () async {
      // Test representative languages across language families
      final testLanguages = [
        {'code': 'hi-IN', 'name': 'Hindi (Devanagari)'},
        {'code': 'ta-IN', 'name': 'Tamil (Dravidian)'},
        {'code': 'te-IN', 'name': 'Telugu (Dravidian)'},
        {'code': 'bn-IN', 'name': 'Bengali (Eastern Indo-Aryan)'},
        {'code': 'mr-IN', 'name': 'Marathi (Western Indo-Aryan)'},
        {'code': 'gu-IN', 'name': 'Gujarati (Western Indo-Aryan)'},
        {'code': 'kn-IN', 'name': 'Kannada (Dravidian)'},
        {'code': 'ml-IN', 'name': 'Malayalam (Dravidian)'},
        {'code': 'pa-IN', 'name': 'Punjabi (Northwestern)'},
        {'code': 'od-IN', 'name': 'Odia (Eastern Indo-Aryan)'},
      ];

      for (final lang in testLanguages) {
        final targetCode = lang['code']!;
        final name = lang['name']!;

        final response = await http.post(
          Uri.parse('https://api.sarvam.ai/translate'),
          headers: {
            'Content-Type': 'application/json',
            'api-subscription-key': apiKey,
          },
          body: jsonEncode({
            'input': 'Consult a Doctor',
            'source_language_code': 'en-IN',
            'target_language_code': targetCode,
            'speaker_gender': 'Male',
            'mode': 'formal',
            'model': 'mayura:v1',
          }),
        );

        expect(
          response.statusCode,
          200,
          reason: 'Language $name ($targetCode) should return 200 from Sarvam API',
        );

        final data = jsonDecode(response.body);
        final translatedText = data['translated_text'] as String;
        expect(translatedText.isNotEmpty, true);
        print('✓ [Sarvam Live] $name ($targetCode) => "$translatedText"');
      }
    });

    test('Verify model behavior for scheduled languages with sarvam-translate:v1 vs mayura:v1', () async {
      // Check Sanskrit (sa-IN) or Urdu (ur-IN)
      for (final targetCode in ['ur-IN', 'as-IN', 'ne-IN']) {
        // Try sarvam-translate:v1 first, then mayura:v1
        final resp1 = await http.post(
          Uri.parse('https://api.sarvam.ai/translate'),
          headers: {
            'Content-Type': 'application/json',
            'api-subscription-key': apiKey,
          },
          body: jsonEncode({
            'input': 'Consult a Doctor',
            'source_language_code': 'en-IN',
            'target_language_code': targetCode,
            'speaker_gender': 'Male',
            'mode': 'formal',
            'model': 'sarvam-translate:v1',
          }),
        );

        print('[Model test sarvam-translate:v1 for $targetCode]: HTTP ${resp1.statusCode} - ${resp1.body}');

        final resp2 = await http.post(
          Uri.parse('https://api.sarvam.ai/translate'),
          headers: {
            'Content-Type': 'application/json',
            'api-subscription-key': apiKey,
          },
          body: jsonEncode({
            'input': 'Consult a Doctor',
            'source_language_code': 'en-IN',
            'target_language_code': targetCode,
            'speaker_gender': 'Male',
            'mode': 'formal',
            'model': 'mayura:v1',
          }),
        );

        print('[Model test mayura:v1 for $targetCode]: HTTP ${resp2.statusCode} - ${resp2.body}');
      }
    });
  });
}
