import 'package:supabase_flutter/supabase_flutter.dart';

class RewardRedemptionRecord {
  const RewardRedemptionRecord({
    required this.id,
    required this.offerId,
    required this.title,
    required this.partnerName,
    required this.summary,
    required this.points,
    required this.code,
    required this.redemptionType,
    required this.createdAt,
    required this.expiresAt,
    required this.termsSnapshot,
    required this.status,
  });

  final String id;
  final String offerId;
  final String title;
  final String partnerName;
  final String summary;
  final int points;
  final String code;
  final String redemptionType;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final Map<String, dynamic> termsSnapshot;
  final String status;

  factory RewardRedemptionRecord.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid reward redemption.');
    }
    final json = Map<String, dynamic>.from(value);
    final id = json['id'];
    final offerId = json['offer_id'];
    final title = json['title'];
    final partnerName = json['partner_name'];
    final summary = json['summary'];
    final points = json['points'];
    final code = json['code'];
    final type = json['redemption_type'];
    final createdAt = json['created_at'];
    final expiresAt = json['expires_at'];
    final termsSnapshot = json['terms_snapshot'];
    final status = json['coupon_status'];
    if (id is! String ||
        offerId is! String ||
        title is! String ||
        partnerName is! String ||
        summary is! String ||
        points is! num ||
        points.toInt() != points ||
        code is! String ||
        type is! String ||
        createdAt is! String ||
        (expiresAt != null && expiresAt is! String) ||
        termsSnapshot is! Map ||
        status is! String) {
      throw const FormatException('Incomplete reward redemption.');
    }
    return RewardRedemptionRecord(
      id: id,
      offerId: offerId,
      title: title,
      partnerName: partnerName,
      summary: summary,
      points: points.toInt(),
      code: code,
      redemptionType: type,
      createdAt: DateTime.parse(createdAt),
      expiresAt: expiresAt == null ? null : DateTime.parse(expiresAt as String),
      termsSnapshot: Map<String, dynamic>.from(termsSnapshot),
      status: status,
    );
  }
}

class RewardsRedemptionRepository {
  RewardsRedemptionRepository(this._client);

  final SupabaseClient _client;

  Future<List<RewardRedemptionRecord>> fetchMine() async {
    final response = await _client.rpc('get_my_reward_redemptions');
    if (response is! List) {
      throw const FormatException('Invalid reward redemptions response.');
    }
    return List.unmodifiable(response.map(RewardRedemptionRecord.fromJson));
  }

  Future<RewardRedemptionRecord> redeemDemo(String offerId) async {
    try {
      final response = await _client.rpc(
        'redeem_reward_offer',
        params: {'p_reward_offer_id': offerId},
      );
      return RewardRedemptionRecord.fromJson(response);
    } on PostgrestException catch (error) {
      final message = error.message.trim();
      throw StateError(
        message.isEmpty ? 'Kupon RPC işlemi başarısız oldu.' : message,
      );
    }
  }
}
