import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parkist/parking_directions.dart';

const _launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

void main() {
  test('directions URL contains the selected destination', () {
    final uri = parkingDirectionsUrl(const LatLng(41.0055, 28.9769));
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['destination'], '41.0055,28.9769');
    expect(uri.queryParameters['travelmode'], 'driving');
    expect(uri.queryParameters, isNot(contains('origin')));
  });

  testWidgets('opens directions only after the user taps', (tester) async {
    final calls = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_launcherChannel, (call) async {
      calls.add(call);
      return true;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(_launcherChannel, null),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ParkingDirectionsAction(
            point: LatLng(41.0055, 28.9769),
            isDemo: true,
          ),
        ),
      ),
    );
    expect(calls, isEmpty);
    await tester.tap(find.text('Yol tarifi al'));
    await tester.pumpAndSettle();
    expect(find.text('Harita uygulaması seç'), findsOneWidget);
    expect(calls, isEmpty);
    await tester.tap(find.text('Google Haritalar'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    final args = calls.single.arguments as Map;
    expect(
      Uri.parse(args['url'] as String).queryParameters['destination'],
      '41.0055,28.9769',
    );
    expect(args['useWebView'], isFalse);
    expect(args['useSafariVC'], isFalse);
  });
}
