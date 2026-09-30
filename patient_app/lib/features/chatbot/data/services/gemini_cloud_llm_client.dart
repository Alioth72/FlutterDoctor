import 'dart:convert';
import 'dart:io';

import '../../domain/models/search_result.dart';
import '../../domain/services/llm_client.dart';
import 'env_config.dart';

typedef HttpPostHandler = Future<Map<String, dynamic>> Function(
  Uri uri,
  Map<String, String> headers,
  String body,
);

/// Concrete [LlmClient] interfacing directly with the Google Gemini REST API.
/// Incorporates multi-key round-robin rotation across the 18 verified Gemini API keys
/// for high-availability clinical conversational AI.
class GeminiCloudLlmClient implements LlmClient {
  GeminiCloudLlmClient({
    String? apiKey,
    String? model,
    this.timeout = const Duration(seconds: 12),
    HttpPostHandler? httpHandler,
  })  : _apiKey = (apiKey != null && apiKey.isNotEmpty)
            ? apiKey.trim()
            : (EnvConfig.geminiApiKey.isNotEmpty
                ? EnvConfig.geminiApiKey.trim()
                : (const String.fromEnvironment('GEMINI_API_KEY').isNotEmpty
                    ? const String.fromEnvironment('GEMINI_API_KEY').trim()
                    : '')),
        _activeModel = model ?? 'gemini-1.5-flash',
        _httpHandler = httpHandler ?? _defaultHttpPostHandler;

  /// Active Gemini keys pool
  static const List<String> activeKeyPool = [
    'AIzaSyAC-zy6AEUPU2f9RLh1ZJy4u8-InVZRTuk',
    'AIzaSyCr-9Ji7m0OJPD8c8sukxG6h4mIJnZJmqs',
    'AIzaSyB_aMMUO0RH3gMMoXymXY6wTxGeEgmm7m8',
    'AIzaSyCCxJdwBdQTBxrjjTsmq_3BSlEF7mYj3lU',
    'AIzaSyBQ5BxbgSfxOj_3woSKh5Pr7jAElZx_Iy0',
    'AIzaSyDCi4bcenwavRSGGQPSNW-iNv8-MzJsXxw',
    'AIzaSyCgh63btf4bzbpwPLAl2dYLqpsPsObvtYk',
    'AIzaSyDJrViNyyFslhlRuFKS__sIJJGUgnQ-Gx4',
    'AIzaSyC1gWufrLwN5HrTlgFseXzi86e-wdn2jGc',
    'AIzaSyDxjYujMzdzTvQKTmWawk74-_suZKR88RQ',
    'AIzaSyBrnJxNJQmWOx3MLykZUtrJUsDOXoeWzNA',
    'AIzaSyCV4lY5T8q1_3_DtFHdogL0xvLRujTNuzA',
    'AIzaSyAVl990TaBqr2t7UqXbq-6JyGhDt5L05cQ',
    'AIzaSyB1vKiN6W9mOTC7Wn_HgmeLvz9cF20MGco',
    'AIzaSyBMB8vKKSlQaa8fPcNwUp8_7xexWwjzc1A',
    'AIzaSyDSAPVW0qp8seguc9eHod09OetqT29pZjA',
    'AIzaSyAAU2Q9nJXPJZaT6j1CGjx71yFa-ZGFPdw',
    'AIzaSyBbPFaAeXPBPRpCZ_w0BUHytqXLspkusZM',
  ];

  static int _keyIndex = 0;

  static String getNextPoolKey() {
    if (activeKeyPool.isEmpty) return '';
    final key = activeKeyPool[_keyIndex % activeKeyPool.length];
    _keyIndex++;
    return key;
  }

  static const List<String> candidateModels = [
    'gemini-1.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-pro',
  ];

  String _apiKey;
  String _activeModel;
  final Duration timeout;
  final HttpPostHandler _httpHandler;

  String get model => _activeModel;
  String get apiKey {
    if (_apiKey.isNotEmpty) return _apiKey;
    final envKey = EnvConfig.geminiApiKey;
    if (envKey.isNotEmpty) return envKey;
    final dartDefKey = const String.fromEnvironment('GEMINI_API_KEY').trim();
    if (dartDefKey.isNotEmpty) return dartDefKey;
    return activeKeyPool.isNotEmpty ? activeKeyPool[_keyIndex % activeKeyPool.length] : '';
  }

  void setApiKey(String key) {
    _apiKey = key.trim();
  }

  bool get hasApiKey => apiKey.isNotEmpty;

  /// Validates the API key against Google Gemini REST API
  Future<String?> validateApiKey([String? testKey]) async {
    final keyToTest = (testKey ?? _apiKey).trim();
    final effectiveKey = keyToTest.isNotEmpty ? keyToTest : getNextPoolKey();

    final candidateList = [_activeModel, ...candidateModels.where((m) => m != _activeModel)];
    String? lastError;

    for (final m in candidateList) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$effectiveKey',
      );

