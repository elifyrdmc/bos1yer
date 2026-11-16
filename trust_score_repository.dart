import 'package:supabase_flutter/supabase_flutter.dart';

class TrustScoreSummary {
  const TrustScoreSummary({
    required this.qualifyingOutcomeCount,
    required this.score,
  });

  final int qualifyingOutcomeCount;
  final double? score;

  bool get isVisible => qualifyingOutcomeCount >= 4 && score != null;
}

class TrustScoreRepository {
  TrustScoreRepository(this._client);

  final SupabaseClient _client;

  Future<TrustScoreSummary> fetch() async {
    final response = await _client.rpc('get_my_trust_score');
    if (response is! List || response.isEmpty || response.first is! Map) {
      throw const FormatException('Invalid trust score response.');
    }

    final row = Map<String, dynamic>.from(response.first as Map);
    final outcomeCount = row['qualifying_outcome_count'];
    final rawScore = row['score'];
    if (outcomeCount is! num || outcomeCount < 0 || outcomeCount % 1 != 0) {
      throw const FormatException('Invalid trust outcome count.');
    }
    if (rawScore != null && rawScore is! num) {
      throw const FormatException('Invalid trust score value.');
    }

    final score = (rawScore as num?)?.toDouble();
    if (score != null && (!score.isFinite || score < 0 || score > 5)) {
      throw const FormatException('Trust score is outside the 0–5 range.');
    }
    return TrustScoreSummary(
      qualifyingOutcomeCount: outcomeCount.toInt(),
      score: score,
    );
  }
}
