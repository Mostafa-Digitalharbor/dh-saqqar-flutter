part of 'account_screen.dart';

class _Accordion extends StatelessWidget {
  const _Accordion({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.open,
    required this.onTap,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool open;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      decoration: BoxDecoration(
        color: Fig.cardFill.withValues(alpha: AppAlphas.a95),
        borderRadius: BorderRadius.circular(AppRadius.navBar),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s9, AppSpacing.s12, AppSpacing.s14, AppSpacing.s12),
              child: Row(
                children: [
                  Container(
                    width: FigMetrics.size30, height: FigMetrics.size30,
                    decoration: BoxDecoration(
                      color: AppColors.figCFFDCE1F1,
                      borderRadius: BorderRadius.circular(FigMetrics.radFig9),
                    ),
                    child: Icon(icon, size: AppIconSizes.small, color: Fig.tileText),
                  ),
                  const SizedBox(width: AppSpacing.s11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Fig.t(
                            context,
                            size: AppFontSizes.pillTitle,
                            weight: FontWeight.w500,
                            color: Fig.navy,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Fig.t(context, size: FigMetrics.fontFig8U5, color: Fig.muted),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: AppDurations.fast,
                    child: const Icon(
                      LucideIcons.chevronDown,
                      size: AppIconSizes.navBar,
                      color: Fig.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDurations.expand,
            alignment: Alignment.topCenter,
            curve: Curves.easeOutCubic,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s14, 0, AppSpacing.s14, AppSpacing.s14),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow(this.icon, this.label, this.onTap, {this.last = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.figCFFD9E0F5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: AppIconSizes.regular, color: AppColors.figCFF5B6585),
            const SizedBox(width: AppSpacing.s14),
            Expanded(
              child: Text(
                label,
                style: Fig.t(
                  context,
                  size: AppFontSizes.pillTitle,
                  weight: FontWeight.w500,
                  color: Fig.navy,
                ),
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? LucideIcons.chevronLeft
                  : LucideIcons.chevronRight,
              size: AppIconSizes.regular,
              color: Fig.mutedSoft,
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s6,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Fig.t(context, size: AppFontSizes.dense, color: Fig.dangerText),
              ),
            ),
            Icon(icon, size: AppIconSizes.action, color: Fig.dangerText),
          ],
        ),
      ),
    );
  }
}
