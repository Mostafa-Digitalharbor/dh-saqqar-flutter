import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/format/file_kind.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/fig/fig.dart';
import '../../../shared/widgets/app_toast.dart';

/// What the viewer can render natively. Anything outside this set is a
/// hand-off, not a failure — see [_UnsupportedBody].
enum AttachmentViewerKind { image, pdf, text, unsupported }

/// Fullscreen in-app viewer for a downloaded attachment or artifact.
///
/// Tapping an attachment used to call `OpenFilex.open`, which ejected the
/// user into Acrobat / the system gallery / Files — they lost the chat and
/// had to navigate back. Testers asked for the file to open *inside*
/// Saqqar. This screen renders the three kinds we can render honestly
/// (images, PDFs, text-shaped documents) and keeps `OpenFilex` as an
/// explicit, user-initiated action in the app bar rather than the default.
///
/// The caller is responsible for getting the bytes onto disk first —
/// `ArtifactDownloader.fetch` does that and hands back the [File].
class AttachmentViewerScreen extends StatefulWidget {
  const AttachmentViewerScreen({
    super.key,
    required this.file,
    required this.name,
    this.kindLabel,
    this.sizeLabel,
  });

  final File file;

  /// Original filename — the app bar title, and what decides the render
  /// mode via its extension.
  final String name;

  /// Short format token ("PDF", "IMAGE") shown in the subtitle. Optional
  /// because the composer preview path doesn't always have one.
  final String? kindLabel;

  /// Pre-formatted human size ("2.4 MB"). Optional for the same reason.
  final String? sizeLabel;

  /// Pushes the viewer on the root navigator so it covers the chat shell's
  /// bottom bar instead of appearing inside a tab.
  static Future<void> open(
    BuildContext context, {
    required File file,
    required String name,
    String? kindLabel,
    String? sizeLabel,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentViewerScreen(
          file: file,
          name: name,
          kindLabel: kindLabel,
          sizeLabel: sizeLabel,
        ),
      ),
    );
  }

  /// Render mode for [name]'s extension. Public so callers can decide
  /// whether opening in-app is even worth a download.
  /// Render mode for [name]'s extension.
  ///
  /// Classification is [FileKinds]', not this screen's — it used to keep its
  /// own image list, which was the only one that knew about `bmp` and the
  /// only one that did NOT know about `heic`. An iPhone photo therefore drew
  /// a thumbnail in the chat and then opened here as "we can't display this".
  ///
  /// DOCX / XLSX / ZIP and friends stay unsupported on purpose: they are
  /// archives of XML, and rendering them faithfully needs an office engine
  /// this app deliberately doesn't ship. The user gets "open in another app".
  static AttachmentViewerKind kindFor(String name) {
    final kind = FileKinds.of(name);
    if (kind == FileKind.image) return AttachmentViewerKind.image;
    if (kind == FileKind.pdf) return AttachmentViewerKind.pdf;
    if (kind.isTextRenderable) return AttachmentViewerKind.text;
    return AttachmentViewerKind.unsupported;
  }

  @override
  State<AttachmentViewerScreen> createState() => _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState extends State<AttachmentViewerScreen> {
  PdfControllerPinch? _pdfController;
  late final AttachmentViewerKind _kind;

  /// Set when the PDF engine rejects the document (corrupt, encrypted, or
  /// not really a PDF). Flips the body to the hand-off state so the user
  /// still has a way to read the file.
  bool _pdfFailed = false;

  @override
  void initState() {
    super.initState();
    _kind = AttachmentViewerScreen.kindFor(widget.name);
    if (_kind == AttachmentViewerKind.pdf) {
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(widget.file.path),
      );
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _openExternally() async {
    final tr = context.tr;
    final result = await OpenFilex.open(widget.file.path);
    if (!mounted) return;
    if (result.type == ResultType.done) return;
    AppToast.show(
      context,
      message: result.type == ResultType.noAppToOpen
          ? tr.artifactNoViewer
          : tr.artifactOpenFailed,
      variant: ToastVariant.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    // Images read best on a neutral dark field regardless of theme; the
    // document modes stay on the app surface so text keeps its contrast.
    final isImage = _kind == AttachmentViewerKind.image;
    final subtitle = [
      if (widget.kindLabel != null && widget.kindLabel!.isNotEmpty)
        widget.kindLabel,
      if (widget.sizeLabel != null && widget.sizeLabel!.isNotEmpty)
        widget.sizeLabel,
    ].join(' · ');

    if (isImage) {
      return _ImageViewer(
        file: widget.file,
        name: widget.name,
        subtitle: subtitle,
        onOpenExternally: _openExternally,
      );
    }

    return Scaffold(
      backgroundColor: isImage ? AppColors.imageBackdrop : s.bg,
      appBar: AppBar(
        backgroundColor: isImage ? AppColors.imageBackdrop : s.bg,
        foregroundColor: isImage ? AppColors.onImageBackdrop : s.text,
        elevation: AppElevations.none,
        titleSpacing: AppSpacing.zero,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isImage ? AppColors.onImageBackdrop : s.text,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: isImage
                      ? AppColors.onImageBackdrop.withValues(
                          alpha: AppAlphas.deemphasis,
                        )
                      : s.muted,
                  fontSize: AppFontSizes.caption,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openExternally,
            icon: const Icon(AppIcons.open, size: AppIconSizes.action),
            tooltip: tr.viewerOpenExternally,
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_kind == AttachmentViewerKind.pdf && _pdfFailed) {
      return _UnsupportedBody(
        onOpenExternally: _openExternally,
        message: context.tr.viewerLoadFailed,
      );
    }
    switch (_kind) {
      case AttachmentViewerKind.image:
        return _ImageBody(file: widget.file, onOpenExternally: _openExternally);
      case AttachmentViewerKind.pdf:
        return PdfViewPinch(
          controller: _pdfController!,
          onDocumentError: (_) {
            if (!mounted || _pdfFailed) return;
            setState(() => _pdfFailed = true);
          },
        );
      case AttachmentViewerKind.text:
        return _TextBody(file: widget.file, onOpenExternally: _openExternally);
      case AttachmentViewerKind.unsupported:
        return _UnsupportedBody(onOpenExternally: _openExternally);
    }
  }
}

/// Pinch-to-zoom image on a black field. Falls back to the hand-off state
/// when the bytes aren't a decodable image (wrong extension, truncated
/// download that still passed the non-empty cache check).
class _ImageBody extends StatelessWidget {
  const _ImageBody({required this.file, required this.onOpenExternally});

  final File file;
  final VoidCallback onOpenExternally;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => _UnsupportedBody(
            onOpenExternally: onOpenExternally,
            message: context.tr.viewerLoadFailed,
          ),
        ),
      ),
    );
  }
}

