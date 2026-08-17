import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/saqqar_logo.dart';
import 'update_action.dart';

/// The wall shown when this build is below the backend's supported floor.
///
/// Modelled on [AppLockScreen] on purpose — same opaque [Material], same
/// [AmbientBackground], same centred column — because both are "the app is
/// not usable right now, here is the one thing to do about it" surfaces and
/// a user should recognise the shape.
///
/// Unlike the lock screen there is deliberately **no escape hatch**: signing
/// out would not make an unsupported build supported. The single action is
/// the store, which is why `AppUpdateStatus.blocks` refuses to return `true`
/// at all when no store URL arrived — a wall whose only button cannot work is
/// a bricked app.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({
    super.key,
    required this.storeUrl,
    required this.latestVersion,
  });

  final String storeUrl;

  /// May be empty — the backend is not obliged to name the version, and the
  /// line is simply omitted rather than rendering "Version ".
  final String latestVersion;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    return Material(
      color: s.bg,
      child: AmbientBackground(
        child: SafeArea(
          // Same scroll-only-when-it-has-to treatment the lock screen needed:
          // this column is tall enough to overflow a landscape phone and a
          // 1.4× text scale, and nothing pins the app to portrait.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SaqqarLogo(height: 34),
                    const SizedBox(height: AppSpacing.s36),
                    Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.brandCyan.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: s.brandCyan.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Icon(
                        AppIcons.download,
                        size: AppIconSizes.emptyState,
                        color: s.brandCyan,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    Text(
                      tr.updateRequiredTitle,
                      style: context.text.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      tr.updateRequiredBody,
                      style: context.text.bodyMedium?.copyWith(color: s.muted),
                      textAlign: TextAlign.center,
                    ),
                    if (latestVersion.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s6),
                      Text(
                        tr.updateNewVersion(latestVersion),
                        style: context.text.labelSmall?.copyWith(color: s.muted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s32),
                    PrimaryButton(
                      label: tr.updateAction,
                      icon: AppIcons.download,
                      expand: true,
                      onPressed: () =>
                          runUpdateAction(context, storeUrl: storeUrl),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
