import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/logging/app_logger.dart';

/// Why a recording could not start.
///
/// Separate from the toast copy on purpose: this class never touches a
/// `BuildContext`, so the screen decides what each problem reads as. That is
/// also what lets the whole lifecycle be unit-tested without pumping a widget.
enum VoiceRecorderProblem {
  /// The device reports no usable microphone, or the plugin refused.
  unavailable,
}

/// What a finished recording produced.
sealed class VoiceNoteOutcome {
  const VoiceNoteOutcome();
}

/// The audio came back as text.
class VoiceNoteTranscribed extends VoiceNoteOutcome {
  const VoiceNoteTranscribed(this.text);
  final String text;
}

/// The upload succeeded and the transcript was empty — the user recorded
/// silence, or the model heard nothing it could write down.
class VoiceNoteEmpty extends VoiceNoteOutcome {
  const VoiceNoteEmpty();
}

/// The recorder stopped without producing a file. Distinct from
/// [VoiceNoteFailed]: nothing was ever uploaded, so there is nothing to
/// retry against the server.
class VoiceNoteNoAudio extends VoiceNoteOutcome {
  const VoiceNoteNoAudio();
}

/// The transcribe call threw. Carries the raw error so the caller can run it
/// through `ApiErrorMapper` — the mapping needs a locale, which lives with
/// the widget, not here.
class VoiceNoteFailed extends VoiceNoteOutcome {
  const VoiceNoteFailed(this.error);
  final Object error;
}

/// Owns the voice-note lifecycle for the chat composer: the recorder handle,
/// the mm:ss ticker, the 120 s hard cap, the temp file and its cleanup.
///
/// Extracted from `_ChatScreenState`, which held all of it as six fields and
/// four methods among thirty-four other fields. Two things came out of that:
///
///  1. **It was untestable.** No test in the repo drove a recording — only
///     `RecordingOverlay`, the pure widget it renders into. Everything below
///     ran solely on a device.
///  2. **It had a dead cleanup path.** `_discardRecording` cleared
///     `_recordingPath` inside its `setState` and then read it back to find
///     the file to delete, so the read always saw `null` and the delete never
///     ran. Every discarded voice note left an `.m4a` in the OS temp
///     directory, on every discard, forever. [discard] below captures the
///     path first, and `voice_note_recorder_test.dart` fails if it stops
///     doing so.
///
/// Deliberately NOT a `Cubit`. It has no state to restore, nothing else
/// observes it, and its whole job is to sequence plugin calls against two
/// timers — a `ChangeNotifier` is the smaller thing that fits.
///
/// Permission handling stays in the screen. It is a consent flow with
/// App-Store-review-sensitive ordering (guideline 5.1.1(iv)) and it needs a
/// context to offer the Settings shortcut, so splitting it here would put
/// half a decision on each side of the boundary.
class VoiceNoteRecorder extends ChangeNotifier {
  /// Both dependencies are injectable so a test can drive the whole lifecycle
  /// without a device: [recorder] fakes the plugin, [temporaryDirectory]
  /// points the `.m4a` at a scratch dir the test can inspect afterwards.
  VoiceNoteRecorder({
    AudioRecorder? recorder,
    Future<Directory> Function()? temporaryDirectory,
    this.onMaxLengthReached,
  })  : _recorder = recorder ?? AudioRecorder(),
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  static const _tag = 'VoiceRecording';

  /// How often the ticker updates the mm:ss readout.
  ///
  /// Read in two places — the timer's period and the amount added to
  /// [elapsed] on each fire. If those two ever disagree the counter silently
  /// lies about how long the user has been recording, and nothing else in the
  /// app would notice, so they read the same constant.
  static const tick = Duration(milliseconds: 100);

  /// Hard cap on a single recording, per SAQQAR_MOBILE_VOICE.md §3.
  static const maxLength = Duration(seconds: 120);

