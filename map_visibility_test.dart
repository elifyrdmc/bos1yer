import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'test_home_app.dart';

void main() {
  testWidgets('active report list shows concise labels and timing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHomeScreen(tester);

    await tester.tap(find.text('Listeyi aç'));
    await tester.pumpAndSettle();
    expect(find.text('Boş yer bildirimi'), findsWidgets);
    expect(find.text('Örnek bildirim'), findsWidgets);
    expect(find.textContaining('Topluluk bildirimi'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('map pins remain visible at the overview zoom', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHomeScreen(tester);

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final controller = map.mapController!;
    expect(controller.camera.zoom, 12);
    expect(find.byType(MarkerLayer), findsWidgets);
    expect(find.text('Yakınlaşınca örnek işaretler görünür'), findsNothing);

    controller.move(const LatLng(41.0082, 28.9784), 13);
    await tester.pump();
    final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(layer.markers, hasLength(6));
    expect(find.byTooltip('Örnek bildirim: 1 dk'), findsNWidgets(2));
    expect(find.byTooltip('Örnek bildirim: 3 dk'), findsOneWidget);
    expect(find.byTooltip('3 kayıtlı bilgi noktası'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('filters apply to vacancy and leaving markers', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHomeScreen(tester);
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    controller.move(const LatLng(41.0082, 28.9784), 13);
    await tester.pump();

    await tester.tap(find.byTooltip('Harita katmanları ve filtreler'));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
    await tester.tap(find.text('Çıkıyorum'));
    await tester.tap(find.text('Sonuçları göster'));
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsNothing);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(5),
    );

    await tester.tap(find.byTooltip('Harita katmanları ve filtreler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boş yer bildirimi'));
    await tester.tap(find.text('Sonuçları göster'));
    await tester.pumpAndSettle();
    expect(find.byType(MarkerLayer), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('map controls stay separated on a narrow phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHomeScreen(tester);

    expect(tester.takeException(), isNull);
    final controls = [
      find.byTooltip('Konumuma git'),
      find.byTooltip('Harita katmanları ve filtreler'),
      find.bySemanticsLabel('Bildirim ekle'),
    ];
    for (var i = 0; i < controls.length; i++) {
      for (var j = i + 1; j < controls.length; j++) {
        expect(
          tester.getRect(controls[i]).overlaps(tester.getRect(controls[j])),
          isFalse,
        );
      }
    }

    await tester.tap(find.bySemanticsLabel('Bildirim ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Boş yer gördüm'), findsOneWidget);
    expect(find.text('Çıkıyorum'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
