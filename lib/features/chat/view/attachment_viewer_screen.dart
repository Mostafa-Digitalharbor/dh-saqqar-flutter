import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/extensions/context_extensions.dart';
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
  static AttachmentViewerKind kindFor(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
    if (const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].contains(ext)) {
      return AttachmentViewerKind.image;
    }
    if (ext == 'pdf') return AttachmentViewerKind.pdf;
    // Text-shaped documents we can show verbatim. CSV/TSV are in the
    // composer's allow-list, the rest show up as agent-generated
    // artifacts (logs, JSON dumps, SQL).
    if (const [
      'csv', 'tsv', 'txt', 'md', 'json', 'log',
      'xml', 'yaml', 'yml', 'ini', 'sql', 'html',
    ].contains(ext)) {
      return AttachmentViewerKind.text;
    }
    // DOCX / XLSX / ZIP and friends are archives of XML — rendering them
    // faithfully needs an office engine we deliberately don't ship.
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

    return Scaffold(
      backgroundColor: isImage ? Colors.black : s.bg,
      appBar: AppBar(
        backgroundColor: isImage ? Colors.black : s.bg,
        foregroundColor: isImage ? Colors.white : s.text,
        elevation: 0,
        titleSpacing: 0,
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
                color: isImage ? Colors.white : s.text,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: isImage ? Colors.white70 : s.muted,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openExternally,
            icon: const Icon(AppIcons.open, size: 20),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: s.warning.withValues(alpha: 0.12),
            child: Text(
              context.tr.viewerTruncated,
              style: context.text.labelSmall?.copyWith(color: s.warning),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                text,
                style: const TextStyle(
                  fontFamily: AppTypography.fontMono,
                  fontSize: 12,
                  height: 1.5,
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.brandCyan.withValues(alpha: 0.10),
              ),
              child: Icon(AppIcons.fileText, size: 26, color: s.brandCyan),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? tr.viewerUnsupportedTitle,
              textAlign: TextAlign.center,
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr.viewerUnsupportedBody,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: s.muted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onOpenExternally,
              icon: const Icon(AppIcons.open, size: 16),
              label: Text(tr.viewerOpenExternally),
              style: FilledButton.styleFrom(
                backgroundColor: s.brandCyan,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.buttonR,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
