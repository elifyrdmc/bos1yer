import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_home_app.dart';

void main() {
  testWidgets('leaving report also requires a camera photo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHomeScreen(tester);

    await tester.tap(find.bySemanticsLabel('Bildirim ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çıkıyorum').last);
    await tester.pumpAndSettle();
    expect(find.text('Şu an neredesin?'), findsOneWidget);
    expect(find.text('Ne zaman ayrılacaksın?'), findsOneWidget);
    expect(find.text('Konumdayım'), findsOneWidget);
    expect(find.text('Yakındayım'), findsOneWidget);

    expect(find.text('Çıkıyorum'), findsOneWidget);
    expect(find.text('Fotoğraf çek'), findsOneWidget);
    expect(find.text('Galeriden seç'), findsNothing);
    expect(find.text('Fotoğraf · zorunlu'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Bildirimi önizle'),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('nearby leaving report may continue without an initial photo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHomeScreen(tester);

    await tester.tap(find.bySemanticsLabel('Bildirim ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çıkıyorum').last);
    await tester.pumpAndSettle();
    expect(find.text('Şu an neredesin?'), findsOneWidget);
    expect(find.text('Ne zaman ayrılacaksın?'), findsOneWidget);
    await tester.tap(find.text('Yakındayım'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Bildirimi önizle'),
    );
    expect(button.onPressed, isNotNull);
    expect(find.text('Fotoğraf · 5 dk içinde'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
