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

/// High-performance [LlmClient] interfacing directly with the Groq Cloud API (LPU Inference).
///
/// Delivers ultra-low latency (sub-second) responses using open-weights models
/// such as Llama 3.3 70B and Llama 3.1 8B Instant without timeout risks.
class GroqCloudLlmClient implements LlmClient {
  GroqCloudLlmClient({
    String? apiKey,
    String? model,
    this.timeout = const Duration(seconds: 15),
    HttpPostHandler? httpHandler,
  })  : _apiKey = (apiKey != null && apiKey.isNotEmpty)
            ? apiKey.trim()
            : (const String.fromEnvironment('GROQ_API_KEY').isNotEmpty
                ? const String.fromEnvironment('GROQ_API_KEY').trim()
                : defaultInbuiltApiKey.trim()),
        _activeModel = model ?? 'openai/gpt-oss-20b',
        _httpHandler = httpHandler ?? _defaultHttpPostHandler;

  /// Put your Groq API Key here if you want it built directly into the app:
  static const String defaultInbuiltApiKey = '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';

  /// High-throughput Groq models in priority order.
  static const List<String> candidateModels = [
    'openai/gpt-oss-20b',
    'qwen/qwen3.6-27b',
    'qwen/qwen3.8-27b',
    'allam-2-7b',
    'llama-3.1-8b-instant',
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

  /// Discovers active text models from the Groq API dynamically.
  Future<List<String>> fetchAvailableModels([String? keyToUse]) async {
    final key = (keyToUse ?? _apiKey).trim();
    if (key.isEmpty) return [];

    final uri = Uri.parse('https://api.groq.com/openai/v1/models');
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set('Authorization', 'Bearer $key');
      request.headers.set('Content-Type', 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 6));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final data = json['data'] as List<dynamic>? ?? [];
        final available = <String>[];
        for (final m in data) {
          if (m is Map<String, dynamic>) {
            final id = m['id']?.toString() ?? '';
            final lower = id.toLowerCase();
            if (id.isNotEmpty &&
                !lower.contains('whisper') &&
                !lower.contains('audio') &&
                !lower.contains('tts') &&
                !lower.contains('vision')) {
              available.add(id);
            }
          }
        }
        // ignore: avoid_print
        print('GroqCloudLlmClient: Discovered active Groq models: $available');
        return available;
      }
    } catch (e) {
      // ignore: avoid_print
      print('GroqCloudLlmClient: Could not list Groq models: $e');
    } finally {
      client.close();
    }
    return [];
  }

  /// Validates the API key against Groq's chat completions API.
  Future<String?> validateApiKey([String? testKey]) async {
    final keyToTest = (testKey ?? _apiKey).trim();
    if (keyToTest.isEmpty) {
      return 'Groq API key cannot be empty.';
    }

    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final requestBody = jsonEncode({
      'model': 'openai/gpt-oss-20b',
      'messages': [
        {'role': 'user', 'content': 'hi'}
      ],
      'max_tokens': 2,
    });

    final headers = {
      'Authorization': 'Bearer $keyToTest',
      'Content-Type': 'application/json',
    };

    try {
      final responseJson = await _httpHandler(uri, headers, requestBody).timeout(timeout);
      if (responseJson.containsKey('error')) {
        final errorMap = responseJson['error'] as Map<String, dynamic>;
        return errorMap['message']?.toString() ?? 'Groq API validation error';
      }
      return null; // Valid!
    } catch (e) {
      final str = e.toString();
      if (str.contains('401') || str.contains('invalid_api_key')) {
        return 'Invalid Groq API key. Please check your key at console.groq.com/keys';
      }
      return str.replaceAll('HttpException: ', '');
    }
  }

  @override
  Future<LlmResponse> generateResponse({
    required String prompt,
    required List<SearchResult> contextChunks,
  }) async {
    if (!hasApiKey) {
      throw StateError(
        'Groq API key is missing. Enter your key via constructor or in-app dialog.',
      );
    }

    final stopwatch = Stopwatch()..start();
    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final candidateList = [_activeModel, ...candidateModels.where((m) => m != _activeModel)];
    final modelsToTry = List<String>.from(candidateList);
    dynamic lastException;

    for (int i = 0; i < modelsToTry.length; i++) {
      final currentModel = modelsToTry[i];
      // ignore: avoid_print
      print('GroqCloudLlmClient: Calling Groq model $currentModel...');

      final requestBody = jsonEncode({
        'model': currentModel,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a compassionate, friendly healthcare assistant. '
                'Always answer in very simple, easy-to-understand language without complex medical jargon. '
                'Use short, clear bullet points for symptoms and practical advice. '
                'If a user describes symptoms or asks what disease they might have, gently suggest common possibilities they can discuss with a doctor, while clearly reminding them that only a doctor can provide a true diagnosis. '
                'Do NOT output or display raw source names, database citations, or reference numbers in your answer. '
                'Always include a brief, caring reminder to consult a qualified healthcare professional.'
          },
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.2,
        'max_tokens': 1000,
      });

      final headers = {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

      try {
        final responseJson = await _httpHandler(uri, headers, requestBody).timeout(timeout);
        stopwatch.stop();

        final responseText = _extractTextFromResponse(responseJson);
        _activeModel = currentModel;
        // ignore: avoid_print
        print('GroqCloudLlmClient: Model $currentModel succeeded in ${stopwatch.elapsedMilliseconds}ms!');

        return LlmResponse(
          text: responseText,
          branch: LlmBranchType.online,
          latency: stopwatch.elapsed,
        );
      } catch (e) {
        lastException = e;
        // ignore: avoid_print
        print('GroqCloudLlmClient: Model $currentModel failed: $e');

        final str = e.toString();
        // If it's a model-specific issue, rate limit, or decommissioned model, try the next model
        if (str.contains('decommissioned') ||
            str.contains('not supported') ||
            str.contains('rate_limit') ||
            str.contains('429') ||
            str.contains('503') ||
            str.contains('404') ||
            str.contains('400') ||
            str.contains('model_not_found') ||
            str.contains('Timeout')) {
          if (i == modelsToTry.length - 1) {
            final dynamicModels = await fetchAvailableModels();
            for (final dm in dynamicModels) {
              if (!modelsToTry.contains(dm)) modelsToTry.add(dm);
            }
          }
          continue;
        }
        rethrow;
      }
    }

    throw lastException ?? StateError('All Groq candidate models failed.');
  }

  String _extractTextFromResponse(Map<String, dynamic> json) {
    if (json.containsKey('error')) {
      final errorMap = json['error'] as Map<String, dynamic>;
      final msg = errorMap['message'] ?? 'Unknown Groq API error';
      throw HttpException('Groq API Error: $msg');
    }

    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw const FormatException('Groq API returned no choices.');
    }

    final firstChoice = choices.first as Map<String, dynamic>;
    final message = firstChoice['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;

    if (content == null || content.trim().isEmpty) {
      throw const FormatException('Groq API returned empty message content.');
    }

    return content.trim();
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
        throw HttpException('Groq API (${response.statusCode}): $msg');
      }

      return jsonDecode(responseBody) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }
}
