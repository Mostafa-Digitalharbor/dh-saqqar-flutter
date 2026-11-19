part of 'attachment_viewer_screen.dart';

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
    const white = AppColors.figWhite;
    return Scaffold(
      backgroundColor: AppColors.figCFF07080C,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s14, AppSpacing.s20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onOpenExternally,
                    child: Tooltip(
                      message: context.tr.viewerOpenExternally,
                      child: Container(
                        width: FigMetrics.size36, height: FigMetrics.size36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.small),
                          border: Border.all(color: white, width: AppBorderWidths.thick),
                        ),
                        child: const Icon(
                          LucideIcons.arrowDownToLine,
                          size: AppIconSizes.regular,
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
                          size: AppFontSizes.body,
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
                        width: FigMetrics.size36, height: FigMetrics.size36,
                        child: Icon(LucideIcons.x, size: AppIconSizes.back, color: white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s30, AppSpacing.s24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Fig.t(
                      context,
                      size: AppFontSizes.crashTitle,
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
                        size: AppFontSizes.metaLine,
                        color: white.withValues(alpha: AppAlphas.a50),
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
              padding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s22, AppSpacing.s24, 0),
              child: Row(
                children: [
                  const _RoundGhost(icon: LucideIcons.arrowLeftToLine),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.zoomIn, size: AppIconSizes.action, color: white),
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          '$_zoomPct%',
                          style: Fig.t(context, size: AppFontSizes.body, color: white),
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
                  width: FigMetrics.size54, height: FigMetrics.size46,
                  padding: const EdgeInsets.all(AppSpacing.s2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(color: Fig.blueBright, width: AppBorderWidths.ring),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.checkbox),
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
              padding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s28, AppSpacing.s24, AppSpacing.s22),
              child: Column(
                children: [
                  Text(
                    context.tr.figSwipeToBrowsePinchOrDouble,
                    textAlign: TextAlign.center,
                    style: Fig.t(
                      context,
                      size: AppFontSizes.microCaps,
                      color: white.withValues(alpha: AppAlphas.a50),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    context.tr.figDragToPanWhenZoomed,
                    textAlign: TextAlign.center,
                    style: Fig.t(
                      context,
                      size: AppFontSizes.microCaps,
                      color: AppColors.figCFF6F7FB0,
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
      width: FigMetrics.size40, height: FigMetrics.size40,
      decoration: BoxDecoration(
        color: AppColors.figWhite.withValues(alpha: AppAlphas.a08),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: AppIconSizes.regular, color: AppColors.figWhite.withValues(alpha: AppAlphas.a40)),
    );
  }
}
