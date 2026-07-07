import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/i18n/view_model/locale_cubit.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/view_model/theme_cubit.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/marquee_text.dart';
import '../../demo/saqqar_demo_data.dart';
import '../../inbox/data/approval_models.dart' as inbox_api;
import '../../inbox/data/approvals_api.dart';
import '../../inbox/data/artifact_downloader.dart';
import '../../inbox/data/artifact_models.dart' as inbox_api;
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
    required String id,
    required bool approved,
  }) async {
    final tr = context.tr;
    try {
      await context.read<ApprovalsApi>().decide(id: id, approved: approved);
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
  /// documents directory) and hands it off to the OS's matching
  /// viewer — Adobe / Drive for PDF, Word for DOCX, Excel for XLSX,
  /// gallery for images, etc. Surfaces a "Downloading…" toast on
  /// first fetch and a localized error if either step fails.
  Future<void> _openArtifact(inbox_api.Artifact artifact) async {
    final tr = context.tr;
    final downloader = ArtifactDownloader(context.read<Dio>());
    AppToast.show(
      context,
      message: tr.downloadingArtifact,
      variant: ToastVariant.info,
    );
    final result = await downloader.downloadAndOpen(artifact);
    if (!mounted) return;
    switch (result) {
      case ArtifactOpenSuccess():
        // OS now owns the viewer — no extra toast, the file's on
        // screen.
        break;
      case ArtifactOpenNoViewer():
        AppToast.show(
          context,
          message: tr.artifactNoViewer,
          variant: ToastVariant.error,
        );
      case ArtifactOpenFailed():
        AppToast.show(
          context,
          message: tr.artifactOpenFailed,
          variant: ToastVariant.error,
        );
      case ArtifactDownloadFailed(:final statusCode):
        AppToast.show(
          context,
          message: tr.artifactDownloadMessage(statusCode),
          variant: ToastVariant.error,
        );
    }
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
      elevation: 8,
      child: SafeArea(
        child: Column(
          children: [
            // ── Top utility row: theme + language toggles + close ────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  _ThemeToggleButton(),
                  const SizedBox(width: 8),
                  _LanguageToggleButton(),
                  const Spacer(),
                  IconButton(
                    tooltip: context.tr.close,
                    icon: Icon(AppIcons.close, color: s.muted, size: 20),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                    onApprove: (id) =>
                        _decideApproval(id: id, approved: true),
                    onReject: (id) =>
                        _decideApproval(id: id, approved: false),
                  ),
                  _ArtifactsTab(
                    artifacts: artifacts,
                    onOpen: _openArtifact,
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
// Bridge: real Approval / Artifact → DemoApproval / DemoArtifact so the
// existing card widgets keep working until they're migrated. Same pattern
// as the chat screen's `_adaptApiMessage` — one-way translation at the
// widget boundary, isolated from the live data path.
// ─────────────────────────────────────────────────────────────────────────

DemoApproval _adaptApiApproval(inbox_api.Approval a, AppStrings tr) {
  return DemoApproval(
    id: a.id,
    // Localized via the shared approval-title table (same one the inline
    // chat approval card uses) so Arabic users don't see English titles.
    title: tr.approvalActionTitle(a.actionType.wire),
    prompt: a.prompt,
    actionType: a.actionType.wire,
    risk: _riskFor(a.actionType),
    status: switch (a.status) {
      inbox_api.ApprovalStatus.pending => DemoApprovalStatus.pending,
      inbox_api.ApprovalStatus.approved => DemoApprovalStatus.approved,
      inbox_api.ApprovalStatus.rejected => DemoApprovalStatus.rejected,
    },
    payload: {
      for (final entry in a.payload.entries) entry.key: entry.value.toString(),
    },
  );
}

String _riskFor(inbox_api.ApprovalActionType t) {
  // High-risk by default; only explicit reads are low. The card uses
  // this as a coloured chip — the bias matches the web's behavior.
  return switch (t) {
    inbox_api.ApprovalActionType.credentialStorage => 'medium',
    inbox_api.ApprovalActionType.credentialUsage => 'medium',
    inbox_api.ApprovalActionType.reportExport => 'low',
    _ => 'high',
  };
}

DemoArtifact _adaptApiArtifact(inbox_api.Artifact a) {
  return DemoArtifact(
    id: a.id,
    name: a.name,
    kind: a.kind.toUpperCase(),
    size: a.sizeKb == null ? '' : '${a.sizeKb} KB',
    conversation: a.conversation?.title ?? '',
    conversationId: a.conversation?.id ?? '',
    createdLabel: '',
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
        isDark ? Icons.dark_mode : Icons.light_mode,
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
    final code = locale?.languageCode ?? 'en';
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.read<LocaleCubit>().toggleEnglishArabic(),
        child: Container(
          width: 40,
          height: 40,
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
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;

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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      cacheExtent: 1500,
      itemCount: approvals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => ChatApprovalCard(
        approval: _adaptApiApproval(approvals[i], context.tr),
        onApprove: () => onApprove(approvals[i].id),
        onReject: () => onReject(approvals[i].id),
      ),
    );
  }
}

class _ArtifactsTab extends StatelessWidget {
  const _ArtifactsTab({required this.artifacts, required this.onOpen});

  final List<inbox_api.Artifact> artifacts;
  final void Function(inbox_api.Artifact) onOpen;

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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      cacheExtent: 1500,
      itemCount: artifacts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => ChatArtifactTile(
        artifact: _adaptApiArtifact(artifacts[i]),
        onOpen: () => onOpen(artifacts[i]),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.surface2.withValues(alpha: context.isDark ? 0.5 : 0.85),
                borderRadius: AppRadius.buttonR,
                border: Border.all(color: s.cardBorder),
              ),
              child: Icon(icon, color: s.muted, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: s.muted),
            ),
          ],
        ),
      ),
    );
  }
}
