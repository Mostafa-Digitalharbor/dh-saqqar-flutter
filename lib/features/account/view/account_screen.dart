import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/view_model/locale_cubit.dart';
import '../../../core/routing/route_names.dart';
import '../../../shared/fig/fig.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/delete_account_helper.dart';
import '../../../shared/widgets/sign_out_helper.dart';
import '../../auth/view_model/auth_cubit.dart';
import '../../billing/data/billing_visibility.dart';
import '../../billing/data/usage_api.dart';
import '../../billing/view_model/plan_cubit.dart';
import '../../billing/view_model/saqqar_features_cubit.dart';
import '../../notifications/view_model/notifications_settings_cubit.dart';
import '../../push/data/devices_api.dart';
import '../../security/view_model/app_lock_cubit.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/theme/app_sizes.dart';
import '../../billing/data/plan_copy.dart';

part 'account_screen_identity.dart';
part 'account_screen_rows.dart';
part 'account_screen_personal.dart';
part 'account_screen_security.dart';
part 'account_screen_preferences.dart';
part 'account_screen_devices.dart';

/// Profile — dark gradient header, identity card, four stat tiles and the
/// accordion of account sections (Personal information, Change password,
/// Preferences, Manage devices, Workspace, Billing), then Sign out and
/// Delete account.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

enum _Section { personal, password, prefs, devices, workspace, billing }

class _AccountScreenState extends State<AccountScreen>
    with WidgetsBindingObserver {
  _Section? _open;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchUsage());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_fetchUsage());
  }

  Future<void> _fetchUsage() async {
    if (!mounted) return;
    final usageApi = context.read<UsageApi>();
    final planCubit = context.read<PlanCubit>();
    final featuresCubit = context.read<SaqqarFeaturesCubit>();
    try {
      final usage = await usageApi.fetch();
      planCubit.update(usage.plan);
      featuresCubit.update(usage.saqqarFeatures);
    } catch (_) {
      // Non-critical: the card just keeps its last known plan.
    }
  }

  void _toggle(_Section s) => setState(() => _open = _open == s ? null : s);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final user = auth.user;
    final counts = auth.counts;
    final plan = context.watch<PlanCubit>().state;
    final planName = (plan == null || plan.name.isEmpty)
        ? context.tr.figStandardUser
        : PlanCopy.nameFor(
            context.tr,
            slug: plan.slug,
            fallback: plan.name,
          ).toUpperCase();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: figLightStatusBar,
      child: Scaffold(
        backgroundColor: Fig.pageGrey,
        body: FigBackdrop(
          stretch: 1.12,
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async {
                await context.read<AuthCubit>().bootstrap();
                await _fetchUsage();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  FigPageHeader(
                    title: context.tr.figProfile,
                    subtitle:
                        context.tr.figManageYourAccountWorkspaceAndBilling,
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go(RouteNames.homePath),
                  ),
                  const SizedBox(height: AppSpacing.s22),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s24,
                    ),
                    child: Column(
                      children: [
                        _IdentityCard(
                          name: user?.displayName ?? '',
                          email: user?.email ?? '',
                          plan: planName,
                          onLongPress: () =>
                              context.pushNamed(RouteNames.storybook),
                        ),
                        const SizedBox(height: AppSpacing.s10),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Stat(
                                counts.conversations,
                                context.tr.figConversations,
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              _Stat(
                                counts.credentials,
                                context.tr.figCredentials,
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              _Stat(counts.approvals, context.tr.figApprovals),
                              const SizedBox(width: AppSpacing.s8),
                              _Stat(counts.artifacts, context.tr.figArtifacts),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s10),
                        _Accordion(
                          icon: LucideIcons.userRound,
                          title: context.tr.figPersonalInformation,
                          subtitle: context.tr.figTheDetailsYouGaveWhenYou,
                          open: _open == _Section.personal,
                          onTap: () => _toggle(_Section.personal),
                          child: _PersonalInfo(
                            name: user?.displayName ?? '',
                            email: user?.email ?? '',
                          ),
                        ),
                        _Accordion(
                          icon: LucideIcons.keyboard,
                          title: context.tr.figChangePassword,
                          subtitle:
                              context.tr.figUpdateThePasswordYouSignInWith,
                          open: _open == _Section.password,
                          onTap: () => _toggle(_Section.password),
                          child: _ChangePassword(
                            onDone: () => setState(() => _open = null),
                          ),
                        ),
                        _Accordion(
                          icon: LucideIcons.languages,
                          title: context.tr.figPreferences,
                          subtitle:
                              context.tr.figLanguageAppLockAndNotifications,
                          open: _open == _Section.prefs,
                          onTap: () => _toggle(_Section.prefs),
                          child: const _Preferences(),
                        ),
                        _Accordion(
                          icon: LucideIcons.monitor,
                          title: context.tr.figManageDevices,
                          subtitle: context.tr.figSeeWhereYouReSignedIn,
                          open: _open == _Section.devices,
                          onTap: () => _toggle(_Section.devices),
                          child: const _Devices(),
                        ),
                        _Accordion(
                          icon: LucideIcons.network,
                          title: context.tr.figWorkspace,
                          subtitle: context.tr.figToolsThatWorkOnYourOdoo,
                          open: _open == _Section.workspace,
                          onTap: () => _toggle(_Section.workspace),
                          child: Column(
                            children: [
                              _SubRow(
                                LucideIcons.layoutGrid,
                                context.tr.figSaqqarApps,
                                () =>
                                    context.push(RouteNames.workspaceAppsPath),
                              ),
                              _SubRow(
                                LucideIcons.cloud,
                                context.tr.figManagedOdooTrial,
                                () => context.push(RouteNames.trialPath),
                              ),
                              _SubRow(
                                LucideIcons.database,
                                context.tr.figDataExplorer,
                                () => context.push(RouteNames.dataExplorerPath),
                                last: true,
                              ),
                            ],
                          ),
                        ),
                        if (showPaidUpsell || showBillingRecords)
                          _Accordion(
                            icon: LucideIcons.receiptText,
                            title: context.tr.figBilling,
                            subtitle: context.tr.figYourPlanPaymentsAndReceipts,
                            open: _open == _Section.billing,
                            onTap: () => _toggle(_Section.billing),
                            child: Column(
                              children: [
                                _SubRow(
                                  LucideIcons.gem,
                                  context.tr.figPlansPricing,
                                  () => context.push(RouteNames.pricingPath),
                                  last: !showBillingRecords,
                                ),
                                if (showBillingRecords)
                                  _SubRow(
                                    LucideIcons.receiptText,
                                    context.tr.figBillingHistory,
                                    () => context.push(
                                      RouteNames.billingHistoryPath,
                                    ),
                                    last: true,
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: AppSpacing.s14),
                        _DangerRow(
                          label: context.tr.figSignOut,
                          icon: LucideIcons.logOut,
                          onTap: () => showSignOutFlow(context),
                        ),
                        if (user != null) ...[
                          const SizedBox(height: AppSpacing.s18),
                          _DangerRow(
                            label: context.tr.figDeleteAccount,
                            icon: LucideIcons.trash2,
                            onTap: () => showDeleteAccountFlow(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section bodies ──────────────────────────────────────────────────────
