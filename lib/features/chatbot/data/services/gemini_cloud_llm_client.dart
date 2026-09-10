import 'dart:convert';
import 'dart:io';

import '../../domain/models/search_result.dart';
import '../../domain/services/llm_client.dart';

/// Signature for custom HTTP POST handlers, facilitating dependency injection in unit tests.
typedef HttpPostHandler = Future<Map<String, dynamic>> Function(
  Uri uri,
  Map<String, String> headers,
  String body,
);

/// Concrete [LlmClient] interfacing directly with the Google Gemini REST API.
class GeminiCloudLlmClient implements LlmClient {
  GeminiCloudLlmClient({
    String? apiKey,
    String? model,
    this.timeout = const Duration(seconds: 10),
    HttpPostHandler? httpHandler,
  })  : _apiKey = (apiKey != null && apiKey.isNotEmpty)
            ? apiKey.trim()
            : (const String.fromEnvironment('GEMINI_API_KEY').isNotEmpty
                ? const String.fromEnvironment('GEMINI_API_KEY').trim()
                : defaultInbuiltApiKey.trim()),
        _activeModel = model ?? 'gemini-flash-latest',
        _httpHandler = httpHandler ?? _defaultHttpPostHandler;

  /// Put your Gemini API Key here if you want it built directly into the app:
  static const String defaultInbuiltApiKey = 'AQ.Ab8RN6L8pfTo48TP8svIW6LiiwffIPSn88u-MikikhmGqdIdkA';

  /// Candidate models in order of priority (handles Google model retirements/deprecations automatically).
  static const List<String> candidateModels = [
    'gemini-flash-latest',
    'gemini-flash-lite-latest',
    'gemini-3.5-flash-lite',
    'gemini-3.5-flash',
    'gemini-3.1-flash-lite',
    'gemini-3-flash-preview',
    'gemini-3.1-pro-preview',
  ];

  String _apiKey;
  String _activeModel;
  final Duration timeout;
  final HttpPostHandler _httpHandler;

  /// Returns the current active model name.
  String get model => _activeModel;

  /// Current configured API key.
  String get apiKey => _apiKey;

  /// Updates the API key at runtime.
  void setApiKey(String key) {
    _apiKey = key.trim();
  }

  /// Returns true if an API key has been configured.
  bool get hasApiKey => _apiKey.isNotEmpty;

  /// Discovers available text generation models for the current API key directly from Google AI Studio.
  Future<List<String>> fetchAvailableModels([String? keyToUse]) async {
    final key = (keyToUse ?? _apiKey).trim();
    if (key.isEmpty) return [];

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models?key=$key',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 8));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final modelsList = json['models'] as List<dynamic>? ?? [];
        final available = <String>[];
        for (final m in modelsList) {
          if (m is Map<String, dynamic>) {
            final methods = (m['supportedGenerationMethods'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            if (methods.contains('generateContent')) {
              final rawName = m['name']?.toString() ?? '';
              final cleanName = rawName.replaceFirst('models/', '');
              final lower = cleanName.toLowerCase();
              // Exclude audio, tts, image, clip, transcribe modalities
              if (lower.contains('tts') ||
                  lower.contains('image') ||
                  lower.contains('transcribe') ||
                  lower.contains('clip') ||
                  lower.contains('audio') ||
                  lower.contains('lyria')) {
                continue;
              }
              if (cleanName.isNotEmpty) {
                available.add(cleanName);
              }
            }
          }
        }
        // Prioritize newest flash models
        available.sort((a, b) {
          int score(String name) {
            final n = name.toLowerCase();
            if (n.contains('3.5-flash')) return 100;
            if (n.contains('flash-latest')) return 90;
            if (n.contains('3.1-flash')) return 80;
            if (n.contains('flash')) return 70;
            return 10;
          }
          return score(b).compareTo(score(a));
        });
        // ignore: avoid_print
        print('GeminiCloudLlmClient: Filtered text generation models: $available');
        return available;
      }
    } catch (e) {
      // ignore: avoid_print
      print('GeminiCloudLlmClient: Could not list models: $e');
    } finally {
      client.close();
    }
    return [];
  }

