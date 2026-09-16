import '../models/search_result.dart';

/// Execution branch indicating where generation occurred.
enum LlmBranchType {
  /// Generated via the remote cloud endpoint.
  online,

  /// Generated via the local on-device quantized model.
  offline,
}

/// Output produced by an [LlmClient].
class LlmResponse {
  const LlmResponse({
    required this.text,
    required this.branch,
    this.latency,
  });

  /// The generated medical response text.
  final String text;

  /// Whether response originated from online or offline engine.
  final LlmBranchType branch;

  /// Optional round-trip generation duration.
  final Duration? latency;

  @override
  String toString() => 'LlmResponse(branch: $branch, length: ${text.length})';
}

/// Unified domain contract for text generation models.
abstract class LlmClient {
  /// Generates an answer given the augmented prompt and retrieved medical chunks.
  Future<LlmResponse> generateResponse({
    required String prompt,
    required List<SearchResult> contextChunks,
  });
}
