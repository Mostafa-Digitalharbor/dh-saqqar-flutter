import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/saqqar_logo.dart';
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
          onLongPress: () => _copyMessage(context, message),
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
                Text(
                  message.toolName!,
                  style: context.text.labelSmall?.copyWith(
                    color: s.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    letterSpacing: 0.2,
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
  await Clipboard.setData(ClipboardData(text: message.content));
  if (!context.mounted) return;
  AppToast.show(
    context,
    message: context.tr.copiedToClipboard,
    variant: ToastVariant.success,
  );
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
    case ArtifactDownloadFailed():
      AppToast.show(
        context,
        message: tr.artifactDownloadFailed,
        variant: ToastVariant.error,
      );
  }
}
