import 'package:supabase_flutter/supabase_flutter.dart';

class RewardOfferRecord {
  const RewardOfferRecord({
    required this.id,
    required this.partnerName,
    required this.title,
    required this.summary,
    required this.redemptionType,
    required this.pointsCost,
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

  final String id;
  final String partnerName;
  final String title;
  final String summary;
  final String redemptionType;
  final int pointsCost;
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

  factory RewardOfferRecord.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid reward offer.');
    }
    final json = Map<String, dynamic>.from(value);
    final id = json['id'];
    final partnerName = json['partner_name'];
    final title = json['title'];
    final summary = json['summary'];
    final redemptionType = json['redemption_type'];
    final pointsCost = json['points_cost'];
    final isDemo = json['is_demo'];
    final validityMonths = json['validity_months'];
    final validityDays = json['validity_days'];
    final validityIsUnlimited = json['validity_is_unlimited'];
    final usageKind = json['usage_kind'];
    final usageLimit = json['usage_limit'];
    final usageLimitIsUnlimited = json['usage_limit_is_unlimited'];
    final allowRepeatPurchase = json['allow_repeat_purchase'];
    final agreementIsOpenEnded = json['agreement_is_open_ended'];
    final agreementEndsAt = json['agreement_ends_at'];
    final branchScope = json['branch_scope'];
    final validBranches = json['valid_branches'];
    final instructions = json['instructions'];
    if (id is! String ||
        partnerName is! String ||
        title is! String ||
        summary is! String ||
        redemptionType is! String ||
        pointsCost is! num ||
        pointsCost.toInt() != pointsCost ||
        isDemo is! bool ||
        (validityMonths != null &&
            (validityMonths is! num ||
                validityMonths.toInt() != validityMonths)) ||
        (validityDays != null &&
            (validityDays is! num || validityDays.toInt() != validityDays)) ||
        validityIsUnlimited is! bool ||
        usageKind is! String ||
        (usageLimit != null &&
            (usageLimit is! num || usageLimit.toInt() != usageLimit)) ||
        usageLimitIsUnlimited is! bool ||
        allowRepeatPurchase is! bool ||
        agreementIsOpenEnded is! bool ||
        (agreementEndsAt != null && agreementEndsAt is! String) ||
        branchScope is! String ||
        validBranches is! List ||
        validBranches.any((item) => item is! String) ||
        instructions is! String) {
      throw const FormatException('Incomplete reward offer.');
    }
    return RewardOfferRecord(
      id: id,
      partnerName: partnerName,
      title: title,
      summary: summary,
      redemptionType: redemptionType,
      pointsCost: pointsCost.toInt(),
      isDemo: isDemo,
      validityMonths: validityMonths == null
          ? null
          : (validityMonths as num).toInt(),
      validityDays: validityDays == null ? null : (validityDays as num).toInt(),
      validityIsUnlimited: validityIsUnlimited,
      usageKind: usageKind,
      usageLimit: usageLimit == null ? null : (usageLimit as num).toInt(),
      usageLimitIsUnlimited: usageLimitIsUnlimited,
      allowRepeatPurchase: allowRepeatPurchase,
      agreementIsOpenEnded: agreementIsOpenEnded,
      agreementEndsAt: agreementEndsAt == null
          ? null
          : DateTime.parse(agreementEndsAt as String),
      branchScope: branchScope,
      validBranches: List.unmodifiable(validBranches.cast<String>()),
      instructions: instructions,
    );
  }
}

class RewardsCatalogRepository {
  RewardsCatalogRepository(this._client);

  final SupabaseClient _client;

  Future<List<RewardOfferRecord>> fetchActiveOffers() async {
    final response = await _client
        .from('reward_offers')
        .select(
          'id, partner_name, title, summary, redemption_type, points_cost, is_demo, validity_months, validity_days, validity_is_unlimited, usage_kind, usage_limit, usage_limit_is_unlimited, allow_repeat_purchase, agreement_is_open_ended, agreement_ends_at, branch_scope, valid_branches, instructions',
        )
        .eq('is_active', true)
        .order('sort_order');
    final now = DateTime.now();
    return List<RewardOfferRecord>.unmodifiable(
      response
          .map(RewardOfferRecord.fromJson)
          .where(
            (offer) =>
                offer.agreementIsOpenEnded ||
                (offer.agreementEndsAt?.isAfter(now) ?? false),
          ),
    );
  }
}
