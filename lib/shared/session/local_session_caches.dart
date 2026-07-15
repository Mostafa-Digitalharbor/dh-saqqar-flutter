import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/conversations/data/conversations_repository.dart';
import '../../features/notifications/data/notifications_store.dart';
import '../../features/vault/data/vault_repository.dart';

/// Every local cache that belongs to the SIGNED-IN USER, purgeable in one
/// call.
///
/// This exists because leaving a cache behind is a cross-user data leak,
/// not a tidiness problem: the next person to sign in on the same device
/// briefly sees the previous user's projects, chat transcripts or
/// notifications while the live fetch runs. Sign-out and account-deletion
/// both have to purge the exact same set, and they previously carried
/// separate hand-maintained copies of the list — so adding a new cache
/// meant remembering to edit both, and forgetting one would leak silently.
///
/// **Adding a new user-scoped cache? Add it to [clear] and both flows pick
/// it up.** That single edit point is the whole reason this type exists.
///
/// Construction is deliberately separate from [clear]: [LocalSessionCaches.of]
/// resolves the repositories synchronously so callers can capture them
/// BEFORE they await anything. Both flows sign the user out, which makes
/// the auth gate rebuild the tree — a `context.read` afterwards would
/// throw. Capturing up front makes that ordering hard to get wrong.
class LocalSessionCaches {
  /// Resolves the cache-owning repositories off [context]. Call this
  /// synchronously, before the first `await`.
  LocalSessionCaches.of(BuildContext context)
    : _vault = context.read<VaultRepository>(),
      _conversations = context.read<ConversationsRepository>(),
      _notifications = context.read<NotificationsStore>();

  final VaultRepository _vault;
  final ConversationsRepository _conversations;
  final NotificationsStore _notifications;

  /// Purges every user-scoped local cache. Repositories with no offline
  /// cache wired simply no-op.
  ///
  /// Callers decide WHEN to run this relative to the server call:
  ///   * sign-out purges BEFORE revoking the token — the local wipe is
  ///     the point, and it should happen even if the revoke fails.
  ///   * account deletion purges only AFTER the server confirms, so a
  ///     failed delete leaves the user's data intact and signed in.
  Future<void> clear() async {
    await _vault.clearOfflineCache();
    // In-memory transcripts + the offline Chats list + its disk mirror.
    _conversations.clearSnapshotCache();
    await _conversations.clearListCache();
    await _conversations.clearDiskCache();
    await _notifications.clearPersisted();
  }
}
