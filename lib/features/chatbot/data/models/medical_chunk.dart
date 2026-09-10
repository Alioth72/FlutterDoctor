import 'package:objectbox/objectbox.dart';

@Entity()
class MedicalChunk {
  @Id()
  int id = 0;

  final String text;
  final String source;

  @HnswIndex(dimensions: 768, distanceType: VectorDistanceType.cosine)
  @Property(type: PropertyType.floatVector)
  final List<double> embedding;

  MedicalChunk({
    this.id = 0,
    required this.text,
    required this.source,
    required this.embedding,
  });

  factory MedicalChunk.fromJson(Map<String, dynamic> json) {
    final rawEmbedding = json['embedding'] as List<dynamic>;
    final embedding = rawEmbedding.map((e) => (e as num).toDouble()).toList();
    return MedicalChunk(
      text: json['text'] as String? ?? '',
      source: json['source'] as String? ?? '',
      embedding: embedding,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'source': source,
      'embedding': embedding,
    };
  }
}
