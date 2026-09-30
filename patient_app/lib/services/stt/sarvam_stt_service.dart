import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../permissions/app_permission_service.dart';
import '../../features/chatbot/data/services/env_config.dart';

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
/// 1. Primary: Sarvam AI Saaras API (https://api.sarvam.ai/speech-to-text) with model `saaras:v3`
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
  bool _usingOnDeviceStt = false;
  String _onDevicePartialText = '';
  VoidCallback? _onAutoStop;
  DateTime? _listenStartTime;
  DateTime? _lastSpeechTime;
  bool _speechDetected = false;
  Timer? _amplitudeTimer;

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

  String get activeApiKey {
    if (_customApiKey.isNotEmpty) return _customApiKey;
    if (EnvConfig.sarvamApiKey.isNotEmpty) return EnvConfig.sarvamApiKey;
    return getNextPoolKey();
  }

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

  /// Starts microphone recording with hybrid dual-engine architecture:
  /// Engine 1 (Primary for Indic): 16kHz WAV capture transcribed via Sarvam Saaras AI cloud
  /// with real-time Voice Activity Detection (VAD) auto-stop when speech ends.
  /// Engine 2: Native on-device Speech-to-Text for English.
  Future<bool> startListening({
    required String languageCode,
    Function(String partialText)? onPartialResult,
    VoidCallback? onAutoStop,
  }) async {
    try {
      _amplitudeTimer?.cancel();
      _amplitudeTimer = null;
      _currentRecordingPath = null;
      _onDevicePartialText = '';
      _usingOnDeviceStt = false;
      _onAutoStop = onAutoStop;
      _listenStartTime = DateTime.now();
      _speechDetected = false;
      _lastSpeechTime = null;

      final osPermission = await AppPermissionService.requestMicrophonePermission();
      if (!osPermission) {
        statusNotifier.value = const SttStatus(
          state: SttState.error,
          errorMessage: 'Microphone permission denied. Please allow microphone access in settings.',
        );
        return false;
      }

      final resolvedCode = resolveLanguageCode(languageCode);
      final isEnglish = resolvedCode.startsWith('en');

      // For Indian languages (Punjabi, Hindi, Bengali, Tamil, etc.), Sarvam Saaras AI
      // is specialized for Indic phonetic models. Native on-device recognizer on Android
      // is missing Indic language packs, causing immediate timeout / notListening errors.
      if (!isEnglish) {
        return await _startAudioRecorder(resolvedCode, onAutoStop);
      }

      // If English, attempt on-device SpeechToText with safe fallback
      bool sttAvailable = false;
      try {
        sttAvailable = await speechToText.initialize(
          onError: (err) {
            debugPrint('[SarvamSttService] SpeechToText error: ${err.errorMsg}');
          },
          onStatus: (status) {
            debugPrint('[SarvamSttService] SpeechToText status: $status');
            if (status == 'notListening' && _usingOnDeviceStt && statusNotifier.value.isListening) {
              final elapsed = _listenStartTime != null
                  ? DateTime.now().difference(_listenStartTime!)
                  : Duration.zero;

              // Ignore false drops in first 2 seconds; seamlessly fallback to AudioRecorder
              if (elapsed < const Duration(milliseconds: 2000) && _onDevicePartialText.trim().isEmpty) {
                debugPrint('[SarvamSttService] SpeechToText dropped early. Switching to AudioRecorder...');
                _usingOnDeviceStt = false;
                _startAudioRecorder(resolvedCode, onAutoStop);
                return;
              }

              if (_onDevicePartialText.trim().isNotEmpty) {
                _triggerAutoStop();
              }
            }
          },
        );
      } catch (e) {
        debugPrint('[SarvamSttService] SpeechToText not available on this device: $e');
        sttAvailable = false;
      }

      if (sttAvailable) {
        _usingOnDeviceStt = true;
        statusNotifier.value = const SttStatus(state: SttState.listening);

        await speechToText.listen(
          onResult: (result) {
            _onDevicePartialText = result.recognizedWords;
            statusNotifier.value = SttStatus(
              state: SttState.listening,
              text: result.recognizedWords,
              usedOnDeviceFallback: true,
            );
            onPartialResult?.call(result.recognizedWords);
          },
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
          ),
        );
        return true;
      }

      // Fallback: AudioRecorder + Sarvam Cloud
      return await _startAudioRecorder(resolvedCode, onAutoStop);
    } catch (e) {
      debugPrint('[SarvamSttService] startListening error: $e');
      statusNotifier.value = SttStatus(
        state: SttState.error,
        errorMessage: 'Microphone error: $e',
      );
      return false;
    }
  }

  /// Starts WAV audio recording with silence detection (auto-stop after speaker pauses)
  Future<bool> _startAudioRecorder(String resolvedCode, VoidCallback? onAutoStop) async {
    final recorderHasPerm = await audioRecorder.hasPermission();
    if (!recorderHasPerm) {
      statusNotifier.value = const SttStatus(
        state: SttState.error,
        errorMessage: 'Microphone permission not granted to audio recorder.',
      );
      return false;
    }

    final tempDir = await getTemporaryDirectory();
    final audioPath =
        '${tempDir.path}/stt_audio_${DateTime.now().millisecondsSinceEpoch}.wav';
    _currentRecordingPath = audioPath;

    await audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: audioPath,
    );

    _listenStartTime = DateTime.now();
    _speechDetected = false;
    _lastSpeechTime = null;
    statusNotifier.value = const SttStatus(state: SttState.listening);

    // Voice Activity Detection: Monitor amplitude periodically and auto-stop after silence
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) async {
      if (!statusNotifier.value.isListening) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final elapsed = now.difference(_listenStartTime!);

      // Grace period: allow at least 1.8 seconds before checking silence
      if (elapsed < const Duration(milliseconds: 1800)) {
        return;
      }

      try {
        if (_audioRecorder != null && await _audioRecorder!.isRecording()) {
          final amp = await _audioRecorder!.getAmplitude();
          // Normal human speech into phone microphone is usually > -38 dBFS
          if (amp.current > -38.0) {
            _speechDetected = true;
            _lastSpeechTime = now;
          } else if (_speechDetected && _lastSpeechTime != null) {
            // Speaker spoke, and has now paused/finished speaking
            final silence = now.difference(_lastSpeechTime!);
            if (silence >= const Duration(milliseconds: 1800)) {
              debugPrint('[SarvamSttService] Speaker stopped speaking for 1.8s. Auto-stopping...');
              timer.cancel();
              _triggerAutoStop();
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('[SarvamSttService] VAD amplitude check error: $e');
      }

      // Max recording safety limit: 30 seconds
      if (elapsed >= const Duration(seconds: 30)) {
        timer.cancel();
        _triggerAutoStop();
      }
    });

    return true;
  }

  void _triggerAutoStop() {
    if (!statusNotifier.value.isListening) return;
    final elapsed = _listenStartTime != null
        ? DateTime.now().difference(_listenStartTime!)
        : Duration.zero;

    // Must never auto-stop within the first 1.8 seconds to avoid false start drops
    if (elapsed < const Duration(milliseconds: 1800)) {
      debugPrint('[SarvamSttService] Ignoring early auto-stop ($elapsed elapsed).');
      return;
    }

    _onAutoStop?.call();
  }

  /// Stops recording and transcribes the speech to text.
  Future<String?> stopAndTranscribe({
    required String languageCode,
  }) async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;

    try {
      statusNotifier.value = const SttStatus(state: SttState.transcribing);

      // 1. If Engine 1 (on-device SpeechToText) was active
      if (_usingOnDeviceStt) {
        try {
          if (speechToText.isListening) {
            await speechToText.stop();
          }
        } catch (_) {}

        final recognized = _onDevicePartialText.trim();
        _usingOnDeviceStt = false;
        _onDevicePartialText = '';

        if (recognized.isNotEmpty) {
          statusNotifier.value = SttStatus(
            state: SttState.idle,
            text: recognized,
            usedOnDeviceFallback: true,
          );
          return recognized;
        }

        statusNotifier.value = const SttStatus(
          state: SttState.idle,
          errorMessage:
              'No speech heard. In Android Emulator, enable "Virtual microphone uses host audio input" in Extended Controls (... -> Microphone).',
        );
        return null;
      }

      // 2. Engine 2: AudioRecorder + Sarvam AI
      String? recordedPath;
      try {
        if (_audioRecorder != null && await audioRecorder.isRecording()) {
          recordedPath = await audioRecorder.stop();
        }
      } catch (e) {
        debugPrint('[SarvamSttService] Error stopping audio recorder: $e');
      }

      final filePath = recordedPath ?? _currentRecordingPath;
      if (filePath == null || !File(filePath).existsSync()) {
        statusNotifier.value = const SttStatus(
          state: SttState.idle,
          errorMessage: 'Could not detect speech. Please try speaking again.',
        );
        return null;
      }

      final file = File(filePath);
      final fileSize = await file.length();
      debugPrint('[SarvamSttService] Recorded audio file: $fileSize bytes at $filePath');

      if (fileSize < 2000) {
        // Less than ~0.15s of audio recorded (e.g. accidental quick tap)
        _cleanupFile(filePath);
        statusNotifier.value = const SttStatus(
          state: SttState.idle,
          errorMessage: 'Audio was too short. Please speak again.',
        );
        return null;
      }

      // Analyze whether the recorded audio actually contains sound or total digital silence
      final bytes = await file.readAsBytes();
      int maxAmp = 0;
      if (bytes.length > 44) {
        for (int i = 44; i < bytes.length - 1; i += 2) {
          int sample = bytes[i] | (bytes[i + 1] << 8);
          if (sample >= 32768) sample -= 65536;
          final abs = sample.abs();
          if (abs > maxAmp) maxAmp = abs;
        }
      }
      debugPrint('[SarvamSttService] Recorded audio peak amplitude: $maxAmp / 32767');

      if (maxAmp < 25) {
        _cleanupFile(filePath);
        statusNotifier.value = const SttStatus(
          state: SttState.idle,
          errorMessage:
              'No speech detected. Please speak into the microphone and try again.',
        );
        return null;
      }

      final resolvedCode = resolveLanguageCode(languageCode);
      final sarvamLanguageCode = sarvamSupportedSttCodes.contains(resolvedCode)
          ? resolvedCode
          : 'unknown';

      // Transcribe via Sarvam AI Saaras API (supports 11+ Indian languages + English)
      final result = await _transcribeWithSarvam(
        audioFile: file,
        languageCode: sarvamLanguageCode,
      );

      _cleanupFile(filePath);

      if (result.transcript != null && result.transcript!.trim().isNotEmpty) {
        statusNotifier.value = SttStatus(
          state: SttState.idle,
          text: result.transcript!.trim(),
        );
        return result.transcript!.trim();
      }

      final errorMsg = result.errorMessage ?? 'Could not detect speech. Please try speaking again.';
      statusNotifier.value = SttStatus(
        state: SttState.idle,
        errorMessage: errorMsg,
      );
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

  /// Models tried in order of priority (saaras:v3 -> saaras:v4 -> saarika:v2.5)
  static const List<String> _sttModels = [
    'saaras:v3',
    'saaras:v4',
    'saarika:v2.5',
  ];

  /// Transcribes recorded audio via Sarvam Saaras API
  Future<_SarvamTranscriptionResult> _transcribeWithSarvam({
    required File audioFile,
    required String languageCode,
  }) async {
    final attempts = _customApiKey.isNotEmpty ? 1 : activeKeyPool.length;
    String? lastError;
    final Uint8List audioBytes = await audioFile.readAsBytes();

    for (int attempt = 0; attempt < attempts; attempt++) {
      final key = _customApiKey.isNotEmpty ? _customApiKey : getNextPoolKey();

      for (final model in _sttModels) {
        try {
          final uri = Uri.parse(_sarvamSttUrl);
          final request = http.MultipartRequest('POST', uri);

          request.headers['api-subscription-key'] = key;
          request.fields['model'] = model;
          request.fields['language_code'] = languageCode;

          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              audioBytes,
              filename: 'audio.wav',
              contentType: MediaType('audio', 'wav'),
            ),
          );

          final response = await () async {
            final streamedResponse = await request.send();
            return await http.Response.fromStream(streamedResponse);
          }().timeout(const Duration(seconds: 35));

          if (response.statusCode == 200) {
            final json = jsonDecode(response.body) as Map<String, dynamic>;
            final transcript = json['transcript'] as String?;
            if (transcript != null && transcript.trim().isNotEmpty) {
              debugPrint(
                '[SarvamSttService] Sarvam Saaras ($model) transcription successful ($languageCode): ${transcript.trim()}',
              );
              return _SarvamTranscriptionResult(transcript: transcript.trim());
            } else {
              // Successfully processed audio, but user did not speak audibly
              return const _SarvamTranscriptionResult(
                errorMessage: 'No speech was detected. Please speak closer to the mic.',
              );
            }
          } else if (response.statusCode == 400) {
            final body = response.body.toLowerCase();
            if (body.contains('language') && languageCode != 'unknown') {
              debugPrint('[SarvamSttService] Language rejected ($languageCode), retrying with unknown');
              final fbReq = http.MultipartRequest('POST', uri);
              fbReq.headers['api-subscription-key'] = key;
              fbReq.fields['model'] = model;
              fbReq.fields['language_code'] = 'unknown';
              fbReq.files.add(
                http.MultipartFile.fromBytes(
                  'file',
                  audioBytes,
                  filename: 'audio.wav',
                  contentType: MediaType('audio', 'wav'),
                ),
              );
              final fbResp = await () async {
                final fbStreamed = await fbReq.send();
                return await http.Response.fromStream(fbStreamed);
              }().timeout(const Duration(seconds: 35));

              if (fbResp.statusCode == 200) {
                final fbJson = jsonDecode(fbResp.body) as Map<String, dynamic>;
                final transcript = fbJson['transcript'] as String?;
                if (transcript != null && transcript.trim().isNotEmpty) {
                  return _SarvamTranscriptionResult(transcript: transcript.trim());
                }
              }
            }
            lastError = 'Model or format rejected (400)';
            debugPrint('[SarvamSttService] $model returned 400: ${response.body}');
            continue; // try next candidate model
          } else if (response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 429) {
            lastError = 'API key issue (${response.statusCode})';
            debugPrint('[SarvamSttService] Key issue on attempt ${attempt + 1}: $lastError');
            break; // rotate to next key
          } else {
            lastError = 'Server error (${response.statusCode})';
            debugPrint('[SarvamSttService] Status ${response.statusCode}: ${response.body}');
          }
        } on TimeoutException {
          debugPrint('[SarvamSttService] Speech recognition request timed out on attempt ${attempt + 1}');
          lastError = 'Voice transcription timed out. Please speak clearly into the mic and try again, or type your message.';
          break; // Stop model loop on timeout so user is not stuck waiting multiple times
        } on SocketException catch (e) {
          debugPrint('[SarvamSttService] Network socket error: $e');
          lastError = 'Network connection issue. Please check your internet connection.';
          break; // Stop loop if device cannot reach the network
        } catch (e) {
          lastError = 'Network error: $e';
          debugPrint('[SarvamSttService] Attempt ${attempt + 1} with $model error: $e');
        }
      }
    }

    return _SarvamTranscriptionResult(
      errorMessage: lastError ?? 'Speech recognition service temporarily unavailable.',
    );
  }

  /// Cancels any in-progress recording or speech recognition
  Future<void> cancel() async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _usingOnDeviceStt = false;
    _onDevicePartialText = '';
    _onAutoStop = null;

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
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _audioRecorder?.dispose();
    _speechToText?.stop();
    statusNotifier.dispose();
  }
}

class _SarvamTranscriptionResult {
  final String? transcript;
  final String? errorMessage;

  const _SarvamTranscriptionResult({
    this.transcript,
    this.errorMessage,
  });
}
