import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/auto_direction_text.dart';
import '../../../shared/widgets/capped_scroll_list.dart';
import '../../../shared/widgets/danger_callout.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/chat_view_models.dart';
import '../../../core/theme/app_radius.dart';
import '../../inbox/data/approval_models.dart'
    show ApprovalActionType, kDeleteOperation;
import 'accent_card_chrome.dart';
import 'email_approval_preview.dart';
import '../../../shared/widgets/colored_icon_box.dart';

/// Approval card shown inside the chat "Pending approvals" sheet.
/// Neutral surface + 4 px amber start-side stripe + Reject / Approve actions.
///
/// The friendly title ("Create 6 × Manufacturing Order", Gap E) is always
/// visible; the raw `payload` map stays collapsed behind a "Show details"
/// toggle so non-technical users aren't faced with a JSON dump by default.
class ChatApprovalCard extends StatefulWidget {
  const ChatApprovalCard({
    super.key,
    required this.approval,
    required this.onApprove,
    required this.onReject,
    this.onApproveAllSimilar,
  });

  final ChatApproval approval;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  /// Sends the decision with `scope: "batch"` — resolves every pending
  /// sibling of the same shape in this conversation AND pre-approves future
  /// ones. Null on surfaces that don't support it (the rail drawer), which
  /// hides the action rather than showing a dead control.
  final VoidCallback? onApproveAllSimilar;

  @override
  State<ChatApprovalCard> createState() => _ChatApprovalCardState();
}

class _ChatApprovalCardState extends State<ChatApprovalCard> {
  bool _showDetails = false;

  /// Whether this approval deletes Odoo records — the one action here that
  /// can't be undone. Read off the SERVER's `payload.operation`, never
  /// guessed from the prompt text.
  bool get _isDestructiveDelete =>
      widget.approval.payload['operation'] == kDeleteOperation;

  /// Approve.
  ///
  /// A destructive delete used to open a type-to-confirm dialog here, and the
  /// user had to reproduce "delete 12" before it would fire. That was removed
  /// on 2026-08-17 (product decision, matching the web's live design) for two
  /// reasons, in order of how much they cost:
  ///
  ///   * It did not work. The phrase was matched and then dropped —
  ///     `ApprovalsApi.decide` had no `confirm_phrase` parameter — so the POST
  ///     went out bare and the backend answered 400. Every delete in the app
  ///     was unresolvable, and the dialog only made that failure slower.
  ///   * It was too hard for real users, which is what caused the reported
  ///     outage: a user typed the correct phrase into the *composer* many
  ///     times, where it could never reach the decision endpoint.
  ///
  /// The consent now lives where the user is already looking — the record list
  /// above and the count inside the button's own label — and the phrase the
  /// server asked for is echoed back for them at the call site.
  void _approve() {
    unawaited(HapticFeedback.mediumImpact());
    widget.onApprove();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final approval = widget.approval;
    // Task 4 — gated on the server's own `action_type` now that it declares
    // `send_email` explicitly, rather than inferring "this looks like an
    // email" purely from which payload keys happen to be present.
    final email = approval.actionType == ApprovalActionType.sendEmail.wire
        ? EmailApprovalPreview.of(approval.payload)
        : null;
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
                  approval.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: s.text,
                    letterSpacing: AppLetterSpacing.title,
                  ),
                ),
              ),
              MiniChip(approval.risk, color: s.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          AutoDirectionText(
            approval.prompt,
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium?.copyWith(
              color: s.muted,
              height: AppLineHeights.body,
            ),
          ),
          // §9 — when the payload is an email, show it AS an email
          // (recipient / subject / body) rather than as key-value
          // chips. The raw payload stays available under "Show
          // details" below, so nothing is hidden, only laid out.
          if (email != null) email,
          // Gap E — raw payload collapsed by default behind a
          // "Show details" disclosure; the friendly title above is
          // enough for non-technical users.
          if (approval.payload.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showDetails = !_showDetails),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showDetails
                        ? AppIcons.chevronUp
                        : AppIcons.chevronDown,
                    size: AppIconSizes.inline,
                    color: s.muted,
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Text(
                    _showDetails
                        ? context.tr.hideDetails
                        : context.tr.showDetails,
                    style: context.text.labelMedium?.copyWith(
                      color: s.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (_showDetails) ...[
              const SizedBox(height: AppSpacing.s10),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  for (final entry in approval.payload.entries)
                    MiniChip(context.tr.keyValue(entry.key, entry.value)),
                ],
              ),
            ],
          ],
          // ── The records a delete would destroy ──────────────────────
          //
          // Shown unconditionally for a destructive delete, ABOVE the
          // buttons and outside the "Show details" toggle, because this is
          // the review the red button's single tap is consenting to. Putting
          // it behind a disclosure would mean the common path is one tap on
          // an irreversible action with nothing on screen but a count.
          if (_isDestructiveDelete && approval.deleteRecords.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            _DeleteRecordList(records: approval.deleteRecords),
          ],
          const SizedBox(height: AppSpacing.s14),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: context.tr.reject,
                  icon: AppIcons.close,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onReject();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                // A destructive delete gets a red button that names the
                // count — "Delete 12". The count is the informed consent
                // that used to live in the phrase the user had to type, and
                // it is the SERVER's `record_count`, never a client guess.
                //
                // Everything else keeps the singular "Approve". That card
                // cannot label a count: the backend has no `grouped_count`
                // field, and the number of siblings a batch clears is only
                // known from the decision RESPONSE, so "Approve all 6" here
                // would be a number the client invented.
                child: _isDestructiveDelete
                    ? GhostButton(
                        label: context.tr
                            .deleteApprovalAction(approval.recordCount ?? 1),
                        icon: AppIcons.trash,
                        tone: GhostButtonTone.danger,
                        onPressed: _approve,
                      )
                    : PrimaryButton(
                        label: context.tr.approve,
                        icon: AppIcons.check,
                        onPressed: _approve,
                      ),
              ),
            ],
          ),
          // Batch resolve — a separate, quieter action rather than the
          // primary button, because it does strictly more than the user
          // asked: it clears every pending sibling AND pre-approves
          // future writes of the same shape. Hidden for deletes (the
          // server 400s) and for approvals already covered by a scope.
          if (widget.onApproveAllSimilar != null &&
              approval.canBatchApprove) ...[
            const SizedBox(height: AppSpacing.s8),
            SizedBox(
              width: double.infinity,
              child: GhostButton(
                label: context.tr.approveAllSimilar,
                icon: AppIcons.check,
                onPressed: () {
                  unawaited(HapticFeedback.mediumImpact());
                  widget.onApproveAllSimilar!();
                },
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              context.tr.preApprovalTip,
              style: context.text.labelSmall?.copyWith(
                color: s.muted,
                height: AppLineHeights.compact,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The rows a destructive delete would destroy, listed for review.
///
/// Capped in height rather than in item count: a delete of 200 rows must not
/// push the buttons off the screen, and it must not silently show only the
/// first few either — "…and 188 more" hides exactly the records a user would
/// want to check. Scrolling keeps every row reachable while the decision
/// stays in view.
class _DeleteRecordList extends StatelessWidget {
  const _DeleteRecordList({required this.records});

  final List<String> records;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return DangerCallout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr.deleteApprovalRecordsHeader(records.length),
            style: context.text.labelSmall?.copyWith(
              color: s.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          CappedScrollList(
            itemCount: records.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s2),
              child: Text(
                records[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(color: s.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
