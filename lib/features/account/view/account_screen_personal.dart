part of 'account_screen.dart';

Widget _readonlyField(BuildContext context, String label, String value) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            bottom: AppSpacing.s6,
            top: AppSpacing.s6,
          ),
          child: Text(
            label,
            style: Fig.t(
              context,
              size: FigMetrics.fontFig10U5,
              weight: FontWeight.w500,
              color: Fig.navy,
            ),
          ),
        ),
        Container(
          height: 46,
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.figCFFEFF2FD,
            borderRadius: BorderRadius.circular(FigMetrics.radFig23),
            border: Border.all(color: Fig.borderBlue),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Fig.t(context, size: AppFontSizes.metaLine, color: Fig.navy),
          ),
        ),
      ],
    );

class _PersonalInfo extends StatelessWidget {
  const _PersonalInfo({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _readonlyField(context, context.tr.figFullName, name),
        const SizedBox(height: AppSpacing.s6),
        _readonlyField(context, context.tr.figEmailAddress, email),
        const SizedBox(height: AppSpacing.s14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.info, size: AppIconSizes.inline, color: Fig.muted),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                context.tr.figTheseAreTheSignUpDetails,
                style: Fig.t(
                  context,
                  size: FigMetrics.fontFig10U5,
                  color: Fig.muted,
                  height: AppLineHeights.label,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
