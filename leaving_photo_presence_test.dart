import 'package:flutter_test/flutter_test.dart';
import 'package:parkist/backend/parking_report_repository.dart';

void main() {
  test('nearby photo deadline matches its selected departure estimate', () {
    expect(
      ParkingReportRepository.lifetimeFor(
        ParkingReportKind.leaving,
        5,
        awaitsPhoto: true,
      ),
      const Duration(minutes: 5),
    );
    expect(
      ParkingReportRepository.lifetimeFor(
        ParkingReportKind.leaving,
        10,
        awaitsPhoto: true,
      ),
      const Duration(minutes: 10),
    );
  });

  test('adding a photo does not reset the original 15 or 20 minute expiry', () {
    expect(
      ParkingReportRepository.lifetimeFor(ParkingReportKind.leaving, 5),
      const Duration(minutes: 15),
    );
    expect(
      ParkingReportRepository.lifetimeFor(ParkingReportKind.leaving, 10),
      const Duration(minutes: 20),
    );
  });

  test(
    'record recognizes only nearby leaving reports without a photo as pending',
    () {
      final record = ParkingReportRecord.fromJson({
        'id': 'report-1',
        'kind': 'leaving',
        'latitude': 41.0,
        'longitude': 29.0,
        'created_at': '2026-11-05T12:00:00Z',
        'age_seconds': 60,
        'note': null,
        'photo_object_path': null,
        'estimated_departure_minutes': 5,
        'leaving_presence': 'nearby',
        'photo_age_seconds': null,
        'can_upload_photo': true,
      });

      expect(record.awaitsLeavingPhoto, isTrue);
      expect(record.visibleLifetime, const Duration(minutes: 5));
      expect(record.canUploadPhoto, isTrue);

      final withPhoto = ParkingReportRecord.fromJson({
        'id': 'report-2',
        'kind': 'leaving',
        'latitude': 41.0,
        'longitude': 29.0,
        'created_at': '2026-11-05T12:00:00Z',
        'age_seconds': 60,
        'note': null,
        'photo_object_path': 'user/photo.jpg',
        'estimated_departure_minutes': 10,
        'leaving_presence': 'nearby',
        'photo_age_seconds': 10,
        'can_upload_photo': false,
      });

      expect(withPhoto.awaitsLeavingPhoto, isFalse);
      expect(withPhoto.visibleLifetime, const Duration(minutes: 20));
      expect(withPhoto.photoAgeAtFetch, const Duration(seconds: 10));
    },
  );
}
