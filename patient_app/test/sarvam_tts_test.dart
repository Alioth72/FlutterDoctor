import 'package:flutter_test/flutter_test.dart';
import 'package:sih_project/services/tts/sarvam_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SarvamTtsService Unit Tests', () {
    final tts = SarvamTtsService.instance;

    test('Maps all 22 Scheduled Indian Languages correctly', () {
      // 11 Native Sarvam Bulbul codes
      expect(tts.resolveLanguageCode('hi'), equals('hi-IN'));
      expect(tts.resolveLanguageCode('Hindi'), equals('hi-IN'));
      expect(tts.resolveLanguageCode('bn'), equals('bn-IN'));
      expect(tts.resolveLanguageCode('Bengali'), equals('bn-IN'));
      expect(tts.resolveLanguageCode('ta'), equals('ta-IN'));
      expect(tts.resolveLanguageCode('Tamil'), equals('ta-IN'));
      expect(tts.resolveLanguageCode('te'), equals('te-IN'));
      expect(tts.resolveLanguageCode('Telugu'), equals('te-IN'));
      expect(tts.resolveLanguageCode('kn'), equals('kn-IN'));
      expect(tts.resolveLanguageCode('Kannada'), equals('kn-IN'));
      expect(tts.resolveLanguageCode('ml'), equals('ml-IN'));
      expect(tts.resolveLanguageCode('Malayalam'), equals('ml-IN'));
      expect(tts.resolveLanguageCode('mr'), equals('mr-IN'));
      expect(tts.resolveLanguageCode('Marathi'), equals('mr-IN'));
      expect(tts.resolveLanguageCode('gu'), equals('gu-IN'));
      expect(tts.resolveLanguageCode('Gujarati'), equals('gu-IN'));
      expect(tts.resolveLanguageCode('pa'), equals('pa-IN'));
      expect(tts.resolveLanguageCode('Punjabi'), equals('pa-IN'));
      expect(tts.resolveLanguageCode('or'), equals('od-IN'));
      expect(tts.resolveLanguageCode('od'), equals('od-IN'));
      expect(tts.resolveLanguageCode('Odia'), equals('od-IN'));
      expect(tts.resolveLanguageCode('en'), equals('en-IN'));
      expect(tts.resolveLanguageCode('English'), equals('en-IN'));

      // Remaining 11 Scheduled Languages
      expect(tts.resolveLanguageCode('as'), equals('as-IN'));
      expect(tts.resolveLanguageCode('ur'), equals('ur-IN'));
      expect(tts.resolveLanguageCode('sa'), equals('sa-IN'));
      expect(tts.resolveLanguageCode('ne'), equals('ne-NP'));
      expect(tts.resolveLanguageCode('kok'), equals('kok-IN'));
      expect(tts.resolveLanguageCode('mai'), equals('mai-IN'));
      expect(tts.resolveLanguageCode('brx'), equals('brx-IN'));
      expect(tts.resolveLanguageCode('doi'), equals('doi-IN'));
      expect(tts.resolveLanguageCode('ks'), equals('ks-IN'));
      expect(tts.resolveLanguageCode('mni'), equals('mni-IN'));
      expect(tts.resolveLanguageCode('sat'), equals('sat-IN'));
      expect(tts.resolveLanguageCode('sd'), equals('sd-IN'));

      // Fallback for null / empty
      expect(tts.resolveLanguageCode(null), equals('en-IN'));
      expect(tts.resolveLanguageCode(''), equals('en-IN'));
      expect(tts.resolveLanguageCode('unknown'), equals('en-IN'));
    });

    test('Cleans markdown, asterisks, URLs, and headers for natural speech', () {
      const rawMarkdown = '''
### 🏥 Healthcare Recommendation
You should take **Paracetamol 650mg** as prescribed:
- 1 tablet in morning
- 1 tablet at night
For more info visit https://example.com/health.
`code snippet` should be stripped.
''';

      final cleaned = tts.cleanTextForSpeech(rawMarkdown);

      expect(cleaned.contains('**'), isFalse);
      expect(cleaned.contains('###'), isFalse);
      expect(cleaned.contains('https://'), isFalse);
      expect(cleaned.contains('`'), isFalse);
      expect(cleaned.contains('Paracetamol 650mg'), isTrue);
      expect(cleaned.contains('1 tablet in morning'), isTrue);
    });

    test('Initializes with default API key and allows custom key configuration', () {
      expect(tts.activeApiKey.isNotEmpty, isTrue);

      tts.setApiKey('sk_custom_test_key_123');
      expect(tts.activeApiKey, equals('sk_custom_test_key_123'));

      tts.setApiKey(''); // Reset to default
      expect(tts.activeApiKey.startsWith('sk_'), isTrue);
    });

    test('TtsPlaybackStatus reports correct states', () {
      const idleStatus = TtsPlaybackStatus(state: TtsState.idle);
      expect(idleStatus.isIdle, isTrue);
      expect(idleStatus.isPlaying, isFalse);
      expect(idleStatus.isLoading, isFalse);

      const loadingStatus = TtsPlaybackStatus(state: TtsState.loading, activeMessageId: 'msg_1');
      expect(loadingStatus.isLoading, isTrue);
      expect(loadingStatus.activeMessageId, equals('msg_1'));

      const playingStatus = TtsPlaybackStatus(state: TtsState.playing, activeMessageId: 'msg_1');
      expect(playingStatus.isPlaying, isTrue);
    });

    test('SarvamTtsService 2-key pool rotates sequentially and has both active keys', () {
      expect(SarvamTtsService.activeKeyPool.length, equals(2));
      expect(SarvamTtsService.activeKeyPool, contains('sk_rfg7nmlj_a5JVAc1PsHmW1l3IKtBMXioA'));
      expect(SarvamTtsService.activeKeyPool, contains('sk_zjtuxntf_kgBFei7kGQ0AYfP3IhMaXqsu'));

      final k1 = SarvamTtsService.getNextPoolKey();
      final k2 = SarvamTtsService.getNextPoolKey();
      expect(k1, isNot(equals(k2)));
    });
  });
}
