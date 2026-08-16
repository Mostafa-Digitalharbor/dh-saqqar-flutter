import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/animations/typing_dots.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/saqqar_logo.dart';
import '../../../shared/widgets/title_trailing_row.dart';
import '../../chat/view_model/running_agents_cubit.dart';
import '../data/conversation_models.dart';
import '../view_model/conversations_cubit.dart';
import 'conversation_action.dart';
import 'conversation_actions_sheet.dart';
import 'conversation_row_menu.dart';

/// Card corner radius — a touch softer than the global row radius so each
/// conversation reads as a distinct, well-rounded card (design parity with
/// the Chats mock). The value lives in [AppRadius.conversationCard]; the alias
/// stays because this file references it a dozen times.
const BorderRadius _kCardRadius = AppRadius.conversationCardR;

/// Status driving the avatar ring, mirroring the Saqqar Design System's
/// `ConversationRow`: thinking (agent mid-run, cyan ring), live (recent,
/// green ring + pip), idle (no ring).
enum _ConvStatus { thinking, live, idle }

/// Single row in the conversation list — the Saqqar Design System's
/// `ConversationRow`: a status-ring gradient avatar carrying the
/// conversation's initial, title + last-message preview with the time inline,
/// and a meta row of plain icon+value items.
///
/// Every meta value here is REAL — never fabricated:
///   * [pendingApprovals] — real pending-approval count for this conversation,
///     grouped from the flat `/approvals/?status=pending` feed (passed in by
///     the screen). Drives the "N to approve" safety pill + the warning accent.
///   * [filesCount] — real produced-file count from the flat `/artifacts/`
///     feed. Hidden when zero.
///   * message count — real, from the conversation summary.
///   * project · environment — only shown when the list endpoint actually
///     carries it ([ConversationSummary.projectName] / `environmentName`);
///     omitted otherwise rather than invented.
///
/// The cyan "thinking" ring tracks the real running-agent set; the green
/// "live" ring tracks the real `updatedAt` recency.
class ConversationCard extends StatelessWidget {
  const ConversationCard({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onAction,
    this.pendingApprovals = 0,
    this.filesCount = 0,
  });

  final ConversationSummary conversation;
  final VoidCallback onTap;
  final ValueChanged<ConversationAction> onAction;

  /// Real pending-approval count for this conversation (0 = none).
  final int pendingApprovals;

  /// Real produced-file count for this conversation (0 = none).
  final int filesCount;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final isArchived = conversation.isArchived;
    final needsAttention = pendingApprovals > 0;
    final isPinned = context.select<ConversationsCubit, bool>(
      (cubit) =>
          cubit.state.data.dataOrNull?.pinnedIds.contains(conversation.id) ??
          false,
    );
    // Thinking when the agent is mid-run for this conversation; else live
    // when it was active recently; else idle. Sourced from EITHER the
    // server's `is_running` flag on the list summary (survives leaving the
    // chat, covers background runs) OR the in-session run tracker (immediate,
    // before the next list refresh lands).
    final localRunning = context.select<RunningAgentsCubit, bool>(
      (cubit) => cubit.state.contains(conversation.id),
    );
    final isThinking = localRunning || conversation.isRunning;
    final status = isThinking
        ? _ConvStatus.thinking
        : (conversation.isLive ? _ConvStatus.live : _ConvStatus.idle);

    final title = conversation.title.trim();
    final preview = _humanPreview(
      conversation.lastMessagePreview.trim(),
      context,
    );
    // Localized fallback only for the avatar's gradient seed when a
    // conversation has no title yet — never shown as text.
    final projectLabel = context.tr.defaultProjectLabel;

