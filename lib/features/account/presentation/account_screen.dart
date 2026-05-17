import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../widgets/widgets.dart';

/// Account tab — identity hero (with stats line), preferences, change
/// password, and sign out. The Storybook entry is hidden behind a long-press
/// on the username inside [ProfileHero] (it's a dev surface, not a user
/// feature).
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return PageScaffold(
      title: context.tr.tabAccount,
      // Username + product affiliation as the subtitle so the brand row
      // up top reads as "Saqqar / Account / who you are" — three
      // pieces of orienting context in one glance.
      subtitle: '${context.tr.sampleUsername} · ${context.tr.workspace}',
      children: [
        ProfileHero(
          onLongPress: () => context.pushNamed(RouteNames.storybook),
        ),
        const SizedBox(height: 14),
        PreferencesCard(mode: mode, locale: locale, ref: ref),
        const SizedBox(height: 14),
        const ChangePasswordCard(),
        const SizedBox(height: 14),
        GhostButton(
          label: context.tr.signOut,
          icon: AppIcons.signOut,
          tone: GhostButtonTone.danger,
          expand: true,
          onPressed: () => context.go(RouteNames.signInPath),
        ),
      ],
    );
  }
}
