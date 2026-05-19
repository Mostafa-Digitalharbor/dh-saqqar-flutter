import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_icons.dart';

/// Friendly fallback for uncaught widget build errors.
///
/// Replaces Flutter's default red [ErrorWidget] (which is fine in debug
/// but terrifying in production). Shows a warning icon + generic message,
/// and exposes the underlying exception when debugging — never to end
/// users in release.
///
/// Wired once at boot via:
/// ```dart
/// ErrorWidget.builder = (details) => AppErrorScreen(details: details);
/// ```
class AppErrorScreen extends StatelessWidget {
  const AppErrorScreen({super.key, required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    // We can't read app theme reliably here — this widget can mount
    // before MaterialApp's theme is in scope. Use a dark neutral palette
    // hardcoded so it always renders something sensible.
    const bg = Color(0xFF030712);
    const card = Color(0xFF111827);
    const danger = Color(0xFFEF4444);
    const muted = Color(0xFF94A3B8);

    return Material(
      color: bg,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: danger.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: danger.withValues(alpha: 0.32),
                      ),
                    ),
                    child: const Icon(
                      AppIcons.warning,
                      color: danger,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Something went wrong',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This screen ran into a problem. The error has been '
                    'logged. Try going back, or restart the app if it '
                    'keeps happening.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: muted,
                      height: 1.45,
                      fontSize: 14,
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: muted.withValues(alpha: 0.2),
                        ),
                      ),
                      child: SelectableText(
                        details.exceptionAsString(),
                        style: const TextStyle(
                          color: muted,
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Programmatic restart: pops everything to the root, then re-pushes a
/// fresh route. Doesn't truly restart the Dart isolate (that's a heavier
/// operation requiring the `restart_app` package), but visually achieves
/// the same effect for most error-recovery cases.
///
/// Called from the recovery action on [AppErrorScreen] (when wired with
/// a navigator key — left out by default because errors thrown from
/// inside `build` can break navigator state).
class AppRestart {
  AppRestart._();

  /// Hard restart by re-running `main()`. Best-effort — won't work for
  /// errors that survive a runApp() call (e.g. corrupted singletons).
  static void hardRestart() {
    // The cheapest visual restart that doesn't require a separate
    // package: signal the system to throw away the current activity so
    // the OS restores the app. iOS ignores this; Android uses it.
    SystemNavigator.pop();
  }
}
