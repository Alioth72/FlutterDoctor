import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

/// Current state of the Text-to-Speech playback
enum TtsState {
  idle,
  loading,
  playing,
}

/// Information holder for the currently active TTS utterance
class TtsPlaybackStatus {
  final TtsState state;
  final String? activeMessageId;
  final String? errorMessage;
  final bool usedOnDeviceFallback;

  const TtsPlaybackStatus({
    this.state = TtsState.idle,
    this.activeMessageId,
    this.errorMessage,
    this.usedOnDeviceFallback = false,
  });

  bool get isPlaying => state == TtsState.playing;
  bool get isLoading => state == TtsState.loading;
  bool get isIdle => state == TtsState.idle;
}

/// Comprehensive Text-to-Speech service for all 22 Official Scheduled Indian Languages (+ English).
///
/// Dual-Engine Architecture:
/// 1. Primary: Sarvam AI Bulbul neural voice synthesis via REST API (/text-to-speech).
/// 2. Fallback: On-device Flutter TTS when Sarvam credits are depleted or for languages
///    outside Sarvam's Bulbul catalog.
class SarvamTtsService {
  SarvamTtsService._();
  static final SarvamTtsService instance = SarvamTtsService._();

  static const String _sarvamApiUrl = 'https://api.sarvam.ai/text-to-speech';
  
  /// Verified active Sarvam AI API keys in round-robin pool
  static const List<String> activeKeyPool = [
    'sk_rfg7nmlj_a5JVAc1PsHmW1l3IKtBMXioA',
    'sk_zjtuxntf_kgBFei7kGQ0AYfP3IhMaXqsu',
  ];
  static int _keyIndex = 0;

  static String getNextPoolKey() {
    final key = activeKeyPool[_keyIndex % activeKeyPool.length];
    _keyIndex++;
    return key;
  }

  String _customApiKey = '';
  AudioPlayer? _audioPlayer;
  FlutterTts? _flutterTts;

  AudioPlayer get audioPlayer => _audioPlayer ??= AudioPlayer();
  FlutterTts get flutterTts => _flutterTts ??= FlutterTts();

  final ValueNotifier<TtsPlaybackStatus> statusNotifier =
      ValueNotifier<TtsPlaybackStatus>(const TtsPlaybackStatus());

  bool _isInitialized = false;

  /// Sarvam Bulbul supported language codes
  static const Set<String> sarvamSupportedCodes = {
    'bn-IN',
    'en-IN',
    'gu-IN',
    'hi-IN',
    'kn-IN',
    'ml-IN',
    'mr-IN',
    'od-IN',
    'pa-IN',
    'ta-IN',
    'te-IN',
  };

  /// BCP-47 and ISO-639 mapping for all 22 Scheduled Indian Languages + English
  static const Map<String, String> languageTagMap = {
    // 11 Sarvam Native Codes
    'hi': 'hi-IN',
    'hindi': 'hi-IN',
    'en': 'en-IN',
    'english': 'en-IN',
    'bn': 'bn-IN',
    'bengali': 'bn-IN',
    'ta': 'ta-IN',
    'tamil': 'ta-IN',
    'te': 'te-IN',
    'telugu': 'te-IN',
    'kn': 'kn-IN',
    'kannada': 'kn-IN',
    'ml': 'ml-IN',
    'malayalam': 'ml-IN',
    'mr': 'mr-IN',
    'marathi': 'mr-IN',
    'gu': 'gu-IN',
    'gujarati': 'gu-IN',
    'pa': 'pa-IN',
    'punjabi': 'pa-IN',
    'or': 'od-IN',
    'od': 'od-IN',
    'odia': 'od-IN',

    // Remaining 11 Scheduled Languages (with on-device TTS locales)
    'as': 'as-IN',
    'assamese': 'as-IN',
    'ur': 'ur-IN',
    'urdu': 'ur-IN',
    'sa': 'sa-IN',
    'sanskrit': 'sa-IN',
    'ne': 'ne-NP',
    'nepali': 'ne-NP',
    'kok': 'kok-IN',
    'konkani': 'kok-IN',
    'mai': 'mai-IN',
    'maithili': 'mai-IN',
    'brx': 'brx-IN',
    'bodo': 'brx-IN',
    'doi': 'doi-IN',
    'dogri': 'doi-IN',
    'ks': 'ks-IN',
    'kashmiri': 'ks-IN',
    'mni': 'mni-IN',
    'manipuri': 'mni-IN',
    'sat': 'sat-IN',
    'santali': 'sat-IN',
    'sd': 'sd-IN',
    'sindhi': 'sd-IN',
  };

  String get activeApiKey =>
      _customApiKey.isNotEmpty ? _customApiKey : getNextPoolKey();

  void setApiKey(String key) {
    _customApiKey = key.trim();
  }

  Future<void> init() async {
    if (_isInitialized) return;

    audioPlayer.onPlayerComplete.listen((_) {
      statusNotifier.value = const TtsPlaybackStatus(state: TtsState.idle);
    });

    flutterTts.setCompletionHandler(() {
      statusNotifier.value = const TtsPlaybackStatus(state: TtsState.idle);
    });

    flutterTts.setErrorHandler((dynamic msg) {
      debugPrint('[SarvamTtsService] FlutterTts error: $msg');
      statusNotifier.value = TtsPlaybackStatus(
        state: TtsState.idle,
        errorMessage: msg?.toString(),
      );
    });

    _isInitialized = true;
  }

  /// Maps an app language code (e.g. 'hi', 'en', 'bn') to standard language code
  String resolveLanguageCode(String? code) {
    if (code == null || code.trim().isEmpty) return 'en-IN';
    final clean = code.trim().toLowerCase();
    return languageTagMap[clean] ?? 'en-IN';
  }

