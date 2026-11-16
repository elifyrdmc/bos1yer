import 'package:flutter_test/flutter_test.dart';
import 'package:parkist/backend/points_wallet_repository.dart';

void main() {
  group('PointsWallet.fromJson', () {
    test('parses the server balance and transaction history', () {
      final wallet = PointsWallet.fromJson({
        'balance': 30,
        'transactions': [
          {
            'id': 'transaction-1',
            'points_delta': 20,
            'event_type': 'report_parked_author_reward',
            'description': 'Başka bir sürücü bildiriminle park etti',
            'created_at': '2026-11-05T12:30:00Z',
          },
          {
            'id': 'transaction-2',
            'points_delta': 10,
            'event_type': 'parked_confirmation_reward',
            'description': 'Park ettim bildirimi',
            'created_at': '2026-11-05T12:30:00Z',
          },
        ],
      });

      expect(wallet.balance, 30);
      expect(wallet.transactions, hasLength(2));
      expect(wallet.transactions.first.pointsDelta, 20);
      expect(wallet.transactions.last.pointsDelta, 10);
      expect(wallet.transactions.first.createdAt.isUtc, isTrue);
    });

    test('rejects malformed wallet data instead of inventing a balance', () {
      expect(
        () => PointsWallet.fromJson({'balance': '1240', 'transactions': []}),
        throwsFormatException,
      );
      expect(
        () => PointsWallet.fromJson({'balance': 0, 'transactions': 'empty'}),
        throwsFormatException,
      );
      expect(
        () => PointsWallet.fromJson({
          'balance': 2,
          'transactions': [
            {
              'id': 'transaction-1',
              'points_delta': 2.5,
              'event_type': 'parked_confirmation_reward',
              'description': 'Park ettim bildirimi',
              'created_at': '2026-11-05T12:30:00Z',
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('history list cannot be modified by the caller', () {
      final wallet = PointsWallet.fromJson({
        'balance': 0,
        'transactions': <Object?>[],
      });

      expect(
        () => wallet.transactions.add(_sampleTransaction),
        throwsUnsupportedError,
      );
    });
  });
}

final _sampleTransaction = PointsTransaction(
  id: 'transaction-1',
  pointsDelta: 1,
  eventType: 'parked_confirmation_reward',
  description: 'Park ettim bildirimi',
  createdAt: DateTime.utc(2026, 11, 5),
);
