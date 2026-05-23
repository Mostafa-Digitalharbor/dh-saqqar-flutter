import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/saqqar_theme_extension.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../demo/saqqar_demo_data.dart';

/// Attachment row used both inside chat bubbles and in the composer preview
/// tray.
///
/// Two display modes:
///   * **Full** (default) — wide chip with a 240-px-tall image preview /
///     row layout for files. Used in sent message bubbles where the chat
///     bubble owns the full message width.
///   * **Compact** ([compact] = true) — 72×72 thumbnail square. Used in the
///     composer staging tray so a batch of attachments doesn't push the
///     text field off the screen. Testers (2026-05-23) flagged the full
///     preview chip as eating the whole chat surface when 2+ images were
///     staged.
///
/// When the attachment is an image and has an [DemoAttachment.imageUrl],
/// renders an inline preview on top of the metadata footer. Non-image
/// kinds fall back to a tight icon + name + meta row.
///
/// [onTap] makes the whole chip tappable (download + open with the OS's
/// matching viewer). Pass null in contexts where opening makes no sense.
class AttachmentChip extends StatelessWidget {
  const AttachmentChip({
    super.key,
    required this.attachment,
    this.onTap,
    this.compact = false,
  });

  final DemoAttachment attachment;
  final VoidCallback? onTap;

  /// When true, renders the tiny 72×72 staging variant instead of the
  /// wide preview. See class doc for context.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (compact) {
      child = _CompactAttachment(attachment: attachment);
    } else {
      child = attachment.isImage && attachment.imageUrl != null
          ? _ImageAttachment(attachment: attachment)
          : _FileAttachment(attachment: attachment);
    }
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}

/// 72×72 thumbnail used in the composer staging tray. Images get the
/// pixels; everything else gets a kind icon + filename badge so the
/// user can still tell a PDF apart from a DOCX at a glance.
///
/// [DemoAttachment.imageUrl] for staged composer attachments is the
/// local on-disk path (set by `_pickAttachment` / `_consumeShareIntake`
/// — both stash `picked.path` / `f.path` there). `Image.file` reads it
/// directly without a network round-trip; sent-bubble attachments hit
/// the network path via `Image.network` inside [_ImageAttachment].
class _CompactAttachment extends StatelessWidget {
  const _CompactAttachment({required this.attachment});

  final DemoAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: s.surface,
          border: Border.all(color: s.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: _isLocalImagePath(attachment.imageUrl)
            ? _localImageThumb(attachment.imageUrl!, s)
            : _fileGlyph(s),
      ),
    );
  }

  bool _isLocalImagePath(String? url) {
    if (url == null || url.isEmpty) return false;
    if (!attachment.isImage) return false;
    // The composer always stages a local file path. Sent-bubble
    // attachments use http(s) URLs — those should fall through to the
    // file-glyph branch here (the composer never renders them anyway).
    return !url.startsWith('http');
  }

  Widget _localImageThumb(String path, SaqqarThemeExtension s) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: 72,
      height: 72,
      errorBuilder: (context, error, stack) => _fileGlyph(s),
    );
  }

  Widget _fileGlyph(SaqqarThemeExtension s) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: s.surface2),
        Center(
          child: Icon(
            attachment.isImage ? AppIcons.image : AppIcons.fileText,
            size: 28,
            color: s.brandCyan,
          ),
        ),
        Positioned(
          left: 4,
          right: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.brandCyan.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              attachment.kind,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: s.brandCyan,
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({required this.attachment});

  final DemoAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: s.surface,
          border: Border.all(color: s.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: Image.network(
                attachment.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) {
                  return Container(
                    height: 120,
                    color: s.surface2,
                    alignment: Alignment.center,
                    child: Icon(
                      AppIcons.image,
                      color: s.muted,
                      size: 28,
                    ),
                  );
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 120,
                    color: s.surface2,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: s.brandCyan,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: s.brandCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: s.brandCyan.withValues(alpha: 0.26),
                      ),
                    ),
                    child: Text(
                      attachment.kind,
                      style: context.text.labelSmall?.copyWith(
                        color: s.brandCyan,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    attachment.size,
                    style: context.text.labelSmall?.copyWith(
                      color: s.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileAttachment extends StatelessWidget {
  const _FileAttachment({required this.attachment});

  final DemoAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: s.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.brandCyan.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(AppIcons.attach, size: 14, color: s.brandCyan),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${attachment.kind} · ${attachment.size}',
                  style: context.text.labelSmall?.copyWith(
                    color: s.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
