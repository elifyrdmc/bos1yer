/// Approved freshness bands for a temporary parking report.
enum ParkingReportFreshness { fresh, aging, expired }

/// Pure preview of the server's future time calculation.
///
/// Pass server-issued timestamps. This helper does not authorize writes or
/// delete records; the backend must enforce expiration independently.
abstract final class ParkingReportLifecycle {
  static const agingAfter = Duration(minutes: 5);
  static const expiresAfter = Duration(minutes: 10);

  static DateTime expiresAt(
    DateTime createdAt, {
    int? estimatedDepartureMinutes,
  }) => createdAt.toUtc().add(
    expiresAfter + Duration(minutes: estimatedDepartureMinutes ?? 0),
  );

  static ParkingReportFreshness at({
    required DateTime createdAt,
    required DateTime serverNow,
    int? estimatedDepartureMinutes,
  }) {
    final age = serverNow.toUtc().difference(createdAt.toUtc());
    if (age.isNegative) {
      throw ArgumentError('Report creation time cannot be in the future.');
    }
    if (age >=
        expiresAfter + Duration(minutes: estimatedDepartureMinutes ?? 0)) {
      return ParkingReportFreshness.expired;
    }
    if (age >= agingAfter) return ParkingReportFreshness.aging;
    return ParkingReportFreshness.fresh;
  }
}
