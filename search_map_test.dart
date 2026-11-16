import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_home_app.dart';

void main() {
  testWidgets(
    'Turkish search text is preserved and selecting a result zooms in',
    (tester) async {
      final fallback = HttpClient();
      final requests = <Uri>[];
      await HttpOverrides.runZoned(() async {
        await pumpHomeScreen(tester);
        await tester.tap(find.byTooltip('Adres veya semt ara'));
        await tester.pumpAndSettle();
        final field = find.byType(TextField).first;
        await tester.enterText(field, 'Ömer, Kadıköy');
        expect(
          tester.widget<TextField>(field).controller!.text,
          'Ömer, Kadıköy',
        );
        await tester.enterText(field, 'Kadıköy');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          requests.single.queryParameters['q'],
          'Kadıköy, Istanbul, Turkey',
        );
        expect(tester.testTextInput.isVisible, isFalse);
        final result = find.text('Kadıköy, İstanbul, Türkiye');
        expect(result, findsOneWidget);
        final controller = tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!;
        expect(controller.camera.zoom, 12);

        await tester.tap(result);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 275));
        expect(controller.camera.zoom, greaterThan(12));
        expect(controller.camera.zoom, lessThan(16));
        await tester.pump(const Duration(milliseconds: 600));
        expect(controller.camera.center.latitude, closeTo(40.9909, 0.00001));
        expect(controller.camera.center.longitude, closeTo(29.0303, 0.00001));
        expect(controller.camera.zoom, closeTo(16, 0.001));
        await tester.pumpWidget(const SizedBox.shrink());
      }, createHttpClient: (_) => _SearchClient(fallback, requests));
    },
  );
}

// Keep map tiles on Flutter's offline test client; only fake address search.
class _SearchClient extends Fake implements HttpClient {
  _SearchClient(this.fallback, this.requests);
  final HttpClient fallback;
  final List<Uri> requests;

  @override
  set connectionTimeout(Duration? value) => fallback.connectionTimeout = value;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    if (url.host != 'nominatim.openstreetmap.org') return fallback.getUrl(url);
    requests.add(url);
    return _SearchRequest();
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      fallback.openUrl(method, url);

  @override
  void close({bool force = false}) {}
}

class _SearchRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _SearchHeaders();

  @override
  Future<HttpClientResponse> close() async => _SearchResponse();
}

class _SearchHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _SearchResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream.value(
        utf8.encode(
          jsonEncode([
            {
              'lat': '40.9909',
              'lon': '29.0303',
              'display_name': 'Kadıköy, İstanbul, Türkiye',
            },
          ]),
        ),
      ).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
