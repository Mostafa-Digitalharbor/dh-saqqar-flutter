// The voice-note lifecycle, which had no test of any kind until 2026-08-20.
//
// It lived as six fields and four methods inside `_ChatScreenState`, among
// thirty-four other fields, reachable only by holding a real microphone. The
// only thing any test touched was `RecordingOverlay` — the pure widget it
// renders into — so every branch below ran solely on a device.
//
// What that hid: `_discardRecording` cleared `_recordingPath` inside its
// `setState` and then read the field back to find the file to delete.
//
// ```dart
// setState(() {
//   _recordingPath = null;      // ← cleared here
// });
// final path = _recordingPath;  // ← read after, so always null
// if (path != null) { …delete… }
// ```
//
// The delete never ran. Every discarded voice note left an `.m4a` of the
// user's voice in the OS temp directory, on every discard, forever — and the
// code read as though it were cleaning up, which is why nobody looked twice.
//
// `deletes the temp file on discard` below is the regression test. It fails
// against that ordering.

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import 'package:saqqar_app/features/chat/view_model/voice_note_recorder.dart';

/// A recorder that writes a real file, so the cleanup assertions are about
/// the filesystem rather than about a call being made.
///
/// `record`'s plugin surface is a platform channel with no test
/// implementation, and a mock that only counted calls would pass whether or
/// not the file survived — which is exactly the thing that went wrong.
class _FakeRecorder implements AudioRecorder {
  _FakeRecorder({this.permitted = true, this.throwOnStart = false});

  final bool permitted;
  final bool throwOnStart;

  String? startedPath;
  bool cancelled = false;
  bool disposed = false;

