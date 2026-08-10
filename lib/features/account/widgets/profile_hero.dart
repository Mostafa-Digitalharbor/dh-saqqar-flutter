import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/view_model/auth_cubit.dart';
import '../../billing/data/plan_copy.dart';
import '../../billing/view_model/plan_cubit.dart';
import 'plan_badge.dart';
import 'stats_line.dart';
import '../../../core/theme/app_icons.dart';

/// Identity card at the top of the Account tab.
///
/// Three regions separated by hairlines, in descending importance:
///   1. **Identity** — avatar, name, email, role chip, plan badge.
///   2. **Stats** — the four workspace counts, as figures rather than prose.
///   3. **Meta** — joined / last-login, the quietest thing on the card.
///
/// Before this split it was six muted lines stacked at roughly equal weight,
/// which made the counts (the only real data) read as footnotes. The product
/// attribution moved to the bottom of the screen, where a footer belongs.
///
/// All identity + counts come from [AuthCubit] — `username`/`email` from
/// `/auth/me/`, `isStaff`/`isSuperuser` to pick the role chip, and
/// [AuthCounts] to render the stats line. Falls back to a sample placeholder
/// when the user isn't hydrated yet so the card never renders empty.
///
/// [onLongPress] is the storybook easter egg — long-press the username to
/// open the dev showcase. Hidden because storybook is not a user feature.
class ProfileHero extends StatelessWidget {
  const ProfileHero({super.key, this.onLongPress});

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final authState = context.watch<AuthCubit>().state;
    final user = authState.user;
    final counts = authState.counts;

    final displayName = _displayName(context, user);
    final initial = _initial(displayName);
    final roleLabel = _roleLabel(context, user);
    // Gap A — paid plan badge beside the name (web shows "Pro" / "Max").
    // Hidden for Free (and when no snapshot has loaded yet).
    final plan = context.watch<PlanCubit>().state;
    // Localized via [PlanCopy.nameFor] like the other two badge sites — the
    // wire `plan_name` is English on both.
    final planBadgeName = (plan != null && plan.showBadge)
        ? PlanCopy.nameFor(context.tr, slug: plan.slug, fallback: plan.name)
        : null;

    return GlassCard(
      // Sits on the Account tab's flat opaque AmbientBackground, so the 14px
      // backdrop blur has no visible subject (blurring a uniform colour yields
      // the same colour). Dropping it removes a full-screen saveLayer per card
      // — the Account tab stacked ~6, the single biggest GPU cost on low-end
      // phones — with pixel-identical output.
      blur: false,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Identity ────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(initial: initial),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onLongPress: onLongPress,
                            behavior: HitTestBehavior.opaque,
                            // Plain Text, not MarqueeText. Django often sets
                            // `username = email`, so this line is frequently a
                            // long address and the marquee was meant to reveal
                            // it — but the marquee lays out TWO copies for its
                            // seamless loop, so mid-cycle the card reads
                            // "Mostafa Ahme … ahmed@x.com" and looks broken.
                            // The full address is spelled out verbatim in the
                            // EMAIL (LOGIN) field further down this same
                            // screen, so ellipsis costs the user nothing and
                            // the card stops moving on its own.
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ),
                        if (planBadgeName != null) ...[
                          const SizedBox(width: 8),
                          PlanBadge(name: planBadgeName, dense: true),
                        ],
                      ],
                    ),
                    if (user != null &&
                        user.email.isNotEmpty &&
                        user.email != displayName) ...[
                      const SizedBox(height: 3),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: s.muted),
                      ),
                    ],
                    const SizedBox(height: 8),
                    MiniChip(roleLabel),
                  ],
                ),
              ),
            ],
          ),

          // ── Stats ───────────────────────────────────────────────────
          // A rule above the counts is what turns this from six stacked
          // grey lines into two labelled regions: who you are, then what
          // you have.
          const SizedBox(height: 16),
          _Hairline(),
          const SizedBox(height: 14),
          StatsLine(
            conversations: counts.conversations,
            credentials: counts.credentials,
            approvals: counts.approvals,
            artifacts: counts.artifacts,
          ),

          // ── Meta footer ─────────────────────────────────────────────
          // Joined / last-login used to sit directly ABOVE the counts in
          // the same muted style, so the timestamps competed with the only
          // real numbers on the card. Demoted to a footer under its own
          // rule, where a timestamp belongs.
          if (user != null &&
              (user.dateJoined != null || user.lastLogin != null)) ...[
            const SizedBox(height: 14),
            _Hairline(),
            const SizedBox(height: 10),
            _AccountMetaLine(user: user),
          ],
        ],
      ),
    );
  }

  /// Prefer the full name (Gap I) → username → email local-part, and finally
  /// a localized sample so the card never renders empty during bootstrap.
  String _displayName(BuildContext context, AuthUser? user) {
    if (user == null) return context.tr.sampleUsername;
    final name = user.displayName;
    if (name.isNotEmpty) return name;
    if (user.email.isNotEmpty) {
      final at = user.email.indexOf('@');
      return at > 0 ? user.email.substring(0, at) : user.email;
    }
    return context.tr.sampleUsername;
  }

  String _initial(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  String _roleLabel(BuildContext context, AuthUser? user) {
    if (user == null) return context.tr.standardUser;
    if (user.isSuperuser) return context.tr.adminUser;
    if (user.isStaff) return context.tr.staffUser;
    return context.tr.standardUser;
  }
}

/// Gradient initial avatar with a soft outer ring.
///
/// The ring is a second circle behind the disc rather than a border on it:
/// a border eats into the 64 px gradient and makes the initial look
/// off-centre at small text scales.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      width: 68,
      height: 68,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // 0.10 was invisible against the light card. This reads as a halo in
        // both themes without competing with the gradient disc inside it.
        color: s.brandCyan.withValues(alpha: context.isDark ? 0.18 : 0.16),
      ),
      child: Container(
        width: 58,
        height: 58,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.vivid,
        ),
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// 1 px rule used to separate the card's three regions.
class _Hairline extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: context.saqqar.cardBorder);
}

/// Web-parity meta line: "Joined 2026-05-18 · Last login 2026-05-18 22:39".
///
/// Renders each piece inside a [Wrap] so on narrow phones the "Last login"
/// segment can flow to a second line instead of clipping. Hidden entirely
/// when both timestamps are null (handled by the caller).
class _AccountMetaLine extends StatelessWidget {
  const _AccountMetaLine({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final style = context.text.labelSmall?.copyWith(
      color: s.muted,
      fontWeight: FontWeight.w500,
      height: 1.4,
    );

    final joined = user.dateJoined;
    final lastLogin = user.lastLogin;

    final parts = <String>[
      if (joined != null)
        '${context.tr.accountJoinedLabel} ${AppDateFormat.date(context, joined)}',
      if (lastLogin != null)
        '${context.tr.accountLastLoginLabel} ${AppDateFormat.dateTime(context, lastLogin)}',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            AppIcons.clock,
            size: 13,
            color: s.muted.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 6),
        // Wrap so the "Last login" segment flows to a second line on narrow
        // phones instead of clipping; Expanded so the Wrap gets a bounded
        // width to lay out against.
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              for (var i = 0; i < parts.length; i++) ...[
                if (i > 0)
                  Text('·',
                      style: style?.copyWith(
                          color: s.muted.withValues(alpha: 0.7))),
                Text(parts[i], style: style),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
