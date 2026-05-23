import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/routing/route_names.dart';
import '../../auth/view_model/auth_cubit.dart';
import '../../auth/view_model/auth_state.dart';
import 'share_destination_sheet.dart';
import 'share_intake_service.dart';

/// Listens for incoming Android `ACTION_SEND` / `ACTION_SEND_MULTIPLE`
/// payloads, stashes the files into [ShareIntakeService], and pops the
/// [ShareDestinationSheet] so the user can pick the target chat.
///
/// Wraps the router child in [SaqqarApp] so:
///   * The widget tree above it is built (RepositoryProvider for the
///     intake service, ConversationsCubit for the sheet's list, AuthCubit
///     so we can defer the prompt until the user is actually signed in).
///   * The widget tree below it is the [MaterialApp.router] body, so we
///     can call `context.go(...)` to navigate after the picker resolves.
///
/// No-op outside Android / iOS (e.g. desktop builds) — the plugin's
/// stream stays empty there.
class ShareIntentBootstrap extends StatefulWidget {
  const ShareIntentBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<ShareIntentBootstrap> createState() => _ShareIntentBootstrapState();
}

class _ShareIntentBootstrapState extends State<ShareIntentBootstrap> {
  static const _tag = 'ShareIntentBootstrap';

  StreamSubscription<List<SharedMediaFile>>? _sub;

  /// Latch so two intents arriving inside the destination sheet don't
  /// stack two modal sheets on top of each other. The second one is
  /// dropped — the user's intent is the most recent payload anyway, so
  /// [ShareIntakeService.stage] replaces the staged batch and the open
  /// sheet picks it up via the next pop.
  bool _pickerOpen = false;

  @override
  void initState() {
    super.initState();
    // Cold-start handoff: if the app was launched FROM the share sheet
    // (process wasn't running before), the initial payload arrives via
    // `getInitialMedia` instead of the stream.
    _consumeInitialMedia();
    // Warm-start handoff: the app was already running (foreground or
    // background); the stream fires for every subsequent share.
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _onMedia,
      onError: (Object error, StackTrace st) {
        AppLogger.warn(_tag, 'getMediaStream error',
            error: error, stackTrace: st);
      },
    );
  }

  Future<void> _consumeInitialMedia() async {
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initial.isEmpty) return;
      _onMedia(initial);
      // Reset the platform-side buffer so we don't replay the same files
      // on the next app launch. Returns a Future we deliberately don't
      // await — the reset is a fire-and-forget housekeeping call.
      unawaited(ReceiveSharingIntent.instance.reset());
    } catch (e, st) {
      AppLogger.warn(_tag, 'getInitialMedia failed',
          error: e, stackTrace: st);
    }
  }

  void _onMedia(List<SharedMediaFile> media) {
    if (!mounted) return;
    final files = _toFiles(media);
    if (files.isEmpty) {
      AppLogger.info(_tag, 'received share intent with no resolvable files');
      return;
    }
    // Replace any prior batch — the most recent share is the user's
    // current intent. The service notifies listeners so an already-open
    // sheet sees the new file count on its next rebuild.
    context.read<ShareIntakeService>().stage(files);
    _maybeShowPicker();
  }

  /// Converts the platform-provided records into `dart:io` `File`s the
  /// chat composer + uploader already understand. The plugin gives us a
  /// content:// path on modern Android for some sources (e.g. Photos);
  /// `File(path)` still resolves those correctly when handed back to
  /// `multipart/form-data` because http reads them as opaque streams.
  List<File> _toFiles(List<SharedMediaFile> media) {
    final out = <File>[];
    for (final m in media) {
      final path = m.path;
      if (path.isEmpty) continue;
      out.add(File(path));
    }
    return out;
  }

  Future<void> _maybeShowPicker() async {
    if (_pickerOpen) return;
    // Don't ambush a signed-out user with a chat picker — they'd land in
    // the sign-in flow with files held in memory and no obvious way to
    // recover them. Stash the files and bail; if/when the user signs in
    // we'll re-trigger via the auth listener below.
    final auth = context.read<AuthCubit>().state;
    if (auth.status != AuthStatus.authenticated) return;

    _pickerOpen = true;
    try {
      while (mounted &&
          context.read<ShareIntakeService>().hasStaged) {
        final intake = context.read<ShareIntakeService>();
        final count = intake.staged.length;
        final pick = await ShareDestinationSheet.show(
          context,
          fileCount: count,
        );
        if (!mounted) return;
        if (pick == null) {
          // User dismissed the sheet — drop the staged batch so the next
          // chat they open doesn't suddenly inherit the files.
          context.read<ShareIntakeService>().clear();
          return;
        }
        final targetId = pick.isNew
            ? UiStrings.routeNewConversation
            : pick.id!;
        // Files stay in the intake service; ChatScreen.initState calls
        // `take()` after the route lands so the composer pre-attaches
        // them. We don't drain the service here — the navigate-then-
        // consume handshake matters because Dart's go() returns
        // synchronously before the new route's initState fires.
        if (!mounted) return;
        context.go(RouteNames.chatPath(targetId));
        // Loop: if another share landed while the picker was open, the
        // service.hasStaged check at the top of the loop will catch it
        // on the next iteration and pop a fresh picker.
        // Otherwise we exit cleanly.
      }
    } catch (e, st) {
      AppLogger.warn(_tag, 'destination picker failed',
          error: e, stackTrace: st);
    } finally {
      _pickerOpen = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-attempt the picker the moment the user transitions to
    // authenticated — covers the "shared while signed out, then signed
    // in" path so the staged files don't sit forever in the service.
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (prev, curr) =>
          prev.status != AuthStatus.authenticated &&
          curr.status == AuthStatus.authenticated,
      listener: (context, _) {
        if (context.read<ShareIntakeService>().hasStaged) {
          _maybeShowPicker();
        }
      },
      child: widget.child,
    );
  }
}
