// Task 1 (MOBILE_TASKS_2026-09.md) — parsing the two fully-specified app-pulse
// payloads (factory, inventory). The other five kinds are documented only by
// their top-level keys and are built from a live payload once captured, per
// the doc's own instruction — nothing to pin here yet.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/data/app_pulse_payloads.dart';
import 'package:saqqar_app/features/chat/data/interactive_card_kind.dart';

void main() {
  group('factory', () {
    const payload = {
      'kind': 'factory',
      'status': 'ok',
      'as_of': '2026-09-05',
      'mo_running': 12,
      'mo_late': 3,
      'mo_done_today': 5,
      'po_late': 2,
      'orders_at_risk': 4,
      'top_risks': [
        {
          'order': 'SO/0042',
          'order_id': 42,
          'customer': 'Al Rajhi Trading',
          'missing_lines': 3,
          'lead_days': 21,
          'worst_product': 'Steel bracket 40mm',
        },
      ],
      'notes': ['بعض بيانات المصنع غير متاحة لأن تطبيق المشتريات غير مثبت.'],
    };

    test('reads the documented shape', () {
      final parsed = FactoryPulsePayload.parse(payload)!;

      expect(parsed.envelope.status, PulseStatus.ok);
      expect(parsed.envelope.asOf, '2026-09-05');
      expect(parsed.moRunning, 12);
      expect(parsed.moLate, 3);
      expect(parsed.moDoneToday, 5);
      expect(parsed.poLate, 2);
      expect(parsed.ordersAtRisk, 4);
      expect(parsed.envelope.notes, hasLength(1));

      final risk = parsed.topRisks.single;
      expect(risk.order, 'SO/0042');
      expect(risk.orderId, 42);
      expect(risk.customer, 'Al Rajhi Trading');
      expect(risk.missingLines, 3);
      expect(risk.leadDays, 21);
      expect(risk.worstProduct, 'Steel bracket 40mm');
    });

    test('null scalars stay null, never default to zero — rule 2', () {
      final parsed = FactoryPulsePayload.parse(const {
        'kind': 'factory',
        'status': 'ok',
        'orders_at_risk': 4,
        // mrp app not installed:
        'mo_running': null,
        'mo_late': null,
        'mo_done_today': null,
        // purchase app not installed:
        'po_late': null,
        'notes': ['تطبيق التصنيع غير مثبت في قاعدة البيانات هذه.'],
      })!;

      expect(parsed.moRunning, isNull);
      expect(parsed.moLate, isNull);
      expect(parsed.moDoneToday, isNull);
      expect(parsed.poLate, isNull);
      expect(parsed.ordersAtRisk, 4);
    });

    test('status: error carries the message, buckets stay empty — rule 3',
        () {
      final parsed = FactoryPulsePayload.parse(const {
        'kind': 'factory',
        'status': 'error',
        'error': 'تعذّر الاتصال بقاعدة بيانات أودو.',
      })!;

      expect(parsed.envelope.status, PulseStatus.error);
      expect(parsed.envelope.error, 'تعذّر الاتصال بقاعدة بيانات أودو.');
      expect(parsed.topRisks, isEmpty);
    });

    test('top_risks caps at what the server sent, order without a customer',
        () {
      final parsed = FactoryPulsePayload.parse(const {
        'kind': 'factory',
        'top_risks': [
          {'order': 'SO/0001'},
        ],
      })!;
      expect(parsed.topRisks.single.order, 'SO/0001');
      expect(parsed.topRisks.single.customer, isEmpty);
    });

    test('the wrong kind does not parse', () {
      expect(
        FactoryPulsePayload.parse(const {'kind': 'inventory'}),
        isNull,
      );
    });
  });

  group('inventory', () {
    const payload = {
      'kind': 'inventory',
      'status': 'ok',
      'as_of': '2026-09-05',
      'sales_days': 90,
      'product_count': 1840,
      'inventory_value': {'available': true, 'total': 984000.0},
      'low_stock': {'available': true, 'count': 12, 'items': <Object?>[]},
      'demand_shortage': {
        'available': true,
        'count': 4,
        'items': <Object?>[],
      },
      'stagnant_stock': {
        'available': true,
        'count': 31,
        'items': <Object?>[],
        'total': 120400.0,
      },
      'overstock': {
        'available': true,
        'count': 8,
        'items': <Object?>[],
        'total': 65000.0,
      },
      'fast_reorder': {'available': true, 'count': 6, 'items': <Object?>[]},
      'missing_data': {'available': true, 'count': 22, 'items': <Object?>[]},
      'notes': ['ملاحظة تشغيلية'],
      'priorities': ['أولوية 1', 'أولوية 2'],
    };

    test('reads the documented shape', () {
      final parsed = InventoryPulsePayload.parse(payload)!;

      expect(parsed.salesDays, 90);
      expect(parsed.productCount, 1840);
      expect(parsed.inventoryValue.total, 984000.0);
      expect(parsed.lowStock.count, 12);
      expect(parsed.stagnantStock.total, 120400.0);
      expect(parsed.priorities, ['أولوية 1', 'أولوية 2']);
    });

    test('available: false is a distinct state from a zero count — rule 1',
        () {
      final parsed = InventoryPulsePayload.parse(const {
        'kind': 'inventory',
        'low_stock': {'available': false},
        'demand_shortage': {'available': true, 'count': 0},
      })!;

      expect(parsed.lowStock.available, isFalse);
      expect(
        parsed.lowStock.count,
        isNull,
        reason: 'an unavailable bucket carries no count to accidentally '
            'render as zero',
      );
      expect(
        parsed.demandShortage.available,
        isTrue,
        reason: 'a GENUINE zero must still read as available',
      );
      expect(parsed.demandShortage.count, 0);
    });

    test('a bucket missing entirely defaults to unavailable, not a crash',
        () {
      final parsed = InventoryPulsePayload.parse(const {'kind': 'inventory'})!;
      expect(parsed.lowStock.available, isFalse);
      expect(parsed.inventoryValue.available, isFalse);
    });

    test('notes and priorities are kept apart', () {
      final parsed = InventoryPulsePayload.parse(const {
        'kind': 'inventory',
        'notes': ['note A'],
        'priorities': ['priority A'],
      })!;
      expect(parsed.envelope.notes, ['note A']);
      expect(parsed.priorities, ['priority A']);
    });

    test('the wrong kind does not parse', () {
      expect(InventoryPulsePayload.parse(const {'kind': 'factory'}), isNull);
    });
  });

  // Fixtures below are trimmed captures from a live Saqqar Apps launch
  // against Sijil IT's `test` environment (2026-09-06) — the doc's own
  // instruction for these five kinds ("read the live payload before writing
  // the widget") means the shape itself is the spec, not a guess.
  group('finance', () {
    const payload = {
      'kind': 'finance',
      'status': 'ok',
      'as_of': '2026-09-06',
      'cash': {
        'balance': 12500.0,
        'journals': ['Bank'],
        'available': true,
        'journal_count': 1,
      },
      'receivables': {
        'overdue': {'count': 3, 'items': <Object?>[], 'total': 4200.0, 'available': true},
        'due_soon': {'count': 0, 'items': <Object?>[], 'total': 0.0, 'available': true},
      },
      'payables': {
        'overdue': {'count': 0, 'items': <Object?>[], 'total': 0.0, 'available': true},
        'due_soon': {'count': 1, 'items': <Object?>[], 'total': 900.0, 'available': true},
      },
      'drafts': {
        'vendor_bills': {'count': 0, 'items': <Object?>[], 'total': null, 'available': true},
        'customer_invoices': {'count': 2, 'items': <Object?>[], 'total': null, 'available': true},
      },
      'bank_reconciliation': {'count': 0, 'items': <Object?>[], 'total': null, 'available': true},
      'liquidity_7d': {
        'cash': 12500.0,
        'status': 'covered',
        'cash_gap': 0.0,
        'available': true,
        'payables_due_7d': 900.0,
        'receivables_due_7d': 0.0,
      },
      'priorities': ['راجع البنك والإقفال الدوري.'],
    };

    test('reads the documented shape', () {
      final parsed = FinancePulsePayload.parse(payload)!;

      expect(parsed.cash.available, isTrue);
      expect(parsed.cash.balance, 12500.0);
      expect(parsed.cash.journals, ['Bank']);
      expect(parsed.receivablesOverdue.count, 3);
      expect(parsed.receivablesOverdue.total, 4200.0);
      expect(parsed.payablesDueSoon.count, 1);
      expect(parsed.draftCustomerInvoices.count, 2);
      expect(parsed.liquidityStatus, 'covered');
      expect(parsed.liquidityAvailable, isTrue);
      expect(parsed.priorities, hasLength(1));
    });

    test('an empty cash object reads as unavailable, not a crash', () {
      final parsed = FinancePulsePayload.parse(const {'kind': 'finance'})!;
      expect(parsed.cash.available, isFalse);
      expect(parsed.cash.balance, isNull);
      expect(parsed.receivablesOverdue.available, isFalse);
    });

    test('the wrong kind does not parse', () {
      expect(FinancePulsePayload.parse(const {'kind': 'purchasing'}), isNull);
    });
  });

  group('purchasing', () {
    test('a database with the app uninstalled degrades to empty buckets, '
        'not a crash', () {
      final parsed = PurchasingPulsePayload.parse(const {
        'kind': 'purchasing',
        'status': 'ok',
        'notes': ['تطبيق المشتريات غير مثبت أو غير مقروء في قاعدة أودو المربوطة.'],
        'to_bill': <String, dynamic>{},
        'open_rfqs': <String, dynamic>{},
        'vendor_bills': <String, dynamic>{},
        'awaiting_approval': <String, dynamic>{},
        'late_purchase_orders': <String, dynamic>{},
        'vendor_delay_summary': <Object?>[],
        'late_incoming_receipts': <String, dynamic>{},
        'priorities': ['اربط/فعّل المشتريات أو اختار Environment فيه بيانات شراء.'],
      })!;

      expect(parsed.openRfqs.count, isNull);
      expect(parsed.vendorDelayCount, 0);
      expect(parsed.envelope.notes, hasLength(1));
      expect(parsed.priorities, hasLength(1));
    });

    test('reads real counts and a vendor delay list length', () {
      final parsed = PurchasingPulsePayload.parse(const {
        'kind': 'purchasing',
        'open_rfqs': {'count': 4, 'items': <Object?>[], 'available': true},
        'late_purchase_orders': {'count': 2, 'items': <Object?>[], 'available': true},
        'vendor_delay_summary': [
          {'vendor': 'Acme'},
          {'vendor': 'Beta Co'},
        ],
      })!;

      expect(parsed.openRfqs.count, 4);
      expect(parsed.latePurchaseOrders.count, 2);
      expect(parsed.vendorDelayCount, 2);
    });

    test('the wrong kind does not parse', () {
      expect(PurchasingPulsePayload.parse(const {'kind': 'finance'}), isNull);
    });
  });

  group('hr', () {
    const payload = {
      'kind': 'hr',
      'status': 'ok',
      'as_of': '2026-09-06',
      'window_days': 90,
      'counters': [
        {'key': 'applicants', 'label': 'متقدمون للفرز', 'value': 0, 'action': 'افرز المتقدمين'},
        {'key': 'contracts', 'label': 'موظفون وعقود للمراجعة', 'value': 1, 'action': 'راجع العقود'},
      ],
      'operations': {
        'available': true,
        'active_employees': 9,
        'missing_managers': 9,
        'missing_work_email': 1,
        'items': [
          {'type': 'missing_work_email', 'reason': 'بريد العمل غير مسجل', 'employee': 'Administrator'},
          {'type': 'missing_manager', 'reason': 'المدير غير محدد', 'employee': 'Ahmed Mohamed'},
        ],
      },
    };

    test('reads the documented shape', () {
      final parsed = HrPulsePayload.parse(payload)!;

      expect(parsed.windowDays, 90);
      expect(parsed.counters, hasLength(2));
      expect(parsed.counters.first.label, 'متقدمون للفرز');
      expect(parsed.counters.first.action, 'افرز المتقدمين');
      expect(parsed.operations.available, isTrue);
      expect(parsed.operations.activeEmployees, 9);
      expect(parsed.operations.items, hasLength(2));
      expect(parsed.operations.items.first.employee, 'Administrator');
    });

    test('operations missing entirely defaults to unavailable, not a crash',
        () {
      final parsed = HrPulsePayload.parse(const {'kind': 'hr'})!;
      expect(parsed.operations.available, isFalse);
      expect(parsed.operations.items, isEmpty);
      expect(parsed.counters, isEmpty);
    });

    test('the wrong kind does not parse', () {
      expect(HrPulsePayload.parse(const {'kind': 'accountant'}), isNull);
    });
  });

  group('accountant', () {
    test('reads month and counters, ignores the audit-trail blocks', () {
      final parsed = AccountantPulsePayload.parse(const {
        'kind': 'accountant',
        'status': 'ok',
        'month': '2026-08',
        'window_days': 365,
        'counters': [
          {'key': 'tax', 'label': 'ملاحظات ضريبية', 'value': 1, 'action': 'راجع الضريبة'},
          {'key': 'close', 'label': 'بنود إقفال 2026-08', 'value': 1, 'action': 'اقفل الشهر'},
        ],
        // A full 'blocks' map would sit here on the real payload — the
        // parser doesn't need it, so a hostile/hollow one is fine too.
        'blocks': {'tax': <String, dynamic>{}},
      })!;

      expect(parsed.month, '2026-08');
      expect(parsed.windowDays, 365);
      expect(parsed.counters, hasLength(2));
      expect(parsed.counters.last.key, 'close');
    });

    test('an empty month string reads as null, not a blank badge', () {
      final parsed = AccountantPulsePayload.parse(const {
        'kind': 'accountant',
      })!;
      expect(parsed.month, isNull);
      expect(parsed.counters, isEmpty);
    });

    test('the wrong kind does not parse', () {
      expect(AccountantPulsePayload.parse(const {'kind': 'hr'}), isNull);
    });
  });

  group('quality_guard', () {
    test('reads the flattened quality_stats and spec_stats summaries', () {
      final parsed = QualityGuardPulsePayload.parse(const {
        'kind': 'quality_guard',
        'status': 'ok',
        'priorities': ['راجع القياسات والخصومات الكبيرة دوريًا.'],
        'quality_stats': {
          'out_of_spec': 2,
          'failed_checks': 1,
          'pending_checks': 0,
          'quality_alerts': 3,
          'missing_numeric_specs': 0,
        },
        'spec_stats': {
          'review_cases': 1,
          'invoice_swaps': 0,
          'delivery_swaps': 2,
          'high_risk_cases': 1,
          'cost_saving_total': 450.0,
        },
      })!;

      expect(parsed.outOfSpec, 2);
      expect(parsed.failedChecks, 1);
      expect(parsed.qualityAlerts, 3);
      expect(parsed.reviewCases, 1);
      expect(parsed.deliverySwaps, 2);
      expect(parsed.costSavingTotal, 450.0);
      expect(parsed.priorities, hasLength(1));
    });

    test('missing quality_stats/spec_stats degrade to null, not zero', () {
      final parsed =
          QualityGuardPulsePayload.parse(const {'kind': 'quality_guard'})!;
      expect(parsed.outOfSpec, isNull);
      expect(parsed.costSavingTotal, isNull);
      expect(parsed.priorities, isEmpty);
    });

    test('the wrong kind does not parse', () {
      expect(
        QualityGuardPulsePayload.parse(const {'kind': 'factory'}),
        isNull,
      );
    });
  });

  group('PulseEnvelope', () {
    test('an unrecognised status degrades to ok, not to error', () {
      // A wording drift must not hide real numbers behind an error screen.
      expect(
        PulseEnvelope.fromJson(const {'status': 'partial'}).status,
        PulseStatus.ok,
      );
    });
  });

  test('InteractiveCardKind wires all seven pulse kinds', () {
    const wires = {
      'factory': InteractiveCardKind.factory,
      'inventory': InteractiveCardKind.inventory,
      'finance': InteractiveCardKind.finance,
      'purchasing': InteractiveCardKind.purchasing,
      'quality_guard': InteractiveCardKind.qualityGuard,
      'accountant': InteractiveCardKind.accountant,
      'hr': InteractiveCardKind.hr,
    };
    wires.forEach((wire, kind) {
      expect(InteractiveCardKind.fromWire(wire), kind, reason: wire);
    });
  });
}
