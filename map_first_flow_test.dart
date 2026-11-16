import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_home_app.dart';

void main() {
  testWidgets('tapping an unknown map point does not imply a parking report', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHomeScreen(tester);

    final map = find.byType(FlutterMap);
    await tester.tapAt(tester.getCenter(map) + const Offset(0, 100));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Seçilen konum'), findsNothing);
    expect(find.text('BOŞ1YER kaydı yok'), findsNothing);
    expect(find.text('Bu konum için bildirim oluştur'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
