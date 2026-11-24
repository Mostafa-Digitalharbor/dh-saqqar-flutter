part of 'chat_screen.dart';

/// Voice notes: permission, record, stop/transcribe, discard.
extension _ChatVoice on _ChatScreenState {
  /// Repaints the composer when the recorder ticks or changes phase.
  ///
  /// The recorder is a `ChangeNotifier` rather than something the widget
  /// tree watches, because it drives exactly one subtree and a listener is
  /// cheaper than a provider for a value that changes ten times a second.
  void _onVoiceChanged() {
    if (mounted) _update(() {});
  }

  /// Mic-tap entry point wired through [ChatComposer.onStartRecording].
  /// Owns the permission prompt, recorder setup, timer + hard-stop
  /// scheduling. Bail out if a recording is already in flight (the UI
  /// disables the mic, but defensive).
  /// Asks [MicPermissionGate] for microphone access and says what happened.
  ///
  /// Returns true only when recording may start. The gate owns the ordering
  /// rule App Store review turns on (5.1.1(iv)); this owns the wording, which
  /// is the part that needs a `BuildContext`.
  Future<bool> _ensureMicPermission() async {
    final outcome = await const MicPermissionGate().ensure();
    if (!mounted) return false;
    switch (outcome) {
      case MicPermissionOutcome.granted:
        return true;
      case MicPermissionOutcome.denied:
        _micPermissionToast(offerSettings: false);
      case MicPermissionOutcome.blocked:
        _micPermissionToast(offerSettings: true);
    }
    return false;
  }

  /// Localised "mic access needed" toast. When [offerSettings] is true it
  /// carries an optional, user-initiated "Open Settings" action — the only
  /// place in the app that ever calls `openAppSettings()`.
  void _micPermissionToast({required bool offerSettings}) {
    AppToast.show(
      context,
      message: offerSettings
          ? context.tr.voicePermissionOpenSettings
          : context.tr.voicePermissionDenied,
      action: offerSettings
          ? ToastAction(
              label: context.tr.openSettings,
              onPressed: openAppSettings,
            )
          : null,
    );
  }

  /// Mic-tap entry point wired through [ChatComposer.onStartRecording].
  ///
  /// Owns only the two things that need a `BuildContext`: the permission
  /// consent flow and the copy for whatever goes wrong. The recorder handle,
  /// the ticker, the 120 s cap and the temp file all live in
  /// [VoiceNoteRecorder].
  Future<void> _startRecording() async {
    if (_voice.isRecording || _voice.isTranscribing || _voice.isPreviewing) {
      return;
    }
    // Permission gate first. Ordering matters for App Store review (guideline
    // 5.1.1(iv)): the native OS prompt must be the FIRST permission-related
    // thing the user ever sees — we never route them to Settings before it.
    if (!await _ensureMicPermission()) return;
    final problem = await _voice.start();
    if (!mounted || problem == null) return;
    _toast(context.tr.micUnavailable);
  }

  /// Tapped on the stop pill (or fired by the recorder's 120 s cap). Ends the
  /// take and opens the preview — nothing is uploaded until the user has had
  /// the chance to listen and chooses Send.
  Future<void> _stopRecording() async {
    final kept = await _voice.finish();
    if (!mounted) return;
    if (!kept) _toast(context.tr.transcribeFailed);
  }

  /// Send on the preview card: uploads the take and appends the transcript to
  /// whatever is already typed.
  Future<void> _sendVoicePreview() async {
    final api = context.read<TranscribeApi>();
    final outcome = await _voice.sendPreview(
      (audio) => api.transcribe(
        audio: audio,
        onProgress: _voice.reportSendProgress,
      ),
    );
    if (!mounted) return;
    _handleVoiceOutcome(outcome);
  }

  void _handleVoiceOutcome(VoiceNoteOutcome outcome) {
    switch (outcome) {
      case VoiceNoteTranscribed(text: final transcript):
        // Append rather than replace — preserves whatever the user typed
        // before tapping the mic. The caret jumps to the end and focus comes
        // back so they can keep editing without a second tap.
        final existing = _composer.text;
        final joiner = existing.isEmpty || existing.endsWith(' ') ? '' : ' ';
        final next = '$existing$joiner$transcript';
        _composer.text = next;
        _composer.selection = TextSelection.collapsed(offset: next.length);
        _composerFocus.requestFocus();
      case VoiceNoteEmpty():
        _toast(context.tr.transcribeEmpty);
      case VoiceNoteNoAudio():
        _toast(context.tr.transcribeFailed);
      case VoiceNoteFailed(error: final error):
        // Gap C — a 403 from /transcribe/ means voice is locked on the
        // caller's plan (the mic is normally hidden, but a stale snapshot or
        // a race can still let one request through). Map it to a friendly
        // "voice is a Pro feature" hint rather than the generic forbidden
        // copy.
        // Test the status, not the mapped failure: the server's 403 text names
        // the plan ("…Pro and Max plans. Upgrade…"), which the mapper reads as a
        // quota, not a permission.
        final locked = isVoiceLockedByPlan(error);
        if (locked) _update(() => _voiceLocked = true);
        _toast(
          locked
              ? context.tr.voiceLockedPro
              : ApiErrorMapper.message(context, error),
        );
    }
  }

  /// Tapped on the discard X. Drops the audio without uploading. Disabled
  /// inside [RecordingOverlay] once transcription has started — the bytes are
  /// already in flight.
  Future<void> _discardRecording() => _voice.discard();
}
