import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/format/compact_number.dart';
import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../inbox/data/artifact_downloader.dart';
import '../data/billing_history_api.dart';
import '../data/plan_copy.dart';
import '../data/billing_history_models.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/fig/fig_page.dart';

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
    switch (result) {
      case ArtifactOpenSuccess():
        break; // handed off to the OS viewer
      // "No viewer installed" is the user's device missing a PDF app, not a
      // failure on our side — info tone, so it doesn't read as a bug report.
      case ArtifactOpenNoViewer():
        AppToast.show(context, message: context.tr.billingReceiptNoViewer);
      // The file arrived but the OS refused to open it — the download is not
      // the problem, so "try again" is the right advice.
      case ArtifactOpenFailed():
        AppToast.show(
          context,
          message: context.tr.billingReceiptFailed,
          variant: ToastVariant.error,
        );
      // The download itself failed, and the status code says why. It used to
      // share the line above, which told a user with no connection to "try
      // again" and a user whose receipt is not yet issued the same thing —
      // neither of which names what to do. `artifactDownloadMessage` already
      // splits offline / forbidden / gone for artifact downloads; a receipt
      // fails the same four ways, so it reads from the same map rather than
      // growing a second one.
      case ArtifactDownloadFailed(:final statusCode):
        AppToast.show(
          context,
          message: context.tr.artifactDownloadMessage(statusCode),
          variant: ToastVariant.error,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final history = _history;
    return FigPage(
      title: context.tr.billingHistoryTitle,
      eyebrow: context.tr.figBilling,
      child: RefreshIndicator(
        color: s.brandCyan,
        backgroundColor: s.surface,
        onRefresh: _fetch,
        child: _buildBody(context, history),
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s48,
            AppSpacing.s16,
            AppSpacing.s28,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: AppIcons.receipt,
              title: context.tr.billingEmptyTitle,
              body: context.tr.billingEmptyBody,
            ),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s16,
          AppSpacing.s16,
          AppSpacing.s28,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _BalanceHeader(history: history),
          const SizedBox(height: AppSpacing.s14),
          for (final row in history.rows) ...[
            _PaymentRowCard(
              row: row,
              opening: _openingReceiptRef == row.receiptRef,
              onReceipt: () => _openReceipt(row),
            ),
            const SizedBox(height: AppSpacing.s10),
          ],
        ],
      );
    }
    if (_failure != null) {
      return ListView(
        padding: const EdgeInsets.only(top: AppSpacing.s64),
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
            padding: const EdgeInsets.only(top: AppSpacing.s64),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: AppStrokeWidths.spinnerRegular,
                color: s.muted,
              ),
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
    return GlassCard.flat(
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              label: context.tr.billingBalance,
              value: compactCount(history.tokenBalance, context.tr),
              valueColor: s.brandCyan,
            ),
          ),
          Container(
            width: AppBorderWidths.hairline,
            height: AppControlSizes.verticalRule,
            color: s.border,
          ),
          Expanded(
            child: StatTile(
              label: context.tr.billingTotalPurchased,
              value: compactCount(history.totalPurchased, context.tr),
              valueColor: s.brandCyan,
            ),
          ),
        ],
      ),
    );
  }
}

// The private `_Stat` here is now `StatTile` in shared/widgets — same shape,
// but with the FittedBox and the two-line ellipsised label that the account
// screen's identical copy had already grown and this one hadn't.

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
    return GlassCard.flat(
      padding: const EdgeInsets.all(AppSpacing.s14),
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
                      _localizedWhat(context, row.what),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      _metaLine(context, row),
                      style: context.text.bodySmall?.copyWith(color: s.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
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
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
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
            const SizedBox(height: AppSpacing.s8),
            Text(
              context.tr.billingPendingNote(row.ref),
              style: context.text.bodySmall?.copyWith(
                color: s.muted,
                height: AppLineHeights.label,
              ),
            ),
          ],
          if (row.hasReceipt) ...[
            const SizedBox(height: AppSpacing.s10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: opening ? null : onReceipt,
                icon: opening
                    ? SizedBox(
                        width: AppControlSizes.spinnerTiny,
                        height: AppControlSizes.spinnerTiny,
                        child: CircularProgressIndicator(
                          strokeWidth: AppStrokeWidths.spinnerThin,
                          color: s.brandCyan,
                        ),
                      )
                    : Icon(
                        AppIcons.download,
                        size: AppIconSizes.small,
                        color: s.brandCyan,
                      ),
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
      parts.add(AppDateFormat.date(context, when));
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
        : (context.tr.billingStatusLabel(row.status), StatusPillVariant.info);
    if (label.isEmpty) return const SizedBox.shrink();
    return StatusPill(label: label, variant: variant);
  }
}

/// The server composes `what` in English ("Solo — monthly"). Plan names and
/// the billing cycle are known vocabulary, so each part is translated and any
/// part that is not (a "Token recharge", a future label) is shown as sent.
String _localizedWhat(BuildContext context, String what) {
  final tr = context.tr;
  final parts = what.split(' — ').map((part) {
    return switch (part.trim().toLowerCase()) {
      'monthly' => tr.pricingCycleMonthly,
      'annual' => tr.pricingCycleAnnual,
      _ => PlanCopy.translate(tr, part),
    };
  });
  return parts.join(' — ');
}
