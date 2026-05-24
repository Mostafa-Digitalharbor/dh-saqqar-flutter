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
///   4. The bootstrap calls [deliverTo] with the picked chat id and
///      navigates the router. [deliverTo] fires `notifyListeners()` —
///      crucial for the **same-chat case**: when the user shares from
///      inside chat A and picks "current chat", `context.go('/chats/A')`
///      is a no-op route (`initState` doesn't re-fire), so the existing
///      chat screen listens to the service directly and consumes the
///      files via [take] when its own id matches `_targetChatId`.
///   5. `ChatScreen.initState` calls [take] to drain the staged files
///      and pre-attach them.
///
/// The service exists outside any cubit so the lifetime survives the
/// route-builder rebuild that fires when the chat screen mounts (cubits
/// inside a `BlocProvider` are torn down + rebuilt across that boundary;
/// the service is a singleton owned by `RepositoryProvider`).
class ShareIntakeService extends ChangeNotifier {
  final List<File> _staged = [];

  /// Conversation id the bootstrap committed the staged batch to. Set
  /// by [deliverTo] right before the router navigates so chat screens
  /// can tell whether the staged files were meant for them — important
  /// when the share lands while the user is already inside a chat.
  String? _targetChatId;

  /// Files currently waiting for a destination. Empty between shares.
  List<File> get staged => List.unmodifiable(_staged);

  bool get hasStaged => _staged.isNotEmpty;

  /// The chat id the bootstrap last picked as the destination for the
  /// staged batch. `null` between shares — also `null` between [stage]
  /// and [deliverTo], i.e. while the destination picker is open.
  String? get targetChatId => _targetChatId;

  /// Replaces the staging area with [files]. Replacement (not append) is
  /// intentional — if two shares arrive back-to-back, the second one is
  /// the user's current intent; the abandoned first one stays out of the
  /// next chat. Listeners are notified so the bootstrap can pop the
  /// destination sheet. Target is reset to `null` here so the
  /// listening chat screens don't consume the new batch before the user
  /// picks a destination for it.
  void stage(List<File> files) {
    _staged
      ..clear()
      ..addAll(files);
    _targetChatId = null;
    notifyListeners();
  }

  /// Commits the staged batch to [chatId]. Called by [ShareIntentBootstrap]
  /// right before navigating; required so the same-chat case works (the
  /// router is a no-op when the picked chat IS the current one, which
  /// means `ChatScreen.initState` never re-fires — the screen relies on
  /// our `notifyListeners()` instead).
  void deliverTo(String chatId) {
    if (_staged.isEmpty) return;
    _targetChatId = chatId;
    notifyListeners();
  }

  /// Returns the staged files and clears the staging area in one call.
  /// If [askingChatId] is supplied (the chat screen calling this), the
  /// drain only happens when the asker matches [_targetChatId] — i.e.
  /// the user explicitly picked this chat as the destination. Other
  /// chat screens that happen to be listening (e.g. one mounting in the
  /// background) get an empty list and the staged files stay put for
  /// the rightful owner.
  ///
  /// Passing `null` (or no argument) bypasses the gate — kept for
  /// backwards compatibility with the cold-start path that has only
  /// one chat screen alive.
  List<File> take([String? askingChatId]) {
    if (_staged.isEmpty) return const [];
    if (askingChatId != null &&
        _targetChatId != null &&
        askingChatId != _targetChatId) {
      return const [];
    }
    final out = List<File>.from(_staged);
    _staged.clear();
    _targetChatId = null;
    notifyListeners();
    return out;
  }

  /// Discards any pending files without delivering them. Used by the
  /// destination sheet when the user explicitly cancels the share.
  void clear() {
    if (_staged.isEmpty && _targetChatId == null) return;
    _staged.clear();
    _targetChatId = null;
    notifyListeners();
  }
}
