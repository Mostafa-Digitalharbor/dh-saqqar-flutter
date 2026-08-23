import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/format/byte_size.dart';
import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/i18n/view_model/locale_cubit.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/view_model/theme_cubit.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/marquee_text.dart';
import '../data/chat_view_models.dart';
import '../data/approval_adapter.dart';
import '../../inbox/data/approval_models.dart' as inbox_api;
import '../../inbox/data/approvals_api.dart';
import '../../inbox/data/artifact_downloader.dart';
import '../../inbox/data/artifact_models.dart' as inbox_api;
import '../../inbox/view/artifact_details_sheet.dart';
import '../view/attachment_viewer_screen.dart';
import '../view_model/chat_cubit.dart';
import 'chat_approval_card.dart';
import 'chat_artifact_tile.dart';

/// Brief §4.3 — rail drawer mounted on `Scaffold.endDrawer` of the chat
/// screen. Opens from the end side via the AppBar bell.
///
/// Carries:
///
///   • Theme toggle + Language toggle at the top
///   • Tabbed body: Approvals · Artifacts · Activity
///
/// Scoped per-conversation — every list shown here belongs to THIS
/// chat. Approvals + artifacts come from the live snapshot
/// (`ChatCubit.state.data.dataOrNull`), not from any local cache.
///
/// New chats (sentinel id) render empty states for everything — there's
/// no server-side conversation to poll yet.
class ChatRailDrawer extends StatefulWidget {
  const ChatRailDrawer({
    super.key,
    required this.conversationId,
    required this.onClose,
  });

  final String conversationId;

  /// Fired when the user taps the X button. Same contract as
  /// [ChatSidebarDrawer.onClose] — the drawer is a Stack overlay, not
  /// a route, so closing means flipping the chat screen's local
  /// `_railOpen` flag (which triggers the slide-out animation).
  final VoidCallback onClose;

  @override
  State<ChatRailDrawer> createState() => _ChatRailDrawerState();
}

