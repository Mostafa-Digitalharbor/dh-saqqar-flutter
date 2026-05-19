import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/marquee_text.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/view_model/auth_cubit.dart';
import 'stats_line.dart';

/// Identity card at the top of the Account tab — gradient avatar, username
/// headline, role chip, compact stats line, and the
/// "Powered by Digital Harbor" footer.
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

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.vivid,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onLongPress: onLongPress,
                      behavior: HitTestBehavior.opaque,
                      // Django often sets `username = email` on register,
                      // so the headline below is frequently the user's
                      // full email — which doesn't fit next to the
                      // 64 px avatar on phones. Marquee so the user
                      // sees their whole identifier without cropping.
                      child: MarqueeText(
                        text: displayName,
                        alwaysScroll: true,
                        style: context.text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (user != null &&
                        user.email.isNotEmpty &&
                        user.email != displayName) ...[
                      const SizedBox(height: 2),
                      // alwaysScroll: true — even when the email
                      // appears to fit, force the right-to-left
                      // ticker so the user always sees the full
                      // address as it cycles past.
                      MarqueeText(
                        text: user.email,
                        alwaysScroll: true,
                        style:
                            context.text.bodySmall?.copyWith(color: s.muted),
                      ),
                    ],
                    const SizedBox(height: 6),
                    MiniChip(roleLabel),
                  ],
                ),
              ),
            ],
          ),
          if (user != null && (user.dateJoined != null || user.lastLogin != null)) ...[
            const SizedBox(height: 10),
            _AccountMetaLine(user: user),
          ],
          const SizedBox(height: 14),
          StatsLine(
            conversations: counts.conversations,
            credentials: counts.credentials,
            approvals: counts.approvals,
            artifacts: counts.artifacts,
          ),
          const SizedBox(height: 6),
          Text(
            context.tr.poweredByDigitalHarbor,
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Prefer the human-readable username; fall back to the email local-part
  /// (everything before `@`) and finally to a localized sample so the card
  /// never renders empty during bootstrap.
  String _displayName(BuildContext context, AuthUser? user) {
    if (user == null) return context.tr.sampleUsername;
    if (user.username.isNotEmpty) return user.username;
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

    return Wrap(
      spacing: 8,
      runSpacing: 2,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            Text('·', style: style?.copyWith(color: s.muted.withValues(alpha: 0.7))),
          Text(parts[i], style: style),
        ],
      ],
    );
  }
}