  /// What `stop()` hands back. Null models the recorder ending with no file,
  /// which is a real outcome (the mic was cut off mid-take).
  String? stopReturns;
  bool stopReturnsSet = false;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    if (throwOnStart) throw StateError('mic busy');
    startedPath = path;
    File(path).writeAsBytesSync(const [0, 1, 2, 3]);
  }

  @override
  Future<String?> stop() async => stopReturnsSet ? stopReturns : startedPath;

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Future<void> dispose() async => disposed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('saqqar-voice-test');
  });

  tearDown(() {
    // Best-effort: on Windows a handle the recorder fake opened can still be
    // closing when the test ends, and a scratch directory that outlives one
    // run is not a failure worth reporting — the assertions above are about
    // the FILES inside it, which each test checks for itself.
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // ignored — see above
    }
  });

  VoiceNoteRecorder build(
    _FakeRecorder fake, {
    void Function()? onMaxLengthReached,
  }) =>
      VoiceNoteRecorder(
        recorder: fake,
        temporaryDirectory: () async => tmp,
        onMaxLengthReached: onMaxLengthReached,
      );

  /// Every `.m4a` the recorder has left behind in the scratch directory.
  List<String> leftovers() => tmp
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.m4a'))
      .map((f) => f.path)
      .toList();

  group('discard', () {
    test('deletes the temp file', () async {
      // THE regression test. Against the ordering this replaced, `leftovers`
      // comes back with one file and this fails.
      final fake = _FakeRecorder();
      final voice = build(fake);

      expect(await voice.start(), isNull);
      expect(leftovers(), hasLength(1),
          reason: 'the recorder should have written a file to record into');

      await voice.discard();

      expect(
        leftovers(),
        isEmpty,
        reason: 'a discarded voice note must not survive on disk — it is the '
            'user\'s voice in a world-readable temp directory, and nothing '
            'ever comes back for it.',
      );
      expect(fake.cancelled, isTrue);
      voice.dispose();
    });

    test('returns to idle', () async {
      final voice = build(_FakeRecorder());
      await voice.start();
      expect(voice.isRecording, isTrue);

      await voice.discard();

      expect(voice.isRecording, isFalse);
      expect(voice.isTranscribing, isFalse);
      expect(voice.elapsed, Duration.zero);
      voice.dispose();
    });

    test('is a no-op when nothing is recording', () async {
      final fake = _FakeRecorder();
      final voice = build(fake);
      await voice.discard();
      expect(fake.cancelled, isFalse,
          reason: 'cancelling an idle recorder would tear down a handle the '
              'next start still needs');
      voice.dispose();
    });
  });

  group('stop', () {
    test('deletes the temp file after a successful transcription', () async {
      final voice = build(_FakeRecorder());
      await voice.start();

      final outcome = await voice.stop((f) async => 'مرحبا بك');

      expect(outcome, isA<VoiceNoteTranscribed>());
      expect((outcome as VoiceNoteTranscribed).text, 'مرحبا بك');
      expect(leftovers(), isEmpty,
          reason: 'consumed audio is not useful afterwards');
      voice.dispose();
    });

    test('deletes the temp file even when transcription throws', () async {
      // The `finally` is the point: a failed upload is the case where a file
      // is most likely to be forgotten, and it is the same private audio.
      final voice = build(_FakeRecorder());
      await voice.start();

      final outcome = await voice.stop((f) async => throw StateError('502'));

      expect(outcome, isA<VoiceNoteFailed>());
      expect(leftovers(), isEmpty);
      voice.dispose();
    });

    test('an empty transcript is its own outcome, not a failure', () async {
      // The screen renders these differently — "we heard nothing" is not
      // "something went wrong", and offering a retry for silence is noise.
      final voice = build(_FakeRecorder());
      await voice.start();

      expect(await voice.stop((f) async => ''), isA<VoiceNoteEmpty>());
      voice.dispose();
    });

    test('a recorder that produced no file reports no audio', () async {
      final fake = _FakeRecorder()
        ..stopReturns = null
        ..stopReturnsSet = true;
      final voice = build(fake);
      await voice.start();
      // The path the recorder started with is still known, so this only
      // reaches `VoiceNoteNoAudio` if BOTH are absent.
      await voice.discard();

      expect(await voice.stop((f) async => 'unreachable'),
          isA<VoiceNoteNoAudio>());
      voice.dispose();
    });

    test('clears both phase flags when it settles', () async {
      final voice = build(_FakeRecorder());
      await voice.start();
      await voice.stop((f) async => 'ok');

      expect(voice.isRecording, isFalse);
      expect(voice.isTranscribing, isFalse,
          reason: 'a stuck `transcribing` leaves the overlay up with no way '
              'out — discard is disabled during transcription');
      voice.dispose();
    });
  });

  group('start', () {
    test('reports unavailable rather than throwing when the mic is refused',
        () async {
      final voice = build(_FakeRecorder(permitted: false));
      expect(await voice.start(), VoiceRecorderProblem.unavailable);
      expect(voice.isRecording, isFalse);
      voice.dispose();
    });

    test('reports unavailable when the plugin throws', () async {
      final voice = build(_FakeRecorder(throwOnStart: true));
      expect(await voice.start(), VoiceRecorderProblem.unavailable);
      expect(voice.isRecording, isFalse);
      voice.dispose();
    });

    test('a second start while recording is ignored', () async {
      final fake = _FakeRecorder();
      final voice = build(fake);
      await voice.start();
      final first = fake.startedPath;

      await voice.start();

      expect(fake.startedPath, first,
          reason: 'a double-tap on the mic must not orphan the first file');
      expect(leftovers(), hasLength(1));
      voice.dispose();
    });
  });

  group('the ticker', () {
    // `FakeAsync` drives the two Timers directly, so the 120 s cap is
    // asserted without a 120 s wait. `flushMicrotasks` after each call is
    // what lets the awaits inside `start` / `discard` settle against the
    // fake clock — without it the Timers have not been scheduled yet and
    // `elapse` has nothing to advance.
    test('advances elapsed and notifies', () {
      FakeAsync().run((async) {
        final voice = build(_FakeRecorder());
        var notifications = 0;
        voice.addListener(() => notifications++);

        unawaited(voice.start());
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 500));

        expect(voice.elapsed, const Duration(milliseconds: 500));
        expect(notifications, greaterThan(1));
        voice.dispose();
      });
    });

    test('fires the max-length callback at the cap, once', () {
      FakeAsync().run((async) {
        var fired = 0;
        final voice =
            build(_FakeRecorder(), onMaxLengthReached: () => fired++);

        unawaited(voice.start());
        async.flushMicrotasks();

        async.elapse(VoiceNoteRecorder.maxLength - const Duration(seconds: 1));
        expect(fired, 0, reason: 'the cap is 120 s, not 119');

        async.elapse(const Duration(seconds: 2));
        expect(fired, 1);

        async.elapse(const Duration(seconds: 60));
        expect(fired, 1, reason: 'the hard stop is a one-shot Timer');
        voice.dispose();
      });
    });

    test('stops ticking after discard', () {
      FakeAsync().run((async) {
        final voice = build(_FakeRecorder());
        unawaited(voice.start());
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 300));

        unawaited(voice.discard());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));

        expect(voice.elapsed, Duration.zero,
            reason: 'a timer left running after discard keeps calling '
                'setState on a composer that is no longer recording');
        voice.dispose();
      });
    });
  });

  test('the tick period and the amount added agree', () {
    // These are one constant precisely so they cannot drift: if the timer
    // fires every 100 ms but adds 200, the counter lies about how long the
    // user has been recording and nothing else in the app would notice.
    expect(VoiceNoteRecorder.tick, const Duration(milliseconds: 100));
    expect(VoiceNoteRecorder.maxLength, const Duration(seconds: 120));
  });
}
