part of '../main.dart';

enum _RewardRedemptionType {
  storeQr,
  onlineCode,
  campaignLink;

  String get label => switch (this) {
    storeQr => 'İşletmede QR',
    onlineCode => 'İnternet sitesi kodu',
    campaignLink => 'Kampanya bağlantısı',
  };

  String get shortLabel => switch (this) {
    storeQr => 'İşletmede QR',
    onlineCode => 'Online kod',
    campaignLink => 'Kampanya linki',
  };

  String get explanation => switch (this) {
    storeQr => 'İşletmede gösterilecek QR kupon türünün demo örneği.',
    onlineCode => 'İnternet sitesinde girilecek indirim kodunun demo örneği.',
    campaignLink => 'Kampanya sayfasına yönlendirme türünün demo örneği.',
  };

  static _RewardRedemptionType fromJson(Object? value) =>
      _RewardRedemptionType.values.firstWhere(
        (item) => item.name == value,
        orElse: () => _RewardRedemptionType.storeQr,
      );
}

class _DemoCoupon {
  const _DemoCoupon({
    required this.id,
    required this.offerId,
    required this.title,
    required this.summary,
    required this.points,
    required this.code,
    required this.partnerName,
    required this.redemptionType,
    required this.createdAt,
    required this.expiresAt,
    required this.termsSnapshot,
    required this.status,
  });

  final String id;
  final String offerId;
  final String title;
  final String summary;
  final int points;
  final String code;
  final String partnerName;
  final _RewardRedemptionType redemptionType;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final Map<String, dynamic> termsSnapshot;
  final String status;

  String get effectiveStatus {
    if (status == 'used') return 'used';
    if (status == 'expired' ||
        (expiresAt != null && !expiresAt!.isAfter(DateTime.now()))) {
      return 'expired';
    }
    return 'active';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'offer_id': offerId,
    'title': title,
    'summary': summary,
    'points': points,
    'code': code,
    'partner_name': partnerName,
    'redemption_type': redemptionType.name,
    'created_at': createdAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'terms_snapshot': termsSnapshot,
    'coupon_status': status,
  };

  factory _DemoCoupon.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value! as Map);
    return _DemoCoupon(
      id: json['id'] as String,
      offerId: json['offer_id'] as String? ?? '',
      title: json['title'] as String,
      summary: json['summary'] as String? ?? '',
      points: json['points'] as int,
      code: json['code'] as String,
      partnerName: json['partner_name'] as String? ?? 'Örnek işletme',
      redemptionType: _RewardRedemptionType.fromJson(json['redemption_type']),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      termsSnapshot: Map<String, dynamic>.from(
        json['terms_snapshot'] as Map? ??
            const <String, dynamic>{'legacy_terms': true},
      ),
      status: json['coupon_status'] as String? ?? 'active',
    );
  }
}

class _DemoMovement {
  const _DemoMovement({
    required this.id,
    required this.description,
    required this.pointsDelta,
    required this.createdAt,
  });

