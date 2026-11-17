part of 'account_screen.dart';

class _Preferences extends StatelessWidget {
  const _Preferences();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleCubit>().state;
    final lock = context.watch<AppLockCubit>().state;
    final notifs = context.watch<NotificationsSettingsCubit>().state;
    final cur = locale?.languageCode;
    Widget seg(String label, bool active, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Fig.slate.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: Fig.t(
                    context,
                    size: 11.5,
                    weight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active ? Fig.blue : Fig.mutedBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (active) ...[
                const SizedBox(width: AppSpacing.s4),
                const Icon(LucideIcons.check, size: 13, color: Fig.blue),
              ],
            ],
          ),
        ),
      ),
    );
    Widget toggle(bool v, ValueChanged<bool> on) => GestureDetector(
      onTap: () => on(!v),
      child: AnimatedContainer(
        duration: AppDurations.menuIn,
        width: 36,
        height: 22,
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: v ? Fig.switchOn : const Color(0xFF3A3C48),
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: v ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
    Widget row(String title, String sub, Widget t) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Fig.t(
                    context,
                    size: 12,
                    weight: FontWeight.w600,
                    color: Fig.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  sub,
                  style: Fig.t(
                    context,
                    size: 10,
                    color: Fig.muted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          t,
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr.figLanguage,
          style: Fig.t(
            context,
            size: 11,
            weight: FontWeight.w500,
            color: Fig.navy,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: const Color(0xFFEAEDFB),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD4DBF4)),
          ),
          child: Row(
            children: [
              seg(
                'English',
                cur == 'en',
                () => context.read<LocaleCubit>().setLocale(const Locale('en')),
              ),
              seg(
                context.tr.figArabic,
                cur == 'ar',
                () => context.read<LocaleCubit>().setLocale(const Locale('ar')),
              ),
              seg(
                context.tr.figSystem,
                cur == null,
                () => context.read<LocaleCubit>().setLocale(null),
              ),
            ],
          ),
        ),
        row(
          context.tr.figAppLock,
          context.tr.figRequireFaceIdFingerprint,
          toggle(lock.enabled, (v) async {
            final ok = await context.read<AppLockCubit>().setEnabled(
              v,
              reason: context.tr.figConfirmItSYouToEnable,
            );
            if (!ok && v && context.mounted) {
              AppToast.show(
                context,
                message: context.tr.figAppLockIsnTAvailableOn,
                variant: ToastVariant.info,
              );
            }
          }),
        ),
        row(
          context.tr.figNotifications,
          context.tr.figGetNotifiedAboutApprovalsFinishedTask,
          toggle(
            notifs,
            (v) => context.read<NotificationsSettingsCubit>().setEnabled(v),
          ),
        ),
      ],
    );
  }
}
