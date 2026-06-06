import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../demo/saqqar_demo_data.dart';
import 'attachment_chip.dart';
import 'chat_send_button.dart';
import 'voice_input_button.dart';

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
    required this.attachments,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.onPreviewAttachment,
    required this.onSend,
    required this.deepThink,
    required this.autoApprove,
    required this.onDeepThinkChanged,
    required this.onAutoApproveChanged,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onDiscardRecording,
    this.recording = false,
    this.transcribing = false,
    this.recordingElapsed = Duration.zero,
    this.onStop,
    this.stopping = false,
    this.focusNode,
    this.voiceEnabled = true,
  });

  final TextEditingController controller;

  /// Optional focus node. Plumbed through so other surfaces (e.g. the
  /// empty-chat suggestion grid) can request keyboard focus after seeding
  /// the composer with a starter prompt.
  final FocusNode? focusNode;

  /// Currently staged attachments — empty when nothing is picked. Each
  /// item renders as its own [AttachmentChip] in a wrap above the pill so
  /// the user can stage and review several files before sending.
  final List<DemoAttachment> attachments;

  /// Tapped on the paperclip icon. The chat screen opens the native
  /// file picker rooted at Photos / Files (multi-select).
  final VoidCallback onAttach;

  /// Tapped on the "x" next to a staged attachment chip. Receives the
  /// index of the chip to remove so the screen can drop just that file
  /// from its parallel `_attachments` / `_pendingFiles` lists.
  final ValueChanged<int> onRemoveAttachment;

  /// Tapped on a staged attachment thumbnail (the chip itself, not the
  /// remove badge). The screen wires this to open the local file —
  /// fullscreen image dialog for pictures, `OpenFilex` system viewer
  /// for everything else — so the user can verify they staged the right
  /// file before sending.
  final ValueChanged<int> onPreviewAttachment;

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

  /// True while the user is actively recording audio (mic open, no
  /// upload yet). Swaps the text field + action bar for the
  /// [RecordingOverlay] (timer + waveform + stop / discard). Other
  /// composer controls (attach, send, toggles) collapse so the user
  /// can't accidentally fire them mid-capture.
  final bool recording;

  /// True after the user tapped stop — the audio bytes are being
  /// uploaded to `/api/v1/transcribe/`. The overlay keeps showing but
  /// flips from "live capture" affordances to a "Transcribing…" line
  /// with a spinner. Discard is disabled (the bytes already left).
  final bool transcribing;

  /// Elapsed recording time fed in from the chat screen. Drives the
  /// monospace mm:ss readout inside the overlay.
  final Duration recordingElapsed;

  /// Mic-tap handler. The screen owns the recorder lifecycle so the
  /// 120 s hard cap, permission flow, and transcribe upload can all
  /// share the same place; the composer just renders the trigger.
  final VoidCallback onStartRecording;

  /// Tapped on the stop pill inside [RecordingOverlay]. Triggers the
  /// transcribe upload flow on the screen.
  final VoidCallback onStopRecording;

  /// Tapped on the discard X inside [RecordingOverlay]. Drops the audio
  /// buffer without uploading and returns to idle.
  final VoidCallback onDiscardRecording;

  /// Whether the voice/mic affordance is available on the caller's plan
  /// (Gap C). `false` hides the mic entirely for Free users — the server
  /// 403s `/transcribe/` for them, so showing the button would just be a
  /// dead end. Defaults to `true` so we never hide it on an unknown plan.
  final bool voiceEnabled;

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
              if (attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    children: [
                      for (var i = 0; i < attachments.length; i++)
                        _StagedAttachment(
                          attachment: attachments[i],
                          tooltip: context.tr.removeAttachment,
                          onRemove: () => onRemoveAttachment(i),
                          onPreview: () => onPreviewAttachment(i),
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
                child: recording || transcribing
                    // Recording / transcribing fully takes over the
                    // composer pill — text field hidden, action bar
                    // hidden, toggles hidden. User has exactly two
                    // affordances: stop (commit) or discard (cancel).
                    // Once transcribe lands, the screen flips
                    // `recording=false` and the text returns with the
                    // transcript appended.
                    ? RecordingOverlay(
                        elapsed: recordingElapsed,
                        transcribing: transcribing,
                        onStop: onStopRecording,
                        onDiscard: onDiscardRecording,
                      )
                    : Column(
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
                    //
                    // Active-mode badges (deep-think + auto-approve) sit
                    // just before the Send button when ON — small
                    // pulsing dots that make the elevated modes
                    // impossible to forget about (testers asked for an
                    // animated indicator next to Send on 2026-05-23).
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
                          // Mic — opens the recording overlay. Same
                          // gating as Send (offline / no env / mid-
                          // generation) so the user can't start a
                          // recording at a surface that isn't ready to
                          // accept the transcript. Hidden entirely when
                          // voice is locked on the plan (Gap C).
                          if (voiceEnabled)
                            VoiceInputButton(
                              enabled: onSend != null && onStop == null,
                              onStart: onStartRecording,
                            ),
                          const Spacer(),
                          if (deepThink) ...[
                            _ActiveModeBadge(
                              icon: AppIcons.lightbulb,
                              color: s.brandPurple,
                              tooltip: context.tr.deepThinkOn,
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (autoApprove) ...[
                            _ActiveModeBadge(
                              icon: AppIcons.shieldCheck,
                              color: s.brandCyan,
                              tooltip: context.tr.autoApproveOn,
                            ),
                            const SizedBox(width: 6),
                          ],
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

/// Composer-side staged attachment — the chip itself plus a small `×` button
/// in the top-right corner. Lets the user drop a single file from a batch
/// without losing the others (vs. the previous single-file row that had one
/// remove button at the trailing edge).
class _StagedAttachment extends StatelessWidget {
  const _StagedAttachment({
    required this.attachment,
    required this.onRemove,
    required this.onPreview,
    required this.tooltip,
  });

  final DemoAttachment attachment;
  final VoidCallback onRemove;
  final VoidCallback onPreview;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AttachmentChip(
          attachment: attachment,
          compact: true,
          onTap: onPreview,
        ),
        PositionedDirectional(
          top: -8,
          end: -8,
          child: Material(
            color: s.surface,
            shape: const CircleBorder(),
            elevation: 1,
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Tooltip(
                message: tooltip,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: s.border),
                  ),
                  child: Icon(AppIcons.close, size: 12, color: s.muted),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pulsing inline badge for an active chat-level mode (deep-think,
/// auto-approve). Sits just before the Send button so the user can't
/// miss that one of the elevated modes is engaged for this message —
/// the pulse is intentionally loud (1.0 ↔ 0.6 opacity, 1100 ms cycle)
/// because "I forgot auto-approve was ON" is a real footgun on a
/// production Odoo connection.
class _ActiveModeBadge extends StatefulWidget {
  const _ActiveModeBadge({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final String tooltip;

  @override
  State<_ActiveModeBadge> createState() => _ActiveModeBadgeState();
}

class _ActiveModeBadgeState extends State<_ActiveModeBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value; // 0 → 1 → 0
          // Outer ring fades in/out for the "breathing" cue; the inner
          // chip stays at full opacity so the icon remains legible at
          // every point in the cycle.
          final ringAlpha = 0.25 + (0.45 * t);
          return Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.14),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: ringAlpha),
                  blurRadius: 6 + (6 * t),
                  spreadRadius: 0.5 + (1.5 * t),
                ),
              ],
            ),
            child: Icon(widget.icon, size: 14, color: widget.color),
          );
        },
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
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!value);
          },
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
