import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_settings_test.dart' show openProfile, tapLabel;
import 'profile_test_storage.dart';

void main() {
  setupProfileStorage();
  testWidgets('Failed save stays in editor and can be retried', (tester) async {
    await openProfile(tester);
    await tapLabel(tester, 'Profili düzenle');
    await tester.enterText(find.byType(TextFormField).first, 'Elif');
    await tester.enterText(find.byType(TextFormField).last, 'Naz');
    profileStorage.failWrites = true;
    await tapLabel(tester, 'Değişiklikleri kaydet');
    expect(find.text('Profil bilgileri kaydedilemedi.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    profileStorage.failWrites = false;
    await tapLabel(tester, 'Değişiklikleri kaydet');
    expect(find.byType(TextFormField), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await openProfile(tester);
    expect(find.text('Elif Naz'), findsOneWidget);
  });
  testWidgets(
    'Local clear can be cancelled and resets the saved profile after confirmation',
    (tester) async {
      await openProfile(tester);
      await tapLabel(tester, 'Profili düzenle');
      await tester.enterText(find.byType(TextFormField).first, 'Elif');
      await tester.enterText(find.byType(TextFormField).last, 'Naz');
      await tapLabel(tester, 'Değişiklikleri kaydet');
      await tapLabel(tester, 'Ayarlar');
      await tapLabel(tester, 'Bu cihazdaki fotoğraf ve tercihleri sil');
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Elif Naz'), findsOneWidget);
      await tapLabel(tester, 'Ayarlar');
      await tapLabel(tester, 'Bu cihazdaki fotoğraf ve tercihleri sil');
      await tester.tap(find.text('Verileri sil'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await openProfile(tester);
      expect(find.text('Sürücü'), findsOneWidget);
    },
  );
}
