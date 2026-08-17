import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/view_model/locale_cubit.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/view_model/theme_cubit.dart';
import '../../shared/extensions/context_extensions.dart';
import '../../shared/widgets/ambient_background.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/eyebrow_label.dart';
import '../../shared/widgets/ghost_button.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/mini_chip.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/user_avatar.dart';
import '../../core/theme/app_icons.dart';

/// Showcase screen — every shared widget rendered with both themes
/// reachable via the Account screen. Used by the developer to verify
/// dark + light + LTR + RTL parity in one place.
class StorybookScreen extends StatelessWidget {
  const StorybookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(context.tr.storybook),
          actions: [
            IconButton(
              icon: Icon(context.isDark ? AppIcons.sun : AppIcons.moon),
              onPressed: () => context.read<ThemeCubit>().toggle(),
              tooltip: context.tr.toggleTheme,
            ),
            IconButton(
              icon: Icon(
                context.isRtl
                    ? AppIcons.textDirLtr
                    : AppIcons.textDirRtl,
              ),
              onPressed: () =>
                  context.read<LocaleCubit>().toggleEnglishArabic(),
              tooltip: context.tr.toggleLanguage,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          children: [
            _section(context, context.tr.storybookEyebrowMiniChip, [
              EyebrowLabel(context.tr.storybookEyebrowLabel),
              const SizedBox(height: AppSpacing.s8),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  MiniChip(context.tr.agentRequests),
                  MiniChip(context.tr.review),
                  MiniChip(context.tr.downloads),
                ],
              ),
            ]),

            _section(context, context.tr.storybookStatusPills, [
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  StatusPill(
                    label: context.tr.live,
                    variant: StatusPillVariant.success,
                    pulsing: true,
                  ),
                  StatusPill(
                    label: context.tr.approvalGated,
                    variant: StatusPillVariant.warning,
                  ),
                  StatusPill(
                    label: context.tr.autoApproveOn,
                    variant: StatusPillVariant.info,
                    pulsing: true,
                  ),
                  StatusPill(
                    label: context.tr.failed,
                    variant: StatusPillVariant.danger,
                  ),
                ],
              ),
            ]),

            _section(context, context.tr.storybookButtons, [
              PrimaryButton(
                label: context.tr.signIn,
                icon: AppIcons.signIn,
                expand: true,
                onPressed: () => AppToast.show(
                  context,
                  message: context.tr.primaryTapped,
                  variant: ToastVariant.success,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              GhostButton(
                label: context.tr.cancel,
                expand: true,
                onPressed: () => AppToast.show(
                  context,
                  message: context.tr.ghostTapped,
                  variant: ToastVariant.info,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              GhostButton(
                label: context.tr.delete,
                icon: AppIcons.trash,
                tone: GhostButtonTone.danger,
                expand: true,
                onPressed: () => AppToast.show(
                  context,
                  message: context.tr.dangerTapped,
                  variant: ToastVariant.error,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              Row(
                children: [
                  AppIconButton(
                    icon: AppIcons.refresh,
                    onPressed: () {},
                    tooltip: context.tr.refresh,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  AppIconButton(
                    icon: AppIcons.plus,
                    onPressed: () {},
                    tooltip: context.tr.add,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  AppIconButton(
                    icon: AppIcons.attach,
                    onPressed: () {},
                    tooltip: context.tr.attach,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  AppIconButton(
                    icon: AppIcons.search,
                    onPressed: () {},
                    tooltip: context.tr.search,
                  ),
                ],
              ),
            ]),

            _section(context, context.tr.storybookInputs, [
              AppTextField(
                label: context.tr.username,
                hint: context.tr.sampleUsername,
                prefixIcon: AppIcons.user,
                helper: context.tr.fieldRulesHint,
              ),
              const SizedBox(height: AppSpacing.s12),
              AppPasswordField(
                label: context.tr.password,
                hint: context.tr.samplePasswordHint,
              ),
              const SizedBox(height: AppSpacing.s12),
              AppTextField(
                label: context.tr.withError,
                hint: context.tr.tryAgain,
                prefixIcon: AppIcons.error,
                errorText: context.tr.invalidValue,
              ),
            ]),

            _section(context, context.tr.storybookSwitches, [
              Row(
                children: [
                  Switch(value: true, onChanged: (_) {}),
                  const SizedBox(width: AppSpacing.s12),
                  Text(context.tr.autoApprove, style: context.text.bodyMedium),
                ],
              ),
            ]),

            _section(context, context.tr.storybookAvatars, [
              Row(
                children: [
                  UserAvatar(
                    username: context.tr.sampleUsername,
                    size: AppAvatarSizes.small,
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  UserAvatar(
                    username: context.tr.sampleUserSarah,
                    size: AppAvatarSizes.medium,
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  UserAvatar(
                    username: context.tr.sampleUserArabic,
                    size: AppAvatarSizes.large,
                  ),
                ],
              ),
            ]),

            _section(context, context.tr.storybookGlassCard, [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EyebrowLabel(context.tr.appName),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      context.tr.conversationTitle,
                      style: context.text.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      context.tr.liveAccessNote,
                      style: (context.text.bodySmall ?? const TextStyle())
                          .copyWith(color: s.muted),
                    ),
                  ],
                ),
              ),
            ]),

            _section(context, context.tr.storybookEmptyState, [
              EmptyState(
                title: context.tr.noConversations,
                body: context.tr.noConversationsHint,
                icon: AppIcons.message,
                action: PrimaryButton(
                  label: context.tr.newConversation,
                  icon: AppIcons.plus,
                  onPressed: () {},
                ),
              ),
            ]),

            const SizedBox(height: AppSpacing.s24),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4,
              vertical: AppSpacing.s4,
            ),
            margin: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: Text(
              title,
              style: (context.text.titleSmall ?? const TextStyle()).copyWith(
                color: s.muted,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
