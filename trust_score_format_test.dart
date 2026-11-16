import 'package:flutter_test/flutter_test.dart';
import 'package:parkist/trust_score_format.dart';

void main() {
  test('uses one score format after four qualifying outcomes', () {
    expect(visibleTrustScore(3.4, 4), '3,4 / 5');
    expect(visibleTrustScore(3.0, 9), '3 / 5');
  });

  test('does not display a score while it is being calculated', () {
    expect(visibleTrustScore(3.4, 3), isNull);
    expect(visibleTrustScore(null, 8), isNull);
  });
}
