/// Represents a retrieved knowledge chunk with its similarity score.
class SearchResult {
  const SearchResult({
    required this.text,
    required this.source,
    required this.score,
  });

  final String text;
  final String source;
  final double score;

  @override
  String toString() =>
      'SearchResult(score: ${score.toStringAsFixed(4)}, source: $source, text: ${text.length > 40 ? '${text.substring(0, 40)}...' : text})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          source == other.source &&
          (score - other.score).abs() < 1e-6;

  @override
  int get hashCode => Object.hash(text, source, score);
}
