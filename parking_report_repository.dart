import 'dart:io';
import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ParkingReportKind { vacancy, leaving }

enum LeavingReportPresence { atLocation, nearby }

/// A safe, short-lived map projection of a parking report.
class ParkingReportRecord {
  const ParkingReportRecord({
    required this.id,
    required this.kind,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.ageAtFetch,
    this.note,
    this.photoObjectPath,
    this.estimatedDepartureMinutes,
    this.leavingPresence,
    this.photoAgeAtFetch,
    this.canUploadPhoto = false,
    this.isAuthor = false,
    this.signedPhotoUrl,
    this.district,
    this.authorTrustScore,
    this.authorTrustOutcomeCount,
  });

  final String id;
  final ParkingReportKind kind;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final Duration ageAtFetch;
  final String? note;
  final String? photoObjectPath;
  final int? estimatedDepartureMinutes;
  final LeavingReportPresence? leavingPresence;
  final Duration? photoAgeAtFetch;
  final bool canUploadPhoto;
  final bool isAuthor;
  final String? signedPhotoUrl;
  final String? district;
  final double? authorTrustScore;
  final int? authorTrustOutcomeCount;

  Duration get visibleLifetime => ParkingReportRepository.lifetimeFor(
    kind,
    estimatedDepartureMinutes,
    awaitsPhoto: awaitsLeavingPhoto,
  );

  bool get awaitsLeavingPhoto =>
      kind == ParkingReportKind.leaving &&
      leavingPresence == LeavingReportPresence.nearby &&
      photoObjectPath == null;

  factory ParkingReportRecord.fromJson(Map<String, dynamic> json) {
    final kind = switch (json['kind']) {
      'vacancy' => ParkingReportKind.vacancy,
      'leaving' => ParkingReportKind.leaving,
      _ => throw const FormatException('Unknown parking report kind.'),
    };
    final createdAtValue = json['created_at'];
    final ageSecondsValue = json['age_seconds'];
    if (createdAtValue is! String || ageSecondsValue is! num) {
      throw const FormatException('Incomplete parking report row.');
    }

    final ageSeconds = ageSecondsValue.toInt();
    if (ageSeconds < 0) {
      throw const FormatException('Parking report age cannot be negative.');
    }
    final latitude = _requiredNumber(json, 'latitude');
    final longitude = _requiredNumber(json, 'longitude');
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Parking report coordinates are invalid.');
    }
    final note = json['note'];
    final photoPath = json['photo_object_path'];
    final estimate = json['estimated_departure_minutes'];
    final photoAge = json['photo_age_seconds'];
    final canUploadPhoto = json['can_upload_photo'];
    final district = json['district'];
    final authorTrustScore = json['author_trust_score'];
    final authorTrustOutcomeCount = json['author_trust_outcome_count'];
    final presence = switch (json['leaving_presence']) {
      null => null,
      'at_location' => LeavingReportPresence.atLocation,
      'nearby' => LeavingReportPresence.nearby,
      _ => throw const FormatException('Unknown leaving report presence.'),
    };
    if (note != null && note is! String) {
      throw const FormatException('Parking report note is invalid.');
    }
    if (photoPath != null && photoPath is! String) {
      throw const FormatException('Parking report photo path is invalid.');
    }
    if (estimate != null && estimate is! num) {
      throw const FormatException('Parking report estimate is invalid.');
    }
    if (photoAge != null && (photoAge is! num || photoAge < 0)) {
      throw const FormatException('Parking report photo age is invalid.');
    }
    if (canUploadPhoto != null && canUploadPhoto is! bool) {
      throw const FormatException(
        'Parking report photo permission is invalid.',
      );
    }
    if (district != null && district is! String) {
      throw const FormatException('Parking report district is invalid.');
    }
    if (authorTrustScore != null &&
        (authorTrustScore is! num || !authorTrustScore.toDouble().isFinite)) {
      throw const FormatException('Parking report trust score is invalid.');
    }
    if (authorTrustOutcomeCount != null &&
        (authorTrustOutcomeCount is! num ||
            authorTrustOutcomeCount.toInt() < 0)) {
      throw const FormatException(
        'Parking report trust outcome count is invalid.',
      );
    }

