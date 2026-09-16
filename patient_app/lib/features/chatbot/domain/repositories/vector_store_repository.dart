import '../models/search_result.dart';
export '../models/search_result.dart';

/// Abstract contract for local vector persistence and similarity retrieval.
abstract class VectorStoreRepository {
  /// Initializes the vector store instance.
  Future<void> init({String? directory});

  /// Ingests chunks from the bundled asset if the store is currently empty.
  /// Returns true if ingestion occurred, false if skipped (idempotent).
  Future<bool> ingestAssetIfEmpty({String? assetPath, String? rawJsonContent});

  /// Performs similarity search using the query vector.
  /// Returns top [topK] chunks ordered by score (highest similarity first).
  Future<List<SearchResult>> similaritySearch(List<double> queryEmbedding, int topK);

  /// Returns total number of chunks currently stored.
  Future<int> count();

  /// Clears all chunks from the vector store.
  Future<void> clearAll();

  /// Closes the underlying database instance.
  Future<void> close();
}
