// The microphone consent gate.
//
// The ordering here is an App Store review requirement (guideline 5.1.1(iv)),
// not a preference: the system permission dialog must be the first
// permission-related thing the user ever sees, and the app may never route
// someone to Settings before it has appeared. A rule that can fail a release
// deserves better enforcement than a comment.
//
// None of it was testable while it lived in `_ChatScreenState`: under
// `flutter test` the real permission subsystem answers "denied" to everything
// and cannot be made to answer anything else, so every branch but one was
// unreachable — and the branch that decides whether we send the user to
// Settings is not the reachable one.

import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:saqqar_app/features/chat/data/mic_permission_gate.dart';

void main() {
  test('an already-granted mic records without prompting', () async {
    final port = _FakePort(status: PermissionStatus.granted);

    expect(await MicPermissionGate(port: port).ensure(),
        MicPermissionOutcome.granted);
    expect(port.requests, 0, reason: 'nothing to ask');
  });

  test('a first-time tap shows the OS dialog, and grants on yes', () async {
    final port = _FakePort(
      status: PermissionStatus.denied,
      afterRequest: PermissionStatus.granted,
    );

    expect(await MicPermissionGate(port: port).ensure(),
        MicPermissionOutcome.granted);
    expect(port.requests, 1);
  });

  test('declining the dialog is retryable, NOT a trip to Settings', () async {
    // The OS will ask again, so tapping the mic once more brings the prompt
    // straight back. Pointing at Settings for something one tap solves is
    // what makes a working feature look broken.
    final port = _FakePort(
      status: PermissionStatus.denied,
      afterRequest: PermissionStatus.denied,
    );

    expect(await MicPermissionGate(port: port).ensure(),
        MicPermissionOutcome.denied);
    expect(port.requests, 1);
  });

  test('"don\'t ask again" at the dialog becomes blocked', () async {
    final port = _FakePort(
      status: PermissionStatus.denied,
      afterRequest: PermissionStatus.permanentlyDenied,
    );

    expect(await MicPermissionGate(port: port).ensure(),
        MicPermissionOutcome.blocked);
  });

  test('a restricted answer at the dialog is blocked, not retryable',
      () async {
    // Device policy (a managed phone, Screen Time) will not soften on a
    // retry, so "tap it again" would be advice that cannot work.
    final port = _FakePort(
      status: PermissionStatus.denied,
      afterRequest: PermissionStatus.restricted,
    );

    expect(await MicPermissionGate(port: port).ensure(),
        MicPermissionOutcome.blocked);
  });

  group('Settings is never offered before the OS dialog has been shown', () {
    // The review rule, stated as the two facts that satisfy it.

    test('a permanently-denied start skips the request it cannot win',
        () async {
      // Legitimate: the dialog has already been shown and answered, which is
      // exactly what `permanentlyDenied` means. Calling `request()` here
      // would be a no-op the OS ignores.
      final port = _FakePort(status: PermissionStatus.permanentlyDenied);

      expect(await MicPermissionGate(port: port).ensure(),
          MicPermissionOutcome.blocked);
      expect(port.requests, 0);
    });

    test('every other route to blocked has asked first', () async {
      for (final start in [
        PermissionStatus.denied,
        PermissionStatus.provisional,
      ]) {
        final port = _FakePort(
          status: start,
          afterRequest: PermissionStatus.permanentlyDenied,
        );

        final outcome = await MicPermissionGate(port: port).ensure();

        expect(outcome, MicPermissionOutcome.blocked, reason: '$start');
        expect(port.requests, 1,
            reason: 'the OS dialog must come first, from $start');
        expect(port.statusReadBeforeRequest, isTrue, reason: '$start');
      }
    });
  });

  test('a restricted start is blocked without a pointless request', () async {
    final port = _FakePort(status: PermissionStatus.restricted);

    expect(await MicPermissionGate(port: port).ensure(),
        MicPermissionOutcome.blocked);
    expect(port.requests, 0);
  });
}

/// One canned status, and a second one for after the dialog.
class _FakePort implements MicPermissionPort {
  _FakePort({required PermissionStatus status, this.afterRequest})
      : _status = status;

  final PermissionStatus _status;
  final PermissionStatus? afterRequest;

  int requests = 0;
  bool statusReadBeforeRequest = false;
  bool _statusRead = false;

  @override
  Future<PermissionStatus> status() async {
    _statusRead = true;
    return _status;
  }

  @override
  Future<PermissionStatus> request() async {
    requests++;
    statusReadBeforeRequest = _statusRead;
    return afterRequest ?? _status;
  }
}