  /// Strips markdown syntax, asterisks, citations, and symbols for natural audio speech
  String cleanTextForSpeech(String text) {
    var cleaned = text;
    // Remove markdown bold / italic formatting
    cleaned = cleaned.replaceAll(RegExp(r'\*\*|__|\*|_'), '');
    // Remove headers
    cleaned = cleaned.replaceAll(RegExp(r'#+\s*'), '');
    // Remove bullets and numbered lists formatting
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[-•*]\s+', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');
    // Remove code blocks and inline code
    cleaned = cleaned.replaceAll(RegExp(r'`{1,3}[^`]*`{1,3}'), '');
    // Remove URLs
    cleaned = cleaned.replaceAll(RegExp(r'https?:\/\/\S+'), '');
    // Clean repetitive whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\n+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
    return cleaned.trim();
  }

  /// Plays text using Sarvam AI Bulbul TTS (with on-device fallback)
  Future<void> speak({
    required String text,
    String? messageId,
    String? languageCode,
    String speaker = 'meera',
    double speechRate = 1.0,
  }) async {
    await init();
    await stop();

    final cleanText = cleanTextForSpeech(text);
    if (cleanText.isEmpty) return;

    final resolvedLang = resolveLanguageCode(languageCode);

    statusNotifier.value = TtsPlaybackStatus(
      state: TtsState.loading,
      activeMessageId: messageId,
    );

    // 1. Try Sarvam AI API if the language is supported by Bulbul
    if (sarvamSupportedCodes.contains(resolvedLang)) {
      try {
        final success = await _trySarvamSpeech(
          text: cleanText,
          languageCode: resolvedLang,
          speaker: speaker,
          speechRate: speechRate,
          messageId: messageId,
        );

        if (success) return;
      } catch (e) {
        debugPrint('[SarvamTtsService] Sarvam API exception: $e. Falling back to on-device TTS.');
      }
    } else {
      debugPrint('[SarvamTtsService] Language $resolvedLang not in Bulbul 11 codes. Routing to system TTS.');
    }

    // 2. Fallback to on-device Flutter TTS
    await _speakOnDevice(
      text: cleanText,
      languageCode: resolvedLang,
      messageId: messageId,
      speechRate: speechRate,
    );
  }

  /// Calls Sarvam AI Text-to-Speech API
  Future<bool> _trySarvamSpeech({
    required String text,
    required String languageCode,
    required String speaker,
    required double speechRate,
    String? messageId,
  }) async {
    // Truncate text to 500 characters if too long for single request to avoid gateway timeout
    final inputChunk = text.length > 500 ? '${text.substring(0, 497)}...' : text;

    final body = jsonEncode({
      'inputs': [inputChunk],
      'target_language_code': languageCode,
      'speaker': speaker,
      'pitch': 0,
      'pace': speechRate,
      'loudness': 1.5,
      'speech_sample_rate': 8000,
      'enable_preprocessing': true,
      'model': 'bulbul:v1',
    });

    final attempts = _customApiKey.isNotEmpty ? 1 : activeKeyPool.length;

    for (int attempt = 0; attempt < attempts; attempt++) {
      final key = _customApiKey.isNotEmpty ? _customApiKey : getNextPoolKey();

      try {
        final response = await http
            .post(
              Uri.parse(_sarvamApiUrl),
              headers: {
                'api-subscription-key': key,
                'Content-Type': 'application/json',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final audios = json['audios'] as List<dynamic>?;
          if (audios != null && audios.isNotEmpty) {
            final base64Audio = audios.first.toString();
            if (base64Audio.isNotEmpty) {
              final audioBytes = base64Decode(base64Audio);

              statusNotifier.value = TtsPlaybackStatus(
                state: TtsState.playing,
                activeMessageId: messageId,
                usedOnDeviceFallback: false,
              );

              await audioPlayer.play(BytesSource(audioBytes));
              return true;
            }
          }
        } else {
          debugPrint(
            '[SarvamTtsService] Sarvam key attempt ${attempt + 1} (${key.substring(0, 10)}...) returned status ${response.statusCode}: ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('[SarvamTtsService] Key attempt ${attempt + 1} failed: $e');
      }
    }

    return false;
  }

  /// Synthesizes speech using local system on-device voice engine
  Future<void> _speakOnDevice({
    required String text,
    required String languageCode,
    String? messageId,
    double speechRate = 1.0,
  }) async {
    try {
      statusNotifier.value = TtsPlaybackStatus(
        state: TtsState.playing,
        activeMessageId: messageId,
        usedOnDeviceFallback: true,
      );

      // Map to standard locale for FlutterTts
      final ttsLocale = languageCode.replaceAll('-', '_');
      await flutterTts.setLanguage(ttsLocale);
      await flutterTts.setSpeechRate(speechRate * 0.5); // Normalized for mobile OS
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);

      await flutterTts.speak(text);
    } catch (e) {
      debugPrint('[SarvamTtsService] On-device TTS error: $e');
      statusNotifier.value = TtsPlaybackStatus(
        state: TtsState.idle,
        errorMessage: e.toString(),
      );
    }
  }

  /// Stops any currently playing audio
  Future<void> stop() async {
    try {
      await _audioPlayer?.stop();
    } catch (_) {}

    try {
      await _flutterTts?.stop();
    } catch (_) {}

    statusNotifier.value = const TtsPlaybackStatus(state: TtsState.idle);
  }

  void dispose() {
    _audioPlayer?.dispose();
    _flutterTts?.stop();
    statusNotifier.dispose();
  }
}
