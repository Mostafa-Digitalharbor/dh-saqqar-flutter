// Screenshot checks for the composer states and the fullscreen image viewer
// (figma-design / "Chats - Mobile Recording", "Chats - Mobile Sent1",
// "Fullscreen image viewer"). Only renders when SHOT_DIR is set.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';
import 'package:saqqar_app/features/chat/view/attachment_viewer_screen.dart';
import 'package:saqqar_app/features/chat/widgets/chat_composer.dart';

import 'shot_harness.dart';

// A 1x1 PNG so the viewer has a decodable local image.
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
  0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, 0xB0, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Widget _composer({bool recording = false, bool transcribing = false,
    List<ChatAttachment> attachments = const []}) {
  return Theme(
    data: AppTheme.dark(const Locale('en')),
    child: Scaffold(
      backgroundColor: const Color(0xFF05070D),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: ChatComposer(
          controller: TextEditingController(),
          attachments: attachments,
          onAttach: () {},
          onTools: () {},
          onRemoveAttachment: (_) {},
          onClearAttachments: () {},
          onPreviewAttachment: (_) {},
          onSend: () {},
          taskPrep: false,
          autoApprove: false,
          onTaskPrepChanged: (_) {},
          onAutoApproveChanged: (_) {},
          onStartRecording: () {},
          onStopRecording: () {},
          onDiscardRecording: () {},
          recording: recording,
          transcribing: transcribing,
          recordingElapsed: const Duration(seconds: 12),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('composer recording', (tester) async {
    await shot(tester, 'composer_recording', _composer(recording: true));
  });

  testWidgets('composer staged files', (tester) async {
    await shot(
      tester,
      'composer_staged',
      _composer(attachments: const [
        ChatAttachment(name: 'site-entry.jpg', kind: 'JPG', size: '2.4 MB'),
        ChatAttachment(name: 'lobby.jpg', kind: 'JPG', size: '1.8 MB'),
        ChatAttachment(name: 'Site brief.pdf', kind: 'PDF', size: '840 KB'),
        ChatAttachment(name: 'Scope.docx', kind: 'DOCX', size: '124 KB'),
      ]),
    );
  });

  testWidgets('image viewer', (tester) async {
    if (Platform.environment['SHOT_DIR'] == null) return;
    final dir = Directory.systemTemp.createTempSync('viewer');
    final f = File('${dir.path}/site-entry.jpg')..writeAsBytesSync(_png);
    addTearDown(() { try { dir.deleteSync(recursive: true); } catch (_) {} });
    await shot(
      tester,
      'image_viewer',
      AttachmentViewerScreen(
        file: f,
        name: 'site-entry.jpg',
        kindLabel: 'You',
        sizeLabel: 'Today, 09:40 · 2.4 MB',
      ),
    );
  });
}

