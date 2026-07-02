import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/route_names.dart';
import '../../auth/view_model/auth_cubit.dart';
import '../../auth/view_model/auth_state.dart';
import 'share_destination_sheet.dart';
import 'share_intake_service.dart';

/// Listens for incoming Android `ACTION_SEND` / `ACTION_SEND_MULTIPLE`
/// payloads, stashes the files into [ShareIntakeService], and **renders
/// the destination picker inline as an overlay** on top of whatever
/// route is currently active.
///
/// The picker is no longer routed or pushed as a separate page — earlier
/// revisions (bottom sheet, then fullscreen `MaterialPageRoute`) all let
/// the previously-open chat flash through the brief window between the
/// share intent arriving and the picker mounting. Rendering the picker
/// as a child of a [Stack] above `widget.child` means the previous
/// route is covered on the SAME frame the service fires `notifyListeners`,
/// which makes the "files-staged → picker-visible" handoff atomic.
///
/// Lives at the [MaterialApp.router] builder layer so:
///   * It can call `context.go(...)` to navigate after the user picks.
///   * Its overlay covers everything the router renders below it,
///     including the chat screen.
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
      // on the next app launch. Fire-and-forget — the reset is a
      // housekeeping call we don't gate the flow on.
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
    // Just stage the files. The overlay in our `build` is watching the
    // service via `context.watch<ShareIntakeService>()` and will render
    // the picker on the next frame — no separate navigation, no push,
    // no async race. Replacement (not append) is intentional: if two
    // shares land back-to-back, the most recent one is the user's
    // current intent.
    context.read<ShareIntakeService>().stage(files);
  }

  /// Converts the platform-provided records into `dart:io` `File`s the
  /// chat composer + uploader already understand. The plugin gives us a
  /// content:// path on modern Android for some sources (e.g. Photos);
  /// `File(path)` still resolves those correctly when handed back to
  /// `multipart/form-data` because http reads them as opaque streams.
  List<File> _toFiles(List<SharedMediaFile> media) {
    final out = <File>[];
    for (final m in media) {
      // Skip non-file payloads. Now that the Android filter accepts `text/*`
      // (so WhatsApp documents with a text-ish MIME show Saqqar), a shared
      // plain-text MESSAGE or link can also reach us — those arrive with
      // `type == text`/`url` and put the CONTENT (not a path) in `m.path`,
      // so `File(m.path)` would point at a file that doesn't exist. Only
      // real file/image/video payloads carry a usable path.
      if (m.type == SharedMediaType.text || m.type == SharedMediaType.url) {
        continue;
      }
      final path = m.path;
      if (path.isEmpty) continue;
      out.add(File(path));
    }
    return out;
  }

  /// Tapped on Cancel inside the picker. Drops the staged batch and
  /// clears the overlay.
  void _cancel() {
    if (!mounted) return;
    context.read<ShareIntakeService>().clear();
  }

  /// Tapped on a destination row (new chat or an existing one) inside
  /// the picker. Commits the batch via `deliverTo` so the destination
  /// chat picks it up via its own `context.watch` consumer, then
  /// navigates to the chat route. The overlay disappears automatically
  /// on the next build because `take()` inside the chat screen's
  /// consume drains the service.
  ///
  /// Uses the global [appRouter] reference instead of `context.go(...)`
  /// because the bootstrap is mounted inside `MaterialApp.router`'s
  /// `builder:` — that context is ABOVE the `InheritedGoRouter`, so
  /// `GoRouter.of(context)` throws "No GoRouter found in context".
  void _pickDestination(ShareDestination dest) {
    if (!mounted) return;
    final targetId =
        dest.isNew ? UiStrings.routeNewConversation : dest.id!;
    context.read<ShareIntakeService>().deliverTo(targetId);
    appRouter?.go(RouteNames.chatPath(targetId));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      // No-op listener; the overlay logic below already reacts to the
      // service. Kept the BlocListener around solely to retain the
      // historical "re-evaluate share picker on auth flip" hook — when
      // the user finally signs in, the service still has the staged
      // files and the overlay will appear via the existing watch.
      listenWhen: (prev, curr) =>
          prev.status != AuthStatus.authenticated &&
          curr.status == AuthStatus.authenticated,
      listener: (_, __) {},
      child: Stack(
        children: [
          widget.child,
          // The overlay is a direct child of the Stack so it covers
          // EVERYTHING the router renders — chat screen, conversations
          // list, vault, account, all of them. Visible only when there's
          // a staged batch that hasn't been delivered yet AND the user
          // is signed in (we don't ambush a signed-out user with a
          // chat picker; the staged batch sits in the service until
          // they auth, then the BlocListener-driven rebuild surfaces
          // the overlay).
          _SharePickerOverlay(
            onCancel: _cancel,
            onPick: _pickDestination,
          ),
        ],
      ),
    );
  }
}

/// Listens to the share intake service and renders the destination
/// picker on top of whatever's behind it when files are staged AND the
/// user is authenticated AND no destination has been committed yet.
///
/// Renders `SizedBox.shrink()` in every other case so it doesn't steal
/// gestures from the underlying app.
class _SharePickerOverlay extends StatelessWidget {
  const _SharePickerOverlay({
    required this.onCancel,
    required this.onPick,
  });

  final VoidCallback onCancel;
  final ValueChanged<ShareDestination> onPick;

  @override
  Widget build(BuildContext context) {
    final intake = context.watch<ShareIntakeService>();
    final auth = context.watch<AuthCubit>().state;
    final shouldShow = intake.hasStaged &&
        intake.targetChatId == null &&
        auth.status == AuthStatus.authenticated;
    if (!shouldShow) return const SizedBox.shrink();
    return Positioned.fill(
      // Wrap in an `Overlay` so descendants that depend on one
      // (`Tooltip`, `MenuAnchor`, `showMenu`, etc.) find an ancestor.
      // Our parent in the widget tree is `MaterialApp.router`'s
      // `builder:` — that level is ABOVE the Navigator the router
      // installs, so the Navigator's built-in Overlay isn't visible
      // to us. Without this wrapper the close-button Tooltip throws
      // "No Overlay widget found" on first render.
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (overlayContext) => Material(
              // Opaque background so the underlying chat / vault /
              // whatever is fully hidden — no scrim peek-through.
              color: Theme.of(overlayContext).scaffoldBackgroundColor,
              child: ShareDestinationOverlayContent(
                fileCount: intake.staged.length,
                onCancel: onCancel,
                onPick: onPick,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
