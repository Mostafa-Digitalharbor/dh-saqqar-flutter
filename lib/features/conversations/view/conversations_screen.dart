import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/data_state_refreshable_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/fig/fig.dart';
import '../../../shared/fig/fig_page.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/search_and_filters_bar.dart';
export '../view_model/chats_list_view.dart' show ChatsFilterMode;

import '../data/conversation_models.dart';
import '../view_model/conversations_cubit.dart';
import '../view_model/chats_list_view.dart';
import '../view_model/conversations_state.dart';
import '../widgets/rename_conversation_dialog.dart';
import '../widgets/swipe_archive_background.dart';
import '../widgets/widgets.dart';
import '../../../shared/widgets/tappable_surface.dart';
part 'conversations_screen_actions.dart';
part 'conversations_screen_rows.dart';
part 'conversations_screen_widgets.dart';

/// See [ConversationSummary.isLive] — the window itself lives on the model
/// so the card and this screen can't drift apart on what "live" means.
///
/// [ChatsFilterMode] moved next to [ChatsListView]: the enum names slices of
/// the list, and that is the object that produces them. It is re-exported
/// here so existing importers of this screen keep resolving it.
bool conversationIsLive(ConversationSummary c) => c.isLive;

/// Conversations list — search + archive filter + paginated rows, with
/// a gradient FAB to start a fresh chat. Pinned conversations float to
/// the top regardless of recency (resolved via [ConversationsData.ordered]).
///
/// Backed by [ConversationsCubit] (Phase 4): `load()` fires on mount,
/// pull-to-refresh re-fetches, rename/archive/delete hit PATCH/DELETE
/// optimistically. Pinning is local-only — no server endpoint exists.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with WidgetsBindingObserver {
  /// `setState` for the part-file extensions, which cannot call the
  /// `@protected` original.
  void _update(VoidCallback fn) => setState(fn);

  static const _pageSize = 30;

  /// How often the list silently revalidates so pending-approval counts,
  /// previews, and the "Saqqar is working" state update on their own — no
  /// manual pull-to-refresh needed. Cheap: list + counts only, no per-row
  /// snapshot prefetch (see [ConversationsCubit.poll]).
  static const _pollInterval = Duration(seconds: 20);
  Timer? _pollTimer;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  String _query = '';
  ChatsFilterMode _filterMode = ChatsFilterMode.all;

  /// Whether the "Archived conversations" collapsible card is open.
  /// Reset to false after every archive/unarchive action so the user
  /// always lands back on the active list — the archived section is a
  /// drawer, not a persistent view.
  bool _archivedExpanded = false;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Always revalidate on mount — NOT gated on `isIdle`, because
    // `hydrateFromCache` leaves the cubit in DataSuccess (the cached list)
    // before the screen ever builds, so an idle-gate would skip the live
    // fetch and the rows would stay stale. `load()` dedupes internally and
    // keeps the cached rows visible while it refreshes. Mirrors VaultScreen.
    context.read<ConversationsCubit>().load();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// (Re)starts the silent auto-poll. The list stays mounted beneath an open
  /// chat, so this keeps counts / running-state fresh even while the user is
  /// inside a conversation — the moment they pop back, the list already
  /// reflects the approval they just actioned instead of a stale count.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      context.read<ConversationsCubit>().poll();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause polling in the background (no point spending battery/data), and
    // fire an immediate revalidation the instant the app returns so the user
    // never stares at stale rows after switching away and back.
    if (state == AppLifecycleState.resumed) {
      context.read<ConversationsCubit>().poll();
      _startPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pollTimer?.cancel();
    }
  }

  // ── Pagination ──────────────────────────────────────────────────────

  void _resetPagination() => _pageIndex = 0;

  void _goToPage(int pageIndex) {
    final data = context.read<ConversationsCubit>().state.data.dataOrNull;
    final pageCount = data == null ? 1 : _view(data).pageCount(_pageSize);
    final next = pageIndex.clamp(0, pageCount - 1);
    if (next == _pageIndex) return;
    setState(() => _pageIndex = next);
    // Paging down used to trigger a project·env enrichment pass for the newly
    // revealed rows. The list endpoint carries both fields directly now, so
    // the rows arrive already tagged and there is nothing to fetch.
    if (!_scrollController.hasClients) return;
    // Soft haptic + a slower-than-default ease so the page swap reads
    // as an intentional "you moved to a new page" rather than the list
    // teleporting to the top. The auto-advance trigger fires when the
    // user is already at the bottom, so the trip back to offset 0 needs
    // the extra runway (380 ms vs the 220 ms motion baseline) to
    // register before the new rows take the user's attention.
    HapticFeedback.lightImpact();
    _scrollController.animateTo(
      0,
      duration: AppDurations.scrollToTop,
      curve: Curves.easeOutQuart,
    );
  }

  /// The whole Chats list, sliced once for the current search + triage.
  ///
  /// One call, one pass. The screen used to hand `_filter` and `_archived`
  /// down to its body as callbacks and both layers invoked them, so the same
  /// rows were walked five times per build — on every keystroke.
  ChatsListView _view(ConversationsData data) =>
      ChatsListView.of(data, query: _query, mode: _filterMode);

  // ── Actions ─────────────────────────────────────────────────────────

  void _openFreshConversation() {
    context.go(RouteNames.chatPath(UiStrings.routeNewConversation));
  }

  // ── Cubit-driven toast surface ──────────────────────────────────────

  // ── Date grouping (locale-aware, real DateTime) ─────────────────────

  /// Routes a row-level action fired from inside [_buildGroupedRows]
  /// (swipe gesture, Dismissible callback) through the shared
  /// [_handleRowAction]. Fire-and-forget — the gesture has already
  /// resolved by the time the async handler chains.
  void onRowActionFromBuild(ConversationSummary c, ConversationAction action) {
    _handleRowAction(c, action);
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConversationsCubit, ConversationsState>(
      listenWhen: (a, b) =>
          a.actionFailure != b.actionFailure || a.actionToast != b.actionToast,
      listener: _onCubitChange,
      // The builder derives everything it renders from `state.data` (counts,
      // empty-state, the row list). Gate rebuilds on that alone so a poll that
      // only touches action-toast/failure state — or re-emits an equal data
      // snapshot — doesn't rebuild the whole list mid-scroll. Local filter /
      // search / page changes go through setState, not the cubit, so they
      // still rebuild independently of this predicate.
      buildWhen: (a, b) => a.data != b.data,
      builder: (context, state) {
        final data = state.data.dataOrNull;
        // REAL "needs approval" total — the number of conversations with at
        // least one pending approval (same source as the filter chip badge,
        // the filter, and the per-row pill). Never the demo-backed
        // `ApprovalsCubit.pendingCount`.
        final pendingCount = data == null
            ? 0
            : data.conversations
                  .where((c) => !c.isArchived && data.needsApproval(c.id))
                  .length;
        // Derived here ONLY for the header subtitle. The body derives its
        // own view from the same inputs, so the two agree by construction —
        // they used to be two independent filter passes that a reviewer had
        // to eyeball to confirm still matched.
        final totalCount = data == null ? 0 : _view(data).active.length;
        final subtitleText = pendingCount > 0
            ? '${context.tr.conversationsCount(totalCount)} · '
                  '$pendingCount ${context.tr.pending}'
            : context.tr.conversationsCount(totalCount);

        // `ConversationsEmptyState` renders its own prominent "New
        // conversation" CTA, so keeping the FAB up as well stacks two
        // identical buttons on the same screen — the FAB even overlaps the
        // empty-state artwork. Drop the FAB for exactly the case the empty
        // state owns; mirrors its own condition below.
        final showsEmptyState = data != null && data.conversations.isEmpty;

        return FigPage(
          title: context.tr.tabChats,
          subtitle: subtitleText,
          child: RefreshIndicator(
            onRefresh: () => context.read<ConversationsCubit>().refresh(),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s16,
                AppSpacing.s16,
                AppSpacing.s140,
              ),
              children: [
                // Inline, not a floating button: the tab bar floats over the
                // bottom of this screen and would cover it. The empty state
                // owns its own "start a conversation" action.
                if (!showsEmptyState) ...[
                  FigButton(
                    label: context.tr.newConversation,
                    height: AppControlSizes.rowMin,
                    onPressed: _openFreshConversation,
                  ),
                  const SizedBox(height: AppSpacing.s14),
                ],
                DataStateRefreshableView<ConversationsData>(
                  state: state.data,
                  onRefresh: () => context.read<ConversationsCubit>().refresh(),
                  loadingLabel: context.tr.loading,
                  // Skeleton-during-refresh: previous data hides, card-shaped
                  // shimmers paint in its place until the new snapshot lands.
                  // Far better than a bare spinner — the user keeps spatial
                  // intuition for "rows are coming back here".
                  keepPreviousOnLoading: false,
                  onLoading: (context, _) => const Column(
                    key: ValueKey('conversations-skeleton'),
                    children: [
                      ConversationCardSkeleton(),
                      SizedBox(height: AppSpacing.s10),
                      ConversationCardSkeleton(),
                      SizedBox(height: AppSpacing.s10),
                      ConversationCardSkeleton(),
                      SizedBox(height: AppSpacing.s10),
                      ConversationCardSkeleton(),
                      SizedBox(height: AppSpacing.s10),
                      ConversationCardSkeleton(),
                    ],
                  ),
                  onData: (context, data) => _ConversationsBody(
                    data: data,
                    query: _query,
                    filterMode: _filterMode,
                    onFilterModeChanged: (mode) => setState(() {
                      _filterMode = mode;
                      _resetPagination();
                    }),
                    archivedExpanded: _archivedExpanded,
                    pageIndex: _pageIndex,
                    pageSize: _pageSize,
                    searchController: _searchController,
                    onSearchChanged: (value) => setState(() {
                      _query = value;
                      _resetPagination();
                    }),
                    onArchivedToggle: () => setState(() {
                      _archivedExpanded = !_archivedExpanded;
                    }),
                    onGoToPage: _goToPage,
                    openFresh: _openFreshConversation,
                    buildGroupedRows: _buildGroupedRows,
                    view: _view(data),
                    onRowAction: _handleRowAction,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Body — kept separate so the DataState builder closure stays thin and
// the screen-level state class doesn't grow build-method noise.
// ─────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────
// Localized labels for the cubit's typed action / toast enums.
// ─────────────────────────────────────────────────────────────────────────
