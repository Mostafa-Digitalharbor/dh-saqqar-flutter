import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../demo/saqqar_demo_data.dart';
import 'attachment_chip.dart';
import 'chat_send_button.dart';

/// Brief §4.5 composer — two-row layout inside a single rounded pill:
///
///   ┌──────────────────────────────────────────────────────┐
///   │ Message Saqqar…                                      │  ← textarea
///   ├──────────────────────────────────────────────────────┤
///   │ 📎    ✦ Deep think    🛡 Auto-approve         [ → ]  │  ← bar
///   └──────────────────────────────────────────────────────┘
///
/// The bar splits the chat controls (attach + deep think + auto-approve)
/// from Send (gradient circle) so the user sees them as siblings of the
/// message, not the message itself. Matches the desktop `composer-bar`.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.attachment,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.onSend,
    required this.deepThink,
    required this.autoApprove,
    required this.onDeepThinkChanged,
    required this.onAutoApproveChanged,
    this.onStop,
    this.stopping = false,
    this.focusNode,
  });

  final TextEditingController controller;

  /// Optional focus node. Plumbed through so other surfaces (e.g. the
  /// empty-chat suggestion grid) can request keyboard focus after seeding
  /// the composer with a starter prompt.
  final FocusNode? focusNode;

  /// The currently staged attachment — null when no file is picked.
  /// Renders the [AttachmentChip] row above the pill when set.
  final DemoAttachment? attachment;

  /// Tapped on the paperclip icon. The chat screen opens the native
  /// file picker rooted at Photos / Files.
  final VoidCallback onAttach;

  /// Tapped on the "x" next to the staged attachment chip. Clears
  /// [attachment] back to null.
  final VoidCallback onRemoveAttachment;

  final VoidCallback? onSend;

  /// Two persistent chat-level toggles live in the composer bar so the
  /// AppBar can stay focused on identity (Saqqar wordmark + page label
  /// + agent pulse). Web parity for `deepThinkToggle` + `autoApproveToggle`.
  final bool deepThink;
  final bool autoApprove;
  final ValueChanged<bool> onDeepThinkChanged;
  final ValueChanged<bool> onAutoApproveChanged;

  /// When non-null the send button morphs into a Stop control — the chat
  /// screen passes a real callback while `_isThinking` so the user can
  /// cancel an in-flight agent reply.
  final VoidCallback? onStop;

  /// Optimistic stop-in-flight state. While true the Stop button shows a
  /// small spinner and becomes non-interactive so the user knows the cancel
  /// is propagating.
  final bool stopping;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: s.surface,
          border: Border(top: BorderSide(color: s.border)),
        ),
        child: ResponsiveContent(
          maxWidth: 980,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (attachment != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: AttachmentChip(attachment: attachment!),
                        ),
                      ),
                      IconButton(
                        onPressed: onRemoveAttachment,
                        icon: Icon(AppIcons.close, color: s.muted, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: context.tr.removeAttachment,
                      ),
                    ],
                  ),
                ),
              // ── Composer pill (textarea + bar) ─────────────────────
              DecoratedBox(
                decoration: BoxDecoration(
                  color: s.surface2,
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  border: Border.all(color: s.cardBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Top row: textarea ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        style: context.text.bodyMedium?.copyWith(
                          fontSize: 15,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: onStop != null
                              ? context.tr.composerBusy
                              : context.tr.composerHint,
                          hintStyle: context.text.bodyMedium?.copyWith(
                            color: s.muted,
                            fontSize: 15,
                            fontStyle: onStop != null
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          isCollapsed: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                    // ── Action bar: attach (start) + send (end) ────────
                    // Order swapped on 2026-05-19 per user feedback —
                    // attach/send sit right under the text input, with
                    // the toggle pills underneath them. Keeps the two
                    // primary actions (write + send) visually grouped.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: onAttach,
                            icon: Icon(AppIcons.attach,
                                color: s.muted, size: 20),
                            tooltip: context.tr.attachFiles,
                            visualDensity: VisualDensity.compact,
                          ),
                          const Spacer(),
                          ChatSendButton(
                            onPressed: onSend,
                            onStop: onStop,
                            stopping: stopping,
                          ),
                        ],
                      ),
                    ),
                    // ── Toggles row ────────────────────────────────────
                    // Toggles get their own line so the full Arabic
                    // labels ("التفكير العميق", "الموافقة التلقائية")
                    // are always readable, no ellipsis. Wrap so a very
                    // narrow screen can flow the second toggle down.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _ComposerToggle(
                            icon: AppIcons.lightbulb,
                            label: context.tr.deepThink,
                            value: deepThink,
                            activeColor: s.brandPurple,
                            onChanged: onDeepThinkChanged,
                          ),
                          _ComposerToggle(
                            // Auto-approve gets the track+thumb mini
                            // switch per spec §9 — reads as "always-on
                            // switch" rather than a one-shot tap, which
                            // matches the semantics (flag stays on
                            // until the user flips it).
                            hasTrack: true,
                            label: context.tr.autoApprove,
                            value: autoApprove,
                            activeColor: s.brandCyan,
                            onChanged: onAutoApproveChanged,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact toggle used inside the composer bar — two flavours per
/// spec §9:
///
///   • **icon flavour** (pass [icon]) — used by Deep think. Renders as
///     a pill with the icon + label, flips muted ↔ accent-tinted.
///   • **track+thumb flavour** ([hasTrack] = true) — used by
///     Auto-approve. Renders as label + mini-switch (26 × 14 track, 10
///     × 10 thumb that slides from start to end on toggle).
///
/// Whole row is one tap target either way so the label is part of the
/// hit area, not just the icon / switch.
class _ComposerToggle extends StatelessWidget {
  const _ComposerToggle({
    this.icon,
    this.hasTrack = false,
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  }) : assert(icon != null || hasTrack,
            'Either icon or hasTrack must be supplied');

  final IconData? icon;
  final bool hasTrack;
  final String label;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    if (hasTrack) {
      return Material(
        color: Colors.transparent,
        borderRadius: AppRadius.pillR,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: AppRadius.pillR,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Flexible so the label ellipsifies when the parent
                // pillarow is too narrow for both toggles + send.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: context.text.labelMedium?.copyWith(
                      color: value ? activeColor : s.muted,
                      fontSize: 12,
                      fontWeight:
                          value ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _MiniSwitch(value: value, activeColor: activeColor),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.pillR,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: AppRadius.pillR,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: value
                ? activeColor.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: AppRadius.pillR,
            border: Border.all(
              color: value
                  ? activeColor.withValues(alpha: 0.40)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: value ? activeColor : s.muted),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: context.text.labelMedium?.copyWith(
                    color: value ? activeColor : s.muted,
                    fontSize: 12,
                    fontWeight: value ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spec §9 — 26 × 14 track with a 10 × 10 thumb that slides from start
/// (off) to end (on). Used by the auto-approve composer toggle. Kept
/// private to this file because the look is hand-tuned to nestle into
/// the composer bar (a Material `Switch` would be too tall + chunky).
class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value, required this.activeColor});

  final bool value;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return SizedBox(
      width: 26,
      height: 14,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: value
                  ? activeColor.withValues(alpha: 0.85)
                  : s.surface3,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: value ? activeColor : s.cardBorder,
                width: 1,
              ),
            ),
          ),
          AnimatedPositionedDirectional(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            top: 1,
            start: value ? 13 : 1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: value ? Colors.white : s.muted,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
