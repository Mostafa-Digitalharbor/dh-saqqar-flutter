import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../demo/saqqar_demo_data.dart';

/// Mutable overlay on top of the const [demoConversations] seed. Holds
/// per-conversation renames + pin state without forcing the demo data
/// itself to drop `const` (which would touch every other call site).
///
/// When the backend ships, swap each mutation for a Dio call and read
/// the canonical title from `conversation.title` in the server payload —
/// the rename map then becomes optimistic-state-only.
class ConversationsState {
  const ConversationsState({
    this.renames = const {},
    this.pinnedIds = const {},
  });

  /// `conversationId → user-supplied display title`. Overrides
  /// `DemoConversation.title` everywhere via [titleFor].
  final Map<String, String> renames;

  /// IDs of conversations the user pinned to the top of the Chats list.
  /// Iteration order is irrelevant — sorting uses pin presence + the
  /// underlying seed order.
  final Set<String> pinnedIds;

  /// Effective display title for a conversation: user rename when set,
  /// otherwise the seed title. Trim handled — an empty rename is
  /// treated as "no rename" so the seed title shows again.
  String titleFor(DemoConversation conv) {
    final renamed = renames[conv.id]?.trim();
    if (renamed != null && renamed.isNotEmpty) return renamed;
    return conv.title;
  }

  bool isPinned(String id) => pinnedIds.contains(id);

  ConversationsState copyWith({
    Map<String, String>? renames,
    Set<String>? pinnedIds,
  }) {
    return ConversationsState(
      renames: renames ?? this.renames,
      pinnedIds: pinnedIds ?? this.pinnedIds,
    );
  }
}

class ConversationsController extends Notifier<ConversationsState> {
  @override
  ConversationsState build() => const ConversationsState();

  void renameConversation({required String id, required String name}) {
    final trimmed = name.trim();
    final next = {...state.renames};
    if (trimmed.isEmpty) {
      next.remove(id);
    } else {
      next[id] = trimmed;
    }
    state = state.copyWith(renames: next);
  }

  void togglePin(String id) {
    final next = {...state.pinnedIds};
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(pinnedIds: next);
  }

  bool isPinned(String id) => state.isPinned(id);
}

final conversationsControllerProvider =
    NotifierProvider<ConversationsController, ConversationsState>(
  ConversationsController.new,
);

/// Convenience selector — the effective display title for a given
/// conversation id, watching only the rename map so widgets don't
/// rebuild on pin changes they don't care about.
final conversationTitleProvider =
    Provider.family<String, DemoConversation>((ref, conv) {
  final renames =
      ref.watch(conversationsControllerProvider.select((s) => s.renames));
  final renamed = renames[conv.id]?.trim();
  if (renamed != null && renamed.isNotEmpty) return renamed;
  return conv.title;
});

/// Convenience: returns the conversations sorted with pinned ones first
/// (preserving their original order within each bucket). Watches both
/// the seed list and the pin set.
final orderedConversationsProvider = Provider<List<DemoConversation>>((ref) {
  final pinned =
      ref.watch(conversationsControllerProvider.select((s) => s.pinnedIds));
  if (pinned.isEmpty) return demoConversations;
  final pinnedList = <DemoConversation>[];
  final restList = <DemoConversation>[];
  for (final c in demoConversations) {
    if (pinned.contains(c.id)) {
      pinnedList.add(c);
    } else {
      restList.add(c);
    }
  }
  return [...pinnedList, ...restList];
});
