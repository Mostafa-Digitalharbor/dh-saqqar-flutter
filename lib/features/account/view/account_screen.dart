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
import '../../../shared/widgets/sign_out_helper.dart';
import '../../../shared/widgets/skeleton_block.dart';
import '../../auth/view_model/auth_cubit.dart';
import '../../billing/data/plan_models.dart';
import '../../billing/view_model/plan_cubit.dart';
import '../widgets/widgets.dart';

/// Account tab — identity hero (with stats line), preferences, change
/// password, and sign out. Pull-to-refresh re-fetches `/auth/me/` so the
/// user's identity + counts stay current; skeleton placeholders paint
/// in place of the cards while the round-trip is in flight.
///
/// The Storybook entry is hidden behind a long-press on the username
/// inside [ProfileHero] (it's a dev surface, not a user feature).
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

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
      },
      children: isReloading
          ? _accountSkeletonChildren()
          : [
              ProfileHero(
                onLongPress: () => context.pushNamed(RouteNames.storybook),
              ),
              const SizedBox(height: 14),
              // Plan & usage (Gap A) — self-hides until a conversation
              // snapshot has populated PlanCubit, so it appears once the
              // user has opened any chat this session. The BlocBuilder owns
              // the trailing spacing so there's no empty gap when hidden.
              BlocBuilder<PlanCubit, PlanSnapshot?>(
                builder: (context, plan) => plan == null
                    ? const SizedBox.shrink()
                    : const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: PlanUsageCard(),
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