    return ParkingReportRecord(
      id: _requiredString(json, 'id'),
      kind: kind,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.parse(createdAtValue).toUtc(),
      ageAtFetch: Duration(seconds: ageSeconds),
      note: note as String?,
      photoObjectPath: photoPath as String?,
      estimatedDepartureMinutes: (estimate as num?)?.toInt(),
      leavingPresence: presence,
      photoAgeAtFetch: photoAge == null
          ? null
          : Duration(seconds: photoAge.toInt()),
      canUploadPhoto: canUploadPhoto as bool? ?? false,
      // The current safe map RPC exposes author ownership through this flag.
      isAuthor: canUploadPhoto ?? false,
      district: district as String?,
      authorTrustScore: (authorTrustScore as num?)?.toDouble(),
      authorTrustOutcomeCount: (authorTrustOutcomeCount as num?)?.toInt(),
    );
  }

  ParkingReportRecord withSignedPhotoUrl(String? url) => ParkingReportRecord(
    id: id,
    kind: kind,
    latitude: latitude,
    longitude: longitude,
    createdAt: createdAt,
    ageAtFetch: ageAtFetch,
    note: note,
    photoObjectPath: photoObjectPath,
    estimatedDepartureMinutes: estimatedDepartureMinutes,
    leavingPresence: leavingPresence,
    photoAgeAtFetch: photoAgeAtFetch,
    canUploadPhoto: canUploadPhoto,
    isAuthor: isAuthor,
    signedPhotoUrl: url,
    district: district,
    authorTrustScore: authorTrustScore,
    authorTrustOutcomeCount: authorTrustOutcomeCount,
  );

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Parking report field "$key" is missing.');
    }
    return value;
  }

  static double _requiredNumber(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num || !value.toDouble().isFinite) {
      throw FormatException('Parking report field "$key" is invalid.');
    }
    return value.toDouble();
  }
}

/// Writes authenticated reports and reads the safe active map projection.
/// Photos stay in a private bucket and are exposed through short-lived URLs.
class ParkingReportRepository {
  ParkingReportRepository(this._client);

  static const photoBucket = 'parking-report-photos';
  static const reportLifetime = Duration(minutes: 10);
  static const maxPhotoBytes = 8 * 1024 * 1024;

  static Duration lifetimeFor(
    ParkingReportKind kind,
    int? estimatedDepartureMinutes, {
    bool awaitsPhoto = false,
  }) => awaitsPhoto
      ? Duration(minutes: estimatedDepartureMinutes ?? 0)
      : reportLifetime +
            (kind == ParkingReportKind.leaving
                ? Duration(minutes: estimatedDepartureMinutes ?? 0)
                : Duration.zero);

  final SupabaseClient _client;

  Future<void> cancelReport(String reportId) async {
    if (_client.auth.currentUser == null) {
      throw StateError('Bildirimi iptal etmek için giriş yapmalısın.');
    }
    await _client.rpc(
      'cancel_my_parking_report',
      params: {'p_report_id': reportId},
    );
  }

