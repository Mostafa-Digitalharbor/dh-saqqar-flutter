import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/view_model/auth_cubit.dart';
import '../../notifications/data/notifications_store.dart';
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
    // Re-engage the lock ONLY when the app is actually backgrounded — the
    // user pressed home or switched to another app (`paused`). We
    // deliberately do NOT lock on `inactive` / `hidden`: those fire for
    // transient interruptions that keep the app in the foreground (pulling
    // down the notification shade, the control center, an incoming-call
    // overlay, the app-switcher peek). Locking on those made the app demand
    // a fingerprint every time the user glanced at their notifications.
    switch (state) {
      case AppLifecycleState.paused:
        context.read<AppLockCubit>().lock();
      case AppLifecycleState.resumed:
        // Pick up any notifications the FCM background isolate wrote while
        // we were away, so the header bell's unread dot is accurate.
        context.read<NotificationsStore>().reload();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authed = context.select<AuthCubit, bool>(
      (c) => c.state.isAuthenticated,
    );
    // Is the opaque lock currently covering the app?
    final showLock = authed &&
        context.select<AppLockCubit, bool>(
          (c) => c.state.enabled && c.state.locked,
        );
    return Stack(
      children: [
        // While the lock is up, drop the authenticated app out of the
        // semantics tree so TalkBack / VoiceOver can't read the Odoo data
        // behind the opaque lock screen — the lock previously hid pixels
        // only, leaving the content reachable to assistive tech. No effect
        // when unlocked (`excluding: false`), so the normal experience is
        // byte-for-byte unchanged.
        ExcludeSemantics(
          excluding: showLock,
          child: widget.child,
        ),
        if (showLock) const Positioned.fill(child: AppLockScreen()),
      ],
    );
  }
}
