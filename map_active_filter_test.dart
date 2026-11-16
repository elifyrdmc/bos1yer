import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_home_app.dart';

void main() {
  testWidgets('active type filter stays visible on a narrow map and clears', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHomeScreen(tester);

    await tester.tap(find.byTooltip('Harita katmanları ve filtreler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çıkıyorum').last);
    await tester.tap(find.text('Sonuçları göster'));
    await tester.pumpAndSettle();

    expect(find.text('Boş yer'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Konumuma git'));
    await tester.pumpAndSettle();
    expect(find.text('Boş yer'), findsOneWidget);
    await tester.tap(find.byTooltip('Tüm filtreleri temizle'));
    await tester.pump();
    expect(find.text('Boş yer'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
