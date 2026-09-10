import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_retrieval.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ObjectBoxVectorStoreRepository repository;

  // Lightweight 768-dim mock JSON for fast, deterministic unit testing
  List<double> createVector(int activeIndex) {
    final v = List<double>.filled(768, 0.0);
    v[activeIndex % 768] = 1.0;
    return v;
  }

  final mockJson = jsonEncode([
    {
      'text': 'Iron deficiency anemia causes fatigue, weakness, and pale skin.',
      'source': 'MedQuAD: What is anemia? (001)',
      'embedding': createVector(10),
    },
    {
      'text': 'Keratoderma with woolly hair affects skin, hair, and causes cardiomyopathy.',
      'source': 'MedQuAD: What is keratoderma? (002)',
      'embedding': createVector(20),
    },
    {
      'text': 'Type 2 diabetes symptoms include frequent urination and increased thirst.',
      'source': 'NHP India: Diabetes overview (003)',
      'embedding': createVector(30),
    },
  ]);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('obx_vector_test_');
    repository = ObjectBoxVectorStoreRepository();
    await repository.init(directory: tempDir.path);
  });

  tearDown(() async {
    await repository.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ObjectBoxVectorStoreRepository', () {
    test('ingests knowledge chunks and verifies idempotency', () async {
      // First ingestion using rawJsonContent
      final firstIngested = await repository.ingestAssetIfEmpty(rawJsonContent: mockJson);
      expect(firstIngested, isTrue);

      final totalCount = await repository.count();
      expect(totalCount, 3);

      // Second ingestion attempt should be skipped (idempotent)
      final secondIngested = await repository.ingestAssetIfEmpty(rawJsonContent: mockJson);
      expect(secondIngested, isFalse);

      final countAfterSecond = await repository.count();
      expect(countAfterSecond, 3, reason: 'Count should not change on second ingestion');
    });

    test('validates 768-dimension constraint on query embedding', () async {
      await repository.ingestAssetIfEmpty(rawJsonContent: mockJson);

      // 384 dimensions should throw ArgumentError
      final invalidDimVector = List<double>.filled(384, 0.1);

      expect(
        () => repository.similaritySearch(invalidDimVector, 3),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('similaritySearch returns ranked top-K results matching query domain', () async {
      await repository.ingestAssetIfEmpty(rawJsonContent: mockJson);

      // Create query vector aligned with chunk 0 (Anemia at index 10)
      final queryEmbedding = createVector(10);
      final results = await repository.similaritySearch(queryEmbedding, 2);

      // Validate topK constraint
      expect(results.length, 2);

      // Top result must be Anemia with highest similarity
      expect(results[0].text.toLowerCase(), contains('anemia'));
      expect(results[0].source, contains('MedQuAD'));
      expect(results[0].score, isNotNull);
    });

    test('clearAll removes all chunks', () async {
      await repository.ingestAssetIfEmpty(rawJsonContent: mockJson);
      expect(await repository.count(), 3);

      await repository.clearAll();
      expect(await repository.count(), 0);
    });

    test('verifies production asset file structure and dimension integrity', () {
      const assetPath = 'assets/data/medical_knowledge_embeddings.json';
      final file = File(assetPath);
      expect(file.existsSync(), isTrue, reason: 'Production embeddings file must exist');

      final size = file.lengthSync();
      expect(size, greaterThan(50 * 1024 * 1024), reason: 'Dataset should be ~88MB');
    });
  });
}
