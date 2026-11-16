import 'package:supabase_flutter/supabase_flutter.dart';

enum ParkingReportOutcome { parked, occupied, notFound }

class ParkingReportFeedbackSummary {
  const ParkingReportFeedbackSummary({
    required this.parkedCount,
    required this.occupiedCount,
    required this.notFoundCount,
    required this.canSubmit,
    required this.canUpdate,
    required this.feedbackOpen,
    required this.isAuthor,
    required this.isNearby,
    required this.isResolved,
    this.myOutcome,
  });

  final int parkedCount;
  final int occupiedCount;
  final int notFoundCount;
  final bool canSubmit;
  final bool canUpdate;
  final bool feedbackOpen;
  final bool isAuthor;
  final bool isNearby;
  final bool isResolved;
  final ParkingReportOutcome? myOutcome;

  factory ParkingReportFeedbackSummary.fromJson(Map<String, dynamic> json) {
    return ParkingReportFeedbackSummary(
      parkedCount: _count(json['parked_count']),
      occupiedCount: _count(json['occupied_count']),
      notFoundCount: _count(json['not_found_count']),
      canSubmit: _boolean(json['can_submit'], 'can_submit'),
      canUpdate: _boolean(json['can_update'], 'can_update'),
      feedbackOpen: _boolean(json['feedback_open'], 'feedback_open'),
      isAuthor: _boolean(json['is_author'], 'is_author'),
      isNearby: _boolean(json['is_nearby'], 'is_nearby'),
      isResolved: _boolean(json['is_resolved'], 'is_resolved'),
      myOutcome: switch (json['my_outcome']) {
        null => null,
        'parked' => ParkingReportOutcome.parked,
        'occupied' => ParkingReportOutcome.occupied,
        'not_found' => ParkingReportOutcome.notFound,
        _ => throw const FormatException('Unknown feedback outcome.'),
      },
    );
  }

  static int _count(Object? value) {
    if (value is! num || value < 0) {
      throw const FormatException('Invalid feedback count.');
    }
    return value.toInt();
  }

  static bool _boolean(Object? value, String key) {
    if (value is! bool) throw FormatException('Invalid $key value.');
    return value;
  }
}

class ParkingReportFeedbackRepository {
  ParkingReportFeedbackRepository(this._client);

  final SupabaseClient _client;

  Future<ParkingReportFeedbackSummary> fetch(
    String reportId, {
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) async {
    final response = await _client.rpc(
      'get_parking_report_feedback',
      params: {
        'p_report_id': reportId,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_accuracy_meters': accuracyMeters,
      },
    );
    return _parseResponse(response);
  }

  Future<ParkingReportFeedbackSummary> submit({
    required String reportId,
    required ParkingReportOutcome outcome,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) async {
    final response = await _client.rpc(
      'submit_parking_report_feedback',
      params: {
        'p_report_id': reportId,
        'p_outcome': switch (outcome) {
          ParkingReportOutcome.parked => 'parked',
          ParkingReportOutcome.occupied => 'occupied',
          ParkingReportOutcome.notFound => 'not_found',
        },
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_accuracy_meters': accuracyMeters,
      },
    );
    return _parseResponse(response);
  }

  ParkingReportFeedbackSummary _parseResponse(Object? response) {
    if (response is! List || response.isEmpty || response.first is! Map) {
      throw const FormatException('Unexpected feedback response.');
    }
    return ParkingReportFeedbackSummary.fromJson(
      Map<String, dynamic>.from(response.first as Map),
    );
  }
}
