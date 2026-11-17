import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/logging/app_logger.dart';

/// Thin, testable wrapper over [LocalAuthentication]. Keeps the plugin out
/// of the cubit so the lock logic can be unit-tested with a fake, and so
/// every platform quirk (a thrown `PlatformException` when no biometrics are
/// enrolled, etc.) is swallowed into a plain `bool` in ONE place.
class BiometricAuth {
  BiometricAuth([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  static const _tag = 'BiometricAuth';

  final LocalAuthentication _auth;

  /// True when the device can authenticate the user — either with a
  /// biometric (Face ID / fingerprint) OR the device passcode/pattern as a
  /// fallback. We accept the passcode fallback so the lock still works on
  /// phones without enrolled biometrics.
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      // `canCheckBiometrics` is false on a passcode-only device, but
      // `isDeviceSupported` already confirms a device credential exists, so
      // `supported` is the real gate. The biometric check is informational.
      return true;
    } catch (e, st) {
      AppLogger.warn(_tag, 'isAvailable() failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Prompts the OS authenticator. [reason] is shown in the system dialog
  /// (localized by the caller). Returns true only on a confirmed success;
  /// any cancel / lockout / error resolves to false (the caller keeps the
  /// app locked and lets the user retry).
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // Keep the prompt up across an app backgrounding mid-auth instead
          // of silently failing.
          stickyAuth: true,
          // Allow the device passcode/pattern as a fallback so a user whose
          // finger isn't recognised (wet hands, etc.) can still get in.
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e, st) {
      AppLogger.warn(
        _tag,
        'authenticate() platform error: ${e.code}',
        error: e,
        stackTrace: st,
      );
      return false;
    } catch (e, st) {
      AppLogger.warn(_tag, 'authenticate() failed', error: e, stackTrace: st);
      return false;
    }
  }
}
