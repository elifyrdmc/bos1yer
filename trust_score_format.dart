/// One display rule for the server-calculated 0–5 trust score.
String? visibleTrustScore(double? score, int? qualifyingOutcomeCount) {
  if (score == null || (qualifyingOutcomeCount ?? 0) < 4) return null;
  final number = score == score.roundToDouble()
      ? score.toInt().toString()
      : score.toStringAsFixed(1).replaceAll('.', ',');
  return '$number / 5';
}
