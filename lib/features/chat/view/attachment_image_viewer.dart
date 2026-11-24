part of 'attachment_viewer_screen.dart';

/// The redesigned fullscreen image viewer (figma-design / Fullscreen image
/// viewer): save + counter + close up top, file name and meta, the picture,
/// a zoom read-out, the thumbnail strip and the gesture hints.
class _ImageViewer extends StatefulWidget {
  const _ImageViewer({
    required this.items,
    required this.initialIndex,
    required this.onOpenExternally,
  });

  final List<ViewerImage> items;
  final int initialIndex;
  final VoidCallback onOpenExternally;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  final TransformationController _tc = TransformationController();
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  Offset _doubleTapAt = Offset.zero;

  ViewerImage get _current => widget.items[_index];

  @override
  void initState() {
    super.initState();
    _tc.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tc.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _onPage(int i) {
    // Each picture starts unzoomed.
    _tc.value = Matrix4.identity();
    setState(() => _index = i);
  }

  void _goTo(int i) {
    if (i < 0 || i >= widget.items.length) return;
    _pages.animateToPage(
      i,
      duration: AppDurations.expand,
      curve: Curves.easeOut,
    );
  }

  /// Tap handler for the arrow on one side, or null when there is no picture
  /// that way. "Left" is what the user sees, so it flips in right-to-left.
  VoidCallback? _step(BuildContext context, {required bool left}) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final target = _index + ((left != rtl) ? -1 : 1);
    if (target < 0 || target >= widget.items.length) return null;
    return () => _goTo(target);
  }

  Widget _picture(ViewerImage item) {
    Widget broken(BuildContext context) => _UnsupportedBody(
      onOpenExternally: widget.onOpenExternally,
      message: context.tr.viewerLoadFailed,
    );
    final file = item.file;
    if (file != null) {
      return Image.file(
        file,
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (context, error, stack) => broken(context),
      );
    }
    return Image.network(
      item.url!,
      fit: BoxFit.contain,
      width: double.infinity,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const Center(child: CircularProgressIndicator()),
      // A picture that will not stream just says so; the full hand-off
      // screen is for a file we have and cannot draw.
      errorBuilder: (context, error, stack) => Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.imageOff,
                size: AppIconSizes.emptyState,
                color: AppColors.figWhite,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                context.tr.viewerLoadFailed,
                style: Fig.t(context, color: AppColors.figWhite),
              ),
            ],
          ),
        ),
      ),
    );
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AppSpacing.s14,
                AppSpacing.s20,
                0,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onOpenExternally,
                    child: Tooltip(
                      message: context.tr.viewerOpenExternally,
                      child: Container(
                        width: FigMetrics.size36,
                        height: FigMetrics.size36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.small),
                          border: Border.all(
                            color: white,
                            width: AppBorderWidths.thick,
                          ),
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
                        '${_index + 1} / ${widget.items.length}',
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
                        width: FigMetrics.size36,
                        height: FigMetrics.size36,
                        child: Icon(
                          LucideIcons.x,
                          size: AppIconSizes.back,
                          color: white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s30,
                AppSpacing.s24,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _current.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Fig.t(
                      context,
                      size: AppFontSizes.crashTitle,
                      weight: FontWeight.w500,
                      color: white,
                    ),
                  ),
                  if (_current.subtitle.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      _current.subtitle,
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
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: widget.items.length,
                    onPageChanged: _onPage,
                    // Zoomed in, a drag pans the picture; only at 100% does
                    // it turn the page.
                    physics: _zoomPct > 100
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemBuilder: (context, i) => InteractiveViewer(
                      transformationController: i == _index ? _tc : null,
                      minScale: 1,
                      maxScale: 5,
                      child: Center(child: _picture(widget.items[i])),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s22,
                AppSpacing.s24,
                0,
              ),
              child: Row(
                children: [
                  _RoundGhost(
                    icon: LucideIcons.arrowLeftToLine,
                    onTap: _step(context, left: true),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.zoomIn,
                          size: AppIconSizes.action,
                          color: white,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          '$_zoomPct%',
                          style: Fig.t(
                            context,
                            size: AppFontSizes.body,
                            color: white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RoundGhost(
                    icon: LucideIcons.arrowRightToLine,
                    onTap: _step(context, left: false),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s22),
              child: SizedBox(
                height: FigMetrics.size46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s24,
                  ),
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.s8),
                  itemBuilder: (context, i) => _Thumb(
                    item: widget.items[i],
                    selected: i == _index,
                    onTap: () => _goTo(i),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s28,
                AppSpacing.s24,
                AppSpacing.s22,
              ),
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
  const _RoundGhost({required this.icon, this.onTap});
  final IconData icon;

  /// Null when there is nothing in that direction: drawn dim and inert.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: FigMetrics.size40,
        height: FigMetrics.size40,
        decoration: BoxDecoration(
          color: AppColors.figWhite.withValues(alpha: AppAlphas.a08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: AppIconSizes.regular,
          color: AppColors.figWhite.withValues(
            alpha: onTap == null ? AppAlphas.a40 : AppAlphas.a85,
          ),
        ),
      ),
    );
  }
}

/// One thumbnail in the strip under the picture; the current one is ringed.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ViewerImage item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const empty = SizedBox.shrink();
    final file = item.file;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: FigMetrics.size54,
        height: FigMetrics.size46,
        padding: const EdgeInsets.all(AppSpacing.s2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
            color: selected ? Fig.blueBright : Colors.transparent,
            width: AppBorderWidths.ring,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.checkbox),
          child: file != null
              ? Image.file(
                  file,
                  fit: BoxFit.cover,
                  cacheWidth: 160,
                  errorBuilder: (_, __, ___) => empty,
                )
              : Image.network(
                  item.url!,
                  fit: BoxFit.cover,
                  cacheWidth: 160,
                  errorBuilder: (_, __, ___) => empty,
                ),
        ),
      ),
    );
  }
}
