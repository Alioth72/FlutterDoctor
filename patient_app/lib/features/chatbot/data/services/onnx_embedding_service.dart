import 'dart:math' as math;

import '../../domain/services/embedding_service.dart';
import 'bert_tokenizer.dart';

abstract class EmbeddingRunner {
  Future<void> init();
  Future<List<double>> runInference(TokenizedInput input);
  void close();
}

class DeterministicEmbeddingRunner implements EmbeddingRunner {
  DeterministicEmbeddingRunner({this.embeddingDimension = 768});

  final int embeddingDimension;
  bool _initialized = false;

  @override
  Future<void> init() async {
    _initialized = true;
  }

  @override
  Future<List<double>> runInference(TokenizedInput input) async {
    if (!_initialized) {
      throw StateError('EmbeddingRunner is not initialized. Call init() first.');
    }

    final vector = List<double>.filled(embeddingDimension, 0.0);
    int activeTokenCount = 0;

    for (int i = 0; i < input.inputIds.length; i++) {
      if (input.attentionMask[i] == 0) continue;

      final tokenId = input.inputIds[i];
      if (tokenId == BertTokenizer.padId) continue;

      activeTokenCount++;

      for (int d = 0; d < embeddingDimension; d++) {
        final seed = (tokenId * 10007 + d * 31 + i * 17) & 0x7FFFFFFF;
        final val = ((seed % 2000) - 1000) / 1000.0;
        vector[d] += val;
      }
    }

    if (activeTokenCount > 0) {
      for (int d = 0; d < embeddingDimension; d++) {
        vector[d] /= activeTokenCount;
      }
    }

    return vector;
  }

  @override
  void close() {
    _initialized = false;
  }
}

class OnnxEmbeddingService implements EmbeddingService {
  OnnxEmbeddingService({
    BertTokenizer? tokenizer,
    EmbeddingRunner? runner,
  })  : _tokenizer = tokenizer ?? BertTokenizer(),
        _runner = runner ?? DeterministicEmbeddingRunner();

  final BertTokenizer _tokenizer;
  final EmbeddingRunner _runner;
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  BertTokenizer get tokenizer => _tokenizer;
  EmbeddingRunner get runner => _runner;

  @override
  Future<void> init() async {
    if (_isInitialized) return;
    await _runner.init();
    _isInitialized = true;
  }

  @override
  Future<List<double>> embedQuery(String text) async {
    if (!_isInitialized) {
      throw StateError('OnnxEmbeddingService is not initialized. Call init() first.');
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Query text cannot be empty or whitespace-only.');
    }

    final tokenized = _tokenizer.encode(trimmed, maxSeqLength: 64);
    final rawVector = await _runner.runInference(tokenized);

    if (rawVector.length != 768) {
      throw StateError(
        'Embedding vector must have 768 dimensions, but got ${rawVector.length}.',
      );
    }

    return _l2Normalize(rawVector);
  }

  List<double> _l2Normalize(List<double> vector) {
    double sumSquares = 0.0;
    for (final val in vector) {
      sumSquares += val * val;
    }

    final norm = math.sqrt(sumSquares);
    if (norm == 0.0 || norm.isNaN) {
      return List<double>.filled(vector.length, 0.0);
    }

    final normalized = List<double>.filled(vector.length, 0.0);
    for (int i = 0; i < vector.length; i++) {
      normalized[i] = vector[i] / norm;
    }
    return normalized;
  }

  @override
  void close() {
    _runner.close();
    _isInitialized = false;
  }
}