  Future<ParkingReportRecord> createReport({
    required ParkingReportKind kind,
    required LatLng location,
    LatLng? deviceLocation,
    required File? photo,
    String? note,
    int? estimatedDepartureMinutes,
    LeavingReportPresence? leavingPresence,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Giriş yapmadan bildirim gönderilemez.');
    }
    if (kind == ParkingReportKind.leaving &&
        estimatedDepartureMinutes != 5 &&
        estimatedDepartureMinutes != 10) {
      throw ArgumentError.value(
        estimatedDepartureMinutes,
        'estimatedDepartureMinutes',
      );
    }
    if (kind == ParkingReportKind.vacancy &&
        estimatedDepartureMinutes != null) {
      throw ArgumentError.value(
        estimatedDepartureMinutes,
        'estimatedDepartureMinutes',
      );
    }
    if (kind == ParkingReportKind.leaving && leavingPresence == null) {
      throw ArgumentError.value(leavingPresence, 'leavingPresence');
    }
    if (kind == ParkingReportKind.leaving &&
        leavingPresence == LeavingReportPresence.atLocation &&
        photo == null) {
      throw ArgumentError('A photo is required when at the parking location.');
    }
    if (kind == ParkingReportKind.vacancy &&
        (photo == null || leavingPresence != null)) {
      throw ArgumentError(
        'Vacancy reports require a photo and no presence mode.',
      );
    }

    final storage = _client.storage.from(photoBucket);
    final objectPath = photo == null ? null : '${user.id}/${_newUuidV4()}.jpg';
    if (photo != null && objectPath != null) {
      await _uploadPhoto(storage, objectPath, photo);
    }

    try {
      final response = await _client.rpc(
        'create_parking_report',
        params: {
          'p_kind': kind == ParkingReportKind.vacancy ? 'vacancy' : 'leaving',
          'p_latitude': location.latitude,
          'p_longitude': location.longitude,
          'p_device_latitude': (deviceLocation ?? location).latitude,
          'p_device_longitude': (deviceLocation ?? location).longitude,
          'p_note': note,
          'p_photo_object_path': objectPath,
          'p_estimated_departure_minutes': estimatedDepartureMinutes,
          'p_leaving_presence': switch (leavingPresence) {
            null => null,
            LeavingReportPresence.atLocation => 'at_location',
            LeavingReportPresence.nearby => 'nearby',
          },
        },
      );
      if (response is! List || response.isEmpty || response.first is! Map) {
        throw const FormatException('Unexpected create report response.');
      }
      final record = ParkingReportRecord.fromJson(
        Map<String, dynamic>.from(response.first as Map),
      );
      return await _attachSignedPhoto(record);
    } catch (_) {
      try {
        if (objectPath != null) await storage.remove([objectPath]);
      } catch (_) {
        // Preserve the database error; an orphan can be cleaned up later.
      }
      rethrow;
    }
  }

  Future<ParkingReportRecord> addLeavingPhoto({
    required String reportId,
    required File photo,
    required LatLng location,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Giriş yapmadan fotoğraf yüklenemez.');
    final objectPath = '${user.id}/${_newUuidV4()}.jpg';
    final storage = _client.storage.from(photoBucket);
    await _uploadPhoto(storage, objectPath, photo);
    try {
      final response = await _client.rpc(
        'attach_leaving_report_photo',
        params: {
          'p_report_id': reportId,
          'p_photo_object_path': objectPath,
          'p_latitude': location.latitude,
          'p_longitude': location.longitude,
        },
      );
      if (response is! List || response.isEmpty || response.first is! Map) {
        throw const FormatException('Unexpected photo upload response.');
      }
      final record = ParkingReportRecord.fromJson(
        Map<String, dynamic>.from(response.first as Map),
      );
      return await _attachSignedPhoto(record);
    } catch (_) {
      try {
        await storage.remove([objectPath]);
      } catch (_) {
        // Preserve the database error; an orphan can be cleaned up later.
      }
      rethrow;
    }
  }

  Future<void> _uploadPhoto(
    StorageFileApi storage,
    String objectPath,
    File photo,
  ) async {
    final bytes = await photo.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxPhotoBytes) {
      throw const FormatException('Fotoğraf boş veya 8 MB sınırını aşıyor.');
    }
    await storage.uploadBinary(
      objectPath,
      bytes,
      fileOptions: const FileOptions(
        cacheControl: '600',
        contentType: 'image/jpeg',
        upsert: false,
      ),
    );
  }

  Future<List<ParkingReportRecord>> fetchActiveReports() async {
    final response = await _client.rpc('get_active_parking_reports');
    if (response is! List) {
      throw const FormatException('Unexpected parking reports response.');
    }

    final records = response
        .map((row) {
          if (row is! Map) {
            throw const FormatException('Invalid parking report row.');
          }
          return ParkingReportRecord.fromJson(Map<String, dynamic>.from(row));
        })
        .toList(growable: false);
    return Future.wait(records.map(_attachSignedPhoto));
  }

  Future<ParkingReportRecord> _attachSignedPhoto(
    ParkingReportRecord record,
  ) async {
    final path = record.photoObjectPath;
    if (path == null || path.isEmpty) return record;
    final seconds =
        record.visibleLifetime.inSeconds - record.ageAtFetch.inSeconds;
    if (seconds <= 0) return record;
    try {
      final signedUrl = await _client.storage
          .from(photoBucket)
          .createSignedUrl(path, seconds);
      return record.withSignedPhotoUrl(signedUrl);
    } catch (_) {
      return record;
    }
  }

  static String _newUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
