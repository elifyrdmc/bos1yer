import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// District coordinates are approximate centers, not administrative borders.
/// Only clear a filter after a deliberate move well away from that center.
bool hasLeftFilteredDistrictView(
  LatLngBounds visibleBounds,
  LatLng districtCenter,
) {
  if (visibleBounds.contains(districtCenter)) return false;
  final meters = const Distance().as(
    LengthUnit.Meter,
    visibleBounds.center,
    districtCenter,
  );
  return meters > 15000;
}
