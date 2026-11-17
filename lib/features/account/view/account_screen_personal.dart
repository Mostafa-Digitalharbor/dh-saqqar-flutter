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
              size: 10.5,
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
            color: const Color(0xFFEFF2FD),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: Fig.borderBlue),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Fig.t(context, size: 12.5, color: Fig.navy),
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
            const Icon(LucideIcons.info, size: 15, color: Fig.muted),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                context.tr.figTheseAreTheSignUpDetails,
                style: Fig.t(
                  context,
                  size: 10.5,
                  color: Fig.muted,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
