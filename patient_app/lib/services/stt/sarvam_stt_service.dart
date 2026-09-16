import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Operational states for Speech-to-Text recognition
enum SttState {
  idle,
  listening,
  transcribing,
  error,
}

/// Immutable state container for STT playback/recording progress
@immutable
class SttStatus {
  final SttState state;
  final String text;
  final String? errorMessage;
  final bool usedOnDeviceFallback;

  const SttStatus({
    this.state = SttState.idle,
    this.text = '',
    this.errorMessage,
    this.usedOnDeviceFallback = false,
  });

  bool get isListening => state == SttState.listening;
  bool get isTranscribing => state == SttState.transcribing;
  bool get isIdle => state == SttState.idle;
}

/// Dual-Engine Speech-to-Text service for the Healthcare Chatbot.
///
/// Dual-Engine Pipeline:
/// 1. Primary: Sarvam AI Saaras API (https://api.sarvam.ai/speech-to-text) with model `saaras:v2`
///    supporting 11+ Indic languages with high transcription accuracy for Indian accents.
/// 2. Fallback: On-device Google/Apple speech recognition engine (`speech_to_text`)
///    when Sarvam credits are depleted or when offline.
class SarvamSttService {
  SarvamSttService._();
  static final SarvamSttService instance = SarvamSttService._();

  static const String _sarvamSttUrl = 'https://api.sarvam.ai/speech-to-text';

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
  AudioRecorder? _audioRecorder;
  stt.SpeechToText? _speechToText;

  AudioRecorder get audioRecorder => _audioRecorder ??= AudioRecorder();
  stt.SpeechToText get speechToText => _speechToText ??= stt.SpeechToText();

  final ValueNotifier<SttStatus> statusNotifier =
      ValueNotifier<SttStatus>(const SttStatus());

  String? _currentRecordingPath;
  String _onDevicePartialText = '';
  bool _isSpeechInitialized = false;

