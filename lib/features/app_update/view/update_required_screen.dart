import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/blocking_wall.dart';
import '../../../shared/fig/fig.dart';
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
    final tr = context.tr;
    return BlockingWall(
      icon: AppIcons.download,
      title: tr.updateRequiredTitle,
      body: tr.updateRequiredBody,
      footnote: latestVersion.isEmpty
          ? null
          : tr.updateNewVersion(latestVersion),
      actions: [
        FigButton(
          label: tr.updateAction,
          onPressed: () => runUpdateAction(context, storeUrl: storeUrl),
        ),
      ],
    );
  }
}
