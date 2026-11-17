part of 'chat_screen.dart';

/// Attachments: staging, removal, preview and picking.
extension _ChatAttachments on _ChatScreenState {
  /// Opens the native file picker rooted in the device's Photos / Files
  /// app. Accepts the same set the web composer does — images, PDFs,
  /// Office docs, CSV/TSV — so the agent's later inspection has the
  /// same surface to work with on mobile + web.
  ///
  /// The picker returns a [PlatformFile]; we keep just the metadata
  /// (name, size, kind, optional thumbnail path) locally because the
  /// chat surfaces only need that to render the chip. Bytes / actual
  /// upload land when `/api/conversations/{id}/attachments/` ships.
  /// Drops a single staged attachment by index — clears its composer chip
  /// AND removes the matching cubit-side staged row so the next
  /// `sendMessage` doesn't ship the orphaned id. The screen-level
  /// `_staged` list and the cubit's
  /// `stagedAttachments` are appended to in the same order in
  /// [_pickAttachment], so positional index → cubit id maps 1:1 for any
  /// row whose upload has settled. Rows still mid-upload (or whose upload
  /// failed) haven't reached the cubit yet — we skip the cubit call for
  /// those and just drop the local row.
  void _clearAttachments() {
    for (var i = _staged.length - 1; i >= 0; i--) {
      _removeAttachmentAt(i);
    }
  }

  void _removeAttachmentAt(int index) {
    if (index < 0 || index >= _staged.length) return;
    if (!_isNewChat) {
      final cubit = context.read<ChatCubit>();
      final staged = cubit.state.stagedAttachments;
      if (index < staged.length) {
        cubit.removeStagedAttachment(staged[index].id);
      }
    }
    // One removal, because there is one list. This used to be two, with a
    // `if (index < other.length)` guard on the second — a guard that only
    // makes sense if you do not believe the alignment it is guarding.
    _update(() => _staged.removeAt(index));
  }

  /// Opens a staged attachment so the user can verify they picked the
  /// right file before tapping Send. Goes through the same in-app
  /// [AttachmentViewerScreen] a sent attachment uses, so the preview a
  /// user gets before Send matches what they get after. Skips silently
  /// for indices that don't map to a real on-disk file (a row mid-upload
  /// user gets before Send matches what they get after.
  ///
  /// The chip and the file are one row now, so the old "a chip whose file
  /// hasn't arrived yet — shouldn't happen, but defensive" branch is gone
  /// along with the possibility it was guarding.
  Future<void> _previewAttachmentAt(int index) async {
    if (index < 0 || index >= _staged.length) return;
    final staged = _staged[index];
    await AttachmentViewerScreen.open(
      context,
      file: staged.file,
      name: staged.chip.name,
      kindLabel: staged.chip.kind,
      sizeLabel: staged.chip.size,
    );
  }

  /// Entry point for the composer's paperclip. Asks *where* the attachment
  /// comes from before opening a picker — one `FileType.custom` dialog that
  /// mixed images with PDFs and archives resolved to the Files browser on
  /// iOS, so attaching a photo meant navigating Files → Photos.
  ///
  /// The pickers themselves live in [AttachmentSourcePicker]: it answers
  /// *which files*, and this method decides what to say about the answer.
  /// Every outcome funnels into [_stageCandidates], which owns the size
  /// caps, the chips and the upload, so no source can bypass them.
  Future<void> _pickAttachment() async {
    final source = await AttachmentPickerSourceSheet.show(context);
    if (!mounted || source == null) return;
    final result = await const AttachmentSourcePicker().pick(source);
    if (!mounted) return;
    switch (result) {
      case AttachmentsPicked(:final candidates):
        await _stageCandidates(candidates);
      // The user backed out. Deliberately silent — a toast here would
      // report their own decision back to them as an event.
      case AttachmentPickCancelled():
        break;
      // Not retryable from inside the app, so the copy points at Settings
      // rather than offering a second attempt that cannot succeed.
      case AttachmentPickDenied():
        _toast(context.tr.attachCameraDenied);
      case AttachmentPickFailed():
        _toast(context.tr.defaultApiError);
    }
  }

  /// The one path every attachment takes into the composer, whichever way it
  /// arrived — the paperclip, the camera, or a share from another app.
  ///
  /// The paperclip and the share intake used to carry their own copies of
  /// this: the same caps, the same chips, the same eager upload and the same
  /// roll-back. They had already drifted once — the share path shipped with
  /// no cap check at all, so a 200 MB video became a 413 *after* the upload
  /// instead of a message before it. `AttachmentStaging` fixed the caps;
  /// this fixes the half that was still written twice.
  ///
  /// [toastRejections] is the only thing the two callers disagree about: the
  /// share path may run while the screen is mid-teardown, where there is no
  /// scaffold to hang a toast on.
  Future<void> _stageCandidates(
    Iterable<AttachmentCandidate> candidates, {
    bool toastRejections = true,
  }) async {
    // Kind-aware size caps (Gap F) and the chips.
    final staged = AttachmentStaging.validate(candidates, context.tr);
    final newFiles = staged.files;

    if (staged.rejected.isNotEmpty && toastRejections) {
      // Name the cap of the first rejected file; the rest were skipped too.
      final first = staged.rejected.first;
      _toast(context.tr.attachmentTooLarge(first.name, first.capMb));
    }
    if (newFiles.isEmpty) return;

    // UI metadata for the composer chips — keeps the visual confirmation
    // instant even if the upload below is still in flight.
    _update(() {
      for (var i = 0; i < newFiles.length; i++) {
        _staged.add(StagedFile(chip: staged.chips[i], file: newFiles[i]));
      }
    });

    // Existing chats own a [ChatCubit] — stage the uploads immediately so the
    // attachment ids are already on the server by the time the user hits
    // Send. New chats can't upload yet (no conversation id);
    // `_sendAsNewConversation` does the deferred upload after it creates the
    // conversation.
    if (_isNewChat) return;
    final cubit = context.read<ChatCubit>();
    final ok = await cubit.uploadAttachments(newFiles);
    if (!mounted || ok) return;
    // Upload failed — drop just the chips we added this round so any
    // previously-staged batch the user might still want stays put.
    _update(() {
      final dropped = {for (final f in newFiles) f.path};
      _staged.removeWhere((s) => dropped.contains(s.file.path));
    });
    _surfaceActionFailure();
  }
}
