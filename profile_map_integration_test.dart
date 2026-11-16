import 'package:flutter/material.dart';

import 'profile_test_storage.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkist/profile_settings_page.dart';
import 'package:parkist/design_system.dart';

import 'test_home_app.dart';

void main() {
  setupProfileStorage();
  testWidgets(
    'Existing map profile entry opens settings and returns to the map',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpHomeScreen(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileSettingsPage), findsOneWidget);
      await tester.tap(find.byTooltip('Ayarlar'));
      await tester.pumpAndSettle();
      expect(find.text('Hesap ve profil bilgileri'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Harita'));
      await tester.pumpAndSettle();
      expect(find.byType(BrandLockup), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
