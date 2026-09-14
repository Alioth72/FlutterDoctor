import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_llm.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_retrieval.dart';

void main() {
  group('GeminiCloudLlmClient', () {
    test('throws StateError when API key is missing', () async {
      final client = GeminiCloudLlmClient(apiKey: '');
      expect(client.hasApiKey, isFalse);

      expect(
        () => client.generateResponse(
          prompt: 'What are anemia symptoms?',
          contextChunks: [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('successfully extracts generated text from Gemini API response', () async {
      late Uri capturedUri;
      late Map<String, String> capturedHeaders;
      late String capturedBody;

      final client = GeminiCloudLlmClient(
        apiKey: 'test_gemini_key_123',
        httpHandler: (uri, headers, body) async {
          capturedUri = uri;
          capturedHeaders = headers;
          capturedBody = body;

          return {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': 'Anemia is characterized by fatigue and low hemoglobin. '
                          '[Source: MedQuAD: Anemia Overview]'
                    }
                  ]
                }
              }
            ]
          };
        },
      );

      final sampleChunks = [
        const SearchResult(
          text: 'Iron deficiency leads to decreased red blood cell count.',
          source: 'MedQuAD: Anemia Overview',
          score: 0.92,
        ),
      ];

      final response = await client.generateResponse(
        prompt: 'Explain anemia',
        contextChunks: sampleChunks,
      );

      // Verify URL and Headers
      expect(capturedUri.queryParameters['key'], 'test_gemini_key_123');
      expect(capturedHeaders['Content-Type'], 'application/json');

      // Verify request payload contains prompt
      final decodedBody = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(decodedBody['contents'], isNotEmpty);

      // Verify extracted response
      expect(response.branch, LlmBranchType.online);
      expect(response.text, contains('fatigue and low hemoglobin'));
      expect(response.latency, isNotNull);
    });

    test('throws HttpException when API returns error object', () async {
      final client = GeminiCloudLlmClient(
        apiKey: 'bad_key',
        httpHandler: (uri, headers, body) async {
          return {
            'error': {
              'code': 400,
              'message': 'API key not valid. Please pass a valid API key.',
              'status': 'INVALID_ARGUMENT',
            }
          };
        },
      );

      expect(
        () => client.generateResponse(
          prompt: 'Test query',
          contextChunks: [],
        ),
        throwsA(isA<HttpException>().having(
          (e) => e.message,
          'message',
          contains('API key not valid'),
        )),
      );
    });

    test('throws FormatException when API returns empty candidates', () async {
      final client = GeminiCloudLlmClient(
        apiKey: 'valid_key',
        httpHandler: (uri, headers, body) async {
          return {'candidates': []};
        },
      );

      expect(
        () => client.generateResponse(
          prompt: 'Test query',
          contextChunks: [],
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('allows updating API key dynamically via setApiKey', () async {
      final client = GeminiCloudLlmClient(apiKey: '');
      expect(client.hasApiKey, isFalse);

      client.setApiKey('new_runtime_key_456');
      expect(client.hasApiKey, isTrue);
    });
  });
}
