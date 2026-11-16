import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_home_app.dart';

void main() {
  testWidgets('show on map closes detail without opening a blank card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHomeScreen(tester);

    await tester.tap(find.text('Listeyi aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Boş yer bildirimi').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boş yer bildirimi').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Haritada göster'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haritada göster'));
    await tester.pumpAndSettle();

    expect(find.text('Park yeri'), findsNothing);
    expect(find.text('Haritada göster'), findsNothing);
    expect(find.text('Detaylar'), findsOneWidget);
    final highlightedPin = find.byKey(const ValueKey('focused-report-pin'));
    expect(highlightedPin, findsOneWidget);
    final paintedPin = tester.widget<CustomPaint>(highlightedPin);
    expect(
      (paintedPin.painter as dynamic).color,
      Theme.of(tester.element(highlightedPin)).colorScheme.tertiary,
    );
    await tester.pump(const Duration(seconds: 7));
    expect(highlightedPin, findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(highlightedPin, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