  /// m4a + AAC-LC + mono + 16 kHz + 32 kbps — SAQQAR_MOBILE_VOICE.md §3.
  /// Small enough to upload on a phone connection, and the shape
  /// `/api/v1/transcribe/` expects.
  static const _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    sampleRate: 16000,
    numChannels: 1,
    bitRate: 32000,
  );

  final AudioRecorder _recorder;
  final Future<Directory> Function() _temporaryDirectory;

  /// Fired when [maxLength] is hit. The owner is expected to call [stop] —
  /// this class does not call it itself so the screen can surface its
  /// "maximum length reached" toast in the same frame as the transition.
  final VoidCallback? onMaxLengthReached;

  Timer? _ticker;
  Timer? _hardStop;
  String? _path;

  bool _isRecording = false;
  bool _isTranscribing = false;
  Duration _elapsed = Duration.zero;

  /// True from a successful [start] until [stop] or [discard].
  bool get isRecording => _isRecording;

  /// True from [stop] until the transcribe call settles. The overlay shows
  /// "Transcribing…" and disables discard across this window — the bytes are
  /// already in flight.
  bool get isTranscribing => _isTranscribing;

  /// How long the current recording has been running.
  Duration get elapsed => _elapsed;

  /// Begins recording. Returns `null` on success, or the reason it could not.
  ///
  /// Callers must resolve microphone permission first; this checks
  /// `hasPermission()` only as the recorder's own device-capability gate.
  Future<VoiceRecorderProblem?> start() async {
    if (_isRecording || _isTranscribing) return null;

    final tmp = await _temporaryDirectory();
    final path =
        '${tmp.path}/saqqar-voice-${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      if (!await _recorder.hasPermission()) {
        return VoiceRecorderProblem.unavailable;
      }
      await _recorder.start(_config, path: path);
    } catch (e, st) {
      AppLogger.warn(_tag, 'start failed', error: e, stackTrace: st);
      return VoiceRecorderProblem.unavailable;
    }

    _isRecording = true;
    _elapsed = Duration.zero;
    _path = path;
    notifyListeners();

    _ticker = Timer.periodic(tick, (_) {
      _elapsed += tick;
      notifyListeners();
    });
    _hardStop = Timer(maxLength, () {
      if (!_isRecording) return;
      onMaxLengthReached?.call();
    });
    return null;
  }

  /// Stops the recorder and hands the audio to [transcribe].
  ///
  /// The transcribe call is passed in rather than reached for, because the
  /// API client lives on the widget tree and this class has no context to
  /// read it from. It also means a test can settle the outcome without a
  /// server.
  ///
  /// The temp file is deleted in a `finally` whichever way the upload goes:
  /// consumed or failed, it is not useful afterwards, and it is the user's
  /// voice sitting in a world-readable temp directory.
  Future<VoiceNoteOutcome> stop(
    Future<String> Function(File audio) transcribe,
  ) async {
    if (!_isRecording) return const VoiceNoteNoAudio();
    _cancelTimers();

    final stopped = await _recorder.stop();
    _isRecording = false;
    _isTranscribing = true;
    notifyListeners();

    final localPath = stopped ?? _path;
    if (localPath == null) {
      _isTranscribing = false;
      _reset();
      return const VoiceNoteNoAudio();
    }

    final file = File(localPath);
    try {
      final transcript = await transcribe(file);
      return transcript.isEmpty
          ? const VoiceNoteEmpty()
          : VoiceNoteTranscribed(transcript);
    } catch (e, st) {
      AppLogger.warn(_tag, 'transcribe failed', error: e, stackTrace: st);
      return VoiceNoteFailed(e);
    } finally {
      await _deleteQuietly(file);
      _isTranscribing = false;
      _reset();
    }
  }

  /// Drops the recording without uploading it, and deletes the file.
  ///
  /// [_path] is read into a local BEFORE [_reset] clears it. That ordering is
  /// the whole fix: the version this replaced cleared the field first and
  /// then read it back, so the delete it looked like it was doing never ran.
  Future<void> discard() async {
    if (!_isRecording) return;
    _cancelTimers();
    final path = _path;

    await _recorder.cancel();
    _isRecording = false;
    _reset();

    if (path != null) await _deleteQuietly(File(path));
  }

  void _cancelTimers() {
    _ticker?.cancel();
    _hardStop?.cancel();
    _ticker = null;
    _hardStop = null;
  }

  void _reset() {
    _path = null;
    _elapsed = Duration.zero;
    notifyListeners();
  }

  /// Best-effort delete. A temp file we cannot remove is not worth failing a
  /// transcription over, and the OS reclaims the directory eventually — but
  /// it is worth *attempting* on every path, which is what the bug above was
  /// missing.
  static Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } catch (e) {
      AppLogger.warn(_tag, 'temp file cleanup failed', error: e);
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    unawaited(_recorder.cancel());
    unawaited(_recorder.dispose());
    super.dispose();
  }
}
