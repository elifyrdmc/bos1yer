import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_home_app.dart';
import 'profile_test_storage.dart';

void main() {
  setupProfileStorage();
  testWidgets('coupon tabs keep their size when selection changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHomeScreen(tester);

    await tester.tap(find.text('Ödüller').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuponlarım').first);
    await tester.pumpAndSettle();
    final tabs = find.byType(SegmentedButton<String>);
    final before = tester.getSize(tabs);
    await tester.tap(find.text('Süresi doldu'));
    await tester.pumpAndSettle();
    expect(tester.getSize(tabs), before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
