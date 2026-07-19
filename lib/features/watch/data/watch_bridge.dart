import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/i18n/platform_strings.dart';
import '../../../core/logging/app_logger.dart';
import '../../chat/data/transcribe_api.dart';
import '../../conversations/data/conversation_models.dart';
import '../../conversations/data/conversations_api.dart';
import '../../inbox/data/approval_models.dart';
import '../../inbox/data/approvals_api.dart';
import '../../vault/data/projects_api.dart';

/// Bridges the flat pending-approvals feed — and now voice commands — to
/// the paired Apple Watch app.
///
/// The watch has no network layer of its own (companion mode) — it only
/// ever sees what this class hands it over `WatchConnectivity`, and any
/// approve/deny tap or recorded voice note on the watch round-trips back
/// through here to the same REST calls the phone's own UI uses. iOS-only;
/// every method is a silent no-op on Android so callers don't need
/// platform checks.
class WatchBridge {
  WatchBridge(
    this._approvalsApi, {
    required TranscribeApi transcribeApi,
    required ConversationsApi conversationsApi,
    required ProjectsApi projectsApi,
    required PlatformStrings platformStrings,
  })  : _transcribeApi = transcribeApi,
        _conversationsApi = conversationsApi,
        _projectsApi = projectsApi,
        _platformStrings = platformStrings {
    if (Platform.isIOS) {
      _channel.setMethodCallHandler(_handleCall);
    }
  }

  static const _tag = 'WatchBridge';
  static const _channel = MethodChannel('sa.com.digitalharbor.saqqarapp/watch');

  /// How long a voice command waits for the assistant's reply before
  /// handing back a "still working" placeholder. The watch's interactive
  /// `WCSession` message stays open for the whole wait — 45s comfortably
  /// covers most real turns (a few tool calls typically land in 10-20s)
  /// while staying under the point where a held-open interactive message
  /// risks the system treating it as unresponsive. Anything slower than
  /// this is delivered by [_watchForLateReply] instead, with the watch's
  /// own spinner staying up client-side in the meantime.
  static const _voiceReplyTimeout = Duration(seconds: 45);
  static const _voiceReplyPollInterval = Duration(milliseconds: 1500);

  /// Bound on the background poll that picks up where [_voiceReplyTimeout]
  /// left off, for turns that run tools / take real work. Generous —
  /// there's no user-facing spinner tied to this one, just a notification
  /// once the answer lands.
  static const _lateReplyTimeout = Duration(minutes: 5);

  final ApprovalsApi _approvalsApi;
  final TranscribeApi _transcribeApi;
  final ConversationsApi _conversationsApi;
  final ProjectsApi _projectsApi;

  /// The watch draws whatever strings we hand back, and there's no
  /// `BuildContext` on this side of the `MethodChannel` — so error copy
  /// resolves through here rather than being hardcoded English.
  final PlatformStrings _platformStrings;

