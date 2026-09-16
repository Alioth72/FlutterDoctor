import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';

import '../../domain/repositories/vector_store_repository.dart';
import '../models/medical_chunk.dart';

/// Lightweight, in-memory implementation of [VectorStoreRepository] using pure Dart
/// cosine similarity calculation. Requires zero native C++ libraries or code generators.
class LocalVectorStoreRepository implements VectorStoreRepository {
  LocalVectorStoreRepository();

  final List<MedicalChunk> _chunks = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  @override
  Future<void> init({String? directory}) async {
    _isInitialized = true;
  }

  @override
  Future<bool> ingestAssetIfEmpty({String? assetPath, String? rawJsonContent}) async {
    if (_chunks.isNotEmpty) {
      return false;
    }

    String? jsonString = rawJsonContent;
    if (jsonString == null) {
      final path = assetPath ?? 'assets/data/medical_knowledge_embeddings.json';
      try {
        jsonString = await rootBundle.loadString(path);
      } catch (_) {
        // Asset not packaged in patient_app — return false gracefully
        return false;
      }
    }

    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      _chunks.clear();
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          _chunks.add(MedicalChunk.fromJson(item));
        }
      }
      return _chunks.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<SearchResult>> similaritySearch(
    List<double> queryEmbedding,
    int topK,
  ) async {
    if (_chunks.isEmpty || queryEmbedding.isEmpty) {
      return [];
    }

    final queryNorm = _computeNorm(queryEmbedding);
    if (queryNorm == 0) return [];

    final scored = <_ScoredChunk>[];
    for (final chunk in _chunks) {
      if (chunk.embedding.isEmpty || chunk.embedding.length != queryEmbedding.length) {
        continue;
      }
      final dot = _dotProduct(queryEmbedding, chunk.embedding);
      final chunkNorm = _computeNorm(chunk.embedding);
      final score = chunkNorm > 0 ? (dot / (queryNorm * chunkNorm)) : 0.0;
      scored.add(_ScoredChunk(chunk: chunk, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    final results = <SearchResult>[];
    for (int i = 0; i < scored.length && i < topK; i++) {
      results.add(SearchResult(
        text: scored[i].chunk.text,
        source: scored[i].chunk.source,
        score: scored[i].score,
      ));
    }

    return results;
  }

  double _dotProduct(List<double> a, List<double> b) {
    double sum = 0.0;
    for (int i = 0; i < a.length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }

  double _computeNorm(List<double> v) {
    double sum = 0.0;
    for (int i = 0; i < v.length; i++) {
      sum += v[i] * v[i];
    }
    return math.sqrt(sum);
  }

  @override
  Future<int> count() async => _chunks.length;

  @override
  Future<void> clearAll() async => _chunks.clear();

  @override
  Future<void> close() async {
    _chunks.clear();
    _isInitialized = false;
  }
}

class _ScoredChunk {
  final MedicalChunk chunk;
  final double score;
  _ScoredChunk({required this.chunk, required this.score});
}
