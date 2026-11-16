part of '../main.dart';

enum _DemoPinKind { vacancy, leaving }

extension on _DemoPinKind {
  String get filterLabel => switch (this) {
    _DemoPinKind.vacancy => 'Boş yer bildirimi',
    _DemoPinKind.leaving => 'Çıkıyorum',
  };

  IconData get icon => this == _DemoPinKind.vacancy
      ? Icons.local_parking_outlined
      : Icons.logout_rounded;

  Color color(BuildContext context) => switch (this) {
    _DemoPinKind.vacancy =>
      Theme.of(context).brightness == Brightness.dark
          ? ParkIstPalette.darkAvailable
          : ParkIstPalette.available,
    _DemoPinKind.leaving =>
      Theme.of(context).brightness == Brightness.dark
          ? ParkIstPalette.darkReview
          : ParkIstPalette.unconfirmedLeaving,
  };
}

class _DemoMapPin {
  const _DemoMapPin({
    required this.point,
    required this.label,
    required this.description,
    required this.kind,
    this.vacancyAge = Duration.zero,
    this.estimatedDepartureMinutes,
    this.createdAt,
    this.photoPath,
    this.remotePhotoUrl,
    this.hasPhoto = false,
    this.canUploadPhoto = false,
    this.isOwnReport = false,
    this.leavingPresence,
    this.isLocalDemo = false,
    this.ageAtFetch,
    this.ageClockBase = Duration.zero,
    this.reportId,
    this.isLiveReport = false,
    this.district,
    this.authorTrustScore,
    this.authorTrustOutcomeCount,
  });

  final LatLng point;
  final String label;
  final String description;
  final _DemoPinKind kind;
  final Duration vacancyAge;
  // The leaving pin is an intention with an estimate, never a vacancy promise.
  final int? estimatedDepartureMinutes;
  final DateTime? createdAt;
  final String? photoPath;
  final String? remotePhotoUrl;
  final bool hasPhoto;
  final bool canUploadPhoto;
  final bool isOwnReport;
  final LeavingReportPresence? leavingPresence;
  final bool isLocalDemo;
  final Duration? ageAtFetch;
  final Duration ageClockBase;
  final String? reportId;
  final bool isLiveReport;
  final String? district;
  final double? authorTrustScore;
  final int? authorTrustOutcomeCount;

  Duration reportAge(Duration elapsed) {
    final fetchedAge = ageAtFetch;
    if (fetchedAge != null) {
      final liveElapsed = elapsed - ageClockBase;
      return fetchedAge +
          (liveElapsed.isNegative ? Duration.zero : liveElapsed);
    }
    if (createdAt != null) {
      final age = DateTime.now().difference(createdAt!);
      return age.isNegative ? Duration.zero : age;
    }
    return vacancyAge + elapsed;
  }

  Duration remainingDepartureEstimate(Duration elapsed) {
    final estimate = estimatedDepartureMinutes;
    if (estimate == null) return Duration.zero;
    final minutesLeft = estimate - reportAge(elapsed).inMinutes;
    return Duration(minutes: minutesLeft < 0 ? 0 : minutesLeft);
  }

  Duration get expirationAge => Duration(
    minutes: awaitsLeavingPhoto
        ? estimatedDepartureMinutes ?? 0
        : 10 +
              (kind == _DemoPinKind.leaving
                  ? estimatedDepartureMinutes ?? 0
                  : 0),
  );

  bool get awaitsLeavingPhoto =>
      isLiveReport &&
      kind == _DemoPinKind.leaving &&
      leavingPresence == LeavingReportPresence.nearby &&
      !hasPhoto;

