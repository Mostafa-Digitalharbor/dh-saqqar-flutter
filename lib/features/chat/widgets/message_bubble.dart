import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/saqqar_logo.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../../demo/saqqar_demo_data.dart';
import '../../inbox/data/artifact_downloader.dart';
import '../view/attachment_viewer_screen.dart';
import 'artifact_pill.dart';
import 'attachment_chip.dart';
import 'chat_markdown.dart';
import '../../../core/theme/app_radius.dart';

/// Spec §8 — two distinct render paths for one message:
///
///   **User** (`§8.1`): cyan-soft bubble with brand-cyan border. The
///   top-end corner is cut to 4 px while the rest of the bubble is
///   14 px — the signature "speech-tail" shape that flips to top-start
///   automatically in RTL via [BorderRadiusDirectional]. Max width is
///   handled by the caller (`MessageRow` clamps to 88 %).
///
///   **Agent** (`§8.2`): **no bubble at all**. Gradient "Saqqar"
///   wordmark + middle-dot + timestamp, then raw markdown body. The
///   absence of a container is what makes the agent voice read as
///   "the system speaking" rather than "another chat participant".
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.isUser,
    required this.message,
    required this.showTime,
  });

  final bool isUser;
  final DemoMessage message;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    return isUser ? _UserBubble(message: message, showTime: showTime)
                  : _AgentMessage(message: message, showTime: showTime);
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message, required this.showTime});

  final DemoMessage message;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => _showMessageActions(context, message),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              // Cyan-soft fill matches `--brand-cyan-soft` in the
              // mockup; opacity stepped per theme so the bubble
              // doesn't get washed out in light mode.
              color: s.brandCyan
                  .withValues(alpha: context.isDark ? 0.18 : 0.10),
              border: Border.all(
                color: s.brandCyan.withValues(alpha: 0.30),
              ),
              borderRadius:
                  AppRadius.userBubbleR.resolve(Directionality.of(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChatMarkdown(data: message.content, isUser: true),
                _MessageAttachments(
                  attachments: message.attachments,
                  spacing: 8,
                ),
              ],
            ),
          ),
        ),
        if (showTime) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: MessageMeta(
              leading: TextSpan(text: context.tr.youLabel),
              time: message.time,
              align: TextAlign.end,
              style: context.text.labelSmall?.copyWith(
                color: s.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
              dotColor: s.muted.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

class _AgentMessage extends StatelessWidget {
  const _AgentMessage({required this.message, required this.showTime});

  final DemoMessage message;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _copyMessage(context, message),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meta line: SAQQÂR logo + middle-dot + (optional time).
          // The logo is small (14 dp) so it sits inline with the
          // adjacent muted timestamp without dominating the meta row.
          MessageMeta(
            leading: const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SaqqarLogo(height: 14),
            ),
            time: showTime ? message.time : null,
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
            dotColor: s.muted.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 6),
          // Optional tool name (sits above the body so the user knows
          // which tool produced this message). Bubble-less style.
          if (message.toolName != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.bolt, size: 11, color: s.muted),
                const SizedBox(width: 4),
                // Flexible + ellipsis so an unusually long tool name can't
                // push this meta row past the screen edge.
                Flexible(
                  child: Text(
                    message.toolName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(
                      color: s.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          // Body — bubble-less, just raw markdown.
          ChatMarkdown(data: message.content, isUser: false),
          _MessageAttachments(
            attachments: message.attachments,
            spacing: 10,
          ),
        ],
      ),
    );
  }
}

