import 'package:equatable/equatable.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/state/data_state.dart';
import '../../conversations/data/attachment_models.dart';
import '../../conversations/data/conversation_models.dart';

/// Typed action enum mirroring [VaultAction] / [ConversationsAction] —
/// keeps strings out of the cubit. The view maps each value to a
/// localized `"Couldn't <X>"` label via a switch.
enum ChatAction {
  load,
  send,
  stop,
  uploadAttachment,
  dismissPendingAction,
  setActiveCredential,
  toggleCredential,
  share,
  patch,
}

enum ChatToast {
  messageSent,
  generationStopped,
  attachmentReady,
  pendingActionDismissed,
  credentialSet,
  shareLinkCopied,
}

class ChatActionFailure extends Equatable {
  const ChatActionFailure({required this.action, required this.failure});
  final ChatAction action;
  final AppFailure failure;
  @override
  List<Object?> get props => [action, failure];
}

/// Per-conversation state owned by [ChatCubit]. Constructed once per
/// chat route via `BlocProvider`, disposed on route pop.
///
/// [data] holds the full server snapshot — messages, approvals,
/// artifacts, pending actions, available + disabled credentials. Wrap
/// reads with `DataStateView<ConversationSnapshot>`.
///
/// [stagedAttachments] are uploaded but NOT yet attached to a sent
/// message; they ride along on the next [ChatCubit.sendMessage].
///
/// [isSending] / [isStopping] / [isUploading] disable composer
/// controls during the matching in-flight action.
///
/// [actionFailure] / [actionToast] are one-shot signals consumed by the
/// view's BlocListener.
class ChatState extends Equatable {
  const ChatState({
    this.data = const DataIdle<ConversationSnapshot>(),
    this.stagedAttachments = const [],
    this.isSending = false,
    this.isStopping = false,
    this.isUploading = false,
    this.isLoadingOlder = false,
    this.hasMoreOlder = true,
    this.lastShareUrl,
    this.actionFailure,
    this.actionToast,
  });

  final DataState<ConversationSnapshot> data;

  /// Attachments already POSTed to `/conversations/<id>/attachments/`
  /// — the upload returned an id + a server-side processing status.
  /// `null` `status` is OK (display the chip); the cubit polls
  /// `/attachments/<aid>/status/` until each flips to `ready` so the
  /// user sees feedback before they tap Send.
  final List<Attachment> stagedAttachments;

  final bool isSending;
  final bool isStopping;
  final bool isUploading;

  /// True while a backward page (`?before=`) is in flight — drives the
  /// small loader pinned at the top of the message list when the user
  /// scrolls up to reach older history.
  final bool isLoadingOlder;

  /// False once a backward page comes back empty — i.e. we've reached the
  /// start of the transcript. Stops the scroll-to-top trigger from firing
  /// fruitless requests. Starts `true` (assume there's history to load
  /// until proven otherwise).
  final bool hasMoreOlder;

  /// Populated after a successful [ChatCubit.shareConversation]. The
  /// view reads + clears this to copy-to-clipboard / open the share
  /// sheet then call [ChatCubit.consumeActionToast].
  final String? lastShareUrl;

  final ChatActionFailure? actionFailure;
  final ChatToast? actionToast;

  /// Convenience: the server-reported running flag from the latest
  /// snapshot. Drives the polling cadence (1.5 s vs 15 s).
  bool get isRunning =>
      data.dataOrNull?.conversation.isRunning ?? false;

  bool get hasUnreadyAttachments => stagedAttachments
      .any((a) => a.status != AttachmentStatus.ready);

  ChatState copyWith({
    DataState<ConversationSnapshot>? data,
    List<Attachment>? stagedAttachments,
    bool? isSending,
    bool? isStopping,
    bool? isUploading,
    bool? isLoadingOlder,
    bool? hasMoreOlder,
    String? lastShareUrl,
    ChatActionFailure? actionFailure,
    ChatToast? actionToast,
    bool clearStagedAttachments = false,
    bool clearShareUrl = false,
    bool clearActionFailure = false,
    bool clearActionToast = false,
  }) {
    return ChatState(
      data: data ?? this.data,
      stagedAttachments: clearStagedAttachments
          ? const []
          : (stagedAttachments ?? this.stagedAttachments),
      isSending: isSending ?? this.isSending,
      isStopping: isStopping ?? this.isStopping,
      isUploading: isUploading ?? this.isUploading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      lastShareUrl:
          clearShareUrl ? null : (lastShareUrl ?? this.lastShareUrl),
      actionFailure:
          clearActionFailure ? null : (actionFailure ?? this.actionFailure),
      actionToast:
          clearActionToast ? null : (actionToast ?? this.actionToast),
    );
  }

  @override
  List<Object?> get props => [
        data,
        stagedAttachments,
        isSending,
        isStopping,
        isUploading,
        isLoadingOlder,
        hasMoreOlder,
        lastShareUrl,
        actionFailure,
        actionToast,
      ];
}
