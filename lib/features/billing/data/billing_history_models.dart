import 'package:flutter/foundation.dart';

/// One row from `GET /api/v1/billing/history/`
/// (API_MOBILE_NEW_ENDPOINTS.md §3). Every displayed value is
/// server-supplied — nothing is derived or invented client-side.
@immutable
class PaymentRow {
  const PaymentRow({
    required this.when,
    required this.what,
    required this.amount,
    required this.currency,
    required this.tokens,
    required this.tokensM,
    required this.status,
    required this.isPaid,
    required this.isFailed,
    required this.ref,
    required this.receiptRef,
  });

  /// Paid time when present, else created time; `null` if the server sent
  /// neither.
  final DateTime? when;

  /// Human label (`"Pro — monthly"`, `"Token recharge"`, …).
  final String what;
  final double amount;
  final String currency;
  final int tokens;
  final double tokensM;

  /// Raw gateway status (`paid` / `failed` / …). Prefer [isPaid] / [isFailed]
  /// for logic; this stays for display of any other state.
  final String status;
  final bool isPaid;
  final bool isFailed;

  /// Short (8-char) reference to quote to support.
  final String ref;

  /// Full reference for the receipt call — `null` unless the row is paid.
  final String? receiptRef;

  /// Whether a receipt PDF can be fetched for this row.
  bool get hasReceipt => isPaid && (receiptRef?.isNotEmpty ?? false);

  /// The money is genuinely still in flight — worth telling the user to wait.
  ///
  /// NOT simply `!isPaid && !isFailed`. The backend contract
  /// (`PAYMOB_WEB_CHECKOUT_BACKEND.md`) also allows `expired`, `refunded` and
  /// `chargeback`, none of which are paid or failed and none of which are
  /// waiting for anything. Telling someone their refund is "awaiting
  /// confirmation from the payment provider" would be worse than saying
  /// nothing.
  ///
  /// An empty or unrecognised status counts as awaiting: the row exists, the
  /// server hasn't called it settled, and "we're still checking" is the
  /// honest reading of a state we don't know.
  bool get isAwaitingConfirmation {
    if (isPaid || isFailed) return false;
    return const {
          'expired',
          'refunded',
          'chargeback',
        }.contains(status.toLowerCase())
        ? false
        : true;
  }

  factory PaymentRow.fromJson(Map<String, dynamic> json) {
    return PaymentRow(
      when: _parseDate(json['when']),
      what: json['what'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'SAR',
      tokens: (json['tokens'] as num?)?.toInt() ?? 0,
      tokensM: (json['tokens_m'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? '',
      isPaid: json['is_paid'] as bool? ?? false,
      isFailed: json['is_failed'] as bool? ?? false,
      ref: json['ref'] as String? ?? '',
      receiptRef: json['receipt_ref'] as String?,
    );
  }

  static DateTime? _parseDate(Object? v) {
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toLocal();
    return null;
  }
}

/// Full `GET /api/v1/billing/history/` payload — the caller's payment rows
/// (newest-first, capped server-side at 100) plus balance totals.
@immutable
class BillingHistory {
  const BillingHistory({
    required this.rows,
    required this.tokenBalance,
    required this.totalPurchased,
    required this.hasAny,
  });

  final List<PaymentRow> rows;
  final int tokenBalance;
  final int totalPurchased;
  final bool hasAny;

  factory BillingHistory.fromJson(Map<String, dynamic> json) {
    return BillingHistory(
      rows: (json['rows'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(PaymentRow.fromJson)
          .toList(),
      tokenBalance: (json['token_balance'] as num?)?.toInt() ?? 0,
      totalPurchased: (json['total_purchased'] as num?)?.toInt() ?? 0,
      hasAny: json['has_any'] as bool? ?? false,
    );
  }
}
