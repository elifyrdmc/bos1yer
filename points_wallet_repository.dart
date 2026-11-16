import 'package:supabase_flutter/supabase_flutter.dart';

class PointsWallet {
  const PointsWallet({required this.balance, required this.transactions});

  final int balance;
  final List<PointsTransaction> transactions;

  factory PointsWallet.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid points wallet response.');
    }
    final json = Map<String, dynamic>.from(value);
    final balance = _integer(json['balance']);
    final rawTransactions = json['transactions'];
    if (rawTransactions is! List) {
      throw const FormatException('Invalid points history.');
    }
    return PointsWallet(
      balance: balance,
      transactions: List<PointsTransaction>.unmodifiable(
        rawTransactions.map(PointsTransaction.fromJson),
      ),
    );
  }

  static int _integer(Object? value) {
    if (value is! num || value.toInt() != value) {
      throw const FormatException('Invalid points value.');
    }
    return value.toInt();
  }
}

class PointsTransaction {
  const PointsTransaction({
    required this.id,
    required this.pointsDelta,
    required this.eventType,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final int pointsDelta;
  final String eventType;
  final String description;
  final DateTime createdAt;

  factory PointsTransaction.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid points transaction.');
    }
    final json = Map<String, dynamic>.from(value);
    final id = json['id'];
    final eventType = json['event_type'];
    final description = json['description'];
    final createdAt = json['created_at'];
    if (id is! String ||
        eventType is! String ||
        description is! String ||
        createdAt is! String) {
      throw const FormatException('Incomplete points transaction.');
    }
    final parsedDate = DateTime.tryParse(createdAt);
    if (parsedDate == null) {
      throw const FormatException('Invalid points transaction date.');
    }
    return PointsTransaction(
      id: id,
      pointsDelta: PointsWallet._integer(json['points_delta']),
      eventType: eventType,
      description: description,
      createdAt: parsedDate,
    );
  }
}

class PointsWalletRepository {
  PointsWalletRepository(this._client);

  final SupabaseClient _client;

  Future<PointsWallet> fetch({int limit = 50}) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 100');
    }
    final response = await _client.rpc(
      'get_my_points_wallet',
      params: {'p_limit': limit},
    );
    return PointsWallet.fromJson(response);
  }
}
