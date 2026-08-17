import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/state/data_state.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/colored_icon_box.dart';
import '../../../shared/widgets/data_state_refreshable_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/filter_pill.dart';
import '../data/app_package_models.dart';
import '../data/apps_api.dart';
import '../view_model/apps_cubit.dart';
import '../widgets/app_launch_dialog.dart';
import '../../../core/theme/app_icons.dart';

/// Saqqar Apps gallery (API_MOBILE_NEW_ENDPOINTS.md §1) — a grid of guided
/// packages. Tapping a tile launches a package-tagged conversation and
/// routes into it so the user lands on the agent's seeded opening message.
///
/// Reached as a full-screen detail route from Account. The [AppsCubit] is
/// provided per-route by the router so its lifetime matches the screen.
class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  /// Slug currently being launched — drives the blocking overlay and stops
  /// a double-tap from firing two launch calls.
  String? _launchingSlug;

  /// Active group filter, or `null` for "All". Client-side: the catalogue is
  /// a handful of packages that already arrived in one response, so filtering
  /// it locally is instant and works offline from the cached list.
  String? _group;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<AppsCubit>().load());
  }

  Future<void> _launch(SaqqarApp app) async {
    if (_launchingSlug != null) return; // one launch at a time

    // Ask WHERE before opening anything. Tapping a package used to drop the
    // user straight into a chat whose first message was the agent asking
    // which database to use — a question this screen can answer from a list
    // instead of making them type a name.
    final choice = await AppLaunchDialog.show(context, app: app);
    // Null means dismissed. Distinct from a choice with no environment,
    // which is the supported "decide later in chat" path.
    if (choice == null || !mounted) return;

    setState(() => _launchingSlug = app.slug);
    try {
      final conversationId = await context.read<AppsApi>().launch(
            app.slug,
            environmentId: choice.environmentId,
          );
      if (!mounted) return;
      setState(() => _launchingSlug = null);
      // Replace-free push so Back returns to the gallery, matching how the
      // Chats list opens a conversation. Fire-and-forget — we don't act on
      // the pushed route's pop result.
      unawaited(context.push(RouteNames.chatPath(conversationId)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _launchingSlug = null);
      AppToast.show(
        context,
        title: context.tr.appsLaunchFailed,
        message: ApiErrorMapper.message(context, e),
        variant: ToastVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Scaffold(
      backgroundColor: s.bg,
      appBar: AppBar(title: Text(context.tr.appsTitle)),
      body: AmbientBackground(
        child: Stack(
          children: [
            BlocBuilder<AppsCubit, DataState<List<SaqqarApp>>>(
              builder: (context, state) {
                return DataStateRefreshableView<List<SaqqarApp>>(
                  state: state,
                  onRefresh: () => context.read<AppsCubit>().refresh(),
                  onData: (context, apps) {
                    // No client-side trim. `GET /apps/` applies the web
                    // gallery's own visibility gate as of 2026-08-09, so the
                    // catalogue it sends IS the catalogue — and a package the
                    // backend adds now appears here with no mobile release.
                    if (apps.isEmpty) {
                      // Scrollable so pull-to-refresh still works on empty.
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s16,
                          AppSpacing.s48,
                          AppSpacing.s16,
                          AppSpacing.s28,
                        ),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          EmptyState(
                            icon: AppIcons.grid,
                            title: context.tr.appsEmptyTitle,
                            body: context.tr.appsEmptyBody,
                          ),
                        ],
                      );
                    }
                    // Group filter, web parity. The pill set is derived from
                    // the data rather than hardcoded, so a group the backend
                    // introduces gets a pill without a mobile release — and
                    // a group it retires stops showing an empty filter.
                    final groups = <String>{
                      for (final a in apps)
                        if (a.group.trim().isNotEmpty) a.group.trim(),
                    }.toList()
                      ..sort();
                    // A selection that no longer matches anything (the
                    // catalogue changed under a pull-to-refresh) falls back
                    // to All instead of showing a permanently empty grid.
                    final active =
                        groups.contains(_group) ? _group : null;
                    final visible = active == null
                        ? apps
                        : [for (final a in apps) if (a.group == active) a];

                    return _AppsGrid(
                      apps: visible,
                      onLaunch: _launch,
                      groups: groups,
                      activeGroup: active,
                      onGroupChanged: (g) => setState(() => _group = g),
                    );
                  },
                );
              },
            ),
            // Blocking overlay while a launch round-trips. Non-dismissible;
            // the launch either routes away or restores the grid on error.
            if (_launchingSlug != null)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: s.brandCyan,
                        ),
                        const SizedBox(height: AppSpacing.s14),
                        Text(
                          context.tr.appsOpening,
                          style: context.text.bodyMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppsGrid extends StatelessWidget {
  const _AppsGrid({
    required this.apps,
    required this.onLaunch,
    required this.groups,
    required this.activeGroup,
    required this.onGroupChanged,
  });

  final List<SaqqarApp> apps;
  final ValueChanged<SaqqarApp> onLaunch;

  /// Distinct groups present in the catalogue, sorted. Empty when the
  /// backend sends none, in which case the pill row is omitted entirely
  /// rather than showing a lone "All" that filters nothing.
  final List<String> groups;

  /// `null` = All.
  final String? activeGroup;
  final ValueChanged<String?> onGroupChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns on phones, three once there's room (tablets / large
        // phones landscape). Keeps tiles a comfortable tap size either way.
        final crossAxisCount = constraints.maxWidth >= 640 ? 3 : 2;

        // A grid cell's height comes from its width via the aspect ratio, so
        // it is fixed with respect to the user's text scale — but the tile's
        // content is not. The 44 px icon, the two-line name and the meta row
        // are all unshrinkable, and at 1.3× text they need ~143 px inside the
        // 138 px cell a 320 px-wide screen produces: a RenderFlex overflow on
        // the smallest supported phone with the OS text slider two notches up.
        //
        // Dividing the ratio by the text scale makes the cell grow at exactly
        // the rate the copy inside it does. Clamped at 1.6 because the tile
        // stops gaining anything past that — `Expanded` has already absorbed
        // the slack — and an unclamped 2.0+ accessibility setting would leave
        // one tile taller than the viewport.
        final textScale =
            MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
        final grid = GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s16,
            AppSpacing.s16,
            AppSpacing.s28,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82 / textScale,
          ),
          itemCount: apps.length,
          itemBuilder: (context, i) =>
              _AppTile(app: apps[i], onTap: () => onLaunch(apps[i])),
        );

        // Nothing to filter with — one group, or none at all. A pill row
        // offering only "All" is a control that cannot do anything.
        if (groups.length < 2) return grid;

        return Column(
          children: [
            // Pinned above the grid, as on web, so the active filter stays
            // visible while the user scrolls the results.
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  AppSpacing.s10,
                  AppSpacing.s16,
                  AppSpacing.s6,
                ),
                children: [
                  FilterPill(
                    label: context.tr.appGroupAll,
                    selected: activeGroup == null,
                    onTap: () => onGroupChanged(null),
                  ),
                  for (final g in groups) ...[
                    const SizedBox(width: AppSpacing.s8),
                    FilterPill(
                      // Translated by value — the taxonomy is a closed set,
                      // so the pills follow the UI language even though the
                      // server sends them in English only.
                      label: context.tr.appGroup(g),
                      selected: activeGroup == g,
                      onTap: () => onGroupChanged(g),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(child: grid),
          ],
        );
      },
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, required this.onTap});

  final SaqqarApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final accent = _parseAccent(app.accent, s.brandCyan);
    return Material(
      color: s.cardBg,
      borderRadius: AppRadius.cardR,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardR,
            border: Border.all(color: s.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accent-tinted icon square. Uses a group-mapped Material icon
              // (the server's inline SVG isn't rendered yet), tinted with the
              // server-supplied accent so each tile keeps its brand colour.
              ColoredIconBox(
                icon: _iconForGroup(app.group),
                color: accent,
                size: AppIconSizes.feature,
                radius: AppRadius.button,
                iconSize: AppIconSizes.boxGlyphLarge,
              ),
              const SizedBox(height: AppSpacing.s12),
              // Localized through the app's slug, falling back to the
              // server's English. `/api/v1/apps/` serves one language, so
              // without this the whole grid stays English on an Arabic phone.
              Text(
                app.displayName(context.tr),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.s4),
              Expanded(
                child: Text(
                  app.displayTagline(context.tr),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: s.muted),
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Row(
                children: [
                  // The GROUP, matching the web card's chip (FINANCE /
                  // INTEGRATIONS / ACCOUNTING) and the filter pills above.
                  // Falls back to `category` when the server sends no group,
                  // so the meta row never goes blank.
                  if (app.group.isNotEmpty || app.category.isNotEmpty)
                    Expanded(
                      child: Text(
                        app.group.isNotEmpty
                            ? app.displayGroup(context.tr).toUpperCase()
                            : app.displayCategory(context.tr),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (app.envRequired)
                    Tooltip(
                      message: context.tr.appsNeedsEnv,
                      child: Icon(AppIcons.server, size: AppIconSizes.inline, color: s.muted),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Group taxonomy → a definitely-present Material icon. The server also
/// sends an inline SVG, but the app bundles no SVG renderer, so this keeps
/// each tile visually distinct without a new dependency.
IconData _iconForGroup(String group) {
  switch (group.toLowerCase()) {
    case 'accounting':
      return AppIcons.calculator;
    case 'finance':
      return AppIcons.bank;
    case 'integrations':
      return AppIcons.puzzle;
    default:
      return AppIcons.grid;
  }
}

/// Parses a `#RRGGBB` (or `#AARRGGBB`) hex string into a [Color], falling
/// back to [fallback] on anything malformed rather than throwing.
Color _parseAccent(String hex, Color fallback) {
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final value = int.tryParse(h, radix: 16);
  return value == null ? fallback : Color(value);
}
