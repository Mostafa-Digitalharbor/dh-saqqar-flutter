import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/meetings/data/meeting_models.dart';
import 'package:saqqar_app/features/meetings/data/meetings_api.dart';
import 'package:saqqar_app/features/meetings/view_model/meetings_cubit.dart';

class _FakeMeetingsApi implements MeetingsApi {
  Map<String, dynamic> startResult = {'id': 'm1', 'status': 'ended'};
  Map<String, dynamic> transcriptResult = {
    'status': 'ended',
    'transcript': 'hello world',
  };
  Map<String, dynamic> summarizeResult = {'summary': 'the summary'};
  Map<String, dynamic> chatResult = {'reply': 'the answer'};
  Object? error;
  Map<String, dynamic>? lastStartBody;
  Map<String, dynamic>? lastChatBody;

  @override
  Future<Map<String, dynamic>> start(Map<String, dynamic> body) async {
    lastStartBody = body;
    if (error != null) throw error!;
    return startResult;
  }

  @override
  Future<Map<String, dynamic>> transcript(String id) async => transcriptResult;

  @override
  Future<Map<String, dynamic>> stop(String id) async => {'status': 'ended'};

  @override
  Future<Map<String, dynamic>> summarize(String id) async => summarizeResult;

  @override
  Future<Map<String, dynamic>> chat(String id, Map<String, dynamic> body) async {
    lastChatBody = body;
    return chatResult;
  }
}

void main() {
  group('MeetingSession.fromJson', () {
    test('reads a bare object', () {
      final m = MeetingSession.fromJson(const {'id': 'm1', 'status': 'recording'});
      expect(m.id, 'm1');
      expect(m.isActive, isTrue);
      expect(m.isValid, isTrue);
    });

    test('unwraps a { meeting: {...} } envelope', () {
      final m = MeetingSession.fromJson(const {
        'meeting': {'meeting_id': 'x9', 'status': 'ended'},
      });
      expect(m.id, 'x9');
      expect(m.isActive, isFalse);
    });
  });

  group('MeetingTranscript', () {
    test('passes through a plain string', () {
      final t = MeetingTranscript.fromJson(const {
        'status': 'ended',
        'transcript': 'line one',
      });
      expect(t.text, 'line one');
    });

    test('flattens a list of speaker segments', () {
      final t = MeetingTranscript.fromJson(const {
        'transcript': [
          {'speaker': 'Sara', 'text': 'Hi'},
          {'speaker': 'Omar', 'text': 'Hello'},
        ],
      });
      expect(t.text, 'Sara: Hi\nOmar: Hello');
    });
  });

  group('MeetingsCubit', () {
    test('start() sends { url } and adopts the session', () async {
      final api = _FakeMeetingsApi();
      final cubit = MeetingsCubit(api);
      addTearDown(cubit.close);

      await cubit.start('https://meet.example/abc');

      expect(api.lastStartBody, {'url': 'https://meet.example/abc'});
      expect(cubit.state.session?.id, 'm1');
      expect(cubit.state.busy, isFalse);
    });

    test('summarize() and ask() populate their fields', () async {
      final api = _FakeMeetingsApi();
      final cubit = MeetingsCubit(api);
      addTearDown(cubit.close);

      await cubit.start('https://meet.example/abc');
      await cubit.summarize();
      await cubit.ask('what happened?');

      expect(cubit.state.summary, 'the summary');
      expect(cubit.state.chatReply, 'the answer');
      expect(api.lastChatBody, {'message': 'what happened?'});
    });

    test('start() records the error and clears busy on failure', () async {
      final api = _FakeMeetingsApi()..error = Exception('boom');
      final cubit = MeetingsCubit(api);
      addTearDown(cubit.close);

      await cubit.start('https://meet.example/abc');

      expect(cubit.state.session, isNull);
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.error, isNotNull);
    });
  });
}