  /// Validates the API key against the Google Gemini REST API.
  /// Automatically tries candidate models if one returns 404 or modality errors.
  Future<String?> validateApiKey([String? testKey]) async {
    final keyToTest = (testKey ?? _apiKey).trim();
    if (keyToTest.isEmpty) {
      return 'API key is empty.';
    }

    final candidateList = [_activeModel, ...candidateModels.where((m) => m != _activeModel)];
    final modelsToTry = List<String>.from(candidateList);
    String? lastError;

    for (int i = 0; i < modelsToTry.length; i++) {
      final m = modelsToTry[i];
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$keyToTest',
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

      final headers = {
        'Content-Type': 'application/json',
      };

      try {
        final responseJson = await _httpHandler(uri, headers, requestBody).timeout(timeout);
        if (responseJson.containsKey('error')) {
          final errorMap = responseJson['error'] as Map<String, dynamic>;
          final msg = errorMap['message']?.toString() ?? 'Gemini error';
          lastError = msg;
          if (i == modelsToTry.length - 1) {
            final dynamicModels = await fetchAvailableModels(keyToTest);
            for (final dm in dynamicModels) {
              if (!modelsToTry.contains(dm)) modelsToTry.add(dm);
            }
          }
          continue; // Try next model
        }
        _activeModel = m; // Remember working model
        return null; // Valid!
      } catch (e) {
        final str = e.toString();
        lastError = str.replaceAll('HttpException: ', '');
        if (str.contains('API key not valid')) {
          return 'API key not valid. Please check your key on Google AI Studio.';
        }
        if (i == modelsToTry.length - 1) {
          final dynamicModels = await fetchAvailableModels(keyToTest);
          for (final dm in dynamicModels) {
            if (!modelsToTry.contains(dm)) modelsToTry.add(dm);
          }
        }
        continue; // Try next model
      }
    }

    return lastError ?? 'Failed to connect with any available Gemini model.';
  }

  @override
  Future<LlmResponse> generateResponse({
    required String prompt,
    required List<SearchResult> contextChunks,
  }) async {
    if (!hasApiKey) {
      throw StateError(
        'Gemini API key is missing. Pass it via constructor or call setApiKey().',
      );
    }

    final stopwatch = Stopwatch()..start();

    final candidateList = [_activeModel, ...candidateModels.where((m) => m != _activeModel)];
    final modelsToTry = List<String>.from(candidateList);
    dynamic lastException;

    for (int i = 0; i < modelsToTry.length; i++) {
      final currentModel = modelsToTry[i];
      // ignore: avoid_print
      print('GeminiCloudLlmClient: Calling model $currentModel...');

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$currentModel:generateContent?key=$_apiKey',
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
              'text': 'You are a compassionate, friendly healthcare assistant. '
                  'Always answer in very simple, easy-to-understand language without complex medical jargon. '
                  'Use short, clear bullet points for symptoms and practical advice. '
                  'If a user describes symptoms or asks what disease they might have, gently suggest common possibilities they can discuss with a doctor, while clearly reminding them that only a doctor can provide a true diagnosis. '
                  'Do NOT output or display raw source names, database citations, or reference numbers in your answer. '
                  'Always include a brief, caring reminder to consult a qualified healthcare professional.'
            }
          ]
        }
      });

      final headers = {
        'Content-Type': 'application/json',
      };

      try {
        final responseJson =
            await _httpHandler(uri, headers, requestBody).timeout(timeout);
        stopwatch.stop();

        final responseText = _extractTextFromResponse(responseJson);
        _activeModel = currentModel; // Lock in the working model
        // ignore: avoid_print
        print('GeminiCloudLlmClient: Model $currentModel succeeded!');

        return LlmResponse(
          text: responseText,
          branch: LlmBranchType.online,
          latency: stopwatch.elapsed,
        );
      } catch (e) {
        lastException = e;
        // ignore: avoid_print
        print('GeminiCloudLlmClient: Model $currentModel failed: $e');

        final str = e.toString();
        // If it's a 503 (high demand), 429 (rate limit), 500, 404, Timeout, or non-TEXT modality (400), try next candidate!
        final isModelSpecificError = str.contains('503') ||
            str.contains('high demand') ||
            str.contains('429') ||
            str.contains('quota') ||
            str.contains('500') ||
            str.contains('404') ||
            str.contains('Timeout') ||
            str.contains('Future not completed') ||
            str.contains('timed out') ||
            str.contains('no longer available') ||
            str.contains('modalities') ||
            str.contains('not supported');

        if (isModelSpecificError) {
          if (i == modelsToTry.length - 1) {
            final dynamicModels = await fetchAvailableModels();
            for (final dm in dynamicModels) {
              if (!modelsToTry.contains(dm)) modelsToTry.add(dm);
            }
          }
          continue; // Try next candidate model
        }
        rethrow;
      }
    }

    throw lastException ?? StateError('All Gemini candidate models failed.');
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

  /// Default production HTTP handler using `dart:io` HttpClient.
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