/// The attribution line under a message — `You · <timestamp>` on the user
/// side, `[Saqqar mark] · <timestamp>` on the agent side.
///
/// **One paragraph, not a Row.** Both sides used to build this as
/// `Row(mainAxisSize: min, children: [Text, Text, Text])`, and `Row` hands its
/// children unbounded width on the main axis — so no `Text` inside one can
/// ever wrap or ellipsize, whatever its own `overflow` says. That was fine
/// while the label read `10:00`. It stopped being fine when the timestamp
/// became the web-parity long form (`August 9, 2026 at 10:00 AM`,
/// `١٨ مايو ٢٠٢٦ في ٠٦:٢٤ م`): on a 320 px screen the bubble column is
/// 268.5 px wide and the line wants 294.5, so it overflowed by 26 px — on
/// every user message, on the app's main surface.
///
/// A single `Text.rich` makes the whole line one paragraph, so the normal
/// line-breaker wraps it. The Saqqar mark rides along as a `WidgetSpan`, which
/// is what keeps the agent side one paragraph too rather than a Row again.
///
/// Wrapping rather than ellipsizing is deliberate. The tool-name row a few
/// lines below *does* ellipsize, because a clipped tool name is still a
/// recognisable tool name — but `August 9, 2026 at 10:0…` misstates when a
/// message was sent, and a second line costs 15 px.
class MessageMeta extends StatelessWidget {
  const MessageMeta({
    super.key,
    required this.leading,
    required this.time,
    required this.style,
    required this.dotColor,
    this.align = TextAlign.start,
  });

  /// The attribution itself: a `TextSpan` for "You", a `WidgetSpan` for the
  /// Saqqar mark. Taking a span rather than a widget is what allows both
  /// shapes to share one paragraph.
  final InlineSpan leading;

  /// Null hides both the separator and the timestamp, leaving [leading]
  /// alone — the agent's meta line still shows its mark on a grouped message.
  final String? time;

  final TextStyle? style;
  final Color dotColor;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final label = time;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          leading,
          if (label != null) ...[
            TextSpan(text: ' · ', style: TextStyle(color: dotColor)),
            TextSpan(text: label),
          ],
        ],
      ),
      textAlign: align,
    );
  }
}

Future<void> _copyMessage(BuildContext context, DemoMessage message) async {
  // Fire haptic the moment the long-press resolves — before the async
  // clipboard write — so the user feels the action register without
  // waiting for the toast.
  unawaited(HapticFeedback.mediumImpact());
  await Clipboard.setData(ClipboardData(text: message.content));
  if (!context.mounted) return;
  AppToast.show(
    context,
    message: context.tr.copiedToClipboard,
    variant: ToastVariant.success,
  );
}

/// Bottom sheet surfaced on long-press of any message bubble. Offers
/// Copy + Share (system share sheet). Replaces the old direct-to-copy
/// behaviour after testers asked for "send the agent's answer to my
/// boss on WhatsApp" — Share goes through `share_plus`, which on
/// Android opens the same system picker WhatsApp itself populates.
///
/// Dismissing the sheet without picking is a no-op.
Future<void> _showMessageActions(
  BuildContext context,
  DemoMessage message,
) async {
  unawaited(HapticFeedback.mediumImpact());
  final action = await showModalBottomSheet<_MessageAction>(
    context: context,
    isScrollControlled: false,
    builder: (_) => const _MessageActionsSheet(),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _MessageAction.copy:
      await _copyMessage(context, message);
    case _MessageAction.share:
      await _shareMessage(context, message);
  }
}

Future<void> _shareMessage(
  BuildContext context,
  DemoMessage message,
) async {
  if (message.content.trim().isEmpty) return;
  final subject = context.tr.shareMessageSubject;
  // Skip on the share-plus return value — Android always reports
  // `ShareResultStatus.unavailable` once the sheet closes because the
  // system picker doesn't report a chosen target back to us.
  await Share.share(
    message.content,
    subject: subject,
    // iPad presents the share sheet as a popover and errors out without an
    // anchor. See `sharePositionOrigin`.
    sharePositionOrigin: context.sharePositionOrigin,
  );
}

enum _MessageAction { copy, share }

