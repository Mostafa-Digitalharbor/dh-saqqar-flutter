import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/format/byte_size.dart';
import '../../../core/format/file_kind.dart';
import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/fig/fig.dart';
import '../data/approval_adapter.dart';
import '../../inbox/data/approval_models.dart' as inbox_api;
import '../../inbox/data/approvals_api.dart';
import '../../inbox/data/artifact_downloader.dart';
import '../../inbox/data/artifact_models.dart' as inbox_api;
import '../../inbox/view/artifact_details_sheet.dart';
import '../view/attachment_viewer_screen.dart';
import '../view_model/chat_cubit.dart';
import '../../../core/theme/app_sizes.dart';
part 'chat_rail_drawer_approvals.dart';
part 'chat_rail_drawer_files.dart';
part 'chat_rail_drawer_activity.dart';

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
    this.company = '',
    this.environment = '',
  });

  final String conversationId;

  /// Header subtitle: "Company · Production".
  final String company;
  final String environment;

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
  final TextEditingController _fileSearch = TextEditingController();
  int _fileFilter = 0;

  bool get _isNewChat => widget.conversationId == UiStrings.newConversationId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _fileSearch.dispose();
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
      _toast(approved ? tr.approvalGrantedExecuting : tr.approvalRejected);
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
    final snapshot = _isNewChat
        ? null
        : context.watch<ChatCubit>().state.data.dataOrNull;
    final approvals = [...?snapshot?.approvals]
      ..sort((a, b) {
        // Pending first, then newest.
        final pa = a.status == inbox_api.ApprovalStatus.pending ? 0 : 1;
        final pb = b.status == inbox_api.ApprovalStatus.pending ? 0 : 1;
        if (pa != pb) return pa - pb;
        return (b.createdAt ?? DateTime(0)).compareTo(
          a.createdAt ?? DateTime(0),
        );
      });
    final artifacts = snapshot?.artifacts ?? const <inbox_api.Artifact>[];
    final tabs = [
      context.tr.figApprovals,
      context.tr.figFiles,
      context.tr.figActivity,
    ];

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadiusDirectional.only(
            topStart: Radius.circular(40),
            bottomStart: Radius.circular(40),
          ),
          boxShadow: [
            BoxShadow(
              color: Fig.drawerShadow,
              blurRadius: 40,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr.figWorkspace,
                            style: Fig.t(
                              context,
                              size: 24,
                              weight: FontWeight.w700,
                              color: Fig.navy,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s2),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: widget.company.isEmpty
                                      ? '—'
                                      : widget.company,
                                ),
                                if (widget.environment.isNotEmpty) ...[
                                  const TextSpan(text: ' · '),
                                  TextSpan(
                                    text: widget.environment,
                                    style: const TextStyle(color: Fig.success),
                                  ),
                                ],
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Fig.t(context, size: 12.5, color: Fig.muted),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Tooltip(
                        message: context.tr.close,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Fig.hairline),
                          ),
                          child: const Icon(
                            LucideIcons.x,
                            size: 19,
                            color: Fig.navy,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Fig.dividerCool)),
                ),
                child: TabBar(
                  controller: _tab,
                  labelColor: Fig.blue,
                  unselectedLabelColor: Fig.muted,
                  indicatorColor: Fig.blue,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle: Fig.t(
                    context,
                    size: 14.5,
                    weight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: Fig.t(context, size: 14.5),
                  tabs: [for (final t in tabs) Tab(height: 44, text: t)],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _ApprovalsTab(
                      approvals: approvals,
                      company: widget.company,
                      onApprove: (a) =>
                          _decideApproval(approval: a, approved: true),
                      onReject: (a) =>
                          _decideApproval(approval: a, approved: false),
                    ),
                    _FilesTab(
                      artifacts: artifacts,
                      search: _fileSearch,
                      filter: _fileFilter,
                      onFilter: (i) => setState(() => _fileFilter = i),
                      onSearch: () => setState(() {}),
                      onOpen: _openArtifact,
                      onDetails: _showArtifactDetails,
                    ),
                    _ActivityTab(approvals: approvals, artifacts: artifacts),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

// ─────────────────────────────────────────────────────────────────────────
// Tabs
// ─────────────────────────────────────────────────────────────────────────

const _statusPending = Color(0xFFD9962B);
const _statusApproved = Color(0xFF1F9D63);
const _statusRejected = Fig.dangerText;

String _initials(String text) {
  final parts = text
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final w = parts.first;
    return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

const _avatarPalette = [
  Color(0xFF5B3E8B),
  Color(0xFF1F6B6B),
  Color(0xFF2A5598),
  Color(0xFF7A5230),
];

class _Avatar extends StatelessWidget {
  const _Avatar(this.label, {this.size = 24});
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _avatarPalette[label.hashCode.abs() % _avatarPalette.length],
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials(label),
        style: Fig.t(
          context,
          size: size * 0.42,
          weight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

(IconData, Color) _fileGlyph(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) {
    return (LucideIcons.fileText, Fig.fileRed);
  }
  if (n.endsWith('.doc') || n.endsWith('.docx')) {
    return (LucideIcons.fileText, Fig.fileBlue);
  }
  if (n.endsWith('.xls') || n.endsWith('.xlsx') || n.endsWith('.csv')) {
    return (LucideIcons.fileSpreadsheet, Fig.fileGreen);
  }
  if (n.endsWith('.zip') || n.endsWith('.tar') || n.endsWith('.gz')) {
    return (LucideIcons.fileArchive, Fig.fileAmber);
  }
  if (FileKinds.isImage(n)) return (LucideIcons.image, Fig.blue);
  return (LucideIcons.file, Fig.muted);
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
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Fig.tintBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: Fig.blue, size: 24),
                  ),
                  const SizedBox(height: AppSpacing.s14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Fig.t(
                      context,
                      size: 15,
                      weight: FontWeight.w600,
                      color: Fig.navy,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: Fig.t(context, size: 13, color: Fig.muted),
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