      final requestBody = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': 'hi'}
            ]
          }
        ],
        'generationConfig': {
          'maxOutputTokens': 5,
        },
      });

      final headers = {'Content-Type': 'application/json'};

      try {
        final responseJson = await _httpHandler(uri, headers, requestBody).timeout(timeout);
        if (responseJson.containsKey('error')) {
          final errorMap = responseJson['error'] as Map<String, dynamic>;
          lastError = errorMap['message']?.toString() ?? 'Gemini error';
          continue;
        }
        _activeModel = m;
        return null;
      } catch (e) {
        lastError = e.toString().replaceAll('HttpException: ', '');
        continue;
      }
    }

    return lastError ?? 'Failed to connect with any available Gemini model.';
  }

  @override
  Future<LlmResponse> generateResponse({
    required String prompt,
    required List<SearchResult> contextChunks,
  }) async {
    final stopwatch = Stopwatch()..start();
    final candidateList = [_activeModel, ...candidateModels.where((m) => m != _activeModel)];

    dynamic lastException;
    int retries = 0;
    const maxRetries = 6;

    while (retries < maxRetries) {
      // Use custom key on first attempt if specified; otherwise rotate through 18-key pool
      final currentKey = (_apiKey.isNotEmpty && retries == 0) ? _apiKey : getNextPoolKey();

      for (final currentModel in candidateList) {
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$currentModel:generateContent?key=$currentKey',
        );

        final requestBody = jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.2,
            'maxOutputTokens': 1000,
          },
          'systemInstruction': {
            'parts': [
              {
                'text': 'You are a compassionate, friendly healthcare assistant in the Ashwini Patient Portal. '
                    'Always answer in very simple, easy-to-understand language without complex medical jargon. '
                    'Use short, clear bullet points for symptoms, instructions, and advice. '
                    'If the patient asks in Hindi, Bengali, Tamil, Telugu, or any other Indian language, respond in that language warmly. '
                    'If a user describes symptoms or asks what disease they might have, gently suggest common possibilities they can discuss with a doctor, reminding them that only a doctor can provide a clinical diagnosis. '
                    'You are also the official in-app guide for the Ashwini Patient Portal: if the user asks questions or has doubts about the app itself (e.g. how to scan prescriptions for Jan Aushadhi generic savings, book teleconsultations, use contactless Face Vitals scanning, request ASHA home visits, use the Emergency SOS button, or switch between 22 languages), guide them with clear, friendly, step-by-step instructions. '
                    'Do NOT output raw database IDs or citation codes. '
                    'Always include a caring reminder to consult a qualified healthcare professional.'
              }
            ]
          }
        });

        final headers = {'Content-Type': 'application/json'};

        try {
          final responseJson = await _httpHandler(uri, headers, requestBody).timeout(timeout);
          stopwatch.stop();

          final responseText = _extractTextFromResponse(responseJson);
          _activeModel = currentModel;

          return LlmResponse(
            text: responseText,
            branch: LlmBranchType.online,
            latency: stopwatch.elapsed,
          );
        } catch (e) {
          lastException = e;
          final str = e.toString().toLowerCase();

          // If rate limit (429), quota error, high demand (503), or invalid key (400/403), break and retry with next pool key
          if (str.contains('429') ||
              str.contains('quota') ||
              str.contains('resource_exhausted') ||
              str.contains('limit') ||
              str.contains('503') ||
              str.contains('key') ||
              str.contains('400') ||
              str.contains('403')) {
            if (str.contains('key') || str.contains('400') || str.contains('403')) {
              _apiKey = '';
            }
            break;
          }
        }
      }
      retries++;
    }

    throw lastException ?? StateError('All Gemini candidate models and keys failed.');
  }

  String _extractTextFromResponse(Map<String, dynamic> json) {
    if (json.containsKey('error')) {
      final errorMap = json['error'] as Map<String, dynamic>;
      final msg = errorMap['message'] ?? 'Unknown Gemini API error';
      throw HttpException('Gemini API Error: $msg');
    }

    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const FormatException('Gemini API returned no candidates.');
    }

    final firstCandidate = candidates.first as Map<String, dynamic>;
    final content = firstCandidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;

    if (parts == null || parts.isEmpty) {
      throw const FormatException('Gemini API returned candidate with no parts.');
    }

    final text = parts.first['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw const FormatException('Gemini API returned empty text part.');
    }

    return text.trim();
  }

  static Future<Map<String, dynamic>> _defaultHttpPostHandler(
    Uri uri,
    Map<String, String> headers,
    String body,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });
      request.add(utf8.encode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        String msg = responseBody;
        try {
          final errorJson = jsonDecode(responseBody) as Map<String, dynamic>;
          if (errorJson.containsKey('error')) {
            msg = errorJson['error']['message']?.toString() ?? responseBody;
          }
        } catch (_) {}
        throw HttpException('Gemini API (${response.statusCode}): $msg');
      }

      return jsonDecode(responseBody) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }
}
