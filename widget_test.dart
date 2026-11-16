import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkist/design_system.dart';

import 'profile_test_storage.dart';
import 'test_home_app.dart';

void main() {
  setupProfileStorage();
  testWidgets('BOŞ1YER opens with a map-first home screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpHomeScreen(tester);

    expect(find.byType(BrandLockup), findsOneWidget);
    expect(find.byTooltip('Adres veya semt ara'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Boş yer gördüm'), findsNothing);
    expect(find.text('Çıkıyorum'), findsNothing);

    await tester.tap(find.text('Ödüller'));
    await tester.pumpAndSettle();
    expect(find.text('CÜZDANIM'), findsOneWidget);
    await tester.tap(find.text('Harita'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('quick report starts with camera-only photo step', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHomeScreen(tester);

    await tester.tap(find.bySemanticsLabel('Bildirim ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boş yer gördüm'));
    await tester.pumpAndSettle();

    expect(find.text('Boş yer bildir'), findsWidgets);
    expect(find.text('Fotoğraf çek'), findsOneWidget);
    expect(find.text('Galeriden seç'), findsNothing);
    expect(find.text('Fotoğraf · zorunlu'), findsOneWidget);
    final nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Bildirimi önizle'),
    );
    expect(nextButton.onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('quick report buttons fit on a narrow phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHomeScreen(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
