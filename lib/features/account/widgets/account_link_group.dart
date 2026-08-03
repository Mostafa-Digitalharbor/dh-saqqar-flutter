import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/glass_card.dart';
import 'account_card_header.dart';

/// One destination inside an [AccountLinkGroup].
@immutable
class AccountLink {
  const AccountLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final String title;

  /// What this actually does, in one line.
  ///
  /// Required rather than optional on purpose. The screen these replaced was a
  /// stack of identical pills reading "Saqqar Apps", "Managed Odoo trial",
  /// "Data explorer" — names that mean something once you already know what
  /// they are, and nothing at all before that. If a destination cannot be
  /// described in a line, that is a signal about the destination, not a reason
  /// to leave the line out.
  final String subtitle;

  final VoidCallback onTap;

  /// Accent for the icon tile; defaults to the brand cyan.
  final Color? tint;
}

/// A titled card of related account destinations.
///
/// Replaces a flat run of full-width [GhostButton]s. Seven identical pills
/// stacked down a screen give the eye nothing to grab: no grouping, no
/// hierarchy, and no hint that "Manage devices" and "Buy tokens" are different
/// kinds of thing. Grouping them under headings turns one long list into three
/// short ones, which is the whole trick — a list of three is scanned, a list of
/// seven is skimmed and abandoned.
///
/// Rows are hairline-separated inside a single card rather than being cards of
/// their own, so a group reads as one object with parts.
class AccountLinkGroup extends StatelessWidget {
  const AccountLinkGroup({
    super.key,
    required this.links,
    this.title,
    this.icon,
    this.subtitle,
    this.tint,
  });

  /// Section heading. Omit it for a group of one.
  ///
  /// A heading above a single row means two icon tiles and two lines of title
  /// for one destination, which reads as a mistake rather than as structure —
  /// it looked exactly like that when this was first built. A lone row with a
  /// description and a chevron says everything the heading would have.
  final String? title;
  final IconData? icon;
  final String? subtitle;
  final Color? tint;
  final List<AccountLink> links;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return GlassCard(
      // Flat opaque Account backdrop → the backdrop blur has no visible
      // subject; dropping it removes a saveLayer with pixel-identical output.
      blur: false,
      padding: EdgeInsets.fromLTRB(16, title == null ? 4 : 16, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Padding(
              // Balances the card's asymmetric padding, which is tight on the
              // end side so the row chevrons sit near the edge.
              padding: const EdgeInsets.only(right: 8),
              child: AccountCardHeader(
                icon: icon ?? AppIcons.grid,
                title: title!,
                subtitle: subtitle,
                tint: tint,
              ),
            ),
            const SizedBox(height: 6),
          ],
          for (var i = 0; i < links.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: s.cardBorder, endIndent: 8),
            _LinkRow(link: links[i]),
          ],
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link});

  final AccountLink link;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final color = link.tint ?? s.brandCyan;

    return InkWell(
      onTap: link.onTap,
      borderRadius: AppRadius.buttonR,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
        child: Row(
          children: [
            // Same 30px tinted tile the card headers use, one step smaller —
            // so a row reads as subordinate to its heading rather than
            // competing with it.
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadius.buttonR,
              ),
              child: Icon(link.icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    link.title,
                    style: context.text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    link.subtitle,
                    // Two lines, not one: Arabic runs longer than English for
                    // the same sentence, and at a large text scale a single
                    // line would ellipsise the description away exactly for
                    // the users most likely to need it.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall
                        ?.copyWith(color: s.muted, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Mirrors automatically in RTL.
            Icon(AppIcons.chevronRight, size: 18, color: s.muted),
          ],
        ),
      ),
    );
  }
}