    // Real project · environment tag — only when the API actually supplied
    // it. Both parts are optional; we join whatever is present.
    final contextParts = <String>[
      if ((conversation.projectName ?? '').trim().isNotEmpty)
        conversation.projectName!.trim(),
      if ((conversation.environmentName ?? '').trim().isNotEmpty)
        conversation.environmentName!.trim(),
    ];
    final envLabel = contextParts.isEmpty ? null : contextParts.join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: () async {
          final action = await ConversationActionsSheet.show(
            context,
            conversation: conversation,
            isPinned: isPinned,
          );
          if (action != null) onAction(action);
        },
        borderRadius: _kCardRadius,
        child: Opacity(
          opacity: isArchived ? 0.7 : 1,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: needsAttention
                  ? Color.alphaBlend(
                      s.warning.withValues(alpha: 0.05),
                      s.cardBg,
                    )
                  : s.cardBg,
              borderRadius: _kCardRadius,
              // Pending cards carry a warm hairline so the "needs approval"
              // state reads at a glance; the rest get the calm card hairline.
              border: Border.all(
                color: needsAttention
                    ? s.warning.withValues(alpha: 0.35)
                    : s.cardBorder,
              ),
              boxShadow: s.glassShadow,
            ),
            child: Stack(
              children: [
                // Attention accent bar (inline-start) when actions await.
                if (needsAttention)
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 3, color: s.warning),
                  ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    needsAttention ? 19 : 16,
                    16,
                    8,
                    16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ConversationAvatar(
                        // The design keys the avatar on project || title; the
                        // summary rarely carries a project, so we fall through
                        // to the title for the varied gradient + initial.
                        seedText: title.isEmpty ? projectLabel : title,
                        status: status,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Time sits inline at the end of the title line,
                            // matching the design's ConversationRow.
                            // `TitleTrailingRow` keeps the stamp from starving
                            // the title on a 320 px screen — see its doc.
                            TitleTrailingRow.stamp(
                              leading: [
                                if (isPinned) ...[
                                  Icon(
                                    AppIcons.pin,
                                    size: 13,
                                    color: s.brandCyan,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                              ],
                              title: Text(
                                title.isEmpty
                                    ? context.tr.untitledConversation
                                    : title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              stamp: AppDateFormat.relative(
                                context,
                                conversation.updatedAt,
                              ),
                              stampStyle: context.text.labelMedium?.copyWith(
                                color: s.muted,
                              ),
                            ),
                            // While the agent is running for THIS chat the
                            // preview line becomes a live "Saqqar is working"
                            // indicator with bouncing cyan dots; it reverts to
                            // the normal last-message preview the moment the
                            // reply lands (isThinking tracks RunningAgentsCubit).
                            if (isThinking) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  TypingDots(
                                    color: s.brandCyan,
                                    dotSize: 5,
                                    bounce: true,
                                  ),
                                  const SizedBox(width: 8),
                                  // Brand wordmark stands in for the word
                                  // "Saqqar" so the indicator reads
                                  // "[SAQQÂR] is working now".
                                  const SaqqarLogo(height: 15),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      context.tr.saqqarWorkingNow,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.bodySmall?.copyWith(
                                        color: s.brandCyan,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (preview.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodySmall?.copyWith(
                                  color: s.muted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            // Meta is a vertical stack of up to three dedicated
                            // lines (design request 2026-07-06) so a card that
                            // needs approval reads cleanly top-to-bottom instead
                            // of wrapping the badge and tag onto one row:
                            //   1. pending-approval safety badge
                            //   2. project · environment ("where this runs")
                            //   3. counts — messages + produced files
                            // Line 1 — pending-approval badge (real), alone.
                            if (pendingApprovals > 0)
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: _WarnPill(
                                  label: context.tr.toApprove(pendingApprovals),
                                ),
                              ),
                            // Line 2 — project · environment (only when real).
                            // Flexible so a long tag ellipsizes to the available
                            // width instead of overflowing on narrow screens.
                            if (envLabel != null)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: pendingApprovals > 0 ? 6 : 0,
                                ),
                                child: _MetaInline(
                                  icon: AppIcons.github,
                                  label: envLabel,
                                  flexible: true,
                                ),
                              ),
                            // Line 3 — counts: messages + produced files, on a
                            // dedicated row beneath the project/environment.
                            Padding(
                              padding: EdgeInsets.only(
                                top: (pendingApprovals > 0 || envLabel != null)
                                    ? 6
                                    : 0,
                              ),
                              // `Wrap`, not `Row`: a Row hands these unbounded
                              // width, so `_MetaInline`'s ellipsis never
                              // engages and the pair overflowed by 2.6 px at
                              // 320 px / 1.3× text once both counts reached
                              // four digits. Ellipsis would be the wrong cure
                              // anyway — a truncated "13…" reads as a real
                              // number. Wrapping keeps both counts legible in
                              // full and drops the file count onto its own
                              // line, which is the same stacked-lines
                              // treatment lines 1 and 2 already use.
                              child: Wrap(
                                spacing: 14,
                                runSpacing: 4,
                                children: [
                                  // Message count (real).
                                  _MetaInline(
                                    icon: AppIcons.chats,
                                    label: '${conversation.messageCount}',
                                  ),
                                  // File count (real) — hidden when none.
                                  if (filesCount > 0)
                                    _MetaInline(
                                      icon: AppIcons.fileText,
                                      label: '$filesCount',
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Overflow menu — trailing, top-aligned, mirroring the
                      // design's ConversationRow `onOverflow` affordance.
                      ConversationRowMenu(
                        onAction: onAction,
                        isPinned: isPinned,
                        isArchived: isArchived,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The last-message preview, or a localized stand-in when the backend's
/// preview is a machine payload rather than something a person wrote.
///
/// `last_message_preview` is whatever the last message contained, and when
/// that message is a tool result or an approval request it is raw JSON. The
/// conversations list was rendering it verbatim — real users saw
/// `{"status": "approval_required", "app…` as the summary of their chat.
///
/// Detection is deliberately narrow: only text that OPENS as JSON is
/// replaced. A message that merely mentions a brace, or quotes a snippet
/// mid-sentence, is still the user's own content and stays untouched.
String _humanPreview(String raw, BuildContext context) {
  if (raw.isEmpty) return raw;
  // Model control-token envelope — `<｜｜DSML｜tool_calls｜>…`.
  //
  // Those bars are U+FF5C FULLWIDTH VERTICAL LINE, not ASCII `|`: they are
  // the special tokens the model wraps a tool call in, and the backend copies
  // whatever the last message held into `last_message_preview` verbatim. When
  // the newest message is a tool call — which is most of the time while an
  // agent is mid-run — that envelope is what the user reads as the summary of
  // their chat. Caught on a live conversation, whose card read
  // `<｜｜DSML｜tool_calls｜>` for the whole run.
  //
  // Keyed on the fullwidth bar rather than the tag name: `DSML` is one
  // model's vocabulary and would change with the model, whereas U+FF5C in a
  // string that opens with `<` is a control token in any of them — it does
  // not occur in Arabic or English prose.
  if (raw.startsWith('<') && raw.contains('｜')) {
    return context.tr.conversationPreviewUnavailable;
  }
  final first = raw[0];
  if (first != '{' && first != '[') return raw;
  // A bare "{" that never closes is prose, not a payload.
  final looksStructured = raw.contains('":') || raw.contains('" :');
  if (!looksStructured) return raw;
  return context.tr.conversationPreviewUnavailable;
}

/// Distinct calm gradient per conversation, derived from its project/title —
/// ports the Saqqar Design System's `gradFor`. Palette lives in
/// [AppColors.avatarGradients] so the brand hex has a single home.
List<Color> _gradFor(String s) {
  var h = 0;
  for (var i = 0; i < s.length; i++) {
    h = (h * 31 + s.codeUnitAt(i)) & 0xffffffff;
  }
  const grads = AppColors.avatarGradients;
  return grads[h % grads.length];
}

/// First Latin or Arabic letter of [s], uppercased; `#` when none.
String _initialOf(String s) {
  final t = s.trim();
  final m = RegExp(r'[A-Za-z؀-ۿ]').firstMatch(t);
  return m == null ? '#' : m.group(0)!.toUpperCase();
}

/// Status-ring gradient identity disc carrying the conversation's initial.
/// Ports the design's avatar: a 2px ring (cyan when thinking, green when
/// live, transparent when idle) hugging a 46px gradient disc, with a green
/// presence pip in the live state.
class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.seedText, required this.status});

  final String seedText;
  final _ConvStatus status;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final grad = _gradFor(seedText);
    final ring = switch (status) {
      _ConvStatus.thinking => s.brandCyan,
      _ConvStatus.live => s.success,
      _ConvStatus.idle => Colors.transparent,
    };
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: 2),
          ),
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: grad,
              ),
            ),
            child: Text(
              _initialOf(seedText),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                height: 1.1,
              ),
            ),
          ),
        ),
        if (status == _ConvStatus.live)
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.success,
                border: Border.all(color: s.cardBg, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}

/// Soft warning pill — the pending-approvals safety badge.
class _WarnPill extends StatelessWidget {
  const _WarnPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: s.warning.withValues(alpha: 0.14),
        borderRadius: AppRadius.pillR,
        border: Border.all(color: s.warning.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.shieldAlert, size: 12, color: s.warning),
          const SizedBox(width: 5),
          // `Flexible` + ellipsis, matching [_MetaInline]. `mainAxisSize.min`
          // does NOT stop a child exceeding the incoming constraint — it only
          // stops the Row from expanding — so an unbounded `Text` here
          // overflowed the card by ~2 px at 320 px wide once the count went
          // double-digit (the label is uppercase with 0.6 letter-spacing, so
          // it grows faster than it looks). Shrinking beats clipping: the
          // count is the load-bearing part and it sits at the start.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: 10,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: s.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain inline meta item — bare icon + value, no chip fill. Mirrors the
/// design's ConversationRow meta row, which uses unfilled inline runs rather
/// than filled chips. When [flexible] is true the (potentially long) project ·
/// environment tag ellipsizes to whatever width is actually available instead
/// of forcing a fixed-width row — keeping the meta line overflow-proof on any
/// screen size.
class _MetaInline extends StatelessWidget {
  const _MetaInline({
    required this.icon,
    required this.label,
    this.flexible = false,
  });

  final IconData icon;
  final String label;
  final bool flexible;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: context.text.labelMedium?.copyWith(color: s.muted),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: s.muted),
        const SizedBox(width: 5),
        // Flexible lets a long label shrink/ellipsize within the Wrap line's
        // available width; short labels (counts) keep their natural size.
        if (flexible) Flexible(child: text) else text,
      ],
    );
  }
}
