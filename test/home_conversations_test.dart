import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/state/data_state.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_cubit.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_state.dart';
import 'package:saqqar_app/features/home/home_screen.dart';
import 'package:saqqar_app/features/vault/data/credentials_api.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';
import 'package:saqqar_app/features/vault/data/vault_repository.dart';
import 'package:saqqar_app/features/vault/view_model/vault_cubit.dart';

import 'support/responsive_harness.dart';

/// Home's "recent conversations" block.
///
/// Two regressions live here, both found on a device:
///  * while the list was still loading Home printed "Start your first
///    conversation", telling a returning user they had no history;
///  * Home only loaded when it had nothing, so a chat started elsewhere
///    (launched from Apps) never appeared until a pull-to-refresh.
class _NoRepo implements ConversationsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoProjects implements ProjectsApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoCreds implements CredentialsApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _SpyConversations extends ConversationsCubit {
  _SpyConversations(DataState<ConversationsData> data)
    : super(repository: _NoRepo()) {
    emit(state.copyWith(data: data));
  }

  int loads = 0;
  int refreshes = 0;

  @override
  Future<void> load({
    bool includeArchived = true,
    bool prefetch = true,
  }) async => loads++;

  @override
  Future<void> refresh() async => refreshes++;
}

class _QuietVault extends VaultCubit {
  _QuietVault()
    : super(
        repository: VaultRepository(
          projectsApi: _NoProjects(),
          credentialsApi: _NoCreds(),
        ),
      );

  @override
  Future<void> load() async {}
}

ConversationSummary _chat(String id, String title) => ConversationSummary(
  id: id,
  title: title,
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1),
  isArchived: false,
  messageCount: 1,
);

void main() {
  late SharedPreferences prefs;
  final en = AppStrings(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<_SpyConversations> pumpHome(
    WidgetTester tester,
    DataState<ConversationsData> data,
  ) async {
    final cubit = _SpyConversations(data);
    addTearDown(cubit.close);
    await pumpOnce(
      tester,
      const HomeScreen(),
      prefs: prefs,
      wrap: (child) => MultiBlocProvider(
        providers: [
          BlocProvider<ConversationsCubit>.value(value: cubit),
          BlocProvider<VaultCubit>(create: (_) => _QuietVault()),
        ],
        child: child,
      ),
    );
    return cubit;
  }

  testWidgets('shows nothing while the list has not loaded yet', (
    tester,
  ) async {
    final cubit = await pumpHome(tester, const DataIdle<ConversationsData>());
    expect(find.text(en.figStartYourFirstConversation), findsNothing);
    expect(cubit.loads, 1, reason: 'a cold open loads');
    expect(cubit.refreshes, 0);
  });

  testWidgets('shows the empty prompt only once loaded and truly empty', (
    tester,
  ) async {
    await pumpHome(
      tester,
      const DataSuccess(ConversationsData(conversations: [])),
    );
    expect(find.text(en.figStartYourFirstConversation), findsOneWidget);
  });

  testWidgets('lists loaded chats and revalidates instead of reloading', (
    tester,
  ) async {
    final cubit = await pumpHome(
      tester,
      DataSuccess(
        ConversationsData(conversations: [_chat('a', 'WhatsApp integration')]),
      ),
    );
    expect(find.text('WhatsApp integration'), findsOneWidget);
    expect(find.text(en.figStartYourFirstConversation), findsNothing);
    expect(
      cubit.refreshes,
      1,
      reason: 'returning to Home must pick up chats made elsewhere',
    );
    expect(cubit.loads, 0);
  });
}
