/// Represents a clinical medical knowledge chunk with text, source citation, and embedding vector.
class MedicalChunk {
  int id;
  final String text;
  final String source;
  final List<double> embedding;

  MedicalChunk({
    this.id = 0,
    required this.text,
    required this.source,
    required this.embedding,
  });

  factory MedicalChunk.fromJson(Map<String, dynamic> json) {
    final rawEmbedding = json['embedding'] as List<dynamic>? ?? [];
    final embedding = rawEmbedding.map((e) => (e as num).toDouble()).toList();
    return MedicalChunk(
      id: json['id'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      source: json['source'] as String? ?? '',
      embedding: embedding,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'source': source,
      'embedding': embedding,
    };
  }
}