/// Monospace dump of a text-shaped file, scrollable in both axes so CSV
/// columns stay aligned instead of wrapping into mush.
class _TextBody extends StatefulWidget {
  const _TextBody({required this.file, required this.onOpenExternally});

  final File file;
  final VoidCallback onOpenExternally;

  @override
  State<_TextBody> createState() => _TextBodyState();
}

class _TextBodyState extends State<_TextBody> {
  /// Reading a whole file into a single `Text` is O(size) in both memory
  /// and layout time. Half a megabyte is already ~10k lines — far past what
  /// anyone reads on a phone — so cap it and say so rather than jank.
  static const int _maxBytes = 512 * 1024;

  String? _text;
  bool _truncated = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Synchronous on purpose. The read is bounded by [_maxBytes] off
  /// app-private storage, so it costs well under a frame — and doing it
  /// inline means no spinner flashes on every open, and no chance of the
  /// widget being disposed with a read still in flight holding the handle.
  void _load() {
    try {
      final handle = widget.file.openSync();
      try {
        final length = handle.lengthSync();
        final bytes = handle.readSync(math.min(length, _maxBytes));
        try {
          _text = utf8.decode(bytes);
        } on FormatException {
          // Not UTF-8 — Windows-authored CSV exports are often cp1252.
          // latin1 never throws, so this always yields something readable
          // instead of an error screen.
          _text = latin1.decode(bytes);
        }
        _truncated = length > _maxBytes;
      } finally {
        handle.closeSync();
      }
    } catch (_) {
      // Unreadable (deleted under us, permission, not a real file). The
      // hand-off state still gives the user a way to open it.
      _failed = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final text = _text;
    if (_failed || text == null) {
      return _UnsupportedBody(
        onOpenExternally: widget.onOpenExternally,
        message: context.tr.viewerLoadFailed,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_truncated)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s8,
            ),
            color: s.warning.withValues(alpha: AppAlphas.a12),
            child: Text(
              context.tr.viewerTruncated,
              style: context.text.labelSmall?.copyWith(color: s.warning),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                text,
                style: const TextStyle(
                  fontFamily: AppTypography.fontMono,
                  fontSize: AppFontSizes.footnote,
                  height: AppLineHeights.body,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown for kinds we can't render (DOCX, XLSX, archives) and for files
/// that failed to decode. Explicitly NOT an error state for the former —
/// it offers the hand-off the user used to get automatically.
class _UnsupportedBody extends StatelessWidget {
  const _UnsupportedBody({required this.onOpenExternally, this.message});

  final VoidCallback onOpenExternally;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppBoxSizes.fileKind,
              height: AppBoxSizes.fileKind,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.brandCyan.withValues(alpha: AppAlphas.a10),
              ),
              child: Icon(
                AppIcons.fileText,
                size: AppIconSizes.tile,
                color: s.brandCyan,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              message ?? tr.viewerUnsupportedTitle,
              textAlign: TextAlign.center,
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              tr.viewerUnsupportedBody,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: s.muted),
            ),
            const SizedBox(height: AppSpacing.s20),
            FilledButton.icon(
              onPressed: onOpenExternally,
              icon: const Icon(AppIcons.open, size: AppIconSizes.small),
              label: Text(tr.viewerOpenExternally),
              style: FilledButton.styleFrom(
                backgroundColor: s.brandCyan,
                foregroundColor: AppColors.onBrand,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.buttonR,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s18,
                  vertical: AppSpacing.s12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The redesigned fullscreen image viewer (figma-design / Fullscreen image
/// viewer): save + counter + close up top, file name and meta, the picture,
/// a zoom read-out, the thumbnail strip and the gesture hints.
class _ImageViewer extends StatefulWidget {
  const _ImageViewer({
    required this.file,
    required this.name,
    required this.subtitle,
    required this.onOpenExternally,
  });

  final File file;
  final String name;
  final String subtitle;
  final VoidCallback onOpenExternally;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  final TransformationController _tc = TransformationController();
  Offset _doubleTapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _tc.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  int get _zoomPct => (_tc.value.getMaxScaleOnAxis() * 100).round();

  void _zoomTo(double scale) {
    final c = _doubleTapAt;
    _tc.value = scale <= 1
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(-c.dx * (scale - 1), -c.dy * (scale - 1), 0, 1)
            ..scaleByDouble(scale, scale, 1, 1));
  }

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Scaffold(
      backgroundColor: const Color(0xFF07080C),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onOpenExternally,
                    child: Tooltip(
                      message: context.tr.viewerOpenExternally,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: white, width: 1.5),
                        ),
                        child: const Icon(
                          LucideIcons.arrowDownToLine,
                          size: 18,
                          color: white,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        context.tr.fig1Of1,
                        style: Fig.t(
                          context,
                          size: 15,
                          weight: FontWeight.w600,
                          color: white,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Tooltip(
                      message: context.tr.close,
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(LucideIcons.x, size: 24, color: white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Fig.t(
                      context,
                      size: 20,
                      weight: FontWeight.w500,
                      color: white,
                    ),
                  ),
                  if (widget.subtitle.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Fig.t(
                        context,
                        size: 12.5,
                        color: white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s34),
                child: GestureDetector(
                  onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
                  onDoubleTap: () => _zoomTo(_zoomPct > 100 ? 1 : 2.5),
                  child: InteractiveViewer(
                    transformationController: _tc,
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: Image.file(
                        widget.file,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        errorBuilder: (context, error, stack) =>
                            _UnsupportedBody(
                              onOpenExternally: widget.onOpenExternally,
                              message: context.tr.viewerLoadFailed,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              child: Row(
                children: [
                  const _RoundGhost(icon: LucideIcons.arrowLeftToLine),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.zoomIn, size: 20, color: white),
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          '$_zoomPct%',
                          style: Fig.t(context, size: 15, color: white),
                        ),
                      ],
                    ),
                  ),
                  const _RoundGhost(icon: LucideIcons.arrowRightToLine),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s22),
              child: Center(
                child: Container(
                  width: 54,
                  height: 46,
                  padding: const EdgeInsets.all(AppSpacing.s2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Fig.blueBright, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(
                      widget.file,
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              child: Column(
                children: [
                  Text(
                    context.tr.figSwipeToBrowsePinchOrDouble,
                    textAlign: TextAlign.center,
                    style: Fig.t(
                      context,
                      size: 12,
                      color: white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    context.tr.figDragToPanWhenZoomed,
                    textAlign: TextAlign.center,
                    style: Fig.t(
                      context,
                      size: 12,
                      color: const Color(0xFF6F7FB0),
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

class _RoundGhost extends StatelessWidget {
  const _RoundGhost({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.4)),
    );
  }
}