  final String id;
  final String description;
  final int pointsDelta;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'description': description,
    'points_delta': pointsDelta,
    'created_at': createdAt.toIso8601String(),
  };

  factory _DemoMovement.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value! as Map);
    return _DemoMovement(
      id: json['id'] as String,
      description: json['description'] as String,
      pointsDelta: json['points_delta'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class _DemoRewardsState {
  const _DemoRewardsState({
    required this.balanceAdjustment,
    required this.coupons,
    required this.movements,
  });

  final int balanceAdjustment;
  final List<_DemoCoupon> coupons;
  final List<_DemoMovement> movements;
}

/// Device-only fallback state used when Supabase is not configured.
/// Configured accounts read coupon and point records from server repositories.
class _DemoRewardsStore {
  _DemoRewardsStore(String accountId)
    : _balanceKey = 'rewards_test_adjustment_v2_$accountId',
      _couponsKey = 'example_rewards_coupons_$accountId',
      _movementsKey = 'rewards_test_movements_v2_$accountId';

  final String _balanceKey;
  final String _couponsKey;
  final String _movementsKey;
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<_DemoRewardsState> load() async {
    final balanceAdjustment = await _preferences.getInt(_balanceKey) ?? 0;
    final encodedCoupons = await _preferences.getString(_couponsKey);
    final encodedMovements = await _preferences.getString(_movementsKey);
    final coupons = encodedCoupons == null
        ? <_DemoCoupon>[]
        : (jsonDecode(encodedCoupons) as List<dynamic>)
              .map(_DemoCoupon.fromJson)
              .toList();
    final movements = encodedMovements == null
        ? <_DemoMovement>[]
        : (jsonDecode(encodedMovements) as List<dynamic>)
              .map(_DemoMovement.fromJson)
              .toList();
    return _DemoRewardsState(
      balanceAdjustment: balanceAdjustment,
      coupons: List.unmodifiable(coupons),
      movements: List.unmodifiable(movements),
    );
  }

  Future<_DemoRewardsState> redeem(
    _DemoRewardsState current,
    _RewardOffer offer, {
    required int availableBalance,
  }) async {
    if (availableBalance < offer.examplePoints) {
      throw StateError('Bu ödül için yeterli puanın yok.');
    }
    final coupon = _DemoCoupon(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      offerId: offer.id,
      title: offer.title,
      summary: offer.summary,
      points: offer.examplePoints,
      code: switch (offer.redemptionType) {
        _RewardRedemptionType.storeQr =>
          'QR-DEMO-${DateTime.now().millisecondsSinceEpoch % 100000}',
        _RewardRedemptionType.onlineCode => 'DEMO10',
        _RewardRedemptionType.campaignLink => 'example.com/kampanya-demo',
      },
      partnerName: offer.partnerName,
      redemptionType: offer.redemptionType,
      createdAt: DateTime.now(),
      expiresAt: offer.validityIsUnlimited
          ? null
          : offer.validityDays != null
          ? DateTime.now().add(Duration(days: offer.validityDays!))
          : _addCalendarMonths(DateTime.now(), offer.validityMonths!),
      termsSnapshot: offer.termsSnapshot,
      status: 'active',
    );
    final movement = _DemoMovement(
      id: coupon.id,
      description: 'Test kuponu · ${offer.title}',
      pointsDelta: -offer.examplePoints,
      createdAt: coupon.createdAt,
    );
    final next = _DemoRewardsState(
      balanceAdjustment: current.balanceAdjustment - offer.examplePoints,
      coupons: List.unmodifiable([coupon, ...current.coupons]),
      movements: List.unmodifiable([movement, ...current.movements]),
    );
    await _preferences.setInt(_balanceKey, next.balanceAdjustment);
    await _preferences.setString(
      _couponsKey,
      jsonEncode(next.coupons.map((item) => item.toJson()).toList()),
    );
    await _preferences.setString(
      _movementsKey,
      jsonEncode(next.movements.map((item) => item.toJson()).toList()),
    );
    return next;
  }
}

class _RewardOffer {
  const _RewardOffer({
    required this.id,
    required this.partnerName,
    required this.title,
    required this.summary,
    required this.redemptionType,
    required this.icon,
    required this.color,
    required this.examplePoints,
    required this.isDemo,
    required this.validityMonths,
    required this.validityDays,
    required this.validityIsUnlimited,
    required this.usageKind,
    required this.usageLimit,
    required this.usageLimitIsUnlimited,
    required this.allowRepeatPurchase,
    required this.agreementIsOpenEnded,
    required this.agreementEndsAt,
    required this.branchScope,
    required this.validBranches,
    required this.instructions,
  });

  factory _RewardOffer.fromRecord(RewardOfferRecord record) {
    final type = switch (record.redemptionType) {
      'store_qr' => _RewardRedemptionType.storeQr,
      'online_code' => _RewardRedemptionType.onlineCode,
      'campaign_link' => _RewardRedemptionType.campaignLink,
      _ => throw FormatException(
        'Bilinmeyen kupon türü: ${record.redemptionType}',
      ),
    };
    final icon = switch (type) {
      _RewardRedemptionType.storeQr => Icons.qr_code_2_rounded,
      _RewardRedemptionType.onlineCode => Icons.shopping_bag_outlined,
      _RewardRedemptionType.campaignLink => Icons.open_in_new_rounded,
    };
    final color = switch (type) {
      _RewardRedemptionType.storeQr => ParkIstPalette.oceanTeal,
      _RewardRedemptionType.onlineCode => const Color(0xFF5967A8),
      _RewardRedemptionType.campaignLink => const Color(0xFF9B5278),
    };
    return _RewardOffer(
      id: record.id,
      partnerName: record.partnerName,
      title: record.title,
      summary: record.summary,
      redemptionType: type,
      icon: icon,
      color: color,
      examplePoints: record.pointsCost,
      isDemo: record.isDemo,
      validityMonths: record.validityMonths,
      validityDays: record.validityDays,
      validityIsUnlimited: record.validityIsUnlimited,
      usageKind: record.usageKind,
      usageLimit: record.usageLimit,
      usageLimitIsUnlimited: record.usageLimitIsUnlimited,
      allowRepeatPurchase: record.allowRepeatPurchase,
      agreementIsOpenEnded: record.agreementIsOpenEnded,
      agreementEndsAt: record.agreementEndsAt,
      branchScope: record.branchScope,
      validBranches: record.validBranches,
      instructions: record.instructions,
    );
  }

  final String id;
  final String partnerName;
  final String title;
  final String summary;
  final _RewardRedemptionType redemptionType;
  final IconData icon;
  final Color color;
  final int examplePoints;
  final bool isDemo;
  final int? validityMonths;
  final int? validityDays;
  final bool validityIsUnlimited;
  final String usageKind;
  final int? usageLimit;
  final bool usageLimitIsUnlimited;
  final bool allowRepeatPurchase;
  final bool agreementIsOpenEnded;
  final DateTime? agreementEndsAt;
  final String branchScope;
  final List<String> validBranches;
  final String instructions;

  Map<String, Object?> get termsSnapshot => {
    'legacy_terms': false,
    'redemption_type': switch (redemptionType) {
      _RewardRedemptionType.storeQr => 'store_qr',
      _RewardRedemptionType.onlineCode => 'online_code',
      _RewardRedemptionType.campaignLink => 'campaign_link',
    },
    'validity_is_unlimited': validityIsUnlimited,
    'validity_months': validityMonths,
    'validity_days': validityDays,
    'usage_kind': usageKind,
    'usage_limit': usageLimit,
    'usage_limit_is_unlimited': usageLimitIsUnlimited,
    'allow_repeat_purchase': allowRepeatPurchase,
    'agreement_is_open_ended': agreementIsOpenEnded,
    'agreement_ends_at': agreementEndsAt?.toIso8601String(),
    'branch_scope': branchScope,
    'valid_branches': validBranches,
    'instructions': instructions,
    'is_demo': isDemo,
  };
}

DateTime _addCalendarMonths(DateTime value, int months) {
  final targetMonth = value.month + months;
  final lastDay = DateTime(value.year, targetMonth + 1, 0).day;
  return DateTime(
    value.year,
    targetMonth,
    value.day > lastDay ? lastDay : value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

String _formatLocalDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatMediumDate(local);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$date · $time';
}
