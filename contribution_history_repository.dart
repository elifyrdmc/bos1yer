import 'package:supabase_flutter/supabase_flutter.dart';

class ParkingReportHistoryEntry {
  const ParkingReportHistoryEntry({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.status,
    required this.parkedCount,
    required this.occupiedCount,
    required this.notFoundCount,
    this.note,
    this.estimatedDepartureMinutes,
    this.photoObjectPath,
    this.photoPathIncluded = true,
  });

  final String id;
  final String kind;
  final DateTime createdAt;
  final String status;
  final int parkedCount;
  final int occupiedCount;
  final int notFoundCount;
  final String? note;
  final int? estimatedDepartureMinutes;
  final String? photoObjectPath;
  final bool photoPathIncluded;

  factory ParkingReportHistoryEntry.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid parking report history entry.');
    }
    final json = Map<String, dynamic>.from(value);
    final id = json['id'];
    final kind = json['kind'];
    final createdAt = json['created_at'];
    final photoObjectPath = json['photo_object_path'];
    final status = json['status'];
    if (id is! String ||
        kind is! String ||
        !{'vacancy', 'leaving'}.contains(kind) ||
        createdAt is! String ||
        (photoObjectPath != null && photoObjectPath is! String) ||
        status is! String) {
      throw const FormatException('Incomplete parking report history entry.');
    }
    return ParkingReportHistoryEntry(
      id: id,
      kind: kind,
      createdAt: DateTime.parse(createdAt).toUtc(),
      status: status,
      note: json['note'] as String?,
      estimatedDepartureMinutes: (json['estimated_departure_minutes'] as num?)
          ?.toInt(),
      photoObjectPath: photoObjectPath as String?,
      photoPathIncluded: json.containsKey('photo_object_path'),
      parkedCount: _integer(json['parked_count']),
      occupiedCount: _integer(json['occupied_count']),
      notFoundCount: _integer(json['not_found_count']),
    );
  }

  static int _integer(Object? value) {
    if (value is! num || value < 0 || value.toInt() != value) {
      throw const FormatException('Invalid feedback count.');
    }
    return value.toInt();
  }
}

class ContributionHistoryRepository {
  ContributionHistoryRepository(this._client);

  final SupabaseClient _client;

  Future<List<ParkingReportHistoryEntry>> fetch({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.rpc(
      'get_my_parking_report_history',
      params: {'p_limit': limit, 'p_offset': offset},
    );
    if (response is! List) {
      throw const FormatException('Invalid parking report history response.');
    }
    return response
        .map(ParkingReportHistoryEntry.fromJson)
        .toList(growable: false);
  }
}
