import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/view_model/locale_cubit.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/view_model/theme_cubit.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/delete_account_helper.dart';
import '../../../shared/widgets/sign_out_helper.dart';
import '../../../shared/widgets/skeleton_block.dart';
import '../../auth/view_model/auth_cubit.dart';
import '../../billing/data/billing_visibility.dart';
import '../../billing/data/usage_api.dart';
import '../../billing/view_model/plan_cubit.dart';
import '../widgets/widgets.dart';

/// Account tab — identity hero (with stats line), preferences, change
/// password, and sign out. Pull-to-refresh re-fetches `/auth/me/` so the
/// user's identity + counts stay current; skeleton placeholders paint
/// in place of the cards while the round-trip is in flight.
///
/// The Storybook entry is hidden behind a long-press on the username
/// inside [ProfileHero] (it's a dev surface, not a user feature).
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pull real token usage on open so the usage bars populate WITHOUT the
    // user having to open a chat first (the snapshot path only fills
    // PlanCubit once a conversation polls). Best-effort — a failure leaves
    // the CurrentPlanCard /plans/ fallback in place.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchUsage());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-read the plan the moment the app comes back to the foreground.
    //
    // This is the closing half of the web-checkout hand-off: subscribing
    // sends the user out to saqqaar.com in the browser, and they return to an
    // app that fetched its plan once, on open. Without this they land back on
    // "Free" with the usage bars they left behind, having just paid — which
    // reads as the payment not having worked. There is no callback to wait
    // for; coming back IS the signal.
    if (state == AppLifecycleState.resumed) unawaited(_fetchUsage());
  }

  /// Best-effort `GET /usage/` → feed [PlanCubit]. Silent on failure; the
  /// Account screen already degrades to the public /plans/ catalogue.
  Future<void> _fetchUsage() async {
    if (!mounted) return;
    final usageApi = context.read<UsageApi>();
    final planCubit = context.read<PlanCubit>();
    try {
      planCubit.update(await usageApi.fetch());
    } catch (_) {
      // Leave the existing PlanCubit state (snapshot-derived or null).
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeCubit>().state;
    final locale = context.watch<LocaleCubit>().state;
    final authState = context.watch<AuthCubit>().state;
    final user = authState.user;
    final isReloading = authState.isLoading;

    final identityLabel = user == null
        ? context.tr.sampleUsername
        : (user.email.isNotEmpty ? user.email : user.username);

    return PageScaffold(
      title: context.tr.tabAccount,
      // Username + product affiliation as the subtitle so the brand row
      // up top reads as "Saqqar / Account / who you are" — three
      // pieces of orienting context in one glance.
      subtitle: '$identityLabel · ${context.tr.workspace}',
      // Pull-to-refresh re-fetches /auth/me/ — the AuthCubit emits
      // AuthStatus.loading while in flight, which we use below to swap
      // the cards for skeleton placeholders.
      onRefresh: () async {
        await context.read<AuthCubit>().bootstrap();
        await _fetchUsage();
      },
      children: isReloading
          ? _accountSkeletonChildren()
          : [
              ProfileHero(
                onLongPress: () => context.pushNamed(RouteNames.storybook),
              ),
              const SizedBox(height: 14),
              // Plan & usage — split into two entry points (moved off the
              // profile so Account stays scannable): "See plans" → the
              // pricing catalogue, "Usage" → the per-window usage bars on
              // their own screen.
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    // "See plans" leads to the pricing catalogue — hidden
                    // while sales are web-only. "Usage" stays (it's what you
                    // already have, not an offer) and fills the row.
                    if (showPaidUpsell) ...[
                      Expanded(
                        child: GhostButton(
                          label: context.tr.accountSeePlans,
                          icon: Icons.workspace_premium_outlined,
                          expand: true,
                          onPressed: () =>
                              context.pushNamed(RouteNames.pricing),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: GhostButton(
                        label: context.tr.accountUsage,
                        icon: Icons.bar_chart_rounded,
                        expand: true,
                        onPressed: () => context.pushNamed(RouteNames.usage),
                      ),
                    ),
                  ],
                ),
              ),
              // Personal information (Gap I) — edit first/last name; email
              // stays read-only. Only shown once the user is hydrated.
              if (user != null) ...[
                const PersonalInfoCard(),
                const SizedBox(height: 14),
              ],
              PreferencesCard(mode: mode, locale: locale),
              const SizedBox(height: 14),
              const ChangePasswordCard(),
              const SizedBox(height: 14),
              // Destinations, grouped.
              //
              // These were seven identical full-width pills stacked down the
              // screen — "Manage devices", "Saqqar Apps", "Managed Odoo
              // trial", "Data explorer", "Billing history", "Buy tokens" —
              // with nothing to distinguish an account setting from a tool
              // from a purchase, and no clue what any of them did. A returning
              // user skims past it; a new one has no reason to tap anything.
              //
              // Grouping turns one list of seven into three of one-to-three,
              // and the per-row descriptions are what make them discoverable:
              // "Data explorer" means nothing on its own, "Read your models
              // and records directly" means something immediately.
              //
              // Devices sits first, headerless, because it continues the
              // thought the two cards above it started (your details, your
              // password → your devices) rather than starting a new one.
              AccountLinkGroup(
                links: [
                  AccountLink(
                    icon: Icons.devices_other_outlined,
                    title: context.tr.devicesManage,
                    subtitle: context.tr.devicesSubtitle,
                    onTap: () => context.pushNamed(RouteNames.devices),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Meeting transcription (§4.1) is deliberately NOT listed here.
              //
              // Withdrawn at the product owner's request (2026-07-28): the
              // backend side is not being built for now, so the entry point
              // comes out of the UI rather than shipping a door that opens
              // onto a feature nobody is finishing. The screen, cubit, API
              // client and route are all left in place — this is a hidden
              // entrance, not a demolition, so restoring it is adding a row
              // back to the Workspace group below.
              //
              // The route is unreachable in the app with this gone, and it is
              // not registered as a deep link, so nothing else surfaces it.
              AccountLinkGroup(
                title: context.tr.accountGroupWorkspace,
                subtitle: context.tr.accountGroupWorkspaceHint,
                icon: AppIcons.grid,
                tint: context.saqqar.brandPurple,
                links: [
                  // Saqqar Apps — guided setups (§1).
                  AccountLink(
                    icon: Icons.grid_view_rounded,
                    title: context.tr.appsTitle,
                    subtitle: context.tr.appsSubtitle,
                    tint: context.saqqar.brandPurple,
                    onTap: () => context.pushNamed(RouteNames.apps),
                  ),
                  // Managed Odoo trial (§2).
                  AccountLink(
                    icon: Icons.rocket_launch_outlined,
                    title: context.tr.trialTitle,
                    subtitle: context.tr.trialSubtitle,
                    tint: context.saqqar.brandPurple,
                    onTap: () => context.pushNamed(RouteNames.trial),
                  ),
                  // Read-only Odoo data explorer (§4.2).
                  AccountLink(
                    icon: Icons.table_chart_outlined,
                    title: context.tr.dataExplorerTitle,
                    subtitle: context.tr.dataExplorerSubtitle,
                    tint: context.saqqar.brandPurple,
                    onTap: () => context.pushNamed(RouteNames.dataExplorer),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Billing — the plan catalogue (§L) and payment history (§3).
              //
              // "Buy tokens" used to sit here and open the in-app Paymob
              // checkout. It is gone for two independent reasons: selling
              // digital content in-app needs store billing on both platforms,
              // and it was built against `GET /billing/plans/`, a two-entry
              // SAR catalogue that does not match what saqqaar.com actually
              // sells (five tiers, USD — see docs/STORE_PAYMENTS_COMPLIANCE).
              // Its replacement shows the real catalogue and hands off to the
              // web to pay.
              if (showPaidUpsell || showBillingRecords) ...[
                AccountLinkGroup(
                  title: context.tr.accountGroupBilling,
                  // Every titled group carries a line of its own; a heading
                  // sitting bare above its rows reads as a missing string
                  // next to the Workspace group directly above it.
                  subtitle: context.tr.accountGroupBillingHint,
                  icon: AppIcons.wallet,
                  links: [
                    // Shown on every platform, including where prices are
                    // suppressed. The screen behind it self-censors down to a
                    // feature comparison — and a user who has just hit their
                    // limit needs to know what a bigger plan would give them
                    // even if the app can't sell it. Hiding the row entirely
                    // left iOS with a limit message and no explanation of it.
                    AccountLink(
                      icon: Icons.workspace_premium_outlined,
                      title: context.tr.pricingPlansTitle,
                      subtitle: showPaidUpsell
                          ? context.tr.pricingPlansSubtitle
                          : context.tr.pricingPlansSubtitlePlain,
                      onTap: () => context.pushNamed(RouteNames.pricing),
                    ),
                    // Not gated with the rest: a receipt for money already
                    // taken is account information, and this is the only
                    // place in the app the money is visible at all.
                    if (showBillingRecords)
                      AccountLink(
                        icon: Icons.receipt_long_outlined,
                        title: context.tr.billingHistoryTitle,
                        subtitle: context.tr.billingHistorySubtitle,
                        onTap: () =>
                            context.pushNamed(RouteNames.billingHistory),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              GhostButton(
                label: context.tr.signOut,
                icon: AppIcons.signOut,
                tone: GhostButtonTone.danger,
                expand: true,
                // showSignOutFlow handles the confirm dialog, blocking
                // loading dialog, vault-cache clear, logout, and toast.
                // Auth-gate redirect routes to /sign-in afterwards.
                onPressed: () => showSignOutFlow(context),
              ),
              // Account deletion — App/Play Store policy requires an in-app
              // path to permanently delete the account and all its data.
              // Only shown once the user is hydrated (no point offering it
              // before we know who's signed in). Visually subordinate to
              // sign-out: a plain text-weight danger action, not a filled
              // button, so it doesn't compete with the primary affordances.
              if (user != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => showDeleteAccountFlow(context),
                  icon: Icon(AppIcons.trash,
                      size: 16, color: context.saqqar.danger),
                  label: Text(
                    context.tr.deleteAccount,
                    style: TextStyle(color: context.saqqar.danger),
                  ),
                ),
              ],
              // Product attribution. Lived inside the identity card until
              // 2026-07-25, where it was a seventh line of muted text
              // competing with the user's own details. A footer belongs at
              // the foot of the screen.
              const SizedBox(height: 18),
              Center(
                child: Text(
                  context.tr.poweredByDigitalHarbor,
                  style: context.text.labelSmall?.copyWith(
                    color: context.saqqar.muted.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
    );
  }
}

/// Card-shaped shimmer placeholders painted in place of the real cards
/// (ProfileHero / PreferencesCard / ChangePasswordCard / sign-out) while
/// the AuthCubit is reloading. Heights mimic each real card so the
/// layout doesn't jump when the data arrives.
///
/// Free function instead of a widget because `PageScaffold.children`
/// expects a flat `List<Widget>` — wrapping in a widget would force a
/// nested `Column` and break the existing spacing rhythm.
List<Widget> _accountSkeletonChildren() {
  return const [
    _SkeletonCard(height: 140),
    SizedBox(height: 14),
    _SkeletonCard(height: 160),
    SizedBox(height: 14),
    _SkeletonCard(height: 220),
    SizedBox(height: 14),
    _SkeletonCard(height: 48),
  ];
}

/// One shimmer card — outer GlassCard-shaped container with a few
/// internal SkeletonBlocks to suggest "this is a card with content
/// loading inside" rather than a flat grey rectangle. Subtle enough
/// not to look like an actual card the user might tap.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    // Short cards (button-height placeholders) can't fit the 3-block
    // layout — render a single fill block instead so the Column doesn't
    // overflow.
    final isCompact = height < 80;
    return Container(
      height: height,
      padding: EdgeInsets.all(isCompact ? 10 : 16),
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.isDark ? 0.45 : 0.85),
        borderRadius: AppRadius.cardR,
        border: Border.all(color: s.cardBorder),
      ),
      child: isCompact
          ? const SkeletonBlock()
          : const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SkeletonBlock(width: 140, height: 14),
                SkeletonBlock(height: 12),
                SkeletonBlock(width: 200, height: 12),
              ],
            ),
    );
  }
}
