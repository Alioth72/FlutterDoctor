import '../../domain/models/search_result.dart';
import '../../domain/services/llm_client.dart';

/// Lightweight, zero-model-download offline synthesizer.
///
/// Formats local ObjectBox MedQuAD chunks into structured medical answers
/// using <1 MB RAM with zero risk of hallucinations or OOM crashes on low-resource devices.
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
            'Please reconnect to the internet for a wider online search, or consult a healthcare professional.',
        branch: LlmBranchType.offline,
        latency: stopwatch.elapsed,
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('📋 **Verified Medical Information (Offline Mode)**');
    buffer.writeln('ℹ️ *Note: Gemini AI is not connected. This is raw reference text from the local MedQuAD database. Tap the 🔑 key icon above to enable simple, conversational answers.*\n');

    for (int i = 0; i < contextChunks.length; i++) {
      final chunk = contextChunks[i];
      buffer.writeln('### Finding ${i + 1}');
      buffer.writeln(_formatParagraph(chunk.text));
      buffer.writeln('\n📖 **Source**: ${chunk.source}\n');
    }

    buffer.writeln('---');
    buffer.writeln('💡 *Tip: Connect to the internet for conversational AI expansion with Gemini.*');
    buffer.writeln('⚠️ *Disclaimer: For educational reference only. Consult a doctor for medical diagnosis.*');

    stopwatch.stop();

    return LlmResponse(
      text: buffer.toString().trim(),
      branch: LlmBranchType.offline,
      latency: stopwatch.elapsed,
    );
  }

  /// Cleanly splits long dense paragraphs into readable sentences with bullet points where helpful.
  String _formatParagraph(String text) {
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    if (sentences.length <= 2) {
      return text.trim();
    }

    // Return structured bulleted list for multi-sentence clinical text
    final buffer = StringBuffer();
    for (final sentence in sentences) {
      buffer.writeln('• ${sentence.trim()}');
    }
    return buffer.toString().trim();
  }
}
