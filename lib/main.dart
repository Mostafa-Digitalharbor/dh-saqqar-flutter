import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme/theme_controller.dart';

/// Boot order:
///   1. Bind Flutter immediately and PRESERVE the native splash so the
///      OS-rendered logo stays visible while we hydrate SharedPreferences.
///   2. Hand off to [SaqqarApp]. Its first child is the in-app
///      [LaunchSplashScreen] which animates the same logo (zoom-in) on
///      top of the OS splash before removing it. The transition feels
///      seamless because both surfaces center the same artwork.
///   3. The in-app splash calls `FlutterNativeSplash.remove()` itself the
///      moment its entrance animation has been on screen long enough — see
///      `SaqqarApp._handleSplashReady`.
Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SaqqarApp(),
    ),
  );
}
