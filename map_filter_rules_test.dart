import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parkist/map_filter_rules.dart';

void main() {
  const islands = LatLng(40.8617, 29.1234);

  test('keeps a district on a nearby viewport move', () {
    final nearby = LatLngBounds(
      const LatLng(40.84, 29.10),
      const LatLng(40.89, 29.15),
    );
    expect(hasLeftFilteredDistrictView(nearby, islands), isFalse);
  });

  test('clears the district after the viewport moves far away', () {
    final elsewhere = LatLngBounds(
      const LatLng(41.00, 28.95),
      const LatLng(41.04, 29.00),
    );
    expect(hasLeftFilteredDistrictView(elsewhere, islands), isTrue);
  });
}
