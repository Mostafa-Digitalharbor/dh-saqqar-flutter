// The "Voice message · Preview" card: listen first, then Send or Cancel.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:saqqar_app/features/chat/widgets/voice_preview_card.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'support/responsive_harness.dart';

class _FakePlayback implements VoicePlayback {
  final _playing = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  int plays = 0;
  int pauses = 0;
  bool disposed = false;

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Future<void> play(File file) async {
    plays++;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    pauses++;
    _playing.add(false);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _playing.close();
    await _position.close();
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('shows the take, plays and pauses it, and Send / Cancel fire',
      (tester) async {
    final playback = _FakePlayback();
    var sent = 0;
    var cancelled = 0;
    await pumpOnce(
      tester,
      Material(
        color: Colors.black,
        child: VoicePreviewCard(
          file: File('take.m4a'),
          length: const Duration(seconds: 24),
          sending: false,
          playback: playback,
          onSend: () => sent++,
          onCancel: () => cancelled++,
        ),
      ),
      prefs: prefs,
    );

    expect(find.text('Voice message'), findsOneWidget);
    expect(find.text('00:24'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.play));
    await tester.pump();
    expect(playback.plays, 1);
    expect(find.byIcon(LucideIcons.pause), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.pause));
    await tester.pump();
    expect(playback.pauses, 1);

    await tester.tap(find.text('Send'));
    await tester.tap(find.text('Cancel'));
    expect([sent, cancelled], [1, 1]);

    await tester.pumpWidget(const SizedBox());
    expect(playback.disposed, isTrue);
  });

  testWidgets('while sending, nothing on the card can be tapped',
      (tester) async {
    var sent = 0;
    var cancelled = 0;
    await pumpOnce(
      tester,
      Material(
        color: Colors.black,
        child: VoicePreviewCard(
          file: File('take.m4a'),
          length: const Duration(seconds: 3),
          sending: true,
          playback: _FakePlayback(),
          onSend: () => sent++,
          onCancel: () => cancelled++,
        ),
      ),
      prefs: prefs,
    );

    // The sending card is the Figma "Sending..." one: progress, no buttons.
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Send'), findsNothing);
    expect(find.text('Sending...'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect([sent, cancelled], [0, 0]);
  });
}
