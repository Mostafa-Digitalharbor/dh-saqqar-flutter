import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/saqqar_theme_extension.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/colored_icon_box.dart';
import '../../demo/saqqar_demo_data.dart';
import '../../../core/theme/app_radius.dart';
import 'pdf_thumbnail.dart';
import '../../../shared/widgets/tappable_surface.dart';

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
    this.gallery = false,
  });

  final DemoAttachment attachment;
  final VoidCallback? onTap;

  /// When true, renders the tiny 72×72 staging variant instead of the
  /// wide preview. See class doc for context.
  final bool compact;

  /// When true, renders the fixed-size card used inside a multi-attachment
  /// horizontal strip. Takes precedence over nothing — [compact] wins if
  /// both are set, since the composer tray is the tighter constraint.
  final bool gallery;

  /// Card width of the [gallery] variant. Exposed so the strip that hosts
  /// these can size its viewport without guessing.
  static const double galleryWidth = 150;

  /// Card height of the [gallery] variant.
  static const double galleryHeight = 176;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (compact) {
      child = _CompactAttachment(attachment: attachment);
    } else if (gallery) {
      child = _GalleryAttachment(attachment: attachment);
    } else {
      child = attachment.isImage && attachment.imageUrl != null
          ? _ImageAttachment(attachment: attachment)
          : _FileAttachment(attachment: attachment);
    }
    if (onTap == null) return child;
    return TappableSurface(
      onTap: onTap,
      child: child,
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
      borderRadius: AppRadius.smallR,
      child: Container(
        width: AppBoxSizes.thumbnail,
        height: AppBoxSizes.thumbnail,
        decoration: BoxDecoration(
          color: s.surface,
          border: Border.all(color: s.border),
          borderRadius: AppRadius.smallR,
        ),
        child: _isLocalImage(attachment)
            ? _localImageThumb(attachment.imageUrl!, s)
            : _localPdfThumb(s) ?? _fileGlyph(s),
      ),
    );
  }

  /// First page of a staged PDF, or null when this isn't a local PDF and
  /// the caller should fall back to the generic glyph.
  Widget? _localPdfThumb(SaqqarThemeExtension s) {
    final path = _localPdfPath(attachment);
    if (path == null) return null;
    return PdfThumbnail(
      path: path,
      width: AppBoxSizes.thumbnail,
      height: AppBoxSizes.thumbnail,
      placeholder: _fileGlyph(s),
    );
  }

  Widget _localImageThumb(String path, SaqqarThemeExtension s) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: AppBoxSizes.thumbnail,
      height: AppBoxSizes.thumbnail,
      // Decode to the thumbnail's pixel size (72 logical × ~3 DPR), NOT the
      // camera's full bitmap: a 4000×3000 photo is ~48 MB of RGBA in memory
      // when painted into a 72 px box. Without this cap, scrolling a chat with
      // several image attachments decodes each at full res → GC pauses + jank.
      // Only cacheWidth (not both) so decode keeps the source aspect ratio —
      // passing both would squish the bitmap before BoxFit.cover crops it.
      cacheWidth: 216,
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
            size: AppIconSizes.tileLarge,
            color: s.brandCyan,
          ),
        ),
        Positioned(
          left: 4,
          right: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4,
              vertical: AppSpacing.s1,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.brandCyan.withValues(alpha: AppAlphas.a16),
              borderRadius: AppRadius.badgeR,
            ),
            child: Text(
              attachment.kind,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: s.brandCyan,
                fontWeight: FontWeight.w800,
                fontSize: AppFontSizes.microCaps,
                letterSpacing: AppLetterSpacing.label,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Path of a PDF that is already on this device, or null.
///
/// Only staged attachments carry [DemoAttachment.localPath]; one that lives
/// on the server has nothing to render until it is downloaded, so those keep
/// the glyph rather than triggering a fetch just to draw a thumbnail.
String? _localPdfPath(DemoAttachment attachment) {
  final path = attachment.localPath;
  if (path == null || path.isEmpty) return null;
  if (!isPdfName(attachment.name)) return null;
  return path;
}

/// True when the attachment's pixels are already on this device.
///
/// The composer stages local file paths; sent-bubble attachments carry
/// http(s) URLs. `Image.file` and `Image.network` are not interchangeable,
/// so every thumbnail site has to make this call the same way.
bool _isLocalImage(DemoAttachment attachment) {
  final url = attachment.imageUrl;
  if (url == null || url.isEmpty) return false;
  if (!attachment.isImage) return false;
  return !url.startsWith('http');
}

/// Fixed-size card used inside a multi-attachment horizontal strip.
/// Sized so a row of them scrolls sideways instead of stacking down the
/// chat: 10 images cost one strip's height, not ten previews.
class _GalleryAttachment extends StatelessWidget {
  const _GalleryAttachment({required this.attachment});

  final DemoAttachment attachment;

  static const double _thumbHeight = 104;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return ClipRRect(
      borderRadius: AppRadius.buttonR,
      child: Container(
        width: AttachmentChip.galleryWidth,
        height: AttachmentChip.galleryHeight,
        decoration: BoxDecoration(
          color: s.surface,
          border: Border.all(color: s.border),
          borderRadius: AppRadius.buttonR,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: _thumbHeight, child: _thumb(s)),
            // Expanded rather than min-sized: the card height is fixed, so
            // letting the footer take the remainder is what keeps a large
            // system text scale from overflowing the card.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s8,
                  AppSpacing.s6,
                  AppSpacing.s8,
                  AppSpacing.s6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      attachment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      '${attachment.kind} · ${attachment.size}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: s.muted,
                        fontSize: AppFontSizes.chipLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(SaqqarThemeExtension s) {
    final url = attachment.imageUrl;
    if (attachment.isImage && url != null && url.isNotEmpty) {
      // Cap decode to the card width (× ~3 DPR) so a full-res photo isn't
      // decoded whole just to fill a small gallery thumb — the memory + decode
      // cost that janks a horizontal image strip on weak devices.
      final decodeWidth = (AttachmentChip.galleryWidth * 3).round();
      final image = _isLocalImage(attachment)
          ? Image.file(
              File(url),
              fit: BoxFit.cover,
              cacheWidth: decodeWidth,
              errorBuilder: (context, error, stack) => _glyph(s),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              cacheWidth: decodeWidth,
              errorBuilder: (context, error, stack) => _glyph(s),
            );
      return SizedBox.expand(child: image);
    }
    final pdfPath = _localPdfPath(attachment);
    if (pdfPath != null) {
      return PdfThumbnail(
        path: pdfPath,
        width: AttachmentChip.galleryWidth,
        height: _thumbHeight,
        placeholder: _glyph(s),
      );
    }
    return _glyph(s);
  }

  Widget _glyph(SaqqarThemeExtension s) {
    return Container(
      color: s.surface2,
      alignment: Alignment.center,
      child: Icon(
        attachment.isImage ? AppIcons.image : AppIcons.fileText,
        size: AppIconSizes.tile,
        color: s.brandCyan,
      ),
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
      borderRadius: AppRadius.buttonR,
      child: Container(
        constraints: const BoxConstraints(maxWidth: AppLayoutWidths.chipCap),
        decoration: BoxDecoration(
          color: s.surface,
          border: Border.all(color: s.border),
          borderRadius: AppRadius.buttonR,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: AppSheetHeights.attachmentPreviewMax),
              child: Image.network(
                attachment.imageUrl!,
                fit: BoxFit.cover,
                // Decode at the display width (× device DPR), capped by the
                // 360 px bubble max — not the source's full resolution.
                cacheWidth:
                    (AppLayoutWidths.chipCap * MediaQuery.devicePixelRatioOf(context)).round(),
                errorBuilder: (context, error, stack) {
                  return Container(
                    height: AppControlSizes.attachmentPreviewHeight,
                    color: s.surface2,
                    alignment: Alignment.center,
                    child: Icon(
                      AppIcons.image,
                      color: s.muted,
                      size: AppIconSizes.tileLarge,
                    ),
                  );
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: AppControlSizes.attachmentPreviewHeight,
                    color: s.surface2,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: AppControlSizes.spinnerMedium,
                      height: AppControlSizes.spinnerMedium,
                      child: CircularProgressIndicator(
                        strokeWidth: AppStrokeWidths.spinnerThin,
                        color: s.brandCyan,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Footer carries the filename as well as the format + size.
            // It used to show only the kind pill and the size, which left
            // an image attachment as the one kind you couldn't identify by
            // name — testers asked for the same detail line a file chip
            // gets, since two screenshots look alike as thumbnails.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s10,
                AppSpacing.s8,
                AppSpacing.s10,
                AppSpacing.s8,
              ),
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
                  const SizedBox(height: AppSpacing.s4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s8,
                          vertical: AppSpacing.s3,
                        ),
                        decoration: BoxDecoration(
                          color: s.brandCyan.withValues(alpha: AppAlphas.a12),
                          borderRadius: AppRadius.pillR,
                          border: Border.all(
                            color: s.brandCyan.withValues(alpha: AppAlphas.a26),
                          ),
                        ),
                        child: Text(
                          attachment.kind,
                          style: context.text.labelSmall?.copyWith(
                            color: s.brandCyan,
                            fontWeight: FontWeight.w700,
                            letterSpacing: AppLetterSpacing.label,
                            fontSize: AppFontSizes.chipLabel,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        attachment.size,
                        style: context.text.labelSmall?.copyWith(
                          color: s.muted,
                          fontSize: AppFontSizes.chipLabel,
                        ),
                      ),
                    ],
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s8,
        AppSpacing.s8,
        AppSpacing.s10,
        AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: AppRadius.smallR,
        border: Border.all(color: s.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColoredIconBox(
            icon: AppIcons.attach,
            color: s.brandCyan,
            size: AppIconSizes.tileLarge,
            radius: AppRadius.checkbox,
            iconSize: AppIconSizes.boxGlyphSmall,
            borderAlpha: null,
          ),
          const SizedBox(width: AppSpacing.s8),
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
                    fontSize: AppFontSizes.chipLabel,
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