class _ChatRailDrawerState extends State<ChatRailDrawer>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  bool get _isNewChat =>
      widget.conversationId == UiStrings.newConversationId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _toast(String message) {
    AppToast.show(context, message: message);
  }

  /// Sends the decide call against the real `/approvals/<id>/decision/`
  /// endpoint, then refreshes the snapshot so the approval drops out
  /// of the pending list on screen.
  Future<void> _decideApproval({
    required inbox_api.Approval approval,
    required bool approved,
  }) async {
    final tr = context.tr;
    try {
      await context.read<ApprovalsApi>().decide(
            id: approval.id,
            approved: approved,
            // Without this the backend 400s every destructive delete. The
            // rail drawer is the second surface that resolves approvals, and
            // a fix applied only to the chat stream would leave this one
            // broken in exactly the way the outage described.
            confirmPhrase: approved ? approval.confirmPhrase : null,
          );
      if (!mounted) return;
      // Snapshot polling will eventually pick this up too, but firing a
      // refresh now means the card disappears the same frame as the
      // success toast — better perceived responsiveness.
      await context.read<ChatCubit>().refresh();
      if (!mounted) return;
      _toast(
        approved ? tr.approvalGrantedExecuting : tr.approvalRejected,
      );
    } catch (e) {
      if (!mounted) return;
      // Surface the real, localized cause (e.g. "No internet connection",
      // "This action needs approval you don't have") instead of a generic
      // "something went wrong".
      AppToast.show(
        context,
        title: approved ? tr.approve : tr.reject,
        message: ApiErrorMapper.message(context, e),
        variant: ToastVariant.error,
      );
    }
  }

  /// Downloads the artifact (or reuses the cached copy under the app's
  /// documents directory) and opens it in Saqqar's own viewer rather than
  /// handing it to Adobe / Word / the gallery. Surfaces a "Downloading…"
  /// toast on first fetch and a localized error if the fetch fails; the
  /// viewer itself owns the "open in another app" escape hatch.
  Future<void> _openArtifact(inbox_api.Artifact artifact) async {
    final tr = context.tr;
    final downloader = ArtifactDownloader(context.read<Dio>());
    AppToast.show(
      context,
      message: tr.downloadingArtifact,
      variant: ToastVariant.info,
    );
    final result = await downloader.fetch(
      url: artifact.absoluteUrl,
      cacheKey: artifact.id,
      originalName: artifact.name,
      kindHint: artifact.kind,
    );
    if (!mounted) return;
    switch (result) {
      case ArtifactFetchSuccess(:final file):
        await AttachmentViewerScreen.open(
          context,
          file: file,
          name: artifact.name,
          kindLabel: artifact.kind.toUpperCase(),
        );
      case ArtifactFetchFailed(:final statusCode):
        AppToast.show(
          context,
          message: tr.artifactDownloadMessage(statusCode),
          variant: ToastVariant.error,
        );
    }
  }

  /// Long-press on an artifact → its detail/metadata sheet (API §4.4).
  /// Fetches `GET /artifacts/<id>/` inside the sheet.
  void _showArtifactDetails(inbox_api.Artifact artifact) {
    showArtifactDetailsSheet(context, id: artifact.id, name: artifact.name);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    // For new chats there's no ChatCubit in the tree — short-circuit
    // and render empty lists so we don't crash on a missing provider.
    final snapshot = _isNewChat
        ? null
        : context.watch<ChatCubit>().state.data.dataOrNull;
    final pending = snapshot?.approvals
            .where((a) => a.status == inbox_api.ApprovalStatus.pending)
            .toList() ??
        const <inbox_api.Approval>[];
    final artifacts = snapshot?.artifacts ?? const <inbox_api.Artifact>[];

    return Material(
      color: s.surface,
      elevation: AppElevations.drawer,
      child: SafeArea(
        child: Column(
          children: [
            // ── Top utility row: theme + language toggles + close ────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s12,
                AppSpacing.s12,
                AppSpacing.s12,
                AppSpacing.s8,
              ),
              child: Row(
                children: [
                  _ThemeToggleButton(),
                  const SizedBox(width: AppSpacing.s8),
                  _LanguageToggleButton(),
                  const Spacer(),
                  IconButton(
                    tooltip: context.tr.close,
                    icon: Icon(AppIcons.close, color: s.muted, size: AppIconSizes.action),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s4,
                AppSpacing.s16,
                AppSpacing.s8,
              ),
              child: Text(
                context.tr.inboxTitle,
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            // ── Tab bar ──────────────────────────────────────────────
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: s.cardBorder)),
              ),
              child: TabBar(
                controller: _tab,
                isScrollable: false,
                labelColor: s.brandCyan,
                unselectedLabelColor: s.muted,
                indicatorColor: s.brandCyan,
                // Indicator spans the full tab cell, not just the label
                // — the marquee labels can scroll inside their slot, so
                // anchoring the indicator to the label would jitter it.
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: context.text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                // Each tab wraps its label in a MarqueeText so the full
                // Arabic phrase ("الموافقات المعلقة"، "نشاط الخادم"...)
                // scrolls into view across narrow slots instead of being
                // truncated to its first few characters.
                tabs: [
                  _MarqueeTab(
                    label: _tabLabel(
                      context.tr.pendingApprovals,
                      pending.length,
                    ),
                  ),
                  _MarqueeTab(
                    label: _tabLabel(context.tr.artifacts, artifacts.length),
                  ),
                  // Server activity — no backend endpoint exists yet
                  // (would derive from tool messages where tool_name ==
                  // 'run_server_command'). Shows an empty state today.
                  _MarqueeTab(label: context.tr.serverActivity),
                ],
              ),
            ),
            // ── Tab content ──────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _ApprovalsTab(
                    approvals: pending,
                    onApprove: (a) =>
                        _decideApproval(approval: a, approved: true),
                    onReject: (a) =>
                        _decideApproval(approval: a, approved: false),
                  ),
                  _ArtifactsTab(
                    artifacts: artifacts,
                    onOpen: _openArtifact,
                    onDetails: _showArtifactDetails,
                  ),
                  // Activity tab is a placeholder until the backend
                  // surfaces a server-activity feed.
                  _EmptyTab(
                    icon: AppIcons.terminal,
                    title: context.tr.noServerActivity,
                    body: context.tr.serverActivity,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tabLabel(String label, int count) =>
      count == 0 ? label : '$label ($count)';
}

// ─────────────────────────────────────────────────────────────────────────
// Bridge: real Artifact → ChatArtifact so the existing card widgets keep
// working until they're migrated. One-way translation at the widget
// boundary, isolated from the live data path.
//
// The APPROVAL half of this bridge moved to `data/approval_adapter.dart`.
// It lived here as a private copy of the chat screen's, over the same input
// type, and the two had drifted on the one field that matters most — the
// title the user reads before approving a write to their Odoo.
// ─────────────────────────────────────────────────────────────────────────

ChatArtifact _adaptApiArtifact(
  BuildContext context,
  inbox_api.Artifact a,
  AppStrings tr,
) {
  final bytes = a.sizeBytes;
  final created = a.createdAt;
  return ChatArtifact(
    id: a.id,
    name: a.name,
    kind: a.kind.toUpperCase(),
    // Through `humanBytes` so the unit scales and localizes. Rendering
    // `'${a.sizeKb} KB'` here showed a 40 MB addon bundle as "40960 KB".
    size: bytes == null ? '' : humanBytes(bytes, tr),
    conversation: a.conversation?.title ?? '',
    conversationId: a.conversation?.id ?? '',
    // The model has carried `createdAt` all along; hardcoding '' here is what
    // made every row's meta line end in a dangling separator.
    createdLabel: created == null ? '' : AppDateFormat.date(context, created),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Tabs
// ─────────────────────────────────────────────────────────────────────────

/// [Tab] wrapper that swaps the plain `Text` for a [MarqueeText] so the
/// label scrolls into view when it's longer than the tab cell. Default
/// tab height is preserved (Material's standard 46 dp) so the bar's
/// vertical rhythm doesn't change.
///
/// `alwaysScroll: true` so the three tab headers all share the same
/// motion — even the shorter "نشاط الخادم" scrolls, keeping the row
/// visually in sync rather than only marqueeing the longest one.
class _MarqueeTab extends StatelessWidget {
  const _MarqueeTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: SizedBox(
        width: double.infinity,
        child: MarqueeText(
          text: label,
          textAlign: TextAlign.center,
          alwaysScroll: true,
        ),
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final mode = context.watch<ThemeCubit>().state;
    final isDark = mode.materialMode == ThemeMode.dark;
    return IconButton(
      tooltip: context.tr.toggleTheme,
      icon: Icon(
        isDark ? AppIcons.moon : AppIcons.sun,
        color: s.text,
      ),
      onPressed: () => context.read<ThemeCubit>().toggle(),
    );
  }
}

class _LanguageToggleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final locale = context.watch<LocaleCubit>().state;
    final code = locale?.languageCode ?? UiStrings.localeEnglishCode;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.read<LocaleCubit>().toggleEnglishArabic(),
        child: Container(
          width: AppBoxSizes.railButton,
          height: AppBoxSizes.railButton,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: s.cardBorder),
          ),
          child: Text(
            code == UiStrings.localeArabicCode
                ? UiStrings.localeEnglishLabel
                : UiStrings.localeArabicLabel,
            style: context.text.labelMedium?.copyWith(
              color: s.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ApprovalsTab extends StatelessWidget {
  const _ApprovalsTab({
    required this.approvals,
    required this.onApprove,
    required this.onReject,
  });

  final List<inbox_api.Approval> approvals;

  /// Take the whole approval, not just its id: a destructive delete has to
  /// carry its confirm phrase into the decision POST, and an id cannot.
  final ValueChanged<inbox_api.Approval> onApprove;
  final ValueChanged<inbox_api.Approval> onReject;

  @override
  Widget build(BuildContext context) {
    if (approvals.isEmpty) {
      return _EmptyTab(
        icon: AppIcons.shield,
        title: context.tr.noPendingApprovalsTitle,
        body: context.tr.noPendingApprovalsBody,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s14,
        AppSpacing.s14,
        AppSpacing.s14,
        AppSpacing.s16,
      ),
      cacheExtent: AppScrollTuning.cacheExtent,
      itemCount: approvals.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s10),
      itemBuilder: (_, i) => ChatApprovalCard(
        approval: adaptApiApproval(approvals[i], context.tr),
        onApprove: () => onApprove(approvals[i]),
        onReject: () => onReject(approvals[i]),
      ),
    );
  }
}

class _ArtifactsTab extends StatelessWidget {
  const _ArtifactsTab({
    required this.artifacts,
    required this.onOpen,
    required this.onDetails,
  });

  final List<inbox_api.Artifact> artifacts;
  final void Function(inbox_api.Artifact) onOpen;
  final void Function(inbox_api.Artifact) onDetails;

  @override
  Widget build(BuildContext context) {
    if (artifacts.isEmpty) {
      return _EmptyTab(
        icon: AppIcons.file,
        title: context.tr.noExportsTitle,
        body: context.tr.noExportsBody,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s14,
        AppSpacing.s14,
        AppSpacing.s14,
        AppSpacing.s16,
      ),
      cacheExtent: AppScrollTuning.cacheExtent,
      itemCount: artifacts.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s10),
      itemBuilder: (context, i) => ChatArtifactTile(
        artifact: _adaptApiArtifact(context, artifacts[i], context.tr),
        onOpen: () => onOpen(artifacts[i]),
        // Long-press → artifact detail metadata (API §4.4). Additive; the
        // tap still downloads/opens as before.
        onLongPress: () => onDetails(artifacts[i]),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    // Scroll-only-when-it-has-to, the same treatment `UpdateRequiredScreen`
    // and the lock screen needed. The 56 px glyph, its two labels and 48 px
    // of padding come to ~210 px, and the rail's tab body on a 568×320
    // landscape phone is well under that — it overflowed by 71 px. The
    // `minHeight` keeps the content centred whenever there IS room, so
    // nothing changes in portrait.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: AppControlSizes.emptyGlyphBox,
                    height: AppControlSizes.emptyGlyphBox,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.surface2
                          .withValues(alpha: context.alpha(AppAlphaPairs.panel)),
                      borderRadius: AppRadius.buttonR,
                      border: Border.all(color: s.cardBorder),
                    ),
                    child: Icon(icon, color: s.muted, size: AppIconSizes.back),
                  ),
                  const SizedBox(height: AppSpacing.s14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(color: s.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
