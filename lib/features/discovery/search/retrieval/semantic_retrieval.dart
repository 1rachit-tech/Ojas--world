import '../domain/search_models.dart';

abstract interface class SemanticRetrievalProvider {
  Future<List<SearchIndexRow>> retrieve(
    SearchQuery query, {
    int limit,
  });
}

class DisabledSemanticRetrievalProvider implements SemanticRetrievalProvider {
  const DisabledSemanticRetrievalProvider();

  @override
  Future<List<SearchIndexRow>> retrieve(
    SearchQuery query, {
    int limit = 50,
  }) async {
    // Semantic retrieval is deliberately pluggable. OJAS can connect this
    // contract to Firestore vector search or another ANN service later without
    // changing Search UI, ranking, or result blending.
    return const <SearchIndexRow>[];
  }
}
