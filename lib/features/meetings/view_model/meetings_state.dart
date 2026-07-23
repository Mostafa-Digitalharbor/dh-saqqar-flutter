import 'package:equatable/equatable.dart';

import '../data/meeting_models.dart';

/// Composite state for the meetings screen: the current [session] plus its
/// derived text (transcript / summary / last chat reply) and a single
/// [busy] flag for any in-flight action.
class MeetingsState extends Equatable {
  const MeetingsState({
    this.session,
    this.transcript = '',
    this.summary = '',
    this.chatReply = '',
    this.busy = false,
    this.error,
  });

  final MeetingSession? session;
  final String transcript;
  final String summary;
  final String chatReply;
  final bool busy;

  /// Last action error; the view maps it to a localized toast via
  /// `ApiErrorMapper` and it's cleared on the next action.
  final Object? error;

  MeetingsState copyWith({
    MeetingSession? session,
    String? transcript,
    String? summary,
    String? chatReply,
    bool? busy,
    Object? error,
    bool clearError = false,
  }) {
    return MeetingsState(
      session: session ?? this.session,
      transcript: transcript ?? this.transcript,
      summary: summary ?? this.summary,
      chatReply: chatReply ?? this.chatReply,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props =>
      [session, transcript, summary, chatReply, busy, error];
}
