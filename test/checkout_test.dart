import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/billing/data/checkout_models.dart';

void main() {
  group('CheckoutPlan.fromJson', () {
    test('reads id/price/currency, tolerating alternate keys', () {
      final p = CheckoutPlan.fromJson(const {
        'sku': 'tokens-5m',
        'title': 'Token recharge',
        'amount': 99,
        'currency': 'SAR',
      });
      expect(p.id, 'tokens-5m');
      expect(p.name, 'Token recharge');
      expect(p.price, 99.0);
      expect(p.currency, 'SAR');
    });

    test('defaults a missing price to zero rather than throwing', () {
      final p = CheckoutPlan.fromJson(const {'id': 'x', 'name': 'X'});
      expect(p.price, 0);
      expect(p.currency, 'SAR');
    });

    test('reads the LIVE nested schema (slug + cycles.monthly.price_sar)', () {
      // Shape verified live against GET /billing/plans/.
      final p = CheckoutPlan.fromJson(const {
        'slug': 'pro',
        'name': 'Pro',
        'cycles': {
          'monthly': {'price_halalas': 7500, 'price_sar': 75.0, 'tokens': 250000000},
          'annual': {'price_sar': 765.0},
        },
      }, currency: 'SAR');
      expect(p.id, 'pro');
      expect(p.name, 'Pro');
      expect(p.price, 75.0); // monthly SAR, not 0
      expect(p.currency, 'SAR');
    });
  });

  group('CheckoutSession.fromJson', () {
    test('accepts payment_url / reference aliases', () {
      final s = CheckoutSession.fromJson(const {
        'payment_url': 'https://pay.example/abc',
        'reference': 'REF123',
      });
      expect(s.url, 'https://pay.example/abc');
      expect(s.ref, 'REF123');
      expect(s.isValid, isTrue);
    });

    test('is invalid when a url or ref is missing', () {
      expect(CheckoutSession.fromJson(const {'ref': 'R'}).isValid, isFalse);
      expect(CheckoutSession.fromJson(const {}).isValid, isFalse);
    });
  });

  group('PaymentStatus.fromJson', () {
    test('infers isPaid from a "paid" status when the flag is absent', () {
      final s = PaymentStatus.fromJson(const {'status': 'paid'});
      expect(s.isPaid, isTrue);
      expect(s.isFailed, isFalse);
    });

    test('flags failed / declined states', () {
      expect(PaymentStatus.fromJson(const {'status': 'failed'}).isFailed, isTrue);
      expect(
        PaymentStatus.fromJson(const {'status': 'declined'}).isFailed,
        isTrue,
      );
    });

    test('honours an explicit is_paid flag', () {
      final s = PaymentStatus.fromJson(const {'status': 'x', 'is_paid': true});
      expect(s.isPaid, isTrue);
    });
  });
}
