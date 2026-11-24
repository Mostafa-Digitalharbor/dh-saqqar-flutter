// Renders the screens and widgets that could not be walked on the real device
// (the account is a live one): Usage, Meetings, AppLock, the picture grid, the
// download card, the new dialogs and the swipeable viewer. Opt-in like the other
// shot tests — set SHOT_DIR and look at the PNGs.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/billing/data/plan_models.dart';
import 'package:saqqar_app/features/billing/data/saqqar_features.dart';
import 'package:saqqar_app/features/billing/data/usage_api.dart';
import 'package:saqqar_app/features/billing/view/usage_screen.dart';
import 'package:saqqar_app/features/billing/view_model/plan_cubit.dart';
import 'package:saqqar_app/features/billing/view_model/saqqar_features_cubit.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';
import 'package:saqqar_app/features/chat/view/attachment_viewer_screen.dart';
import 'package:saqqar_app/features/chat/widgets/attachment_image_grid.dart';
import 'package:saqqar_app/features/chat/widgets/attachment_open.dart';
import 'package:saqqar_app/features/chat/widgets/voice_preview_card.dart';
import 'package:saqqar_app/features/conversations/widgets/rename_conversation_dialog.dart';
import 'package:saqqar_app/features/meetings/data/meetings_api.dart';
import 'package:saqqar_app/features/meetings/view/meetings_screen.dart';
import 'package:saqqar_app/features/meetings/view_model/meetings_cubit.dart';
import 'package:saqqar_app/features/security/view/app_lock_screen.dart';
import 'package:saqqar_app/shared/fig/fig.dart';
import 'package:saqqar_app/shared/widgets/confirm_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/responsive_harness.dart';
import 'shot_harness.dart';

const _window = UsageWindow(used: 8423, cap: 10000, pct: 84, remaining: 1577);
const _plan = PlanSnapshot(
  slug: 'max-20x',
  name: 'Max 20×',
  exempt: false,
  day: _window,
  week: _window,
  month: _window,
  features: PlanFeatures(
    voice: true,
    postgres: true,
    github: true,
    serverShell: true,
  ),
);

class _PlanCubit extends PlanCubit {
  _PlanCubit() {
    emit(_plan);
  }
}

class _UsageApi extends UsageApi {
  _UsageApi() : super(Dio());
  @override
  Future<UsageSnapshot> fetch() async =>
      const UsageSnapshot(plan: _plan, saqqarFeatures: SaqqarFeatures.unknown);
}

class _MeetingsApi implements MeetingsApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// A 1x1 PNG, enough for a viewer page to have a file to draw.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

ChatAttachment _pic(int i) => ChatAttachment(
  name: 'photo$i.png',
  kind: 'IMAGE',
  size: '1 MB',
  imageUrl: 'https://example.invalid/$i.png',
  downloadUrl: 'https://example.invalid/$i.png',
  serverId: 'id$i',
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('usage', (tester) async {
    await shot(
      tester,
      'v_usage',
      appChrome(
        BlocProvider<PlanCubit>(
          create: (_) => _PlanCubit(),
          child: RepositoryProvider<UsageApi>(
            create: (_) => _UsageApi(),
            child: BlocProvider<SaqqarFeaturesCubit>(
              create: (_) => SaqqarFeaturesCubit(_UsageApi()),
              child: const UsageScreen(),
            ),
          ),
        ),
        prefs,
      ),
    );
  });

  testWidgets('meetings', (tester) async {
    await shot(
      tester,
      'v_meetings',
      appChrome(
        BlocProvider(
          create: (_) => MeetingsCubit(_MeetingsApi()),
          child: const MeetingsScreen(),
        ),
        prefs,
      ),
    );
  });

  testWidgets('app lock', (tester) async {
    await shot(tester, 'v_applock', appChrome(const AppLockScreen(), prefs));
  });

  testWidgets('image grids and download card', (tester) async {
    Widget grid(int n) => Padding(
      padding: const EdgeInsets.all(12),
      child: ChatImageGrid(attachments: [for (var i = 0; i < n; i++) _pic(i)]),
    );
    await shot(
      tester,
      'v_grid',
      Scaffold(
        backgroundColor: const Color(0xFF16181C),
        body: SingleChildScrollView(
          child: Column(
            children: [
              grid(2),
              grid(3),
              grid(4),
              grid(7),
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 180,
                  height: 90,
                  child: Stack(
                    children: [
                      ColoredBox(
                        color: Color(0xFF2A2D35),
                        child: SizedBox.expand(),
                      ),
                      DownloadProgressOverlay(progress: 0.42),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  });

  testWidgets('dialogs', (tester) async {
    await shot(
      tester,
      'v_dialogs',
      Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => ConfirmDialog.show(
                    c,
                    title: 'Delete ACME?',
                    body: 'Its environments and credentials will be removed.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  ),
                  child: const Text('confirm'),
                ),
                TextButton(
                  onPressed: () =>
                      RenameConversationDialog.show(c, initial: 'Sales'),
                  child: const Text('rename'),
                ),
              ],
            ),
          ),
        ),
      ),
      after: (t) async {
        await t.tap(find.text('confirm'));
        await t.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('rename dialog', (tester) async {
    await shot(
      tester,
      'v_rename',
      Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  RenameConversationDialog.show(c, initial: 'Sales'),
              child: const Text('rename'),
            ),
          ),
        ),
      ),
      after: (t) async {
        await t.tap(find.text('rename'));
        await t.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('dark dialog', (tester) async {
    await shot(
      tester,
      'v_dark_dialog',
      FigDarkSurface(
        child: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => ConfirmDialog.show(
                  c,
                  title: 'Delete ACME?',
                  body: 'Its environments and credentials will be removed.',
                  confirmLabel: 'Delete',
                  destructive: true,
                ),
                child: const Text('confirm'),
              ),
            ),
          ),
        ),
      ),
      after: (t) async {
        await t.tap(find.text('confirm'));
        await t.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('voice sending card', (tester) async {
    await shot(
      tester,
      'v_voice_sending',
      Scaffold(
        backgroundColor: const Color(0xFF0B1B4A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DownloadingFileCard(
                  attachment: const ChatAttachment(
                    name: 'Review notes.pdf',
                    kind: 'PDF',
                    size: '214 KB',
                  ),
                  progress: 0.42,
                  onCancel: () {},
                ),
                const SizedBox(height: 24),
                VoicePreviewCard(
                  file: File('take.m4a'),
                  length: const Duration(seconds: 24),
                  sending: true,
                  progress: 0.62,
                  onSend: () {},
                  onCancel: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  });

  testWidgets('gallery viewer', (tester) async {
    if (Platform.environment['SHOT_DIR'] == null) return;
    final dir = Directory.systemTemp.createTempSync('verify');
    final file = File('${dir.path}/b.png')..writeAsBytesSync(_png);
    await shot(
      tester,
      'v_gallery',
      AttachmentViewerScreen(
        file: file,
        name: 'photo1.png',
        gallery: const [
          ViewerImage(
            name: 'photo0.png',
            subtitle: 'IMAGE · 1 MB',
            url: 'https://example.invalid/0.png',
          ),
          ViewerImage(
            name: 'photo1.png',
            subtitle: 'IMAGE · 1 MB',
            url: 'https://example.invalid/1.png',
          ),
          ViewerImage(
            name: 'photo2.png',
            subtitle: 'IMAGE · 1 MB',
            url: 'https://example.invalid/2.png',
          ),
        ],
        galleryIndex: 1,
      ),
    );
  });
}
