import 'package:permission_handler/permission_handler.dart';

/// The three answers "may I use the microphone?" can have, and they are three
/// because each needs different words.
enum MicPermissionOutcome {
  /// Record.
  granted,

  /// Denied, but the OS will ask again. The message must **not** mention
  /// Settings: tapping the mic again brings the native prompt straight back,
  /// and pointing at Settings for something one tap solves is the kind of
  /// instruction that makes a feature look broken.
  denied,

  /// The OS will not ask again — permanently denied, or restricted by device
  /// policy. A Settings shortcut is the only way forward, and it is offered,
  /// never forced.
  blocked,
}

/// The two plugin calls [MicPermissionGate] makes.
///
/// Behind an interface so the ordering rule below can be tested at all: the
/// real thing reaches the OS permission subsystem, which under `flutter test`
/// answers `denied` to everything and cannot be made to answer anything else.
abstract interface class MicPermissionPort {
  Future<PermissionStatus> status();

  Future<PermissionStatus> request();
}

/// Resolves microphone access before recording.
///
/// ## The ordering is an App Store requirement, not a preference
///
/// Guideline 5.1.1(iv): the system permission dialog must be the **first**
/// permission-related thing the user sees. The app may never route someone to
/// Settings before that dialog has appeared. So the sequence is fixed —
/// check, then `request()`, and only a status that says the OS is done asking
/// may produce [MicPermissionOutcome.blocked].
///
/// ## Why it is not in the chat screen
///
/// It was, as a `Future<bool>` with the toast wording inlined in two of its
/// four branches — which collapsed [denied] and [blocked] at the return and
/// re-derived the difference from a second read of the status. Nothing tested
/// it, because reaching any branch but "denied" needs a real device with a
/// real user tapping a real dialog. A rule that ships an app is worth more
/// than that.
///
/// Returns an outcome rather than showing anything. The screen owns the
/// wording, because the wording needs a `BuildContext` and a locale.
class MicPermissionGate {
  const MicPermissionGate({MicPermissionPort port = const _MicrophonePort()})
    : _port = port;

  final MicPermissionPort _port;

  Future<MicPermissionOutcome> ensure() async {
    final current = await _port.status();
    if (current.isGranted) return MicPermissionOutcome.granted;

    // Already permanently denied, or restricted by device policy: the OS will
    // not surface the dialog again, so recording cannot proceed without a
    // manual change. This is the ONLY path to `blocked` that skips the
    // request, and it is legitimate precisely because the dialog has already
    // been shown and answered.
    if (current.isPermanentlyDenied || current.isRestricted) {
      return MicPermissionOutcome.blocked;
    }

    // notDetermined / denied-but-askable: show the native prompt now. This is
    // the user's first sight of anything permission-related.
    final result = await _port.request();
    if (result.isGranted) return MicPermissionOutcome.granted;

    // Denied at the prompt. Offer the Settings shortcut only if the OS now
    // marks it permanent; otherwise keep the message gentle, with no Settings
    // mention, because the user can simply tap the mic again.
    return result.isPermanentlyDenied || result.isRestricted
        ? MicPermissionOutcome.blocked
        : MicPermissionOutcome.denied;
  }
}

/// `permission_handler` against the real microphone permission.
class _MicrophonePort implements MicPermissionPort {
  const _MicrophonePort();

  @override
  Future<PermissionStatus> status() => Permission.microphone.status;

  @override
  Future<PermissionStatus> request() => Permission.microphone.request();
}
