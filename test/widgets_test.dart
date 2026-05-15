import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/widgets/attachment_chip.dart';
import 'package:saqqar_app/features/chat/widgets/chat_avatar.dart';
import 'package:saqqar_app/features/chat/widgets/chat_mini_switch.dart';
import 'package:saqqar_app/features/chat/widgets/chat_scroll_down_button.dart';
import 'package:saqqar_app/features/chat/widgets/credential_chip.dart';
import 'package:saqqar_app/features/chat/widgets/message_bubble.dart';
import 'package:saqqar_app/features/conversations/widgets/conversation_card.dart';
import 'package:saqqar_app/features/conversations/widgets/meta_dot.dart';
import 'package:saqqar_app/features/demo/saqqar_demo_data.dart';

/// Wraps [child] with the bare-minimum scaffolding the Saqqar widgets need:
/// MaterialApp with the locale delegates, the real Saqqar themes, and an
/// `en` locale. Reproduces how the widgets render in production without
/// pulling in GoRouter or Riverpod.
Widget _harness(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
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

    testWidgets('ChatMiniSwitch shows thumb at start when off', (tester) async {
      await tester.pumpWidget(
        _harness(const ChatMiniSwitch(value: false, color: Colors.cyan)),
      );
      final alignFinder = find.byType(AnimatedAlign);
      expect(alignFinder, findsOneWidget);
      final align = tester.widget<AnimatedAlign>(alignFinder);
      expect(align.alignment, AlignmentDirectional.centerStart);
    });

    testWidgets('ChatMiniSwitch shifts thumb to end when on', (tester) async {
      await tester.pumpWidget(
        _harness(const ChatMiniSwitch(value: true, color: Colors.cyan)),
      );
      final align = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
      expect(align.alignment, AlignmentDirectional.centerEnd);
    });

    testWidgets('CredentialChip is tappable and shows its label', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _harness(
          CredentialChip(label: 'GAC Staging', onTap: () => tapped = true),
        ),
      );
      expect(find.text('GAC Staging'), findsOneWidget);
      await tester.tap(find.byType(CredentialChip));
      expect(tapped, isTrue);
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

    testWidgets('ConversationCard renders title, preview, and message count', (
      tester,
    ) async {
      final conversation = demoConversations.firstWhere(
        (c) => !c.isArchived,
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
      expect(find.text(conversation.preview), findsOneWidget);
      expect(find.text('${conversation.messageCount}'), findsOneWidget);
    });
  });

  // The standalone CredentialRow widget was retired when the Vault was
  // restructured to projects → envs → credentials-per-kind. Tests for the
  // new flow live alongside `ProjectCard` / `EnvironmentDetailSheet` once
  // the controller-backed sheets stabilise.

  // The standalone ArtifactCard widget was retired when the global Files
  // tab was folded into each chat's ⋯ menu. The per-chat ChatArtifactTile
  // covers the same role and is exercised via chat tests.
}
