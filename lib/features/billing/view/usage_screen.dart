import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../account/widgets/current_plan_card.dart';
import '../../account/widgets/plan_usage_card.dart';
import '../data/plan_models.dart';
import '../data/usage_api.dart';
import '../view_model/plan_cubit.dart';
import '../view_model/saqqar_features_cubit.dart';

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
  /// The last fetch failure, kept ONLY to render an error state when there
  /// is nothing else to show. Cleared on every new attempt.
  Object? _failure;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchUsage());
  }

  Future<void> _fetchUsage() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final usage = await context.read<UsageApi>().fetch();
      if (!mounted) return;
      context.read<PlanCubit>().update(usage.plan);
      context.read<SaqqarFeaturesCubit>().update(usage.saqqarFeatures);
      setState(() => _loading = false);
    } catch (e) {
      // Deliberately RECORDED, not swallowed. This used to be `catch (_) {}`,
      // which left PlanCubit null → the view fell back to CurrentPlanCard →
      // whose own /plans/ call had failed in the same outage → which renders
      // SizedBox.shrink(). Net effect: tapping "Usage" offline produced an
      // app bar over a totally blank page. No spinner, no error, no hint that
      // anything had failed — the worst surface in the app.
      //
      // Whatever PlanCubit already holds still wins (see `build`), so a
      // failed REFRESH never blanks data the user can already see.
      if (!mounted) return;
      setState(() {
        _failure = e;
        _loading = false;
      });
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
                builder: (context, plan) {
                  // Real usage data wins outright — a failed refresh must
                  // never replace numbers the user can already read.
                  if (plan != null) return const PlanUsageCard();
                  // Nothing to show AND the fetch failed: say so, and give
                  // them a way out. `RefreshIndicator` alone isn't an
                  // affordance — nothing on a blank page invites a pull.
                  if (_failure != null) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: AppErrorState(
                        message: ApiErrorMapper.message(context, _failure),
                        onRetry: _fetchUsage,
                      ),
                    );
                  }
                  if (_loading) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: s.muted,
                        ),
                      ),
                    );
                  }
                  // Fetch succeeded but carried no snapshot — fall back to
                  // the public plan catalogue, as before.
                  return const CurrentPlanCard();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
