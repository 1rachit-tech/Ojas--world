import '../models/home_feed_models.dart';
import '../models/home_feed_runtime_models.dart';

class HomeFeedEvaluationResult {
  const HomeFeedEvaluationResult({
    required this.precisionAtK,
    required this.recallAtK,
    required this.ndcgAtK,
    required this.diversity,
    required this.freshness,
    required this.negativeFeedbackRate,
  });

  final double precisionAtK;
  final double recallAtK;
  final double ndcgAtK;
  final double diversity;
  final double freshness;
  final double negativeFeedbackRate;
}

class HomeFeedEvaluation {
  const HomeFeedEvaluation();

  HomeFeedEvaluationResult evaluate({
    required List<HomeFeedItem> served,
    required Set<String> relevantIds,
    required int k,
    required HomeFeedQualityMetrics quality,
  }) {
    final top = served.take(k).toList(growable: false);
    if (top.isEmpty) {
      return HomeFeedEvaluationResult(
        precisionAtK: 0,
        recallAtK: 0,
        ndcgAtK: 0,
        diversity: 0,
        freshness: 0,
        negativeFeedbackRate: quality.negativeFeedbackRate,
      );
    }

    final hits = top.where((item) => relevantIds.contains(item.contentId)).length;
    final precision = hits / top.length;
    final recall = relevantIds.isEmpty ? 0 : hits / relevantIds.length;
    final dcg = top.asMap().entries.fold<double>(0, (sum, entry) {
      if (!relevantIds.contains(entry.value.contentId)) return sum;
      return sum + (1 / (1 + _log2(entry.key + 2)));
    });
    final idealHits = relevantIds.length.clamp(0, top.length);
    final idealDcg = List<int>.generate(idealHits, (index) => index)
        .fold<double>(0, (sum, index) => sum + (1 / (1 + _log2(index + 2))));
    final ndcg = idealDcg == 0 ? 0 : dcg / idealDcg;
    final uniqueCreators = top.map((item) => item.creatorId).where((id) => id.isNotEmpty).toSet().length;
    final diversity = uniqueCreators / top.length;
    final freshness = top.fold<double>(0, (sum, item) {
      final ageHours = DateTime.now().toUtc().difference(item.createdAt.toUtc()).inHours;
      return sum + (1 / (1 + ageHours / 24));
    }) / top.length;

    return HomeFeedEvaluationResult(
      precisionAtK: precision,
      recallAtK: recall,
      ndcgAtK: ndcg,
      diversity: diversity,
      freshness: freshness,
      negativeFeedbackRate: quality.negativeFeedbackRate,
    );
  }

  double _log2(num value) => value <= 1 ? 0 : (value.toDouble().log() / 2.302585092994046);
}

extension on double {
  double log() {
    var x = this;
    if (x <= 0) return double.negativeInfinity;
    var y = 0.0;
    while (x > 2) {
      x /= 2;
      y += 0.6931471805599453;
    }
    while (x < 1) {
      x *= 2;
      y -= 0.6931471805599453;
    }
    final z = (x - 1) / (x + 1);
    final z2 = z * z;
    return y + 2 * (z + z2 * z / 3 + z2 * z2 * z / 5 + z2 * z2 * z2 * z / 7);
  }
}
