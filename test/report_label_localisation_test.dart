// The report card's chips read in the user's language, not the server's.
//
// Found in the full web-vs-mobile sweep. `ReportOption.displayLabel` looks up
// `rbType_<key>` and falls back to the server's `label` — a good design with
// an empty table behind it, so the fallback was taken every single time.
//
// That matters because of what the fallback contains. The web's own comment
// on the same card says the chips are "localised on the FRONTEND from the
// current UI language ... the backend only sends keys (+ Arabic fallback
// labels)". So an English-language user was reading Arabic chips, and the
// client-side translation the mechanism existed for never happened.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/features/chat/data/interactive_cards.dart';

/// Every option key the web ships a translation for, by group.
const _keysByPrefix = <String, List<String>>{
  ReportLabelKeys.type: [
    'sales',
    'invoices',
    'inventory',
    'purchases',
    'products',
    'customers',
    'vendors',
    'employees',
  ],
  ReportLabelKeys.lens: [
    'sales_orders',
    'sales_deliveries',
    'sales_invoices',
    'sales_collections',
    'sales_quotations',
    'purchase_orders',
    'purchase_receipts',
    'purchase_rfqs',
    'vendor_bills',
    'vendor_payments',
    'customer_invoices',
    'unpaid_customer_invoices',
    'unpaid_vendor_bills',
    'overdue_customer_invoices',
  ],
  ReportLabelKeys.period: [
    'last_week',
    'last_month',
    'last_quarter',
    'this_year',
    'custom',
  ],
  ReportLabelKeys.format: ['excel', 'pdf', 'html'],
};

/// The three format names stay Latin in both tables — see the same reason in
/// `i18n_parity_test`'s allowlist.
const _latinInBothLocales = {'rbFormat_excel', 'rbFormat_pdf', 'rbFormat_html'};

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  test('every option the web translates, the app translates', () {
    final missing = <String>[];
    for (final entry in _keysByPrefix.entries) {
      for (final key in entry.value) {
        final full = '${entry.key}$key';
        for (final tr in [en, ar]) {
          if (tr.lookup(full).isEmpty) missing.add(full);
        }
      }
    }

    expect(missing, isEmpty, reason: 'untranslated chips: ${missing.join(', ')}');
    expect(
      _keysByPrefix.values.fold<int>(0, (n, v) => n + v.length),
      30,
      reason: 'the web ships 30 of these; add the new one to both tables',
    );
  });

  test('an English UI gets English, whatever the server sent', () {
    // The exact failure: the server sends the key plus an Arabic label, and
    // without the table the Arabic label reached an English screen.
    const option = ReportOption(key: 'sales', label: 'مبيعات');

    expect(option.displayLabel(en, ReportLabelKeys.type), 'Sales');
    expect(option.displayLabel(ar, ReportLabelKeys.type), 'مبيعات');
  });

  test('and the client translation wins over an English server label too', () {
    // Symmetric: a deployment that sends English labels must not leave an
    // Arabic screen reading English.
    const option = ReportOption(key: 'last_week', label: 'Last week');

    expect(option.displayLabel(ar, ReportLabelKeys.period), 'آخر أسبوع');
  });

  test('a key the app has never heard of still renders the server label', () {
    // The fallback is what makes it safe to ship a fixed table: a lens the
    // backend adds tomorrow shows its own label rather than `rbLens_new`.
    const option = ReportOption(key: 'brand_new_lens', label: 'Brand new lens');

    expect(option.displayLabel(en, ReportLabelKeys.lens), 'Brand new lens');
    expect(option.displayLabel(ar, ReportLabelKeys.lens), 'Brand new lens');
  });

  test('the two languages actually differ', () {
    // Copying English into the Arabic table would pass the presence check
    // above while leaving the card half-translated.
    for (final entry in _keysByPrefix.entries) {
      for (final key in entry.value) {
        final full = '${entry.key}$key';
        if (_latinInBothLocales.contains(full)) continue;
        expect(ar.lookup(full), isNot(en.lookup(full)), reason: full);
      }
    }
  });
}
