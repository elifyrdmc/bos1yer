import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Simplified Istanbul district outlines used only for visual map highlighting.
class IstanbulDistrictBoundaryStore {
  IstanbulDistrictBoundaryStore._();

  static Future<Map<String, DistrictBoundary>>? _loadFuture;

  static Future<Map<String, DistrictBoundary>> load() =>
      _loadFuture ??= _load();

  static Future<DistrictBoundary?> forName(String name) async =>
      (await load())[name];

  static Future<Map<String, DistrictBoundary>> _load() async {
    final raw = await rootBundle.loadString(
      'assets/map/istanbul_district_boundaries.geojson',
    );
    final collection = jsonDecode(raw) as Map<String, dynamic>;
    final result = <String, DistrictBoundary>{};

    for (final rawFeature in collection['features'] as List<dynamic>) {
      final feature = rawFeature as Map<String, dynamic>;
      final properties = feature['properties'] as Map<String, dynamic>;
      final name = properties['name'] as String?;
      if (name == null) continue;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      final polygons = geometry['type'] == 'Polygon'
          ? <dynamic>[coordinates]
          : coordinates;
      final rings = <List<LatLng>>[];
      for (final polygon in polygons) {
        final outerRing = (polygon as List<dynamic>).first as List<dynamic>;
        final points = outerRing
            .map((rawPoint) {
              final point = rawPoint as List<dynamic>;
              return LatLng(
                (point[1] as num).toDouble(),
                (point[0] as num).toDouble(),
              );
            })
            .toList(growable: false);
        if (points.length >= 4) rings.add(points);
      }
      if (rings.isEmpty) continue;
      final allPoints = rings.expand((ring) => ring).toList(growable: false);
      result[name] = DistrictBoundary(
        rings: rings,
        bounds: LatLngBounds.fromPoints(allPoints),
      );
    }
    return Map.unmodifiable(result);
  }

  /// Chooses a zoom that keeps the district outline inside the usable map area.
  static double zoomToFit(LatLngBounds bounds, Size screenSize) {
    final width = math.max(240.0, screenSize.width - 64);
    final height = math.max(260.0, screenSize.height - 340);
    final longitudeSpan = math.max(0.01, bounds.east - bounds.west) / 360;
    final northY = _mercatorY(bounds.north);
    final southY = _mercatorY(bounds.south);
    final latitudeSpan = math.max(0.00001, (southY - northY).abs());
    final zoomX = math.log(width / (256 * longitudeSpan)) / math.ln2;
    final zoomY = math.log(height / (256 * latitudeSpan)) / math.ln2;
    return (math.min(zoomX, zoomY) - .55).clamp(8.0, 13.5).toDouble();
  }

  static double _mercatorY(double latitude) {
    final clamped = latitude.clamp(-85.0, 85.0) * math.pi / 180;
    return (1 - math.log(math.tan(clamped) + 1 / math.cos(clamped)) / math.pi) /
        2;
  }
}

class DistrictBoundary {
  const DistrictBoundary({required this.rings, required this.bounds});

  /// One exterior outline per polygon; interior holes are intentionally omitted.
  final List<List<LatLng>> rings;
  final LatLngBounds bounds;
}
