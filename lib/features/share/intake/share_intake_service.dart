import 'dart:io';

import 'package:flutter/foundation.dart';

/// Holds files received via Android `ACTION_SEND` / `SEND_MULTIPLE` until the
/// user picks a chat to attach them to.
///
/// The flow is:
///   1. The system share sheet hands files to Saqqar via the intent-filter
///      declared in `AndroidManifest.xml`.
///   2. [ShareIntentBootstrap] receives them through `receive_sharing_intent`
///      and calls [stage].
///   3. The bootstrap opens [ShareDestinationSheet]; the user picks an
///      existing chat or "new chat".
///   4. The router navigates to that chat; `ChatScreen.initState` calls
///      [take] to drain the staged files and pre-attach them.
///
/// The service exists outside any cubit so the lifetime survives the
/// route-builder rebuild that fires when the chat screen mounts (cubits
/// inside a `BlocProvider` are torn down + rebuilt across that boundary;
/// the service is a singleton owned by `RepositoryProvider`).
class ShareIntakeService extends ChangeNotifier {
  final List<File> _staged = [];

  /// Files currently waiting for a destination. Empty between shares.
  List<File> get staged => List.unmodifiable(_staged);

  bool get hasStaged => _staged.isNotEmpty;

  /// Replaces the staging area with [files]. Replacement (not append) is
  /// intentional — if two shares arrive back-to-back, the second one is
  /// the user's current intent; the abandoned first one stays out of the
  /// next chat. Listeners are notified so the bootstrap can pop the
  /// destination sheet.
  void stage(List<File> files) {
    _staged
      ..clear()
      ..addAll(files);
    notifyListeners();
  }

  /// Returns the staged files and clears the staging area in one call.
  /// Called by `ChatScreen` right after it mounts to consume the batch.
  List<File> take() {
    if (_staged.isEmpty) return const [];
    final out = List<File>.from(_staged);
    _staged.clear();
    notifyListeners();
    return out;
  }

  /// Discards any pending files without delivering them. Used by the
  /// destination sheet when the user explicitly cancels the share.
  void clear() {
    if (_staged.isEmpty) return;
    _staged.clear();
    notifyListeners();
  }
}
