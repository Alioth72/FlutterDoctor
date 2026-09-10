import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../objectbox.g.dart';
import '../../domain/repositories/vector_store_repository.dart';
import '../models/medical_chunk.dart';

/// Concrete implementation of [VectorStoreRepository] using ObjectBox HNSW Vector Search.
class ObjectBoxVectorStoreRepository implements VectorStoreRepository {
  ObjectBoxVectorStoreRepository([this._store]);

  Store? _store;
  Box<MedicalChunk>? _box;

  /// Returns true if the store is open and ready.
  bool get isInitialized => _store != null && !_store!.isClosed();

  /// Underlying ObjectBox store. Throws StateError if not initialized.
  Store get store {
    final s = _store;
    if (s == null || s.isClosed()) {
      throw StateError('ObjectBox store is not initialized. Call init() first.');
    }
    return s;
  }

  /// Box containing [MedicalChunk] entities.
  Box<MedicalChunk> get box {
    final b = _box;
    if (b == null || _store == null || _store!.isClosed()) {
      throw StateError('ObjectBox store is not initialized. Call init() first.');
    }
    return b;
  }

  @override
  Future<void> init({String? directory}) async {
    if (isInitialized) return;

    final dir = directory ??
        p.join((await getApplicationDocumentsDirectory()).path, 'medical_vector_store');
    final dirFile = Directory(dir);
    if (!dirFile.existsSync()) {
      dirFile.createSync(recursive: true);
    }

    _store = await openStore(directory: dir);
    _box = _store!.box<MedicalChunk>();
  }

  @override
  Future<bool> ingestAssetIfEmpty({String? assetPath, String? rawJsonContent}) async {
    if (box.count() > 0) {
      // Store already populated - idempotent skip
      return false;
    }

    String jsonString;
    if (rawJsonContent != null) {
      jsonString = rawJsonContent;
    } else {
      final path = assetPath ?? 'assets/data/medical_knowledge_embeddings.json';
      try {
        jsonString = await rootBundle.loadString(path);
      } catch (_) {
        final file = File(path);
        if (file.existsSync()) {
          jsonString = await file.readAsString();
        } else {
          throw StateError('Could not load knowledge embeddings asset from: $path');
        }
      }
    }

    final decoded = jsonDecode(jsonString) as List<dynamic>;
    final chunks = decoded
        .map((item) => MedicalChunk.fromJson(item as Map<String, dynamic>))
        .toList();

    box.putMany(chunks);
    return true;
  }

  @override
  Future<List<SearchResult>> similaritySearch(
    List<double> queryEmbedding,
    int topK,
  ) async {
    if (queryEmbedding.length != 768) {
      throw ArgumentError(
        'queryEmbedding must have 768 dimensions (PubMedBERT format), got ${queryEmbedding.length}',
      );
    }

    final query = box
        .query(MedicalChunk_.embedding.nearestNeighborsF32(queryEmbedding, topK))
        .build();

    final scoredResults = query.findWithScores();
    query.close();

    // Map ObjectBox ObjectWithScore to SearchResult
    return scoredResults.map((result) {
      return SearchResult(
        text: result.object.text,
        source: result.object.source,
        score: result.score,
      );
    }).toList();
  }

  @override
  Future<int> count() async {
    return box.count();
  }

  @override
  Future<void> clearAll() async {
    box.removeAll();
  }

  @override
  Future<void> close() async {
    if (_store != null && !_store!.isClosed()) {
      _store!.close();
      _store = null;
      _box = null;
    }
  }
}
