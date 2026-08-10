import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/skeleton_block.dart';

/// Renders the first page of a local PDF as a thumbnail.
///
/// A staged PDF used to show the same grey file glyph as every other
/// document, so a tray of three PDFs was three identical squares — you
/// could not tell which one you had just attached. Images already showed
/// their pixels; this gives documents the same treatment, using the
/// renderer `pdfx` already ships (Android `PdfRenderer`, iOS `PDFKit`), so
/// it costs no new dependency and behaves identically on both platforms.
///
/// Falls back to [placeholder] whenever anything goes wrong — an encrypted
/// or corrupt file, a path that no longer exists, or a host with no pdfx
/// implementation registered (widget tests, desktop). A thumbnail is a
/// nicety, so it must never be able to break the surface hosting it.
class PdfThumbnail extends StatefulWidget {
  const PdfThumbnail({
    super.key,
    required this.path,
    required this.width,
    required this.height,
    required this.placeholder,
  });

  final String path;

  /// Logical size of the thumbnail. Rendering is done at this size (times
  /// the device pixel ratio) rather than full page size — a first page at
  /// 72×72 costs a fraction of a full render.
  final double width;
  final double height;

  /// Shown when the page cannot be rendered. NOT used while rendering is in
  /// flight — that state gets a shimmer, so a document that is still loading
  /// never masquerades as one that failed.
  final Widget placeholder;

  /// Decoded first pages, keyed by file path. Composer chips rebuild on
  /// every keystroke in the message field; without this, each rebuild would
  /// kick off a fresh native render of the same page.
  static final Map<String, Uint8List?> _cache = <String, Uint8List?>{};

  /// Drops cached pages. Only needed by tests — the cache is keyed by path
  /// and staged files get unique paths, so it does not grow in practice.
  @visibleForTesting
  static void clearCache() {
    _cache.clear();
    lastError = null;
    renderAttempts = 0;
  }

  /// Pre-populates the page cache so a test can land directly in the
  /// "rendered" or "failed" state.
  ///
  /// The real render goes through a platform channel that never resolves in
  /// a widget-test zone, which otherwise leaves every test stuck on the
  /// loading shimmer. Seeding uses the same cache the widget reads on
  /// startup, so this exercises the production path rather than a stub.
  /// Pass null for [bytes] to represent a page that could not be rendered.
  @visibleForTesting
  static void debugSeedCache(String path, Uint8List? bytes) {
    _cache[path] = bytes;
  }

  /// How many times the renderer has actually been entered.
  ///
  /// Incremented synchronously, so a test can prove the widget got as far as
  /// calling pdfx without waiting on a platform channel to resolve. That
  /// distinction is the whole point: the bug this guards against failed
  /// during widget setup and never reached the renderer at all, which looks
  /// identical on screen to a PDF that failed to render.
  @visibleForTesting
  static int renderAttempts = 0;

  /// Why the most recent render failed, or null if it succeeded.
  ///
  /// Exposed because a failed render is invisible by design — it just shows
  /// the placeholder. That let a bug where the render was never attempted
  /// look exactly like a PDF that could not be drawn. Tests assert on this
  /// to tell those two apart.
  @visibleForTesting
  static Object? lastError;

  @override
  State<PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<PdfThumbnail> {
  Uint8List? _bytes;
  bool _done = false;
  bool _started = false;

  // The device pixel ratio has to be read here, NOT in initState. It comes
  // from MediaQuery, and an inherited-widget lookup before initState has
  // returned throws in debug builds. That threw straight into the catch
  // below, which cached a null and left every PDF showing the placeholder
  // forever — the render was never even attempted.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load(MediaQuery.devicePixelRatioOf(context));
  }

  @override
  void didUpdateWidget(PdfThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _bytes = null;
      _done = false;
      _load(MediaQuery.devicePixelRatioOf(context));
    }
  }

  Future<void> _load(double ratio) async {
    if (PdfThumbnail._cache.containsKey(widget.path)) {
      // Runs before the first build, so assigning directly is enough — and
      // setState() during didChangeDependencies would be an error.
      _bytes = PdfThumbnail._cache[widget.path];
      _done = true;
      return;
    }

    final bytes = await _render(ratio);
    PdfThumbnail._cache[widget.path] = bytes;
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _done = true;
    });
  }

  Future<Uint8List?> _render(double ratio) async {
    PdfThumbnail.renderAttempts += 1;
    try {
      final document = await PdfDocument.openFile(widget.path);
      try {
        final page = await document.getPage(1);
        try {
          // Render at the PAGE's aspect ratio, scaled so it covers the
          // target box, then let BoxFit.cover crop. Rendering straight into
          // the box's own aspect would squash a portrait page into a square.
          final scale = math.max(
            widget.width / page.width,
            widget.height / page.height,
          ) * ratio;
          final image = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            format: PdfPageImageFormat.jpeg,
            // PDF pages are transparent where unpainted, which would read as
            // a dark hole on a dark theme.
            backgroundColor: '#FFFFFF',
          );
          PdfThumbnail.lastError = null;
          return image?.bytes;
        } finally {
          await page.close();
        }
      } finally {
        await document.close();
      }
    } catch (e, st) {
      PdfThumbnail.lastError = e;
      // Encrypted, corrupt, deleted, or no pdfx implementation on this host
      // (widget tests, desktop). Logged rather than swallowed: this catch
      // already hid one real bug, and a silent null is indistinguishable
      // from "this PDF genuinely has no renderable first page".
      AppLogger.warn(
        'PdfThumbnail',
        'first-page render failed for ${widget.path}',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Three distinct states, not two. Showing [placeholder] while the render
    // is still running made the file glyph read as the finished result, and
    // then it swapped to the page a couple of seconds later — the user saw a
    // wrong answer replaced by a right one. A shimmer says "still working",
    // so the page arriving is the end of a story rather than a surprise.
    final Widget child;
    if (!_done) {
      child = SkeletonBlock(
        key: const ValueKey('loading'),
        width: widget.width,
        height: widget.height,
        radius: 0,
      );
    } else if (_bytes == null) {
      child = KeyedSubtree(
        key: const ValueKey('failed'),
        child: widget.placeholder,
      );
    } else {
      child = Image.memory(
        _bytes!,
        key: const ValueKey('page'),
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        // Top-aligned: a document's identity lives in its header, so cropping
        // a portrait page to a square should keep the top, not the middle.
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stack) => widget.placeholder,
      );
    }

    return AnimatedSwitcher(
      duration: AppDurations.cardIn,
      child: child,
    );
  }
}

/// Whether [name] is a PDF, by extension. Kept here so the chip variants
/// that opt into [PdfThumbnail] all agree on the answer.
bool isPdfName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot == -1 || dot >= name.length - 1) return false;
  return name.substring(dot + 1).toLowerCase() == 'pdf';
}