  /// Pushes the current pending-approvals snapshot to the watch via
  /// `WCSession.updateApplicationContext` (native side). Best-effort and
  /// fire-and-forget — a watch that isn't paired, or a phone-side channel
  /// hiccup, must never surface as a failure in the phone UI.
  ///
  /// Capped to the newest [maxItems] — the watch is a glanceable surface,
  /// not a full inbox.
  Future<void> syncApprovals(
    List<Approval> pending, {
    required int pendingCount,
    int maxItems = 10,
  }) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('syncApprovals', {
        'pendingCount': pendingCount,
        'approvals': [
          for (final a in pending.take(maxItems)) _encode(a),
        ],
      });
    } catch (e, st) {
      AppLogger.warn(_tag, 'syncApprovals failed (non-fatal)', error: e, stackTrace: st);
    }
  }

  // `createdAtMs` (epoch millis) rather than an ISO string — `createdAt`
  // is stored `.toLocal()`, and `DateTime.toIso8601String()` on a
  // non-UTC instant omits the offset suffix, which trips up
  // `ISO8601DateFormatter` strict parsing on the watch. Millis sidestep
  // the whole format question.
  Map<String, dynamic> _encode(Approval a) => {
        'id': a.id,
        'prompt': a.prompt,
        'actionType': a.actionType.wire,
        'conversationTitle': a.conversation?.title ?? '',
        'createdAtMs': a.createdAt?.millisecondsSinceEpoch,
        'recordCount': a.recordCount,
      };

  /// Handles calls placed by the native iOS host on behalf of the watch —
  /// today just the approve/deny action relayed from a `WCSession`
  /// message. Runs the same decision endpoint the phone's chat screen
  /// uses, so the watch never talks to the server directly.
  Future<dynamic> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'decideApproval':
        final args = (call.arguments as Map).cast<String, dynamic>();
        final id = args['id'] as String;
        final approved = args['approved'] as bool;
        AppLogger.info(_tag, 'decideApproval($id, approved=$approved) from watch');
        final result = await _approvalsApi.decide(id: id, approved: approved);
        return {'id': result.approval.id, 'status': result.approval.status.wire};
      case 'voiceCommand':
        final args = (call.arguments as Map).cast<String, dynamic>();
        return _handleVoiceCommand(
          path: args['path'] as String,
          conversationId: args['conversationId'] as String?,
          environmentId: args['environmentId'] as String?,
        );
      case 'listProjects':
        return _handleListProjects();
      case 'useDefaultProject':
        return _handleUseDefaultProject();
      default:
        throw MissingPluginException('Unhandled method ${call.method}');
    }
  }

  /// Transcribes a voice note recorded on the watch and forwards it as a
  /// normal chat turn — the same [TranscribeApi] + [ConversationsApi] pair
  /// the phone's own chat screen drives. Reuses [conversationId] when the
  /// watch is continuing a conversation from an earlier turn in the same
  /// session, otherwise starts a fresh one.
  ///
  /// New conversations are also switched to `auto_approve` — there's no
  /// approve/deny UI mid-recording, so a voice-driven turn must run
  /// hands-free rather than stall on a prompt the watch has no way to
  /// surface until the whole reply lands. The server still enforces its
  /// own safety rail on top of this (auto-approve is ignored against a
  /// LIVE environment), and anything that still needs a human call
  /// surfaces on the Approvals tab exactly like it would from the phone.
  Future<Map<String, dynamic>> _handleVoiceCommand({
    required String path,
    String? conversationId,
    String? environmentId,
  }) async {
    final file = File(path);
    try {
      AppLogger.info(_tag, 'voiceCommand(conversationId=$conversationId) from watch');
      final transcript = await _transcribeApi.transcribe(audio: file);
      if (transcript.isEmpty) {
        return {'error': _platformStrings.strings.watchErrorNoSpeech};
      }
      String id;
      if (conversationId != null) {
        id = conversationId;
      } else {
        id = await _conversationsApi.create();
        // Binding + auto-approve always happen right after create, never
        // on a continuing turn — the watch only ever asks for a
        // project/env once per conversation, same as the phone's picker.
        await _conversationsApi.patch(
          id: id,
          autoApprove: true,
          environmentId:
              (environmentId != null && environmentId.isNotEmpty) ? environmentId : null,
        );
      }
      final sent = await _conversationsApi.sendMessage(
        conversationId: id,
        content: transcript,
      );
      final firstPass = await _pollForReply(id, since: sent.cursor, timeout: _voiceReplyTimeout);
      // Best-effort refresh so an approval the turn just created reaches
      // the watch immediately rather than waiting for the phone's own
      // next poll cycle.
      unawaited(_refreshApprovals());
      if (firstPass.reply == null) {
        // The run outlived the interactive WCSession round-trip (easy for
        // a tool-using turn) — keep watching in the background and
        // deliver the answer once it lands, instead of just leaving the
        // watch with "still working" forever.
        unawaited(_watchForLateReply(id, since: firstPass.cursor));
      }
      return {
        'transcript': transcript,
        'conversationId': id,
        if (firstPass.reply != null) 'reply': firstPass.reply,
      };
    } catch (e, st) {
      AppLogger.warn(_tag, 'voiceCommand failed', error: e, stackTrace: st);
      return {'error': _platformStrings.strings.watchErrorUnreachable};
    } finally {
      unawaited(file.delete().catchError((_) => file));
    }
  }

  /// Polls until the run actually finishes, bounded by [timeout], and
  /// returns the LAST assistant message seen (if any). A multi-step tool
  /// run emits interim assistant text along the way ("Let me check
  /// what fields are needed…") before its real answer — returning on the
  /// first assistant message seen, while `isRunning` is still true, was
  /// the bug: it handed the watch that interim line and never came back
  /// for the actual "Done. User created." Returns the cursor either way
  /// so a caller can resume polling from where this left off.
  Future<({String? reply, DateTime? cursor})> _pollForReply(
    String conversationId, {
    DateTime? since,
    required Duration timeout,
  }) async {
    var cursor = since;
    String? latestAssistantText;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_voiceReplyPollInterval);
      final snapshot = await _conversationsApi.getSnapshot(conversationId, since: cursor);
      cursor = snapshot.cursor ?? cursor;
      for (final message in snapshot.messages) {
        if (message.role == MessageRole.assistant && message.content.trim().isNotEmpty) {
          latestAssistantText = message.content;
        }
      }
      if (!snapshot.conversation.isRunning) {
        final text = latestAssistantText;
        return (reply: text != null ? _sanitizeForWatch(text) : null, cursor: cursor);
      }
    }
    return (reply: null, cursor: cursor);
  }

  static final _markdownLinkPattern = RegExp(r'\[[^\]]*\]\(https?://[^)]+\)');
  static final _bareUrlPattern = RegExp(r'https?://\S+');
  static final _danglingConnectorPattern = RegExp(
    r'\s*\b(?:here|link)\s*[:.]?\s*$',
    caseSensitive: false,
    multiLine: true,
  );
  static const _maxReplyLength = 220;

  /// The watch has no browser — a link, even shown as just its label
  /// ("Open Zizu561"), is a dead promise of an action that can't happen
  /// here, and a raw Odoo record URL is long enough to eat the whole
  /// screen in wrapped text. Drop the entire `[label](url)` construct
  /// (not just the URL), clean up whatever dangling "...here:" lead-in
  /// text it leaves behind, and cap the length — watch replies need to be
  /// glanceable, not the full chat transcript.
  String _sanitizeForWatch(String text) {
    var result = text.replaceAll(_markdownLinkPattern, '');
    result = result.replaceAll(_bareUrlPattern, '');
    result = result.replaceAll(_danglingConnectorPattern, '');
    result = result.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    result = result.trim();
    if (result.length > _maxReplyLength) {
      result = '${result.substring(0, _maxReplyLength).trimRight()}…';
    }
    return result;
  }

  /// Keeps polling well past the interactive reply window and, once the
  /// assistant actually answers, hands it to the watch via
  /// `transferUserInfo` — queued, guaranteed delivery (unlike
  /// `sendMessage`), so it still arrives even if the watch app isn't
  /// foregrounded by the time the run finishes.
  Future<void> _watchForLateReply(String conversationId, {DateTime? since}) async {
    try {
      final result = await _pollForReply(conversationId, since: since, timeout: _lateReplyTimeout);
      final reply = result.reply;
      if (reply != null) {
        await _pushVoiceReply(conversationId: conversationId, reply: reply);
      }
    } catch (e, st) {
      AppLogger.warn(_tag, 'watchForLateReply failed', error: e, stackTrace: st);
    }
  }

  Future<void> _pushVoiceReply({required String conversationId, required String reply}) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('pushVoiceReply', {
        'conversationId': conversationId,
        'reply': reply,
      });
    } catch (e, st) {
      AppLogger.warn(_tag, 'pushVoiceReply failed (non-fatal)', error: e, stackTrace: st);
    }
  }

  /// Every project the user has, each with its nested environments — the
  /// same tree the phone's environment-picker sheet renders, flattened to
  /// plain maps for the `WCSession` round-trip.
  Future<Map<String, dynamic>> _handleListProjects() async {
    try {
      final projects = await _projectsApi.list();
      return {
        'projects': [
          for (final p in projects)
            {
              'id': p.id,
              'name': p.name,
              'environments': [
                for (final e in p.environments)
                  {'id': e.id, 'name': e.name, 'isLive': e.isLive},
              ],
            },
        ],
      };
    } catch (e, st) {
      AppLogger.warn(_tag, 'listProjects failed', error: e, stackTrace: st);
      return {'error': _platformStrings.strings.watchErrorProjectsLoad};
    }
  }

  /// Mirrors the phone's "Use My Database" CTA (`chat_screen.dart`) — for
  /// an account with no projects yet, this idempotently provisions a
  /// default project + production environment and hands back that
  /// environment, so the watch picker always has something selectable
  /// instead of dead-ending on an empty list.
  Future<Map<String, dynamic>> _handleUseDefaultProject() async {
    try {
      final env = await _projectsApi.defaultProject();
      return {
        'environmentId': env.id,
        'environmentName': env.name,
        'projectId': env.projectId,
      };
    } catch (e, st) {
      AppLogger.warn(_tag, 'useDefaultProject failed', error: e, stackTrace: st);
      return {'error': _platformStrings.strings.watchErrorProjectSetup};
    }
  }

  Future<void> _refreshApprovals() async {
    try {
      final page = await _approvalsApi.list(status: ApprovalStatus.pending, limit: 10);
      await syncApprovals(page.approvals, pendingCount: page.pendingCount);
    } catch (e, st) {
      AppLogger.warn(_tag, 'post-voice-command approvals refresh failed', error: e, stackTrace: st);
    }
  }
}
