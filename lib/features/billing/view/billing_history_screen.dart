import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/format/compact_number.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../inbox/data/artifact_downloader.dart';
import '../data/billing_history_api.dart';
import '../data/billing_history_models.dart';

/// Read-only billing history + PDF receipts (API_MOBILE_NEW_ENDPOINTS.md §3).
///
/// Reached as a detail route from Account. Fetches on open; each paid row
/// exposes a "Receipt" action that streams the PDF through
/// [ArtifactDownloader] (same auth + cache path as artifact downloads) and
/// hands it to the OS viewer.
///
/// Deliberately NO checkout surface here — buying in-app via Paymob may
/// clash with App Store / Play IAP rules (see the doc's store-policy note),
/// so the app only reads history, never sells.
class BillingHistoryScreen extends StatefulWidget {
  const BillingHistoryScreen({super.key});

  @override
  State<BillingHistoryScreen> createState() => _BillingHistoryScreenState();
}

class _BillingHistoryScreenState extends State<BillingHistoryScreen> {
  BillingHistory? _history;
  Object? _failure;
  bool _loading = true;

  /// Receipt reference currently downloading — drives the per-row spinner
  /// and blocks a second concurrent open.
  String? _openingReceiptRef;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final history = await context.read<BillingHistoryApi>().fetch();
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Keep any history we already showed; only surface a full-screen error
      // when there's nothing to fall back to.
      setState(() {
        _failure = e;
        _loading = false;
      });
    }
  }

  Future<void> _openReceipt(PaymentRow row) async {
    final ref = row.receiptRef;
    if (ref == null || ref.isEmpty || _openingReceiptRef != null) return;
    setState(() => _openingReceiptRef = ref);
    final downloader = ArtifactDownloader(context.read<Dio>());
    final url = '${ApiEndpoints.baseUrl}${ApiEndpoints.billingReceipt(ref)}';
    final result = await downloader.downloadAndOpenUrl(
      url: url,
      cacheKey: 'receipt-$ref',
      originalName: 'saqqar-receipt-${row.ref}.pdf',
      kindHint: 'pdf',
    );
    if (!mounted) return;
    setState(() => _openingReceiptRef = null);
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    switch (result) {
      case ArtifactOpenSuccess():
        break; // handed off to the OS viewer
      case ArtifactOpenNoViewer():
        messenger.showSnackBar(
          SnackBar(content: Text(context.tr.billingReceiptNoViewer)),
        );
      case ArtifactOpenFailed():
      case ArtifactDownloadFailed():
        messenger.showSnackBar(
          SnackBar(content: Text(context.tr.billingReceiptFailed)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final history = _history;
    return Scaffold(
      backgroundColor: s.bg,
      appBar: AppBar(title: Text(context.tr.billingHistoryTitle)),
      body: AmbientBackground(
        child: RefreshIndicator(
          color: s.brandCyan,
          backgroundColor: s.surface,
          onRefresh: _fetch,
          child: _buildBody(context, history),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, BillingHistory? history) {
    final s = context.saqqar;
    // Real data wins outright — a failed refresh never blanks rows the user
    // can already read.
    if (history != null) {
      if (history.rows.isEmpty) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 28),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.receipt_long_outlined,
              title: context.tr.billingEmptyTitle,
              body: context.tr.billingEmptyBody,
            ),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _BalanceHeader(history: history),
          const SizedBox(height: 14),
          for (final row in history.rows) ...[
            _PaymentRowCard(
              row: row,
              opening: _openingReceiptRef == row.receiptRef,
              onReceipt: () => _openReceipt(row),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    }
    if (_failure != null) {
      return ListView(
        padding: const EdgeInsets.only(top: 64),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppErrorState(
            message: ApiErrorMapper.message(context, _failure),
            onRetry: _fetch,
          ),
        ],
      );
    }
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 64),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2.4, color: s.muted),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.history});

  final BillingHistory history;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: s.cardBg,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: s.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: context.tr.billingBalance,
              value: compactCount(history.tokenBalance, context.tr),
            ),
          ),
          Container(width: 1, height: 34, color: s.border),
          Expanded(
            child: _Stat(
              label: context.tr.billingTotalPurchased,
              value: compactCount(history.totalPurchased, context.tr),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Column(
      children: [
        Text(
          value,
          style: context.text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: s.brandCyan,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: context.text.labelSmall?.copyWith(color: s.muted)),
      ],
    );
  }
}

class _PaymentRowCard extends StatelessWidget {
  const _PaymentRowCard({
    required this.row,
    required this.opening,
    required this.onReceipt,
  });

  final PaymentRow row;
  final bool opening;
  final VoidCallback onReceipt;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: s.cardBg,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: s.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.what,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _metaLine(context, row),
                      style: context.text.bodySmall?.copyWith(color: s.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Flexible so a long amount can shrink/ellipsize instead of
              // overflowing the row on a narrow screen.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${row.amount.toStringAsFixed(2)} ${row.currency}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    _StatusChip(row: row),
                  ],
                ),
              ),
            ],
          ),
          // A payment stuck between "sent" and "paid" is the state that most
          // needs explaining and had none. Verified on production 2026-08-03:
          // three attempts pending, one of them eight days old, with a token
          // balance of zero — a user looking at that has no way to tell
          // "still processing" from "my money went nowhere". Say which, and
          // hand them the reference to quote.
          if (row.isAwaitingConfirmation) ...[
            const SizedBox(height: 8),
            Text(
              context.tr.billingPendingNote(row.ref),
              style: context.text.bodySmall
                  ?.copyWith(color: s.muted, height: 1.35),
            ),
          ],
          if (row.hasReceipt) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: opening ? null : onReceipt,
                icon: opening
                    ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: s.brandCyan,
                        ),
                      )
                    : Icon(Icons.download_outlined, size: 16, color: s.brandCyan),
                label: Text(context.tr.billingReceipt),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Date + tokens granted (both server-supplied). Blank pieces are dropped
  /// so we never render a stray separator.
  String _metaLine(BuildContext context, PaymentRow row) {
    final parts = <String>[];
    final when = row.when;
    if (when != null) {
      parts.add('${when.year}-${_two(when.month)}-${_two(when.day)}');
    }
    // Tokens granted, localized compact ("+250 م" / "+250M").
    if (row.tokens > 0) parts.add('+${compactCount(row.tokens, context.tr)}');
    return parts.join('  ·  ');
  }
}

/// Maps a payment row's state to the shared [StatusPill]. Paid rows read
/// success, failed rows danger, and any other server status shows neutral.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.row});

  final PaymentRow row;

  @override
  Widget build(BuildContext context) {
    // `row.status` is the raw wire value — rendering it directly put the
    // Latin word "PENDING" in the middle of an Arabic screen, which the i18n
    // parity test can't catch because the string never lived in our tables.
    final (label, variant) = row.isPaid
        ? (context.tr.billingPaid, StatusPillVariant.success)
        : row.isFailed
            ? (context.tr.billingFailed, StatusPillVariant.danger)
            : (context.tr.billingStatusLabel(row.status),
                StatusPillVariant.info);
    if (label.isEmpty) return const SizedBox.shrink();
    return StatusPill(label: label, variant: variant);
  }
}

String _two(int n) => n < 10 ? '0$n' : '$n';
