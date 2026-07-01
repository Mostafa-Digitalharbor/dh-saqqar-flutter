import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../account/widgets/current_plan_card.dart';
import '../../account/widgets/plan_usage_card.dart';
import '../data/plan_models.dart';
import '../data/usage_api.dart';
import '../view_model/plan_cubit.dart';

/// Standalone token-usage page, reached from the Account "Usage" button.
///
/// Splits usage off the profile so Account stays scannable — a dedicated
/// screen for the per-window usage bars (day / week / month). Fetches fresh
/// usage on open; falls back to the public plan catalogue before any usage
/// has loaded.
class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchUsage());
  }

  Future<void> _fetchUsage() async {
    if (!mounted) return;
    try {
      final usage = await context.read<UsageApi>().fetch();
      if (mounted) context.read<PlanCubit>().update(usage);
    } catch (_) {
      // Leave whatever PlanCubit already holds (snapshot-derived, or the
      // CurrentPlanCard /plans/ fallback).
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Scaffold(
      backgroundColor: s.bg,
      appBar: AppBar(title: Text(context.tr.usageTitle)),
      body: AmbientBackground(
        child: RefreshIndicator(
          color: s.brandCyan,
          backgroundColor: s.surface,
          onRefresh: _fetchUsage,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              BlocBuilder<PlanCubit, PlanSnapshot?>(
                builder: (context, plan) =>
                    plan == null ? const CurrentPlanCard() : const PlanUsageCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
