import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/state/data_state.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/share/data/shared_transcript_models.dart';
import 'package:saqqar_app/features/share/data/shares_api.dart';
import 'package:saqqar_app/features/share/view_model/shared_transcript_cubit.dart';

/// In-memory [SharesApi] — never touches Dio/the network. Returns [result] or
/// throws [error] so the cubit's success/failure branches are both exercised.
class _FakeSharesApi implements SharesApi {
  _FakeSharesApi({this.result, this.error});

  final SharedTranscript? result;
  final Object? error;
  int calls = 0;

  @override
  Future<SharedTranscript> get(String token) async {
    calls++;
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

void main() {
  group('SharedTranscriptCubit', () {
    test('starts idle', () {
      final cubit = SharedTranscriptCubit(_FakeSharesApi());
      addTearDown(cubit.close);
      expect(cubit.state, isA<DataIdle<SharedTranscript>>());
    });

    test('load() emits DataSuccess with the fetched transcript', () async {
      final transcript = SharedTranscript(
        title: 'Q3 numbers',
        updatedAt: DateTime(2026, 1, 2),
        messages: [
          _msg('1', MessageRole.user, 'Show me Q3'),
          _msg('2', MessageRole.assistant, 'Here is Q3.'),
        ],
      );
      final cubit = SharedTranscriptCubit(_FakeSharesApi(result: transcript));
      addTearDown(cubit.close);

      await cubit.load('tok-123');

      expect(cubit.state, isA<DataSuccess<SharedTranscript>>());
      final data = (cubit.state as DataSuccess<SharedTranscript>).data;
      expect(data.title, 'Q3 numbers');
      expect(data.messages, hasLength(2));
    });

    test('load() emits DataFailure (with a typed error) when the fetch throws',
        () async {
      final cubit =
          SharedTranscriptCubit(_FakeSharesApi(error: Exception('boom')));
      addTearDown(cubit.close);

      await cubit.load('tok-404');

      expect(cubit.state, isA<DataFailure<SharedTranscript>>());
      // `error` carries the mapped AppFailure so DataStateView can localize it.
      expect((cubit.state as DataFailure<SharedTranscript>).error, isNotNull);
    });

    test('load() is re-entrancy guarded while a fetch is in flight', () async {
      final api = _FakeSharesApi(
        result: SharedTranscript(
          title: 't',
          updatedAt: DateTime(2026, 1, 1),
          messages: const [],
        ),
      );
      final cubit = SharedTranscriptCubit(api);
      addTearDown(cubit.close);

      // Fire the first load and, before awaiting it, the second — the guard
      // (`state is DataLoading`) should drop the second call.
      final first = cubit.load('tok');
      final second = cubit.load('tok');
      await Future.wait([first, second]);

      expect(api.calls, 1);
    });
  });
}
