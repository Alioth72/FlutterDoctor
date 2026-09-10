/// Domain contract for generating on-device text embeddings.
///
/// In the healthcare chatbot pipeline, this service converts user queries into
/// 768-dimensional PubMedBERT-aligned vectors for vector similarity search.
abstract class EmbeddingService {
  /// Initializes the tokenizer vocabulary, model sessions, and underlying runtime.
  Future<void> init();

  /// Converts a user query into a 768-dimensional L2-normalized float vector.
  ///
  /// Throws an [ArgumentError] if [text] is empty or whitespace-only.
  /// Throws a [StateError] if called before [init] or after [close].
  Future<List<double>> embedQuery(String text);

  /// Returns true if the service has been initialized and is ready for inference.
  bool get isInitialized;

  /// Releases model sessions, tokenizer memory, and associated native resources.
  void close();
}
