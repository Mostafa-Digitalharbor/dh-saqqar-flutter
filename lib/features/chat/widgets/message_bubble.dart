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
import 'artifact_pill.dart';
import 'attachment_chip.dart';
import 'chat_markdown.dart';

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
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(14),
                topEnd: Radius.circular(4), // signature cut corner
                bottomStart: Radius.circular(14),
                bottomEnd: Radius.circular(14),
              ).resolve(Directionality.of(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChatMarkdown(data: message.content, isUser: true),
                for (final attachment in message.attachments) ...[
                  const SizedBox(height: 8),
                  AttachmentChip(
                    attachment: attachment,
                    onTap: attachment.downloadUrl == null
                        ? null
                        : () => _openAttachment(context, attachment),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showTime) ...[
          const SizedBox(height: 5),
          // Split into separate Text widgets so each is independently
          // findable in tests (and screen readers can announce them as
          // discrete pieces of meta).
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr.youLabel,
                  style: context.text.labelSmall?.copyWith(
                    color: s.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  ' · ',
                  style: context.text.labelSmall?.copyWith(
                    color: s.muted.withValues(alpha: 0.7),
                    fontSize: 10.5,
                  ),
                ),
                Text(
                  message.time,
                  style: context.text.labelSmall?.copyWith(
                    color: s.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SaqqarLogo(height: 14),
              if (showTime) ...[
                Text(
                  ' · ',
                  style: TextStyle(
                    color: s.muted.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                Text(
                  message.time,
                  style: context.text.labelSmall?.copyWith(
                    color: s.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
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
          for (final attachment in message.attachments) ...[
            const SizedBox(height: 10),
            if (attachment.isAgentGenerated)
              ArtifactPill(
                attachment: attachment,
                onOpen: attachment.downloadUrl == null
                    ? () {}
                    : () => _openAttachment(context, attachment),
              )
            else
              AttachmentChip(
                attachment: attachment,
                onTap: attachment.downloadUrl == null
                    ? null
                    : () => _openAttachment(context, attachment),
              ),
          ],
        ],
      ),
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
  await Share.share(message.content, subject: subject);
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
              icon: Icons.content_copy_outlined,
              label: tr.copyAction,
              onTap: () =>
                  Navigator.of(context).pop(_MessageAction.copy),
            ),
            _SheetRow(
              icon: Icons.ios_share,
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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

/// Downloads the attachment (or reuses the cached copy under the
/// app's documents directory) and hands it off to the OS's matching
/// viewer — PDF reader for PDFs, Word for DOCX, Excel for XLSX,
/// gallery for images, etc. Same flow the artifact downloader uses
/// in the rail drawer, just keyed by the attachment's server id so
/// the cache stays per-file.
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
  final result = await downloader.downloadAndOpenUrl(
    url: url,
    cacheKey: cacheKey,
    originalName: attachment.name,
    kindHint: attachment.kind,
  );
  if (!context.mounted) return;
  switch (result) {
    case ArtifactOpenSuccess():
      // System viewer is now on screen — no extra toast needed.
      break;
    case ArtifactOpenNoViewer():
      AppToast.show(
        context,
        message: tr.artifactNoViewer,
        variant: ToastVariant.error,
      );
    case ArtifactOpenFailed():
      AppToast.show(
        context,
        message: tr.artifactOpenFailed,
        variant: ToastVariant.error,
      );
    case ArtifactDownloadFailed(:final statusCode):
      AppToast.show(
        context,
        message: tr.artifactDownloadMessage(statusCode),
        variant: ToastVariant.error,
      );
  }
}
