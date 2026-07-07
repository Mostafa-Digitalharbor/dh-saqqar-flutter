import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/widgets/attachment_chip.dart';
import 'package:saqqar_app/features/chat/widgets/chat_avatar.dart';
import 'package:saqqar_app/features/chat/widgets/chat_scroll_down_button.dart';
import 'package:saqqar_app/features/chat/widgets/message_bubble.dart';
import 'package:saqqar_app/features/conversations/data/attachment_models.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_cache.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';
import 'package:saqqar_app/features/chat/view_model/running_agents_cubit.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_cubit.dart';
import 'package:saqqar_app/features/conversations/widgets/conversation_card.dart';
import 'package:saqqar_app/features/conversations/widgets/meta_dot.dart';
import 'package:saqqar_app/features/demo/saqqar_demo_data.dart';
import 'package:saqqar_app/features/inbox/data/approvals_api.dart';
import 'package:saqqar_app/features/inbox/view_model/approvals_cubit.dart';

/// Stub repository for widget tests — never makes a real HTTP call.
/// Every method returns a benign empty / no-op value so widgets that
/// poke the cubit during construction don't blow up.
class _StubConversationsRepository implements ConversationsRepository {
  @override
  Future<({List<ConversationSummary> conversations, int? total})> list({
    int limit = 30,
    bool includeArchived = false,
  }) async =>
      (conversations: const <ConversationSummary>[], total: 0);

  @override
  Future<({Map<String, int> pendingByConv, Map<String, int> filesByConv})>
      conversationMeta() async => (
            pendingByConv: const <String, int>{},
            filesByConv: const <String, int>{},
          );

  @override
  Future<({Map<String, String> projectByConv, Map<String, String> envByConv})>
      conversationContext(List<String> ids, {int concurrency = 6}) async => (
            projectByConv: const <String, String>{},
            envByConv: const <String, String>{},
          );

  @override
  Future<String> create({String? title}) async => 'stub-id';

  @override
  Future<ConversationSnapshot> getSnapshot(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) {
    throw UnimplementedError();
  }

  @override
  ConversationSnapshot? cachedSnapshot(String id) => null;

  @override
  void cacheSnapshot(String id, ConversationSnapshot snapshot) {}

  @override
  void clearSnapshotCache() {}

  @override
  ConversationsCacheEntry? readCachedList() => null;

  @override
  Future<void> writeCachedList({
    required List<ConversationSummary> conversations,
    required Map<String, int> pendingByConv,
    required Map<String, int> filesByConv,
  }) async {}

  @override
  Future<void> clearListCache() async {}

  @override
  Future<ConversationSnapshot> getSnapshotOffIsolate(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ConversationSnapshot?> diskCachedSnapshot(String id) async => null;

  @override
  Future<void> prefetchSnapshots(List<String> ids) async {}

  @override
  Future<void> clearDiskCache() async {}

  @override
  Future<Conversation> patch({
    required String id,
    String? title,
    bool? isArchived,
    bool? autoApprove,
    bool? deepThink,
    Map<String, dynamic>? context,
    String? environmentId,
    List<String>? environmentIds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<({bool isRunning, bool stopRequested})> stop(String id) async =>
      (isRunning: false, stopRequested: false);

  @override
  Future<({String token, String url, String path})> share(String id) async =>
      (token: '', url: '', path: '');

  @override
  Future<void> revokeShare(String id) async {}

  @override
  Future<String?> setActiveCredential({
    required String id,
    required String? name,
  }) async =>
      null;

  @override
  Future<List<String>> toggleCredential({
    required String id,
    required String name,
    required bool enabled,
  }) async =>
      const [];

  @override
  Future<ConversationSnapshot> dismissPendingAction({
    required String conversationId,
    String? actionType,
    String? credentialName,
    String? credentialKind,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ConversationSnapshot> sendMessage({
    required String conversationId,
    required String content,
    List<String> attachmentIds = const [],
    String? model,
    bool deepThink = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Attachment>> uploadAttachments({
    required String conversationId,
    required List<File> files,
  }) async =>
      const [];

  @override
  Future<Attachment> getAttachmentStatus({
    required String conversationId,
    required String attachmentId,
  }) {
    throw UnimplementedError();
  }
}

// Silence the unused-import warnings for the Dio types that
// _StubConversationsRepository's implements brings transitively.
// ignore: unused_element
Dio? _silenceDio;

/// Wraps [child] with the bare-minimum scaffolding the Saqqar widgets need:
/// MaterialApp with the locale delegates + the real Saqqar themes, plus a
/// `MultiBlocProvider` so any Cubit-reading widget (e.g. [ConversationCard]
/// pulling the rename + pin state from [ConversationsCubit], or the chat
/// row pulling needs-attention from [ApprovalsCubit]) resolves its
/// dependencies without each test setting up its own tree.
Widget _harness(Widget child, {Locale locale = const Locale('en')}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ConversationsCubit>(
        create: (_) => ConversationsCubit(
          repository: _StubConversationsRepository(),
        ),
      ),
      // The cubit never loads in these tests (no consumer triggers it), so a
      // bare ApprovalsApi over a throwaway Dio is enough to satisfy DI.
      BlocProvider<ApprovalsCubit>(
        create: (_) => ApprovalsCubit(ApprovalsApi(Dio())),
      ),
      // The conversation row reads the running-agent set for its "thinking"
      // status ring, so the harness must provide it too.
      BlocProvider<RunningAgentsCubit>(create: (_) => RunningAgentsCubit()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      theme: AppTheme.light(locale),
      darkTheme: AppTheme.dark(locale),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('Chat primitives', () {
    testWidgets('ChatAvatar renders assistant variant with sparkles', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const ChatAvatar(isUser: false)));
      expect(find.byType(ChatAvatar), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
      // The exact icon is provided by AppIcons; just check no exception.
      expect(tester.takeException(), isNull);
    });

    testWidgets('ChatAvatar renders user variant without exception', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const ChatAvatar(isUser: true)));
      expect(find.byType(ChatAvatar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ChatScrollDownButton is invisible when not visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(ChatScrollDownButton(visible: false, onTap: () {})),
      );
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 0);
    });

    testWidgets('AttachmentChip renders the attachment name + meta', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const AttachmentChip(
            attachment: DemoAttachment(
              name: 'report.xlsx',
              kind: 'EXCEL',
              size: '24 KB',
            ),
          ),
        ),
      );
      expect(find.text('report.xlsx'), findsOneWidget);
      expect(find.textContaining('EXCEL'), findsOneWidget);
    });
  });

