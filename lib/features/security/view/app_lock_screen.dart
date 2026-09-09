import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../shared/widgets/blocking_wall.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sign_out_helper.dart';
import '../view_model/app_lock_cubit.dart';
import '../../../core/theme/app_icons.dart';

/// Full-screen lock shown over the app when the biometric / device-credential
/// lock is engaged. Auto-prompts the OS authenticator on first show; on
/// failure the user can retry, or sign out as an escape hatch (so a user who
/// genuinely can't authenticate is never stranded).
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  @override
  void initState() {
    super.initState();
    // Fire the system prompt as soon as the lock appears so the common case
    // (open app → Face ID) needs zero taps.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    await context.read<AppLockCubit>().unlock(reason: context.tr.appLockReason);
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return BlockingWall(
      icon: AppIcons.lock,
      title: tr.appLockTitle,
      body: tr.appLockSubtitle,
      actions: [
        BlocBuilder<AppLockCubit, AppLockState>(
          buildWhen: (a, b) => a.authenticating != b.authenticating,
          builder: (context, state) => PrimaryButton(
            label: tr.appLockUnlock,
            icon: AppIcons.biometric,
            expand: true,
            loading: state.authenticating,
            onPressed: state.authenticating ? null : _unlock,
          ),
        ),
        // Escape hatch — never strand a user who cannot authenticate.
        GhostButton(
          label: tr.signOut,
          icon: AppIcons.signOut,
          tone: GhostButtonTone.danger,
          expand: true,
          onPressed: () => showSignOutFlow(context),
        ),
      ],
    );
  }
}
