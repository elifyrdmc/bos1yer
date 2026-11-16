import 'package:flutter_test/flutter_test.dart';
import 'package:parkist/backend/parking_report_lifecycle.dart';

void main() {
  final created = DateTime.utc(2026, 11, 1, 12);

  test('fresh, aging and expired bands include the exact boundaries', () {
    final cases = <Duration, ParkingReportFreshness>{
      Duration.zero: ParkingReportFreshness.fresh,
      const Duration(minutes: 5) - const Duration(microseconds: 1):
          ParkingReportFreshness.fresh,
      const Duration(minutes: 5): ParkingReportFreshness.aging,
      const Duration(minutes: 10) - const Duration(microseconds: 1):
          ParkingReportFreshness.aging,
      const Duration(minutes: 10): ParkingReportFreshness.expired,
      const Duration(days: 1): ParkingReportFreshness.expired,
    };
    for (final entry in cases.entries) {
      expect(
        ParkingReportLifecycle.at(
          createdAt: created,
          serverNow: created.add(entry.key),
        ),
        entry.value,
        reason: 'Age: ${entry.key}',
      );
    }
  });

  test('expiration uses the same instant across timezone offsets', () {
    final withOffset = DateTime.parse('2026-11-01T15:00:00+03:00');
    expect(
      ParkingReportLifecycle.expiresAt(withOffset),
      DateTime.utc(2026, 11, 1, 12, 10),
    );
    expect(
      ParkingReportLifecycle.at(
        createdAt: withOffset,
        serverNow: DateTime.utc(2026, 11, 1, 12, 5),
      ),
      ParkingReportFreshness.aging,
    );
  });

  test('leaving report gets ten more minutes after its departure estimate', () {
    expect(
      ParkingReportLifecycle.expiresAt(created, estimatedDepartureMinutes: 5),
      created.add(const Duration(minutes: 15)),
    );
    expect(
      ParkingReportLifecycle.at(
        createdAt: created,
        serverNow: created.add(const Duration(minutes: 14, seconds: 59)),
        estimatedDepartureMinutes: 5,
      ),
      ParkingReportFreshness.aging,
    );
    expect(
      ParkingReportLifecycle.at(
        createdAt: created,
        serverNow: created.add(const Duration(minutes: 15)),
        estimatedDepartureMinutes: 5,
      ),
      ParkingReportFreshness.expired,
    );
    expect(
      ParkingReportLifecycle.expiresAt(created, estimatedDepartureMinutes: 10),
      created.add(const Duration(minutes: 20)),
    );
  });

  test(
    'future creation time is rejected instead of showing a fresh report',
    () {
      expect(
        () => ParkingReportLifecycle.at(
          createdAt: created,
          serverNow: created.subtract(const Duration(seconds: 1)),
        ),
        throwsArgumentError,
      );
    },
  );
}
