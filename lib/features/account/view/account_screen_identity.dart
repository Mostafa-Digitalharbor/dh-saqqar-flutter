part of 'account_screen.dart';

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.email,
    required this.plan,
    this.onLongPress,
  });

  final String name;
  final String email;
  final String plan;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.figWhite,
          borderRadius: BorderRadius.circular(AppRadius.heroPlate),
        ),
        child: Row(
          children: [
            ClipOval(
              child: Image.asset(
                AssetPaths.avatar,
                width: FigMetrics.size66, height: FigMetrics.size66,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Fig.t(
                      context,
                      size: AppFontSizes.crashTitle,
                      weight: FontWeight.w600,
                      color: Fig.inkDeep,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Fig.t(context, size: FigMetrics.fontFig11U5, color: Fig.muted),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s18,
                      vertical: AppSpacing.s6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.figCFF414A9E,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                    child: Text(
                      plan,
                      style: Fig.t(
                        context,
                        size: FigMetrics.fontFig11,
                        color: AppColors.figWhite,
                        letterSpacing: AppLetterSpacing.tight,
                      ),
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

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: FigMetrics.boxMInHU68),
        padding: const EdgeInsets.fromLTRB(AppSpacing.s10, AppSpacing.s8, AppSpacing.s4, AppSpacing.s8),
        decoration: BoxDecoration(
          color: AppColors.figWhite.withValues(alpha: AppAlphas.a90),
          borderRadius: BorderRadius.circular(AppRadius.modal),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: Fig.t(
                context,
                size: AppFontSizes.headlineLarge,
                weight: FontWeight.w700,
                color: Fig.inkDeep,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Fig.t(context, size: FigMetrics.fontFig9U5, color: AppColors.figCFF5E6478),
            ),
          ],
        ),
      ),
    );
  }
}
