import '../../domain/models/search_result.dart';
import '../../domain/services/llm_client.dart';

/// Lightweight offline synthesizer for offline knowledge.
class ExtractiveOfflineLlmClient implements LlmClient {
  const ExtractiveOfflineLlmClient();

  @override
  Future<LlmResponse> generateResponse({
    required String prompt,
    required List<SearchResult> contextChunks,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (contextChunks.isEmpty) {
      return LlmResponse(
        text: '📋 **Offline Medical Knowledge**\n\n'
            'No matching medical records were found in the local offline database.\n'
            'Please check your internet connection for online AI assistance, or consult a healthcare professional.',
        branch: LlmBranchType.offline,
        latency: stopwatch.elapsed,
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('📋 **Verified Medical Information (Offline Mode)**\n');

    for (int i = 0; i < contextChunks.length; i++) {
      final chunk = contextChunks[i];
      buffer.writeln('### Finding ${i + 1}');
      buffer.writeln(_formatParagraph(chunk.text));
      buffer.writeln('\n📖 **Source**: ${chunk.source}\n');
    }

    buffer.writeln('---');
    buffer.writeln('⚠️ *Disclaimer: For educational reference only. Consult a doctor for medical diagnosis.*');

    stopwatch.stop();

    return LlmResponse(
      text: buffer.toString().trim(),
      branch: LlmBranchType.offline,
      latency: stopwatch.elapsed,
    );
  }

  String _formatParagraph(String text) {
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    if (sentences.length <= 2) {
      return text.trim();
    }

    final buffer = StringBuffer();
    for (final sentence in sentences) {
      buffer.writeln('• ${sentence.trim()}');
    }
    return buffer.toString().trim();
  }
}
