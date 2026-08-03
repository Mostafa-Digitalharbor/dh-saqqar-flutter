import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
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

  // A payment that is neither paid nor failed is the state that most needs
  // explaining and had none. Observed on production 2026-08-03: three
  // attempts pending, one eight days old, token balance zero. The row said
  // "PENDING" and nothing else — a user cannot tell "still processing" from
  // "my money went nowhere".
  group('PaymentRow.isAwaitingConfirmation', () {
    PaymentRow row(Map<String, dynamic> j) => PaymentRow.fromJson(j);

    test('pending is awaiting', () {
      expect(row({'status': 'pending'}).isAwaitingConfirmation, isTrue);
    });

    test('paid and failed are settled', () {
      expect(
        row({'status': 'paid', 'is_paid': true}).isAwaitingConfirmation,
        isFalse,
      );
      expect(
        row({'status': 'failed', 'is_failed': true}).isAwaitingConfirmation,
        isFalse,
      );
    });

    // The trap this guards: `!isPaid && !isFailed` is true for all three of
    // these, and telling someone their refund is "awaiting confirmation from
    // the payment provider" is worse than saying nothing.
    for (final terminal in const ['expired', 'refunded', 'chargeback']) {
      test('$terminal is settled, not awaiting', () {
        expect(row({'status': terminal}).isAwaitingConfirmation, isFalse);
      });
    }

    test('an unknown or missing status counts as awaiting', () {
      // The server hasn't called it settled; "we're still checking" is the
      // honest reading of a state we don't recognise.
      expect(row({'status': 'authorising'}).isAwaitingConfirmation, isTrue);
      expect(row(const {}).isAwaitingConfirmation, isTrue);
    });
  });

  group('billingStatusLabel', () {
    for (final locale in const ['en', 'ar']) {
      test('localizes every documented state in $locale', () {
        final tr = AppStrings(Locale(locale));
        for (final wire in const [
          'pending',
          'paid',
          'failed',
          'expired',
          'refunded',
          'chargeback',
        ]) {
          final label = tr.billingStatusLabel(wire);
          expect(label, isNotEmpty);
          expect(
            label,
            isNot(wire),
            reason: '"$wire" reached the screen untranslated — that is how a '
                'Latin "PENDING" ends up inside an Arabic row',
          );
        }
      });
    }

    test('an unrecognised state is shown raw rather than swallowed', () {
      // Better a status support can look up than a blank chip.
      final tr = AppStrings(const Locale('en'));
      expect(tr.billingStatusLabel('authorising'), 'authorising');
    });

    test('the pending note carries the reference to quote', () {
      final tr = AppStrings(const Locale('en'));
      expect(tr.billingPendingNote('7EA02D5F'), contains('7EA02D5F'));
      final ar = AppStrings(const Locale('ar'));
      expect(ar.billingPendingNote('7EA02D5F'), contains('7EA02D5F'));
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
