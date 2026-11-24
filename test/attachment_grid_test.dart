// The image grid in a message bubble, and the download shown on its tiles.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';
import 'package:saqqar_app/features/chat/widgets/attachment_image_grid.dart';
import 'package:saqqar_app/features/chat/widgets/attachment_open.dart';

ChatAttachment _pic(int i) => ChatAttachment(
  name: 'photo$i.png',
  kind: 'IMAGE',
  size: '1 MB',
  imageUrl: 'https://example.invalid/$i.png',
  downloadUrl: 'https://example.invalid/$i.png',
  serverId: 'id$i',
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('four pictures make four tiles and no "+N"', (tester) async {
    await _pump(
      tester,
      ChatImageGrid(attachments: [for (var i = 0; i < 4; i++) _pic(i)]),
    );
    expect(find.byType(AttachmentOpenTarget), findsNWidgets(4));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('past four the last tile counts the rest', (tester) async {
    await _pump(
      tester,
      ChatImageGrid(attachments: [for (var i = 0; i < 7; i++) _pic(i)]),
    );
    expect(find.byType(AttachmentOpenTarget), findsNWidgets(4));
    expect(find.text('+3'), findsOneWidget);
  });

  testWidgets('only real pictures are accepted as tiles', (tester) async {
    expect(ChatImageGrid.accepts(_pic(1)), isTrue);
    expect(
      ChatImageGrid.accepts(
        const ChatAttachment(name: 'a.pdf', kind: 'PDF', size: '1 MB'),
      ),
      isFalse,
    );
    expect(
      ChatImageGrid.accepts(
        const ChatAttachment(name: 'a.png', kind: 'IMAGE', size: '1 MB'),
      ),
      isFalse,
      reason: 'no preview URL means nothing to draw',
    );
  });

  testWidgets('the overlay shows the percentage, or a bare bar when unknown', (
    tester,
  ) async {
    await _pump(
      tester,
      const SizedBox(
        height: 80,
        width: 160,
        child: DownloadProgressOverlay(progress: 0.42),
      ),
    );
    expect(find.text('42%'), findsOneWidget);

    await _pump(
      tester,
      const SizedBox(
        height: 80,
        width: 160,
        child: DownloadProgressOverlay(progress: indeterminateProgress),
      ),
    );
    expect(find.textContaining('%'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
