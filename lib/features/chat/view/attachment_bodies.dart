part of 'attachment_viewer_screen.dart';

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
