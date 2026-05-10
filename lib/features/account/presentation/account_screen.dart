import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/danger_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../../shared/widgets/status_pill.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr.tabAccount)),
      body: AmbientBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ResponsiveContent(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ProfileHero(),
                  const SizedBox(height: 14),
                  const _StatsGrid(),
                  const SizedBox(height: 14),
                  _PreferencesCard(mode: mode, locale: locale, ref: ref),
                  const SizedBox(height: 14),
                  const _CoverageCard(),
                  const SizedBox(height: 14),
                  GhostButton(
                    label: context.tr.openStorybook,
                    icon: AppIcons.palette,
                    expand: true,
                    onPressed: () => context.pushNamed(RouteNames.storybook),
                  ),
                  const SizedBox(height: 10),
                  DangerButton(
                    label: context.tr.signOut,
                    icon: AppIcons.signOut,
                    expand: true,
                    onPressed: () => context.go(RouteNames.signInPath),
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero();

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.vivid,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: s.brandCyan.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              UiStrings.demoUserInitial,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  UiStrings.demoUsername,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    MiniChip(context.tr.standardUser),
                    StatusPill(label: context.tr.live, pulsing: true),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr.poweredByDigitalHarbor,
                  style: context.text.labelSmall?.copyWith(
                    color: s.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _StatTile(label: context.tr.tabChats, value: '6', icon: AppIcons.chats),
        _StatTile(label: context.tr.tabVault, value: '7', icon: AppIcons.key),
        _StatTile(
          label: context.tr.approvals,
          value: '2',
          icon: AppIcons.shieldCheck,
        ),
        _StatTile(
          label: context.tr.artifacts,
          value: '8',
          icon: AppIcons.fileDown,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return GlassCard(
      blur: false,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: s.brandCyanSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: s.brandCyanBorder),
            ),
            child: Icon(icon, color: s.brandCyan, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    color: s.muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppGradients.vivid.createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    value,
                    style: context.text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({
    required this.mode,
    required this.locale,
    required this.ref,
  });

  final AppThemeMode mode;
  final Locale? locale;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr.preferences, style: context.text.titleMedium),
          const SizedBox(height: 14),
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
            onSelectionChanged: (selection) => ref
                .read(themeControllerProvider.notifier)
                .setMode(selection.first),
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
              ref
                  .read(localeControllerProvider.notifier)
                  .setLocale(
                    value == UiStrings.localeSystemCode ? null : Locale(value),
                  );
            },
          ),
        ],
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr.workspaceCoverage, style: context.text.titleMedium),
          const SizedBox(height: 12),
          _CoverageTile(
            icon: AppIcons.chats,
            title: context.tr.conversationsCoverageTitle,
            body: context.tr.conversationsCoverageBody,
          ),
          _CoverageTile(
            icon: AppIcons.key,
            title: context.tr.vaultCoverageTitle,
            body: context.tr.vaultCoverageBody,
          ),
          _CoverageTile(
            icon: AppIcons.shieldCheck,
            title: context.tr.approvalsCoverageTitle,
            body: context.tr.approvalsCoverageBody,
          ),
          _CoverageTile(
            icon: AppIcons.fileDown,
            title: context.tr.artifactsCoverageTitle,
            body: context.tr.artifactsCoverageBody,
          ),
        ],
      ),
    );
  }
}

class _CoverageTile extends StatelessWidget {
  const _CoverageTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: s.brandCyan, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: context.text.bodySmall?.copyWith(color: s.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
