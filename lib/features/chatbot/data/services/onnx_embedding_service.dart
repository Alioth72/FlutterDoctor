import 'dart:io';
import 'dart:math' as math;

import '../../domain/services/embedding_service.dart';
import 'bert_tokenizer.dart';

/// Pluggable delegate for executing token-to-vector embedding inference.
abstract class EmbeddingRunner {
  /// Initializes model sessions or sets up inference weights.
  Future<void> init();

  /// Runs inference over tokenized inputs and returns an unnormalized 768-dim vector.
  Future<List<double>> runInference(TokenizedInput input);

  /// Releases model sessions or native handles.
  void close();
}

/// Deterministic embedding runner using pseudo-random hashing and mean pooling.
///
/// Ensures fast, predictable 768-dimensional vector generation for local testing,
/// CI environments, and platforms prior to bundling the heavy ~110MB ONNX binary.
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
      if (input.attentionMask[i] == 0) continue; // Skip padding tokens

      final tokenId = input.inputIds[i];
      if (tokenId == BertTokenizer.padId) continue;

      activeTokenCount++;

      // Deterministic pseudo-random projection for token ID + position
      for (int d = 0; d < embeddingDimension; d++) {
        // Linear congruential hash per dimension
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

/// Production runner designed to interface with an ONNX Runtime model file.
///
/// Expects a PubMedBERT ONNX model taking `input_ids`, `attention_mask`, and
/// `token_type_ids` and returning a `[1, 768]` or `[1, seq_len, 768]` tensor.
class OnnxModelRunner implements EmbeddingRunner {
  OnnxModelRunner({
    this.modelPath = 'assets/models/pubmedbert_quantized.onnx',
    this.fallbackRunner,
  });

  final String modelPath;
  final EmbeddingRunner? fallbackRunner;
  bool _initialized = false;
  bool _useFallback = false;

  @override
  Future<void> init() async {
    final file = File(modelPath);
    if (!file.existsSync()) {
      if (fallbackRunner != null) {
        _useFallback = true;
        await fallbackRunner!.init();
        _initialized = true;
        return;
      }
      throw StateError(
        'ONNX model file not found at: $modelPath. '
        'Provide a valid model path or supply a fallback runner.',
      );
    }

    // When native onnxruntime package is attached, session is created here:
    // _session = OrtSession.fromFile(file, ...);
    _initialized = true;
  }

  @override
  Future<List<double>> runInference(TokenizedInput input) async {
    if (!_initialized) {
      throw StateError('OnnxModelRunner is not initialized. Call init() first.');
    }

    if (_useFallback && fallbackRunner != null) {
      return fallbackRunner!.runInference(input);
    }

    // Native inference execution
    throw UnimplementedError(
      'Native ONNX inference requires the onnxruntime platform plugin. '
      'Use DeterministicEmbeddingRunner or provide fallbackRunner for testing.',
    );
  }

  @override
  void close() {
    if (_useFallback && fallbackRunner != null) {
      fallbackRunner!.close();
    }
    _initialized = false;
  }
}

/// Concrete implementation of [EmbeddingService].
///
/// Orchestrates [BertTokenizer] and [EmbeddingRunner] to generate 768-dimensional,
/// L2-normalized float embeddings suitable for ObjectBox HNSW cosine search.
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

  /// Underlying tokenizer instance.
  BertTokenizer get tokenizer => _tokenizer;

  /// Underlying runner instance.
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

    // 1. Tokenize query into BERT tensor inputs (maxSeqLength 64)
    final tokenized = _tokenizer.encode(trimmed, maxSeqLength: 64);

    // 2. Run inference to produce raw 768-dimension vector
    final rawVector = await _runner.runInference(tokenized);

    if (rawVector.length != 768) {
      throw StateError(
        'Embedding vector must have 768 dimensions, but got ${rawVector.length}.',
      );
    }

    // 3. Apply L2 unit normalization: v / sqrt(sum(v_i^2))
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
