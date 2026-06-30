import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/security/data/biometric_auth.dart';
import 'package:saqqar_app/features/security/view_model/app_lock_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake authenticator so the lock logic can be tested without the platform
/// plugin. [available] / [willSucceed] are toggled per scenario.
class _FakeBiometricAuth implements BiometricAuth {
  _FakeBiometricAuth({this.willSucceed = true});

  bool willSucceed;
  int authCalls = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate(String reason) async {
    authCalls++;
    return willSucceed;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('AppLockCubit', () {
    test('starts unlocked + disabled when no preference is saved', () async {
      final cubit = AppLockCubit(
        prefs: await prefs(),
        auth: _FakeBiometricAuth(),
      );
      expect(cubit.state.enabled, isFalse);
      expect(cubit.state.locked, isFalse);
    });

    test('cold-starts LOCKED when the lock was previously enabled', () async {
      SharedPreferences.setMockInitialValues({'saqqar.app_lock.enabled': true});
      final cubit = AppLockCubit(
        prefs: await prefs(),
        auth: _FakeBiometricAuth(),
      );
      expect(cubit.state.enabled, isTrue);
      expect(cubit.state.locked, isTrue);
    });

    test('enabling requires a successful auth (and persists it)', () async {
      final auth = _FakeBiometricAuth(willSucceed: true);
      final p = await prefs();
      final cubit = AppLockCubit(prefs: p, auth: auth);

      final ok = await cubit.setEnabled(true, reason: 'x');

      expect(ok, isTrue);
      expect(cubit.state.enabled, isTrue);
      expect(auth.authCalls, 1);
      expect(p.getBool('saqqar.app_lock.enabled'), isTrue);
    });

    test('enabling stays OFF when auth fails', () async {
      final cubit = AppLockCubit(
        prefs: await prefs(),
        auth: _FakeBiometricAuth(willSucceed: false),
      );

      final ok = await cubit.setEnabled(true, reason: 'x');

      expect(ok, isFalse);
      expect(cubit.state.enabled, isFalse);
    });

    test('lock() re-engages only when enabled', () async {
      final disabled = AppLockCubit(
        prefs: await prefs(),
        auth: _FakeBiometricAuth(),
      );
      disabled.lock();
      expect(disabled.state.locked, isFalse, reason: 'disabled → no lock');

      SharedPreferences.setMockInitialValues({'saqqar.app_lock.enabled': true});
      final enabled = AppLockCubit(
        prefs: await prefs(),
        auth: _FakeBiometricAuth(),
      );
      // Simulate a successful unlock, then a background → re-lock.
      await enabled.unlock(reason: 'x');
      expect(enabled.state.locked, isFalse);
      enabled.lock();
      expect(enabled.state.locked, isTrue);
    });

    test('unlock clears the lock on success, keeps it on failure', () async {
      SharedPreferences.setMockInitialValues({'saqqar.app_lock.enabled': true});
      final auth = _FakeBiometricAuth(willSucceed: false);
      final cubit = AppLockCubit(prefs: await prefs(), auth: auth);

      expect(cubit.state.locked, isTrue);
      expect(await cubit.unlock(reason: 'x'), isFalse);
      expect(cubit.state.locked, isTrue, reason: 'failed auth → still locked');

      auth.willSucceed = true;
      expect(await cubit.unlock(reason: 'x'), isTrue);
      expect(cubit.state.locked, isFalse);
    });
  });
}
