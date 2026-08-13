import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../view_model/app_update_cubit.dart';
import 'update_required_screen.dart';

/// Replaces the entire app with [UpdateRequiredScreen] while the running
/// build is below the backend's supported floor, and re-asks on resume.
///
/// **Why resume matters.** The interesting case is not cold start — it is the
/// phone that has had Saqqar open in the background for a week. The backend
/// raises the floor at 10:00; without a resume check that user keeps talking
/// to an API that no longer supports them until they happen to force-quit.
///
/// The re-check is cheap by construction: [AppUpdateCubit.check] throttles on
/// a monotonic stopwatch and stops entirely once it is blocking, so `resumed`
/// firing on every app switch costs one comparison.
///
/// Mounted beside `AppLockGate` rather than inside the router, so it covers
/// the sign-in screens too — an unsupported build must not be able to attempt
/// an auth handshake it no longer speaks.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Post-frame, not inline: `check()` emits, and emitting during the first
    // build of a subtree that is already listening is the classic
    // "setState() called during build" crash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppUpdateCubit?>()?.check();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    if (!mounted) return;
    context.read<AppUpdateCubit?>()?.check();
  }

  @override
  Widget build(BuildContext context) {
    // Nullable, for the same reason [UpdateNudgeBanner] is: a harness that
    // pumps `SaqqarApp` without the full `main()` provider list must still
    // get an app, not a `ProviderNotFoundException`. Absent cubit → absent
    // opinion → pass through, which is the same fail-open rule the whole
    // feature is built on.
    //
    // `select` rather than `watch` so a `dismissed` flip (which only the
    // banner cares about) does not rebuild every screen in the app to hide
    // one row.
    final blocking =
        context.select<AppUpdateCubit?, bool>((c) => c?.state.isBlocking ?? false);
    if (!blocking) return widget.child;
    final status = context.read<AppUpdateCubit>().state.status!;
    return UpdateRequiredScreen(
      storeUrl: status.storeUrl,
      latestVersion: status.latestVersion,
    );
  }
}
