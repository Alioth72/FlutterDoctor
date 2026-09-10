import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_llm.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_retrieval.dart';

void main() {
  group('ExtractiveOfflineLlmClient', () {
    const client = ExtractiveOfflineLlmClient();

    test('formats single retrieved MedQuAD chunk with bullet points and source', () async {
      const chunks = [
        SearchResult(
          text: 'Keratoderma with woolly hair causes coarse hair. '
              'Affected individuals develop palmoplantar keratoderma on palms and soles. '
              'Cardiomyopathy is a potentially life-threatening complication.',
          source: 'MedQuAD: What is keratoderma? (0000559)',
          score: 0.88,
        ),
      ];

      final response = await client.generateResponse(
        prompt: 'Query prompt',
        contextChunks: chunks,
      );

      expect(response.branch, LlmBranchType.offline);
      expect(response.text, contains('Offline Mode'));
      expect(response.text, contains('MedQuAD: What is keratoderma? (0000559)'));
      expect(response.text, contains('•'));
      expect(response.text, contains('Cardiomyopathy'));
      expect(response.text, contains('Disclaimer'));
      expect(response.latency, isNotNull);
    });

    test('formats multiple retrieved chunks into numbered findings', () async {
      const chunks = [
        SearchResult(
          text: 'Chunk 1 clinical details about symptoms.',
          source: 'MedQuAD: Source 1',
          score: 0.95,
        ),
        SearchResult(
          text: 'Chunk 2 clinical details about treatments.',
          source: 'MedQuAD: Source 2',
          score: 0.85,
        ),
      ];

      final response = await client.generateResponse(
        prompt: 'Query prompt',
        contextChunks: chunks,
      );

      expect(response.text, contains('Finding 1'));
      expect(response.text, contains('Finding 2'));
      expect(response.text, contains('MedQuAD: Source 1'));
      expect(response.text, contains('MedQuAD: Source 2'));
    });

    test('returns helpful guidance message when no chunks are retrieved', () async {
      final response = await client.generateResponse(
        prompt: 'Query prompt',
        contextChunks: [],
      );

      expect(response.branch, LlmBranchType.offline);
      expect(response.text, contains('No matching medical records were found'));
      expect(response.text, contains('reconnect to the internet'));
    });
  });
}
