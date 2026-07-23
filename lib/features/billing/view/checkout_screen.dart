import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/preview_banner.dart';
import '../data/checkout_api.dart';
import '../data/checkout_models.dart';

/// Paymob checkout (API_MOBILE_NEW_ENDPOINTS.md §4.3).
///
/// ⚠️ Reachable ONLY where [showPaidUpsell] is true (Android) — the route +
/// Account entry both gate on it, so iOS never surfaces a purchase flow.
/// Confirm App Store / Play IAP compliance before shipping this anywhere.
///
/// Flow: list plans → tap Buy → open the hosted payment page in the browser
/// → poll the payment status until it's paid / failed.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  List<CheckoutPlan>? _plans;
  Object? _failure;
  bool _loading = true;

  String? _buyingId;
  String? _pollRef;
  PaymentStatus? _payment;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlans());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final plans = await context.read<CheckoutApi>().plans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = e;
        _loading = false;
      });
    }
  }

  Future<void> _buy(CheckoutPlan plan) async {
    if (_buyingId != null) return;
    setState(() => _buyingId = plan.id);
    final api = context.read<CheckoutApi>();
    try {
      final session = await api.start(plan.id);
      if (!mounted) return;
      setState(() => _buyingId = null);
      if (!session.isValid) {
        _snack(context.tr.checkoutOpenFailed);
        return;
      }
      final opened = await launchUrl(
        Uri.parse(session.url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        if (mounted) _snack(context.tr.checkoutOpenFailed);
        return;
      }
      _beginPolling(api, session.ref);
    } catch (e) {
      if (!mounted) return;
      setState(() => _buyingId = null);
      _snack(ApiErrorMapper.message(context, e));
    }
  }

  void _beginPolling(CheckoutApi api, String ref) {
    _poll?.cancel();
    setState(() {
      _pollRef = ref;
      _payment = null;
    });
    _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final status = await api.status(ref);
        if (!mounted) return;
        setState(() => _payment = status);
        if (status.isPaid || status.isFailed) {
          _poll?.cancel();
          _poll = null;
        }
      } catch (_) {
        // Transient poll failure — keep trying on the next tick.
      }
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Scaffold(
      backgroundColor: s.bg,
      appBar: AppBar(title: Text(context.tr.checkoutTitle)),
      body: AmbientBackground(
        child: RefreshIndicator(
          color: s.brandCyan,
          backgroundColor: s.surface,
          onRefresh: _loadPlans,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final s = context.saqqar;
    final plans = _plans;
    if (plans != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          PreviewBanner(text: context.tr.checkoutPreviewNote),
          const SizedBox(height: 14),
          if (_pollRef != null) ...[
            _PaymentBanner(payment: _payment),
            const SizedBox(height: 14),
          ],
          if (plans.isEmpty)
            EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: context.tr.checkoutEmpty,
            )
          else
            for (final plan in plans) ...[
              _PlanCard(
                plan: plan,
                busy: _buyingId == plan.id,
                onBuy: () => _buy(plan),
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
            onRetry: _loadPlans,
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.busy, required this.onBuy});

  final CheckoutPlan plan;
  final bool busy;
  final VoidCallback onBuy;

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name,
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (plan.description != null &&
                    plan.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(plan.description!,
                      style: context.text.bodySmall?.copyWith(color: s.muted)),
                ],
                const SizedBox(height: 6),
                Text(
                  '${plan.price.toStringAsFixed(2)} ${plan.currency}',
                  style: context.text.titleMedium?.copyWith(
                    color: s.brandCyan,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GhostButton(
            label: context.tr.checkoutBuy,
            icon: Icons.shopping_cart_checkout,
            loading: busy,
            onPressed: busy ? null : onBuy,
          ),
        ],
      ),
    );
  }
}

class _PaymentBanner extends StatelessWidget {
  const _PaymentBanner({required this.payment});

  final PaymentStatus? payment;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final (label, color, icon) = switch (payment) {
      PaymentStatus(isPaid: true) => (
          context.tr.checkoutPaid,
          s.success,
          Icons.check_circle_outline,
        ),
      PaymentStatus(isFailed: true) => (
          context.tr.checkoutFailed,
          s.danger,
          Icons.error_outline,
        ),
      _ => (context.tr.checkoutWaiting, s.warning, Icons.hourglass_top),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.rowR,
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: context.text.bodySmall
                    ?.copyWith(color: color, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
