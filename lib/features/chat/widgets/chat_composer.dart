import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/fig/fig.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../data/chat_view_models.dart';
import 'attachment_chip.dart';
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
    this.onClearAttachments,
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
  final List<ChatAttachment> attachments;

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

  /// "Clear all" in the staged-files header. Null hides the link.
  final VoidCallback? onClearAttachments;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(),
        child: ResponsiveContent(
          maxWidth: AppLayoutWidths.chatShell,
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
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
              if (attachments.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr.figSelected(attachments.length),
                          style: Fig.t(
                            context,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      if (onClearAttachments != null)
                        GestureDetector(
                          onTap: onClearAttachments,
                          child: Text(
                            context.tr.figClearAll,
                            style: Fig.t(
                              context,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      const SizedBox(width: AppSpacing.s16),
                      Flexible(
                        child: GestureDetector(
                          onTap: onAttach,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.plus,
                                size: 15,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: AppSpacing.s4),
                              Flexible(
                                child: Text(
                                  context.tr.figAddMore,
                                  style: Fig.t(
                                    context,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s14),
                  child: SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: attachments.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.s10),
                      itemBuilder: (context, i) => _StagedAttachment(
                        attachment: attachments[i],
                        tooltip: context.tr.removeAttachment,
                        onRemove: () => onRemoveAttachment(i),
                        onPreview: () => onPreviewAttachment(i),
                      ),
                    ),
                  ),
                ),
              ],
              // Addon authoring hint (Gap M) — when an addon `.zip` is staged,
              // tell the user Saqqar can read/edit/rebuild it. Driven purely
              // off the staged file names so it appears the moment they attach.
              if (attachments.any((a) => _isAddonArchive(a.name)))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s10),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.archive,
                        size: AppIconSizes.inline,
                        color: s.brandCyan,
                      ),
                      const SizedBox(width: AppSpacing.s8),
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
              // ── Composer pill (redesign) ───────────────────────────
              // Dark glass card: "Ask me anything …" over a row of round
              // controls — attach, tools · mic, send. Task prep / Auto-approve
              // now live in the ⋮ Saqqar Tools sheet.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                ),
                child: recording || transcribing
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 56),
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                minLines: 1,
                                maxLines: 6,
                                textInputAction: TextInputAction.newline,
                                cursorColor: Colors.white,
                                style: Fig.t(
                                  context,
                                  size: 15,
                                  color: Colors.white,
                                  height: 1.35,
                                ),
                                decoration: InputDecoration(
                                  hintText: onStop != null
                                      ? context.tr.composerBusy
                                      : context.tr.figAskMeAnything,
                                  hintStyle: Fig.t(
                                    context,
                                    size: 15,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  hintMaxLines: 2,
                                  isCollapsed: true,
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            child: Row(
                              children: [
                                _RoundAction(
                                  icon: LucideIcons.paperclip,
                                  onTap: onAttach,
                                ),
                                const SizedBox(width: AppSpacing.s10),
                                if (onTools != null)
                                  _RoundAction(
                                    icon: LucideIcons.workflow,
                                    onTap: onTools,
                                  ),
                                const Spacer(),
                                if (voiceEnabled) ...[
                                  _RoundAction(
                                    icon: LucideIcons.mic,
                                    onTap: (onSend != null && onStop == null)
                                        ? onStartRecording
                                        : null,
                                  ),
                                  const SizedBox(width: AppSpacing.s10),
                                ],
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: controller,
                                  builder: (context, value, _) {
                                    final hasContent =
                                        value.text.trim().isNotEmpty ||
                                        attachments.isNotEmpty;
                                    final running = onStop != null;
                                    final enabled = running
                                        ? !stopping
                                        : (hasContent && onSend != null);
                                    return GestureDetector(
                                      onTap: !enabled
                                          ? null
                                          : (running ? onStop : onSend),
                                      child: Opacity(
                                        opacity: enabled ? 1 : 0.55,
                                        child: Container(
                                          width: 46,
                                          height: 46,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Fig.blueAction,
                                                Color(0xFF1B4FD0),
                                              ],
                                            ),
                                          ),
                                          child: Icon(
                                            running
                                                ? LucideIcons.square
                                                : LucideIcons.arrowUpToLine,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
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

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Icon(
            icon,
            size: 19,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

/// Composer-side staged file card: kind thumbnail, name, size and a small ×.
class _StagedAttachment extends StatelessWidget {
  const _StagedAttachment({
    required this.attachment,
    required this.onRemove,
    required this.onPreview,
    required this.tooltip,
  });

  final ChatAttachment attachment;
  final VoidCallback onRemove;
  final VoidCallback onPreview;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    final localImg =
        a.isImage &&
        a.imageUrl != null &&
        a.imageUrl!.isNotEmpty &&
        !a.imageUrl!.startsWith('http');
    return GestureDetector(
      onTap: onPreview,
      child: Container(
        width: 100,
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: localImg
                        ? Image.file(
                            File(a.imageUrl!),
                            fit: BoxFit.cover,
                            cacheWidth: 96,
                            errorBuilder: (_, __, ___) =>
                                _KindGlyph(attachment: a),
                          )
                        : _KindGlyph(attachment: a),
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: tooltip,
                  child: GestureDetector(
                    onTap: onRemove,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      LucideIcons.x,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              a.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Fig.t(context, size: 12, color: Colors.white),
            ),
            Text(
              a.size,
              maxLines: 1,
              style: Fig.t(
                context,
                size: 11,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindGlyph extends StatelessWidget {
  const _KindGlyph({required this.attachment});
  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final n = attachment.name.toLowerCase();
    final (IconData icon, Color c) = n.endsWith('.pdf')
        ? (LucideIcons.fileText, Fig.fileRed)
        : (n.endsWith('.doc') || n.endsWith('.docx'))
        ? (LucideIcons.fileText, Fig.fileBlue)
        : (n.endsWith('.xls') || n.endsWith('.xlsx') || n.endsWith('.csv'))
        ? (LucideIcons.fileSpreadsheet, Fig.fileGreen)
        : (n.endsWith('.zip') || n.endsWith('.tar') || n.endsWith('.gz'))
        ? (LucideIcons.fileArchive, Fig.fileAmber)
        : (LucideIcons.file, Colors.white70);
    return ColoredBox(
      color: c.withValues(alpha: 0.22),
      child: Icon(icon, size: 15, color: c),
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
