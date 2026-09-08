import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/auto_direction_text.dart';
import '../../../shared/widgets/colored_icon_box.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../inbox/data/approval_models.dart' show Approval;
import '../data/approval_grouping.dart';
import 'accent_card_chrome.dart';

/// One card standing in for several identical approvals.
///
/// Rendered instead of N copies of `ChatApprovalCard` when the agent raises a
/// burst of same-shape writes. The two headline buttons resolve the whole run
/// in one tap each — the app previously had no way to reject a run at all,
/// though the API has supported `scope: "batch"` on a reject the whole time.
///
/// Nothing is hidden by the collapse: "Show individual" expands to every
/// request with its own Approve and Reject, so a user who wants to let five of
/// six through still can. That is why the group is a summary rather than a
/// replacement.
class ChatGroupedApprovalCard extends StatefulWidget {
  const ChatGroupedApprovalCard({
    super.key,
    required this.group,
    required this.subtitle,
    required this.promptOf,
    required this.onApproveAll,
    required this.onRejectAll,
    required this.onApproveOne,
    required this.onRejectOne,
  });

  final ApprovalGroup group;

  /// Plain-language line under the title — the first request's own prompt
  /// where the server sent one, else the operation and model it targets.
  final String subtitle;

  /// Label for one row inside the expanded list.
  final String Function(Approval) promptOf;

  final ValueChanged<Approval> onApproveAll;
  final ValueChanged<Approval> onRejectAll;
  final ValueChanged<Approval> onApproveOne;
  final ValueChanged<Approval> onRejectOne;

  @override
  State<ChatGroupedApprovalCard> createState() =>
      _ChatGroupedApprovalCardState();
}

class _ChatGroupedApprovalCardState extends State<ChatGroupedApprovalCard> {
  bool _expanded = false;

  void _fire(ValueChanged<Approval> action, Approval approval) {
    unawaited(HapticFeedback.mediumImpact());
    action(approval);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    final group = widget.group;
    final count = group.count;

    return AccentCardChrome(
      accent: s.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ColoredIconBox(
                icon: AppIcons.shieldAlert,
                color: s.warning,
                size: AppIconSizes.cardHeader,
                radius: AppRadius.small,
                iconSize: AppIconSizes.boxGlyphCard,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: AutoDirectionText(
                  tr.similarRequestsCount(count),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: s.text,
                    letterSpacing: AppLetterSpacing.title,
                  ),
                ),
              ),
              MiniChip('$count', color: s.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          AutoDirectionText(
            widget.subtitle,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium?.copyWith(
              color: s.muted,
              height: AppLineHeights.body,
            ),
          ),
          const SizedBox(height: AppSpacing.s14),
          _DecisionButtons(
            approveLabel: tr.approveAllN(count),
            rejectLabel: tr.rejectAllN(count),
            onApprove: () => _fire(widget.onApproveAll, group.first),
            onReject: () => _fire(widget.onRejectAll, group.first),
          ),
          const SizedBox(height: AppSpacing.s8),
          // The same disclosure the single card carries, for the same reason:
          // a batch decision also pre-approves future writes of this shape.
          Text(
            tr.preApprovalTip,
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              height: AppLineHeights.compact,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _expanded ? AppIcons.chevronUp : AppIcons.chevronDown,
                  size: AppIconSizes.inline,
                  color: s.muted,
                ),
                const SizedBox(width: AppSpacing.s4),
                Text(
                  _expanded ? tr.hideIndividual : tr.showIndividual,
                  style: context.text.labelMedium?.copyWith(
                    color: s.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (_expanded)
            for (final approval in group.approvals)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s10),
                child: _IndividualRow(
                  label: widget.promptOf(approval),
                  onApprove: () => _fire(widget.onApproveOne, approval),
                  onReject: () => _fire(widget.onRejectOne, approval),
                ),
              ),
        ],
      ),
    );
  }
}

/// "Reject all 3" beside "Approve all 3" — side by side where both fit, one
/// above the other where they do not.
///
/// Neither button takes an icon, unlike the single card and unlike the rest
/// of the app: these two labels carry a NUMBER, and the number is the entire
/// reason the button exists. "Approve all" without it is a different and much
/// vaguer promise.
///
/// The stacking is not defensive tidiness. On a real 360 px phone in Arabic,
/// "وافق على الكل (3)" rendered as "وافق على الكل (…)" — the count clipped
/// off the end of the button it belongs to. Ellipsis is the wrong answer for
/// a label whose last glyph is the decision; the row simply is not wide
/// enough for two of these on a phone, and pretending otherwise is what put
/// the "…" on screen. So the labels are measured against the width actually
/// available and the layout gives way instead of the text.
class _DecisionButtons extends StatelessWidget {
  const _DecisionButtons({
    required this.approveLabel,
    required this.rejectLabel,
    required this.onApprove,
    required this.onReject,
  });

  final String approveLabel;
  final String rejectLabel;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  /// Width one of these labels needs, including the padding its button puts
  /// around it. `labelLarge` at w600 is what both button widgets render with.
  double _needed(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: (context.text.labelLarge ?? const TextStyle())
            .copyWith(fontWeight: FontWeight.w600),
      ),
      textDirection: Directionality.of(context),
      maxLines: 1,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width + AppSpacing.s18 * 2;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - AppSpacing.s10) / 2;
        final fits = _needed(context, approveLabel) <= half &&
            _needed(context, rejectLabel) <= half;

        final reject = GhostButton(label: rejectLabel, onPressed: onReject);
        final approve = PrimaryButton(
          label: approveLabel,
          onPressed: onApprove,
          expand: !fits,
        );

        if (fits) {
          return Row(
            children: [
              Expanded(child: reject),
              const SizedBox(width: AppSpacing.s10),
              Expanded(child: approve),
            ],
          );
        }
        // Stacked, and the primary goes on top: with the buttons full-width
        // the eye lands on the first row, and that should be the one the user
        // most often wants.
        return Column(
          children: [
            SizedBox(width: double.infinity, child: approve),
            const SizedBox(height: AppSpacing.s8),
            SizedBox(width: double.infinity, child: reject),
          ],
        );
      },
    );
  }
}

/// One request inside an expanded group: what it does, and its own two
/// decisions. Stacked rather than laid out in a single row — an Odoo prompt
/// is a sentence, and squeezing it beside two buttons on a phone leaves room
/// for about three words.
class _IndividualRow extends StatelessWidget {
  const _IndividualRow({
    required this.label,
    required this.onApprove,
    required this.onReject,
  });

  final String label;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s10),
      decoration: BoxDecoration(
        color: s.surface2,
        border: Border.all(color: s.border),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AutoDirectionText(
            label,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(color: s.text),
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: context.tr.reject,
                  icon: AppIcons.close,
                  onPressed: onReject,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: GhostButton(
                  label: context.tr.approve,
                  icon: AppIcons.check,
                  onPressed: onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