class _MessageActionsSheet extends StatelessWidget {
  const _MessageActionsSheet();

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetDragHandle(),
            const SizedBox(height: 18),
            _SheetRow(
              icon: AppIcons.copy,
              label: tr.copyAction,
              onTap: () =>
                  Navigator.of(context).pop(_MessageAction.copy),
            ),
            _SheetRow(
              icon: AppIcons.share,
              label: tr.shareMessage,
              onTap: () =>
                  Navigator.of(context).pop(_MessageAction.share),
            ),
            const SizedBox(height: 4),
            // Subtle hint so the user knows the source — keeps the sheet
            // self-explanatory even when triggered accidentally.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                tr.shareMessageSubject,
                textAlign: TextAlign.center,
                style: context.text.labelSmall?.copyWith(
                  color: s.muted,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.buttonR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.buttonR,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.muted.withValues(alpha: 0.10),
                ),
                child: Icon(icon, size: 18, color: s.text),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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

/// Renders a message's attachments, shared by the user bubble and the
/// agent reply.
///
/// Agent-generated artifacts keep their full-width "Artifact ready" pill —
/// those are the deliverable, not a thumbnail. Everything else collapses
/// into a horizontal strip as soon as there is more than one: a message
/// carrying 10 images used to stack 10 full previews down the bubble and
/// bury the rest of the conversation, so past a single attachment they
/// become fixed-size cards you scroll sideways through.
class _MessageAttachments extends StatelessWidget {
  const _MessageAttachments({
    required this.attachments,
    required this.spacing,
  });

  final List<DemoAttachment> attachments;

  /// Gap above each attachment block. The user bubble is tighter (8) than
  /// the bubble-less agent reply (10).
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    final artifacts = <DemoAttachment>[];
    final plain = <DemoAttachment>[];
    for (final a in attachments) {
      (a.isAgentGenerated ? artifacts : plain).add(a);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in artifacts) ...[
          SizedBox(height: spacing),
          ArtifactPill(
            attachment: a,
            onOpen: a.downloadUrl == null
                ? () {}
                : () => _openAttachment(context, a),
          ),
        ],
        if (plain.length == 1) ...[
          SizedBox(height: spacing),
          AttachmentChip(
            attachment: plain.first,
            onTap: plain.first.downloadUrl == null
                ? null
                : () => _openAttachment(context, plain.first),
          ),
        ] else if (plain.length > 1) ...[
          SizedBox(height: spacing),
          _AttachmentStrip(attachments: plain),
        ],
      ],
    );
  }
}

/// Fixed-height, horizontally-scrolling row of attachment cards. Height is
/// driven by [AttachmentChip.galleryHeight] so the strip and the cards can
/// never disagree.
class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({required this.attachments});

  final List<DemoAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AttachmentChip.galleryHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final a = attachments[i];
          return AttachmentChip(
            attachment: a,
            gallery: true,
            onTap: a.downloadUrl == null
                ? null
                : () => _openAttachment(context, a),
          );
        },
      ),
    );
  }
}

/// Downloads the attachment (or reuses the cached copy under the app's
/// documents directory) and opens it in Saqqar's own viewer.
///
/// This used to end in `OpenFilex.open`, which threw the user into
/// Acrobat / the gallery / Files and lost their place in the chat.
/// [AttachmentViewerScreen] renders images, PDFs and text files inline;
/// the kinds it can't render still reach another app, but only behind an
/// explicit button there instead of automatically.
///
/// Caller must guard with `attachment.downloadUrl != null`; this
/// function asserts both [downloadUrl] and [serverId] are set.
Future<void> _openAttachment(
  BuildContext context,
  DemoAttachment attachment,
) async {
  final url = attachment.downloadUrl;
  final cacheKey = attachment.serverId;
  if (url == null || cacheKey == null) return;
  final tr = context.tr;
  AppToast.show(
    context,
    message: tr.downloadingArtifact,
    variant: ToastVariant.info,
  );
  final downloader = ArtifactDownloader(context.read<Dio>());
  final result = await downloader.fetch(
    url: url,
    cacheKey: cacheKey,
    originalName: attachment.name,
    kindHint: attachment.kind,
  );
  if (!context.mounted) return;
  switch (result) {
    case ArtifactFetchSuccess(:final file):
      await AttachmentViewerScreen.open(
        context,
        file: file,
        name: attachment.name,
        kindLabel: attachment.kind,
        sizeLabel: attachment.size,
      );
    case ArtifactFetchFailed(:final statusCode):
      AppToast.show(
        context,
        message: tr.artifactDownloadMessage(statusCode),
        variant: ToastVariant.error,
      );
  }
}
