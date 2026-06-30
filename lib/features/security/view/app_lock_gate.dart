import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/view_model/auth_cubit.dart';
import '../view_model/app_lock_cubit.dart';
import 'app_lock_screen.dart';

/// Wraps the whole app and overlays [AppLockScreen] whenever the app lock is
/// engaged. Also owns the re-lock policy: the lock re-engages every time the
/// app returns from the background, so a glance at the app switcher (or
/// handing the phone over) never exposes the user's Odoo data.
///
/// The lock is only shown to an AUTHENTICATED user — there's nothing
/// sensitive to guard on the sign-in screen, and gating it there would mean
/// a pointless Face ID prompt before login.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Re-engage the lock the moment the app is no longer in the foreground —
    // on `inactive`/`hidden`/`paused`, BEFORE the OS captures the app-switcher
    // snapshot — so the snapshot shows the lock, not the user's data.
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        context.read<AppLockCubit>().lock();
      case AppLifecycleState.resumed:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authed = context.select<AuthCubit, bool>(
      (c) => c.state.isAuthenticated,
    );
    return Stack(
      children: [
        widget.child,
        if (authed)
          BlocBuilder<AppLockCubit, AppLockState>(
            buildWhen: (a, b) =>
                a.enabled != b.enabled || a.locked != b.locked,
            builder: (context, state) {
              if (!state.enabled || !state.locked) {
                return const SizedBox.shrink();
              }
              return const Positioned.fill(child: AppLockScreen());
            },
          ),
      ],
    );
  }
}
