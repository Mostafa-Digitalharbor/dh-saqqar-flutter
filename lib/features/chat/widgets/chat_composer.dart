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
///   │ ＋  📎  🎤                              [badges] [→] │  ← bar
///   ├──────────────────────────────────────────────────────┤
///   │ ✦ Task prep      🛡 Auto-approve                     │  ← toggles
///   └──────────────────────────────────────────────────────┘
///
/// The bar splits the chat controls from Send (gradient circle) so the user
/// sees them as siblings of the message, not the message itself. Matches the
/// web's reshaped `composer-bar`:
///
///   * `＋` opens the **Saqqar tools** sheet (web's `#shadowMenuButton`).
///   * The paperclip is GONE (2026-08-06). It used to stay on mobile on the
///     reasoning that hiding upload behind a menu costs a tap — but the `＋`
///     sheet's first row is "Upload file", so the two controls sat side by
///     side firing the same action. Two doors into one room read as two
///     different rooms. [onAttach] survives as the sheet row's callback.
///   * The slash (`/`) button moved INTO the tools sheet: it is a rarely-used
///     power affordance, and the web has no composer equivalent at all.
///   * Deep think is gone entirely (web parity — the backend escalates hard
///     tasks on its own), replaced by **Task prep**.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.attachments,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.onPreviewAttachment,
    required this.onSend,
    this.onTools,
    required this.taskPrep,
    required this.autoApprove,
    required this.onTaskPrepChanged,
    required this.onAutoApproveChanged,
    this.taskPrepAvailable = true,
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
  /// item renders as its own [AttachmentChip] in a single horizontally
  /// scrolling row above the pill, so staging 20 files costs the same
  /// vertical space as staging one.
  final List<DemoAttachment> attachments;

  /// Tapped on the paperclip icon. The chat screen opens the native
  /// file picker rooted at Photos / Files (multi-select).
  final VoidCallback onAttach;

  /// Tapped on the "x" next to a staged attachment chip. Receives the
  /// index of the chip to remove so the screen can drop just that file
  /// from its parallel `_attachments` / `_pendingFiles` lists.
  final ValueChanged<int> onRemoveAttachment;

  /// Tapped on a staged attachment thumbnail (the chip itself, not the
  /// remove badge). The screen wires this to Saqqar's in-app attachment
  /// viewer so the user can verify they staged the right file before
  /// sending, without being ejected into another app.
  final ValueChanged<int> onPreviewAttachment;

  final VoidCallback? onSend;

  /// Tapped on the `＋` button — opens the Saqqar tools sheet (upload,
  /// modes, Odoo tools, connections). Null hides the button entirely.
  final VoidCallback? onTools;

  /// Two persistent chat-level toggles live in the composer bar so the
  /// AppBar can stay focused on identity (Saqqar wordmark + page label
  /// + agent pulse). Web parity for `taskPrepToggle` + `autoApproveToggle`.
  final bool taskPrep;
  final bool autoApprove;
  final ValueChanged<bool> onTaskPrepChanged;
  final ValueChanged<bool> onAutoApproveChanged;

  /// Whether the caller's plan carries task prep. The server gates the
  /// feature itself (coercing `task_prep` to `false` for ineligible plans),
  /// so `false` here only hides a toggle that would do nothing — it is never
  /// what enforces the gate.
  ///
  /// Defaults to `true` because the mobile feature snapshot does not carry
  /// `task_prep_available` yet: an unknown flag must not hide a working
  /// control. See `ChatFeatures.taskPrepAvailable`.
  final bool taskPrepAvailable;

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
              // One horizontally-scrolling row, never a grid. A `Wrap` here
              // reflowed into a new run every 4 thumbnails, so staging 10
              // files grew the composer by three rows and pushed the
              // conversation off screen. A fixed-height strip keeps the
              // composer the same size for 1 attachment or 50, and the
              // overflow becomes a horizontal scroll instead of vertical
              // growth.
              if (attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    // 72 chip + 10 top inset for the `×` that hangs off the
                    // corner + 6 slack, so nothing clips against the viewport.
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      // End inset gives the last chip's `×` room to render
                      // inside the viewport; directional so RTL flips it.
                      padding: const EdgeInsetsDirectional.only(
                        top: 10,
                        end: 10,
                      ),
                      itemCount: attachments.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => _StagedAttachment(
                        attachment: attachments[i],
                        tooltip: context.tr.removeAttachment,
                        onRemove: () => onRemoveAttachment(i),
                        onPreview: () => onPreviewAttachment(i),
                      ),
                    ),
                  ),
                ),
              // Addon authoring hint (Gap M) — when an addon `.zip` is staged,
              // tell the user Saqqar can read/edit/rebuild it. Driven purely
              // off the staged file names so it appears the moment they attach.
              if (attachments.any((a) => _isAddonArchive(a.name)))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(AppIcons.archive, size: 15, color: s.brandCyan),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr.addonHint,
                          style: context.text.labelMedium?.copyWith(
                            color: s.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                          // The hint shares the field's `maxLines: 6`, so it
                          // grows the box exactly as typed text would. The
                          // busy hint is a full sentence — "Saqqar is working
                          // — type your next task; send unlocks when done." —
                          // which at 320 px and 1.3× text wraps to four lines
                          // and inflates an EMPTY composer to over half the
                          // screen. Capping it lets a placeholder ellipsize
                          // rather than push the chat off the top.
                          hintMaxLines: 2,
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
                          // `＋` — Saqqar tools. Left-most control, matching
                          // the web composer. Everything that isn't one of
                          // the two hot actions (attach, mic) lives behind
                          // it: prompt bank, Odoo tools, connections, and
                          // the slash commands that used to sit out here.
                          if (onTools != null)
                            IconButton(
                              onPressed: onTools,
                              icon: Icon(AppIcons.plus,
                                  color: s.muted, size: 20),
                              tooltip: context.tr.toolsTitle,
                              visualDensity: VisualDensity.compact,
                            ),
                          // NO separate paperclip. It duplicated the ＋
                          // sheet's own "Upload file" row — two controls, one
                          // action, sitting next to each other. Removed
                          // 2026-08-06; [onAttach] is still the callback the
                          // sheet's upload row fires, so nothing about the
                          // attachment flow changed except the second door
                          // into it.
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
                          if (taskPrep && taskPrepAvailable) ...[
                            _ActiveModeBadge(
                              icon: AppIcons.lightbulb,
                              color: s.brandPurple,
                              tooltip: context.tr.taskPrepOn,
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
                          // Send stays disabled until there's something to
                          // send — typed text or a staged attachment — so an
                          // empty tap never costs a wasted round-trip. The
                          // ValueListenableBuilder watches only the text
                          // controller, so keystrokes rebuild just this
                          // button, not the whole screen. `onStop` (mid-
                          // generation) always wins — the Stop control must
                          // stay live regardless of composer content.
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: controller,
                            builder: (context, value, _) {
                              final hasContent =
                                  value.text.trim().isNotEmpty ||
                                      attachments.isNotEmpty;
                              return ChatSendButton(
                                onPressed:
                                    hasContent ? onSend : null,
                                onStop: onStop,
                                stopping: stopping,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // ── Toggles row ────────────────────────────────────
                    // Toggles get their own line so the full Arabic
                    // labels ("تجهيز المهمة", "الموافقة التلقائية")
                    // are always readable, no ellipsis. Wrap so a very
                    // narrow screen can flow the second toggle down.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (taskPrepAvailable)
                            _ComposerToggle(
                              icon: AppIcons.lightbulb,
                              label: context.tr.taskPrep,
                              tooltip: context.tr.taskPrepTitle,
                              value: taskPrep,
                              activeColor: s.brandPurple,
                              onChanged: onTaskPrepChanged,
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
///
/// The pulse runs [_attentionPulses] times and then HOLDS at its brightest
/// ring instead of breathing forever. Deep-think and auto-approve are sticky
/// settings, not transient states, so an endless pulse meant the chat screen
/// — where users spend nearly all their time — never stopped producing
/// frames for as long as either mode was on. Holding at peak keeps the badge
/// exactly as loud as the pulse's most visible moment, so the warning is not
/// weakened; only the repaint is.
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

  /// Breaths to draw the eye before settling. Enough to register as motion
  /// in peripheral vision; short enough that the screen goes quiet.
  static const _attentionPulses = 4;
  int _pulsesDone = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppDurations.breathe,
    )..addStatusListener(_onHalfCycle);
    _ctrl.forward();
  }

  /// One `forward` + one `reverse` is a full breath. Count the reverses so
  /// we always settle from the same end, then park at 1.0 — the peak of the
  /// ring, i.e. the badge's most visible state.
  void _onHalfCycle(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _ctrl.reverse();
      return;
    }
    if (status != AnimationStatus.dismissed) return;
    _pulsesDone++;
    if (_pulsesDone >= _attentionPulses) {
      _ctrl.value = 1.0; // hold bright; no further frames scheduled
      return;
    }
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl
      ..removeStatusListener(_onHalfCycle)
      ..dispose();
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
    this.tooltip,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  }) : assert(icon != null || hasTrack,
            'Either icon or hasTrack must be supplied');

  final IconData? icon;
  final bool hasTrack;
  final String label;

  /// Long-press / hover explanation. Task prep gets one because "Task prep"
  /// alone doesn't say what flipping it changes; the sentence the web shows
  /// as a `title` attribute is the same copy.
  final String? tooltip;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    final message = tooltip;
    return message == null ? body : Tooltip(message: message, child: body);
  }

  Widget _buildBody(BuildContext context) {
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
          duration: AppDurations.fast,
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
              borderRadius: AppRadius.pillR,
              border: Border.all(
                color: value ? activeColor : s.cardBorder,
                width: 1,
              ),
            ),
          ),
          AnimatedPositionedDirectional(
            duration: AppDurations.fast,
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

/// Whether a staged attachment is an Odoo addon archive (Gap M). Drives the
/// "Saqqar can read/edit/build this addon" hint above the composer.
bool _isAddonArchive(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.zip') ||
      lower.endsWith('.tar') ||
      lower.endsWith('.gz') ||
      lower.endsWith('.tgz');
}