  /// Sarvam Saaras officially supported Indic language codes
  static const Set<String> sarvamSupportedSttCodes = {
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

  /// Mapping table for all 22 Official Scheduled Indian Languages + English
  static const Map<String, String> languageCodeMap = {
    'en': 'en-IN',
    'english': 'en-IN',
    'hi': 'hi-IN',
    'hindi': 'hi-IN',
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
    'od': 'od-IN',
    'oriya': 'od-IN',
    'odia': 'od-IN',
    'as': 'as-IN',
    'assamese': 'as-IN',
    'ur': 'ur-IN',
    'urdu': 'ur-IN',
    'sa': 'sa-IN',
    'sanskrit': 'sa-IN',
    'ne': 'ne-NP',
    'nepali': 'ne-NP',
    'ks': 'ks-IN',
    'kashmiri': 'ks-IN',
    'kok': 'kok-IN',
    'konkani': 'kok-IN',
    'mai': 'mai-IN',
    'maithili': 'mai-IN',
    'mni': 'mni-IN',
    'manipuri': 'mni-IN',
    'brx': 'brx-IN',
    'bodo': 'brx-IN',
    'doi': 'doi-IN',
    'dogri': 'doi-IN',
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

  /// Maps an app language code (e.g. 'hi', 'en', 'bn') to standard BCP-47 locale code
  String resolveLanguageCode(String? code) {
    if (code == null || code.trim().isEmpty) return 'en-IN';
    final normalized = code.trim().toLowerCase().replaceAll('_', '-');

    if (languageCodeMap.containsKey(normalized)) {
      return languageCodeMap[normalized]!;
    }
    final primary = normalized.split('-').first;
    if (languageCodeMap.containsKey(primary)) {
      return languageCodeMap[primary]!;
    }
    return 'en-IN';
  }

  /// Starts microphone recording
  Future<bool> startListening({
    required String languageCode,
    Function(String partialText)? onPartialResult,
  }) async {
    try {
      _onDevicePartialText = '';
      final hasPermission = await audioRecorder.hasPermission();
      if (!hasPermission) {
        statusNotifier.value = const SttStatus(
          state: SttState.error,
          errorMessage: 'Microphone permission denied.',
        );
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final audioPath =
          '${tempDir.path}/stt_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = audioPath;

      // Start recording via high-performance native recorder
      await audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: audioPath,
      );

      statusNotifier.value = const SttStatus(state: SttState.listening);

      // Optional on-device live listening for immediate real-time visual feedback
      _startOnDeviceLiveListener(languageCode, onPartialResult);

      return true;
    } catch (e) {
      debugPrint('[SarvamSttService] startListening error: $e');
      statusNotifier.value = SttStatus(
        state: SttState.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void _startOnDeviceLiveListener(
    String languageCode,
    Function(String partialText)? onPartialResult,
  ) async {
    try {
      if (!_isSpeechInitialized) {
        _isSpeechInitialized = await speechToText.initialize(
          onError: (val) => debugPrint('[SarvamSttService] OnDevice STT error: $val'),
          onStatus: (val) => debugPrint('[SarvamSttService] OnDevice STT status: $val'),
        );
      }

      if (_isSpeechInitialized && speechToText.isAvailable) {
        final locale = resolveLanguageCode(languageCode).replaceAll('-', '_');
        await speechToText.listen(
          onResult: (result) {
            _onDevicePartialText = result.recognizedWords;
            if (onPartialResult != null && _onDevicePartialText.isNotEmpty) {
              onPartialResult(_onDevicePartialText);
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            localeId: locale,
          ),
        );
      }
    } catch (_) {
      // On-device listener is best-effort for live previews; ignore failure
    }
  }

  /// Stops recording and transcribes the speech to text.
  /// First calls Sarvam Saaras STT API; falls back to on-device text if needed.
  Future<String?> stopAndTranscribe({
    required String languageCode,
  }) async {
    try {
      statusNotifier.value = const SttStatus(state: SttState.transcribing);

      // Stop on-device speech listener if active
      try {
        if (_speechToText != null && speechToText.isListening) {
          await speechToText.stop();
        }
      } catch (_) {}

      // Stop native audio recorder
      final recordedPath = await audioRecorder.stop();
      final filePath = recordedPath ?? _currentRecordingPath;

      if (filePath == null || !File(filePath).existsSync()) {
        if (_onDevicePartialText.trim().isNotEmpty) {
          statusNotifier.value = SttStatus(
            state: SttState.idle,
            text: _onDevicePartialText,
            usedOnDeviceFallback: true,
          );
          return _onDevicePartialText;
        }
        statusNotifier.value = const SttStatus(
          state: SttState.idle,
          errorMessage: 'No audio recorded.',
        );
        return null;
      }

      final resolvedCode = resolveLanguageCode(languageCode);

      // 1. Try Sarvam AI Saaras API first if key exists
      if (activeApiKey.isNotEmpty) {
        final sarvamResult = await _transcribeWithSarvam(
          audioFile: File(filePath),
          languageCode: resolvedCode,
        );

        if (sarvamResult != null && sarvamResult.trim().isNotEmpty) {
          statusNotifier.value = SttStatus(
            state: SttState.idle,
            text: sarvamResult.trim(),
            usedOnDeviceFallback: false,
          );
          _cleanupFile(filePath);
          return sarvamResult.trim();
        }
      }

      // 2. Fallback to on-device recognized speech
      if (_onDevicePartialText.trim().isNotEmpty) {
        debugPrint('[SarvamSttService] Using on-device speech fallback');
        final recognized = _onDevicePartialText.trim();
        statusNotifier.value = SttStatus(
          state: SttState.idle,
          text: recognized,
          usedOnDeviceFallback: true,
        );
        _cleanupFile(filePath);
        return recognized;
      }

      statusNotifier.value = const SttStatus(
        state: SttState.idle,
        errorMessage: 'Could not transcribe speech.',
      );
      _cleanupFile(filePath);
      return null;
    } catch (e) {
      debugPrint('[SarvamSttService] stopAndTranscribe error: $e');
      statusNotifier.value = SttStatus(
        state: SttState.idle,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Transcribes recorded audio via Sarvam Saaras API
  Future<String?> _transcribeWithSarvam({
    required File audioFile,
    required String languageCode,
  }) async {
    final attempts = _customApiKey.isNotEmpty ? 1 : activeKeyPool.length;

    for (int attempt = 0; attempt < attempts; attempt++) {
      final key = _customApiKey.isNotEmpty ? _customApiKey : getNextPoolKey();

      try {
        final uri = Uri.parse(_sarvamSttUrl);
        final request = http.MultipartRequest('POST', uri);

        request.headers['api-subscription-key'] = key;
        request.fields['model'] = 'saaras:v2';
        request.fields['language_code'] = languageCode;

        final multipartFile = await http.MultipartFile.fromPath(
          'file',
          audioFile.path,
        );
        request.files.add(multipartFile);

        final streamedResponse =
            await request.send().timeout(const Duration(seconds: 15));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final transcript = json['transcript'] as String?;
          if (transcript != null && transcript.trim().isNotEmpty) {
            debugPrint('[SarvamSttService] Sarvam Saaras transcription successful with key attempt ${attempt + 1}');
            return transcript.trim();
          }
        } else {
          debugPrint(
            '[SarvamSttService] Sarvam STT key attempt ${attempt + 1} (${key.substring(0, 10)}...) status ${response.statusCode}: ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('[SarvamSttService] Sarvam API request failed on attempt ${attempt + 1}: $e');
      }
    }

    return null;
  }

  /// Cancels any in-progress recording or speech recognition
  Future<void> cancel() async {
    try {
      if (_audioRecorder != null && await audioRecorder.isRecording()) {
        await audioRecorder.stop();
      }
    } catch (_) {}

    try {
      if (_speechToText != null && speechToText.isListening) {
        await speechToText.cancel();
      }
    } catch (_) {}

    if (_currentRecordingPath != null) {
      _cleanupFile(_currentRecordingPath!);
      _currentRecordingPath = null;
    }

    statusNotifier.value = const SttStatus(state: SttState.idle);
  }

  void _cleanupFile(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) {
        f.deleteSync();
      }
    } catch (_) {}
  }

  void dispose() {
    _audioRecorder?.dispose();
    _speechToText?.stop();
    statusNotifier.dispose();
  }
}
