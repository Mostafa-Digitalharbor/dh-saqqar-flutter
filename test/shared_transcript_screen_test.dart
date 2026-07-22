import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/widgets/chat_markdown.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/share/data/shared_transcript_models.dart';
import 'package:saqqar_app/features/share/data/shares_api.dart';
import 'package:saqqar_app/features/share/view/shared_transcript_screen.dart';
import 'package:saqqar_app/features/share/view_model/shared_transcript_cubit.dart';
import 'package:saqqar_app/shared/widgets/app_error_state.dart';
import 'package:saqqar_app/shared/widgets/empty_state.dart';

/// Fake [SharesApi] that returns [result] or throws [error].
class _FakeSharesApi implements SharesApi {
  _FakeSharesApi({this.result, this.error});
  final SharedTranscript? result;
  final Object? error;

  @override
  Future<SharedTranscript> get(String token) async {
    if (error != null) throw error!;
    return result!;
  }
}

Message _msg(String id, MessageRole role, String content) => Message(
      id: id,
      role: role,
      content: content,
      createdAt: DateTime(2026, 1, 1),
    );

Widget _host(SharedTranscriptCubit cubit) => BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        theme: AppTheme.light(const Locale('en')),
        home: const SharedTranscriptScreen(token: 'tok-1'),
      ),
    );

void main() {
  testWidgets('renders the fetched transcript read-only', (tester) async {
    final transcript = SharedTranscript(
      title: 'Q3 numbers',
      updatedAt: DateTime(2026, 1, 2, 14, 30),
      messages: [
        _msg('1', MessageRole.user, 'Show me Q3'),
        _msg('2', MessageRole.assistant, 'Here is Q3.'),
      ],
    );
    final cubit = SharedTranscriptCubit(_FakeSharesApi(result: transcript));
    addTearDown(cubit.close);
    await cubit.load('tok-1');

    await tester.pumpWidget(_host(cubit));
    await tester.pump(); // resolve the load future
    await tester.pump();

    // Conversation title in the app bar.
    expect(find.text('Q3 numbers'), findsWidgets);
    // Read-only badge (English copy) — proves the "look but don't touch" chrome.
    expect(find.text('READ-ONLY'), findsOneWidget);
    // Both messages rendered through the shared markdown renderer.
    expect(find.byType(ChatMarkdown), findsNWidgets(2));
    // No composer / text field — this surface is strictly read-only.
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an error surface with retry when the fetch fails',
      (tester) async {
    final cubit = SharedTranscriptCubit(_FakeSharesApi(error: Exception('x')));
    addTearDown(cubit.close);
    await cubit.load('tok-1');

    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.byType(ChatMarkdown), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the empty state when the transcript has no messages',
      (tester) async {
    final cubit = SharedTranscriptCubit(
      _FakeSharesApi(
        result: SharedTranscript(
          title: 'Empty chat',
          updatedAt: DateTime(2026, 1, 1),
          messages: const [],
        ),
      ),
    );
    addTearDown(cubit.close);
    await cubit.load('tok-1');

    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(ChatMarkdown), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
