import 'package:flutter_test/flutter_test.dart';
import 'package:sih_project/features/chatbot/data/services/gemini_cloud_llm_client.dart';
import 'package:sih_project/services/stt/sarvam_stt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SarvamSttService Unit Tests', () {
    final stt = SarvamSttService.instance;

    test('Maps all 22 Scheduled Indian Languages correctly for STT', () {
      expect(stt.resolveLanguageCode('hi'), equals('hi-IN'));
      expect(stt.resolveLanguageCode('hindi'), equals('hi-IN'));
      expect(stt.resolveLanguageCode('en'), equals('en-IN'));
      expect(stt.resolveLanguageCode('bn'), equals('bn-IN'));
      expect(stt.resolveLanguageCode('ta'), equals('ta-IN'));
      expect(stt.resolveLanguageCode('te'), equals('te-IN'));
      expect(stt.resolveLanguageCode('kn'), equals('kn-IN'));
      expect(stt.resolveLanguageCode('ml'), equals('ml-IN'));
      expect(stt.resolveLanguageCode('mr'), equals('mr-IN'));
      expect(stt.resolveLanguageCode('gu'), equals('gu-IN'));
      expect(stt.resolveLanguageCode('pa'), equals('pa-IN'));
      expect(stt.resolveLanguageCode('od'), equals('od-IN'));
      expect(stt.resolveLanguageCode('as'), equals('as-IN'));
      expect(stt.resolveLanguageCode('ur'), equals('ur-IN'));
      expect(stt.resolveLanguageCode('sa'), equals('sa-IN'));
      expect(stt.resolveLanguageCode('ne'), equals('ne-NP'));
      expect(stt.resolveLanguageCode('ks'), equals('ks-IN'));
      expect(stt.resolveLanguageCode('kok'), equals('kok-IN'));
      expect(stt.resolveLanguageCode('mai'), equals('mai-IN'));
      expect(stt.resolveLanguageCode('mni'), equals('mni-IN'));
      expect(stt.resolveLanguageCode('brx'), equals('brx-IN'));
      expect(stt.resolveLanguageCode('doi'), equals('doi-IN'));
      expect(stt.resolveLanguageCode('sat'), equals('sat-IN'));
      expect(stt.resolveLanguageCode('sd'), equals('sd-IN'));
      expect(stt.resolveLanguageCode(null), equals('en-IN'));
      expect(stt.resolveLanguageCode('unknown_lang'), equals('en-IN'));
    });

    test('STT status notifier defaults to idle', () {
      expect(stt.statusNotifier.value.isIdle, isTrue);
      expect(stt.statusNotifier.value.isListening, isFalse);
      expect(stt.statusNotifier.value.isTranscribing, isFalse);
    });

    test('Custom API key can be set and accessed', () {
      stt.setApiKey('test_sarvam_stt_key');
      expect(stt.activeApiKey, equals('test_sarvam_stt_key'));
      stt.setApiKey('');
    });
  });

  group('Gemini 18-Key Round-Robin & Failover Tests', () {
    test('Active key pool contains exactly 18 verified keys', () {
      expect(GeminiCloudLlmClient.activeKeyPool.length, equals(18));
      for (final key in GeminiCloudLlmClient.activeKeyPool) {
        expect(key.startsWith('AIzaSy'), isTrue);
      }
    });

    test('getNextPoolKey rotates sequentially through all keys', () {
      final key1 = GeminiCloudLlmClient.getNextPoolKey();
      final key2 = GeminiCloudLlmClient.getNextPoolKey();
      expect(key1, isNotEmpty);
      expect(key2, isNotEmpty);
      expect(key1, isNot(equals(key2)));
    });

    test('GeminiCloudLlmClient automatically fails over on 429 and rotates key', () async {
      final requestedKeys = <String>[];
      int callCount = 0;

      final client = GeminiCloudLlmClient(
        httpHandler: (uri, headers, body) async {
          callCount++;
          final key = uri.queryParameters['key'] ?? '';
          requestedKeys.add(key);

          // Fail first call with rate limit 429
          if (callCount == 1) {
            throw Exception('HTTP 429: Resource has been exhausted (rate limit)');
          }

          // Second call on rotated key succeeds
          return {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Paracetamol is safe to take as prescribed by your doctor.'}
                  ]
                }
              }
            ]
          };
        },
      );

      final response = await client.generateResponse(
        prompt: 'Can I take paracetamol?',
        contextChunks: const [],
      );
      expect(response.text, contains('Paracetamol is safe'));
      expect(callCount, equals(2));
      expect(requestedKeys.length, equals(2));
      expect(requestedKeys[0], isNot(equals(requestedKeys[1])));
    });
  });
}
