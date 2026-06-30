import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../chat/view_model/running_agents_cubit.dart';
import '../data/conversation_models.dart';
import '../view_model/conversations_cubit.dart';
import 'conversation_action.dart';
import 'conversation_actions_sheet.dart';
import 'conversation_row_menu.dart';

/// A conversation counts as "live" (green status ring) when it was active
/// within this window — mirrors the Chats screen's triage signal. Kept local
/// so the card stays decoupled from the screen file.
const Duration _kLiveWindow = Duration(hours: 2);

/// Card corner radius — a touch softer than the global row radius so each
/// conversation reads as a distinct, well-rounded card (design parity with
/// the Chats mock).
const BorderRadius _kCardRadius = BorderRadius.all(Radius.circular(16));

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
    // when it was active recently; else idle.
    final isThinking = context.select<RunningAgentsCubit, bool>(
      (cubit) => cubit.state.contains(conversation.id),
    );
    final status = isThinking
        ? _ConvStatus.thinking
        : (DateTime.now().difference(conversation.updatedAt) <= _kLiveWindow
            ? _ConvStatus.live
            : _ConvStatus.idle);

    final title = conversation.title.trim();
    final preview = conversation.lastMessagePreview.trim();
    final isAr = context.locale.languageCode == 'ar';
    // Localized fallback only for the avatar's gradient seed when a
    // conversation has no title yet — never shown as text.
    final projectLabel = isAr ? 'الافتراضي' : 'Default';

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
                      s.warning.withValues(alpha: 0.05), s.cardBg)
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (isPinned) ...[
                                  Icon(Icons.push_pin,
                                      size: 13, color: s.brandCyan),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    title.isEmpty
                                        ? context.tr.untitledConversation
                                        : title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Time sits inline at the end of the title
                                // line, matching the design's ConversationRow.
                                Text(
                                  AppDateFormat.relative(
                                      context, conversation.updatedAt),
                                  style: context.text.labelMedium?.copyWith(
                                    color: s.muted,
                                  ),
                                ),
                              ],
                            ),
                            if (preview.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodySmall
                                    ?.copyWith(color: s.muted),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Pending-approval safety badge (real).
                                if (pendingApprovals > 0)
                                  _WarnPill(
                                    label: context.tr.toApprove(pendingApprovals),
                                  ),
                                // Project · environment (only when real).
                                // Flexible so a long tag ellipsizes to the
                                // available width instead of forcing a fixed
                                // 170px row that overflows on narrow screens.
                                if (envLabel != null)
                                  _MetaInline(
                                    icon: AppIcons.github,
                                    label: envLabel,
                                    flexible: true,
                                  ),
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

/// Distinct calm gradient per conversation, derived from its project/title —
/// ports the Saqqar Design System's `AVATAR_GRADS` + `gradFor`.
const List<List<Color>> _avatarGrads = [
  [Color(0xFF1F3C88), Color(0xFF06B6D4)],
  [Color(0xFF0E7490), Color(0xFF22D3EE)],
  [Color(0xFF5B21B6), Color(0xFF8B5CF6)],
  [Color(0xFF155E63), Color(0xFF10B981)],
  [Color(0xFF1E3A8A), Color(0xFF6366F1)],
  [Color(0xFF0F766E), Color(0xFF2DD4BF)],
];

List<Color> _gradFor(String s) {
  var h = 0;
  for (var i = 0; i < s.length; i++) {
    h = (h * 31 + s.codeUnitAt(i)) & 0xffffffff;
  }
  return _avatarGrads[h % _avatarGrads.length];
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
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: s.warning,
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
