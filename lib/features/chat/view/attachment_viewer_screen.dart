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
import '../../../core/theme/fig_metrics.dart';

part 'attachment_bodies.dart';
part 'attachment_image_viewer.dart';

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
