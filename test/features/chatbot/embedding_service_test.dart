import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_embedding.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_retrieval.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OnnxEmbeddingService embeddingService;

  setUp(() async {
    embeddingService = OnnxEmbeddingService();
    await embeddingService.init();
  });

  tearDown(() {
    embeddingService.close();
  });

  group('OnnxEmbeddingService', () {
    test('generates strictly 768-dimensional float embedding', () async {
      final vector = await embeddingService.embedQuery('what are the symptoms of diabetes?');

      expect(vector.length, 768);
      for (final val in vector) {
        expect(val.isNaN, isFalse);
        expect(val.isInfinite, isFalse);
      }
    });

    test('applies L2 unit normalization so Euclidean norm equals 1.0', () async {
      final vector = await embeddingService.embedQuery('severe headache and fever');

      double sumSquares = 0.0;
      for (final val in vector) {
        sumSquares += val * val;
      }
      final norm = math.sqrt(sumSquares);

      expect(norm, closeTo(1.0, 1e-4));
    });

    test('throws ArgumentError for empty or whitespace-only queries', () async {
      expect(
        () => embeddingService.embedQuery(''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => embeddingService.embedQuery('   \t\n  '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws StateError when called before init or after close', () async {
      final uninitialized = OnnxEmbeddingService();
      expect(
        () => uninitialized.embedQuery('test query'),
        throwsA(isA<StateError>()),
      );

      uninitialized.close();
      expect(
        () => uninitialized.embedQuery('test query'),
        throwsA(isA<StateError>()),
      );
    });

    test('produces deterministic identical embeddings for identical input', () async {
      final query = 'high blood pressure hypertension';
      final v1 = await embeddingService.embedQuery(query);
      final v2 = await embeddingService.embedQuery(query);

      expect(v1, equals(v2));
    });

    test('produces distinct embeddings for different queries', () async {
      final v1 = await embeddingService.embedQuery('chest pain heart attack');
      final v2 = await embeddingService.embedQuery('skin rash dermatosis');

      expect(v1, isNot(equals(v2)));
    });

    test('integrates seamlessly with ObjectBox VectorStoreRepository', () async {
      // 1. Setup temporary ObjectBox vector store
      final tempDir = await Directory.systemTemp.createTemp('obx_embed_chain_test_');
      final vectorStore = ObjectBoxVectorStoreRepository();
      await vectorStore.init(directory: tempDir.path);

      try {
        // 2. Ingest 2 sample knowledge chunks
        final sampleJson = jsonEncode([
          {
            'text': 'Iron deficiency anemia causes fatigue and shortness of breath.',
            'source': 'MedQuAD: Anemia overview',
            'embedding': List<double>.filled(768, 0.05),
          },
          {
            'text': 'Keratoderma with woolly hair affects palms, soles, and cardiac tissue.',
            'source': 'MedQuAD: Keratoderma overview',
            'embedding': List<double>.filled(768, -0.05),
          },
        ]);
        await vectorStore.ingestAssetIfEmpty(rawJsonContent: sampleJson);

        // 3. Generate 768-dim query embedding
        final queryVector = await embeddingService.embedQuery('iron deficiency symptoms');
        expect(queryVector.length, 768);

        // 4. Execute vector similarity search with the generated query vector
        final results = await vectorStore.similaritySearch(queryVector, 2);

        expect(results.length, 2);
        expect(results.first.text, isNotEmpty);
        expect(results.first.score, isNotNull);
      } finally {
        await vectorStore.close();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });
}