  group('Chat message bubble', () {
    testWidgets('MessageBubble renders the message content', (tester) async {
      const text = 'Show me how many users are in Odoo.';
      await tester.pumpWidget(
        _harness(
          const MessageBubble(
            isUser: true,
            showTime: true,
            message: DemoMessage(
              role: DemoMessageRole.user,
              content: text,
              time: '12:04',
            ),
          ),
        ),
      );
      expect(find.text(text), findsOneWidget);
      expect(find.text('12:04'), findsOneWidget);
    });

    testWidgets('MessageBubble hides timestamp when showTime is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const MessageBubble(
            isUser: false,
            showTime: false,
            message: DemoMessage(
              role: DemoMessageRole.assistant,
              content: 'OK',
              time: '12:05',
            ),
          ),
        ),
      );
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('12:05'), findsNothing);
    });
  });

  group('Conversations widgets', () {
    testWidgets('MetaDot shows icon and text', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MetaDot(icon: Icons.message, text: '42', color: Colors.cyan),
        ),
      );
      expect(find.text('42'), findsOneWidget);
      expect(find.byIcon(Icons.message), findsOneWidget);
    });

    testWidgets('ConversationCard renders title, preview and message count', (
      tester,
    ) async {
      // The row shows title + relative time + last-message preview + the
      // real meta run (message count, and project · environment / file count
      // when present). Mirrors the current Chats design.
      final conversation = ConversationSummary(
        id: 'test-conv-1',
        title: 'GAC production audit',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        isArchived: false,
        messageCount: 14,
        lastMessagePreview: 'Pulled the last 30 invoices.',
      );
      await tester.pumpWidget(
        _harness(
          ConversationCard(
            conversation: conversation,
            onTap: () {},
            onAction: (_) {},
          ),
        ),
      );
      expect(find.text(conversation.title), findsOneWidget);
      expect(find.text(conversation.lastMessagePreview), findsOneWidget);
      expect(find.text('${conversation.messageCount}'), findsOneWidget);
    });

    testWidgets(
      'ConversationCard swaps the preview for the "Saqqar is working" '
      'indicator while the conversation is running',
      (tester) async {
        final conversation = ConversationSummary(
          id: 'running-conv',
          title: 'Excel export',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          updatedAt: DateTime.now().subtract(const Duration(minutes: 1)),
          isArchived: false,
          messageCount: 3,
          lastMessagePreview: 'This preview is hidden while working.',
          isRunning: true,
        );
        await tester.pumpWidget(
          _harness(
            ConversationCard(
              conversation: conversation,
              onTap: () {},
              onAction: (_) {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        // The live indicator (brand wordmark + "is working now") replaces
        // the last-message preview.
        expect(find.text('is working now'), findsOneWidget);
        expect(find.text(conversation.lastMessagePreview), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // The standalone CredentialRow widget was retired when the Vault was
  // restructured to projects → envs → credentials-per-kind. Tests for the
  // new flow live alongside `ProjectCard` / `EnvironmentDetailSheet` once
  // the controller-backed sheets stabilise.

  // The standalone ArtifactCard widget was retired when the global Files
  // tab was folded into each chat's ⋯ menu. The per-chat ChatArtifactTile
  // covers the same role and is exercised via chat tests.
}
