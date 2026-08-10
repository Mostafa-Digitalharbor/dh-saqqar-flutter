import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/view_model/locale_cubit.dart';
import '../../../core/theme/app_icons.dart';
import 'account_card_header.dart';
import '../../../core/theme/view_model/theme_cubit.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../notifications/view_model/notifications_settings_cubit.dart';
import '../../push/data/push_notifications_service.dart';
import '../../security/view_model/app_lock_cubit.dart';

/// Theme + language preferences card. Reads/writes the two top-level
/// Cubits ([ThemeCubit], [LocaleCubit]).
class PreferencesCard extends StatelessWidget {
  const PreferencesCard({
    super.key,
    required this.mode,
    required this.locale,
  });

  final AppThemeMode mode;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return GlassCard(
      // Flat opaque Account backdrop → the backdrop blur has no visible
      // subject; dropping it removes a saveLayer with pixel-identical output.
      blur: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AccountCardHeader(
            icon: AppIcons.settings,
            title: context.tr.preferences,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr.theme,
            style: context.text.labelLarge?.copyWith(color: s.muted),
          ),
          const SizedBox(height: 8),
          SegmentedButton<AppThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: AppThemeMode.light,
                label: Text(context.tr.themeLight),
                icon: const Icon(AppIcons.sun),
              ),
              ButtonSegment(
                value: AppThemeMode.dark,
                label: Text(context.tr.themeDark),
                icon: const Icon(AppIcons.moon),
              ),
              ButtonSegment(
                value: AppThemeMode.system,
                label: Text(context.tr.themeSystem),
                icon: const Icon(AppIcons.settings),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) =>
                context.read<ThemeCubit>().setMode(selection.first),
          ),
          const SizedBox(height: 18),
          Text(
            context.tr.language,
            style: context.text.labelLarge?.copyWith(color: s.muted),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: UiStrings.localeEnglishCode,
                label: Text(context.tr.english),
              ),
              ButtonSegment(
                value: UiStrings.localeArabicCode,
                label: Text(context.tr.arabic),
              ),
              ButtonSegment(
                value: UiStrings.localeSystemCode,
                label: Text(context.tr.system),
              ),
            ],
            selected: {locale?.languageCode ?? UiStrings.localeSystemCode},
            onSelectionChanged: (selection) {
              final value = selection.first;
              context.read<LocaleCubit>().setLocale(
                    value == UiStrings.localeSystemCode ? null : Locale(value),
                  );
            },
          ),
          const SizedBox(height: 18),
          Text(
            context.tr.security,
            style: context.text.labelLarge?.copyWith(color: s.muted),
          ),
          // Biometric / device-credential app lock. Disabled (with a hint)
          // on devices that can't authenticate; toggling ON proves the user
          // can unlock before it's saved.
          BlocBuilder<AppLockCubit, AppLockState>(
            builder: (context, lock) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(AppIcons.lock, color: s.brandCyan),
                title: Text(context.tr.appLockSettingTitle),
                subtitle: Text(
                  lock.available
                      ? context.tr.appLockSettingSubtitle
                      : context.tr.appLockUnavailable,
                  style: context.text.bodySmall?.copyWith(color: s.muted),
                ),
                value: lock.enabled,
                onChanged: lock.available
                    ? (value) => _toggleLock(context, value)
                    : null,
              );
            },
          ),
          // Push notifications on/off. Turning OFF unregisters the device so
          // the backend stops sending; ON re-registers it.
          BlocBuilder<NotificationsSettingsCubit, bool>(
            builder: (context, enabled) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(AppIcons.bell, color: s.brandCyan),
                title: Text(context.tr.notificationsSettingTitle),
                subtitle: Text(
                  context.tr.notificationsSettingSubtitle,
                  style: context.text.bodySmall?.copyWith(color: s.muted),
                ),
                value: enabled,
                onChanged: (value) => _toggleNotifications(context, value),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleNotifications(BuildContext context, bool value) async {
    await context.read<NotificationsSettingsCubit>().setEnabled(value);
    if (!context.mounted) return;
    final push = context.read<PushNotificationsService>();
    if (value) {
      final code =
          context.read<LocaleCubit>().state?.languageCode ==
                  UiStrings.localeArabicCode
              ? UiStrings.localeArabicCode
              : UiStrings.localeEnglishCode;
      await push.start(localeCode: code);
    } else {
      await push.stop();
    }
  }

  Future<void> _toggleLock(BuildContext context, bool value) async {
    // Resolved before the await because `context.tr` is unsafe once the
    // cubit's state change has rebuilt this subtree.
    final failedMsg = context.tr.appLockEnableFailed;
    final enabled = await context
        .read<AppLockCubit>()
        .setEnabled(value, reason: context.tr.appLockReason);
    // Turning ON requires a successful auth; surface a toast if it didn't
    // take so the switch snapping back isn't mysterious. No messenger
    // capture needed — `AppToast.show` resolves one itself and no-ops when
    // there is none.
    if (value && !enabled && context.mounted) {
      AppToast.show(context, message: failedMsg, variant: ToastVariant.error);
    }
  }
}
