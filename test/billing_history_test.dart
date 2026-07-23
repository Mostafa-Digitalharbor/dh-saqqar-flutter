import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/billing/data/billing_history_models.dart';

void main() {
  group('PaymentRow.fromJson', () {
    test('parses a paid row with a receipt reference', () {
      final row = PaymentRow.fromJson(const {
        'when': '2026-07-20T10:15:00+00:00',
        'what': 'Pro — monthly',
        'amount': 99.0,
        'currency': 'SAR',
        'tokens': 5000000,
        'tokens_m': 5.0,
        'status': 'paid',
        'is_paid': true,
        'is_failed': false,
        'ref': 'A1B2C3D4',
        'receipt_ref': 'A1B2C3D4E5F6',
      });
      expect(row.what, 'Pro — monthly');
      expect(row.amount, 99.0);
      expect(row.currency, 'SAR');
      expect(row.isPaid, isTrue);
      expect(row.hasReceipt, isTrue);
      expect(row.when, isNotNull);
    });

    test('a non-paid row (or null receipt) exposes no receipt', () {
      final failed = PaymentRow.fromJson(const {
        'what': 'Token recharge',
        'status': 'failed',
        'is_paid': false,
        'is_failed': true,
        'ref': 'ZZ',
        'receipt_ref': null,
      });
      expect(failed.hasReceipt, isFalse);
      expect(failed.isFailed, isTrue);
    });

    test('tolerates a completely empty object', () {
      final row = PaymentRow.fromJson(const {});
      expect(row.amount, 0);
      expect(row.currency, 'SAR');
      expect(row.hasReceipt, isFalse);
      expect(row.when, isNull);
    });
  });

  group('BillingHistory.fromJson', () {
    test('parses rows + balance totals', () {
      final history = BillingHistory.fromJson(const {
        'rows': [
          {'what': 'Pro', 'is_paid': true, 'receipt_ref': 'R1'},
          {'what': 'Recharge', 'is_paid': true, 'receipt_ref': 'R2'},
        ],
        'token_balance': 4200000,
        'total_purchased': 5000000,
        'has_any': true,
      });
      expect(history.rows, hasLength(2));
      expect(history.tokenBalance, 4200000);
      expect(history.totalPurchased, 5000000);
      expect(history.hasAny, isTrue);
    });

    test('an empty account yields no rows', () {
      final history = BillingHistory.fromJson(const {
        'rows': <Map<String, dynamic>>[],
        'has_any': false,
      });
      expect(history.rows, isEmpty);
      expect(history.hasAny, isFalse);
    });
  });
}
