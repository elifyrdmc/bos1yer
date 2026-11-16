import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkist/app_appearance.dart';
import 'package:parkist/design_system.dart';
import 'package:parkist/main.dart';
import 'package:parkist/profile_settings_page.dart';

import 'profile_test_storage.dart';

void main() {
  setupProfileStorage();
  testWidgets('appearance switches the app theme without replacing its route', (
    tester,
  ) async {
    final previous = AppAppearance.mode.value;
    addTearDown(() => AppAppearance.mode.value = previous);
    AppAppearance.mode.value = ThemeMode.light;
    await tester.pumpWidget(const ParkIstApp());
    final scaffold = find.byType(Scaffold).first;
    expect(Theme.of(tester.element(scaffold)).brightness, Brightness.light);
    AppAppearance.mode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    final theme = Theme.of(tester.element(scaffold));
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, ParkDesign.darkPage);
    expect(theme.colorScheme.surface, ParkDesign.darkSurface);
    expect(theme.colorScheme.surface.computeLuminance(), lessThan(.1));
    expect(
      theme.colorScheme.surfaceContainerHigh.computeLuminance(),
      lessThan(.1),
    );
    final contrast =
        (theme.colorScheme.onSurface.computeLuminance() + .05) /
        (theme.colorScheme.surface.computeLuminance() + .05);
    expect(contrast, greaterThan(4.5));
    for (final color in [Colors.green, Colors.blue, Colors.purple]) {
      expect(
        AppearanceColors.fill(
          tester.element(scaffold),
          color,
        ).computeLuminance(),
        lessThan(color.computeLuminance()),
      );
    }
    AppAppearance.mode.value = ThemeMode.light;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(scaffold)).brightness, Brightness.light);
  });

  testWidgets('profile edit link is readable on the dark page', (tester) async {
    final previous = AppAppearance.mode.value;
    addTearDown(() => AppAppearance.mode.value = previous);
    AppAppearance.mode.value = ThemeMode.dark;
    await tester.pumpWidget(const ParkIstApp());
    final context = tester.element(find.byType(Scaffold).first);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: ProfileSettingsPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Profili düzenle'), findsOneWidget);
    final theme = Theme.of(tester.element(find.text('Profili düzenle')));
    final background = theme.scaffoldBackgroundColor;
    final foreground = theme.colorScheme.primary;
    expect(background.computeLuminance(), lessThan(.1));
    expect(
      (foreground.computeLuminance() + .05) /
          (background.computeLuminance() + .05),
      greaterThan(4.5),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