  Duration photoUploadRemaining(Duration elapsed) {
    final age = reportAge(elapsed);
    final remaining = Duration(minutes: estimatedDepartureMinutes ?? 0) - age;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration mapAge(Duration elapsed) {
    return reportAge(elapsed);
  }

  bool isStale(Duration elapsed) {
    if (kind != _DemoPinKind.leaving) {
      return reportAge(elapsed) >= _staleReportAge;
    }
    final estimate = Duration(minutes: estimatedDepartureMinutes ?? 0);
    return reportAge(elapsed) >= estimate + _staleReportAge;
  }

  Color mapColor(BuildContext context, Duration elapsed) {
    if (kind == _DemoPinKind.leaving) {
      final age = reportAge(elapsed);
      final estimate = Duration(minutes: estimatedDepartureMinutes ?? 0);
      if (age >= estimate + _staleReportAge) {
        return ParkIstPalette.staleReport;
      }
      if (age < estimate) return ParkIstPalette.unconfirmedLeaving;
    } else if (isStale(elapsed)) {
      return ParkIstPalette.staleReport;
    }
    return Theme.of(context).brightness == Brightness.dark
        ? ParkIstPalette.darkAvailable
        : ParkIstPalette.available;
  }

  IconData get icon => kind.icon;

  Color color(BuildContext context) => kind.color(context);
}

const _staleReportAge = Duration(minutes: 5);

String? _approximateDistrictForPoint(LatLng point) {
  if (istanbulDistricts.isEmpty) return null;
  IstanbulDistrict? nearest;
  var bestDistance = double.infinity;
  for (final district in istanbulDistricts) {
    final latitudeDelta = point.latitude - district.latitude;
    final longitudeDelta = point.longitude - district.longitude;
    final distance =
        latitudeDelta * latitudeDelta + longitudeDelta * longitudeDelta;
    if (distance < bestDistance) {
      bestDistance = distance;
      nearest = district;
    }
  }
  return nearest?.name;
}

String _publishedAgeLabel(Duration age) => age.inMinutes <= 0
    ? 'Az önce paylaşıldı'
    : '${age.inMinutes} dk önce paylaşıldı';

const _demoMapPins = <_DemoMapPin>[
  _DemoMapPin(
    point: LatLng(41.0055, 28.9769),
    label: 'Boş yer bildirimi',
    description: 'Örnek bildirim; gerçek zamanlı park bilgisi değildir.',
    kind: _DemoPinKind.vacancy,
    vacancyAge: Duration(minutes: 1),
    district: 'Fatih',
  ),
  _DemoMapPin(
    point: LatLng(41.0136, 28.9813),
    label: 'Çıkıyorum',
    description: 'Sürücünün ayrılma bildirimi için örnek.',
    kind: _DemoPinKind.leaving,
    vacancyAge: Duration(minutes: 1),
    estimatedDepartureMinutes: 10,
    district: 'Beyoğlu',
  ),
  _DemoMapPin(
    point: LatLng(41.0027, 28.9845),
    label: 'Boş yer bildirimi',
    description: 'Örnek boş yer bildirimi; gerçek veriye bağlı değildir.',
    kind: _DemoPinKind.vacancy,
    vacancyAge: Duration(minutes: 3),
    district: 'Fatih',
  ),
  _DemoMapPin(
    point: LatLng(41.0098, 28.9685),
    label: 'Boş yer bildirimi',
    description: 'Harita tasarımını denemek için eklenmiş sabit örnek işaret.',
    kind: _DemoPinKind.vacancy,
    district: 'Beyoğlu',
  ),
  _DemoMapPin(
    point: LatLng(41.0162, 28.9705),
    label: 'Boş yer bildirimi',
    description: 'Harita tasarımını denemek için eklenmiş sabit örnek işaret.',
    kind: _DemoPinKind.vacancy,
    district: 'Fatih',
  ),
  _DemoMapPin(
    point: LatLng(41.0071, 28.9808),
    label: 'Boş yer bildirimi',
    description: 'Harita tasarımını denemek için eklenmiş sabit örnek işaret.',
    kind: _DemoPinKind.vacancy,
    district: 'Fatih',
  ),
];
