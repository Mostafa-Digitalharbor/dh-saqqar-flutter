import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/saqqar_logo.dart';
import '../../../shared/widgets/sign_out_helper.dart';
import '../view_model/app_lock_cubit.dart';

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
    final s = context.saqqar;
    final tr = context.tr;
    return Material(
      // Opaque so nothing behind the lock is ever visible (incl. the app
      // switcher snapshot, which iOS/Android take of the top-most layer).
      color: s.bg,
      child: AmbientBackground(
        child: SafeArea(
          // Scrolls only when it has to. The column is ~360dp tall, which
          // fits any portrait phone but NOT a landscape one (~320dp of
          // viewport) — and nothing pins this screen to portrait, so a
          // returning user rotating their phone hit a RenderFlex overflow on
          // the very first surface they see. `minHeight: maxHeight` keeps
          // `MainAxisAlignment.center` behaving exactly as before wherever
          // there's room; past that the content scrolls instead of clipping.
          // Also covers the 1.4× text-scale case, where the subtitle wraps to
          // three lines and overflows portrait too.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SaqqarLogo(height: 34),
                    const SizedBox(height: 36),
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
                      child: Icon(AppIcons.lock, size: 32, color: s.brandCyan),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      tr.appLockTitle,
                      style: context.text.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr.appLockSubtitle,
                      style: context.text.bodyMedium?.copyWith(color: s.muted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
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
                    const SizedBox(height: 10),
                    // Escape hatch — never strand a user who can't
                    // authenticate.
                    GhostButton(
                      label: tr.signOut,
                      icon: AppIcons.signOut,
                      tone: GhostButtonTone.danger,
                      expand: true,
                      onPressed: () => showSignOutFlow(context),
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
