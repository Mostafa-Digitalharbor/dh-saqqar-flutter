import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/state/data_state.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/data_state_refreshable_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/app_package_models.dart';
import '../data/apps_api.dart';
import '../view_model/apps_cubit.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<AppsCubit>().load());
  }

  Future<void> _launch(SaqqarApp app) async {
    if (_launchingSlug != null) return; // one launch at a time
    setState(() => _launchingSlug = app.slug);
    try {
      // Launch WITHOUT an environment_id: per the API, the agent asks the
      // user to pick one in-chat when the task needs it, so we don't block
      // the tap on an env picker here.
      final conversationId = await context.read<AppsApi>().launch(app.slug);
      if (!mounted) return;
      setState(() => _launchingSlug = null);
      // Replace-free push so Back returns to the gallery, matching how the
      // Chats list opens a conversation. Fire-and-forget — we don't act on
      // the pushed route's pop result.
      unawaited(context.push(RouteNames.chatPath(conversationId)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _launchingSlug = null);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(ApiErrorMapper.message(context, e))),
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
                    if (apps.isEmpty) {
                      // Scrollable so pull-to-refresh still works on empty.
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 48, 16, 28),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          EmptyState(
                            icon: Icons.grid_view_rounded,
                            title: context.tr.appsEmptyTitle,
                            body: context.tr.appsEmptyBody,
                          ),
                        ],
                      );
                    }
                    return _AppsGrid(apps: apps, onLaunch: _launch);
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
                        const SizedBox(height: 14),
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
  const _AppsGrid({required this.apps, required this.onLaunch});

  final List<SaqqarApp> apps;
  final ValueChanged<SaqqarApp> onLaunch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns on phones, three once there's room (tablets / large
        // phones landscape). Keeps tiles a comfortable tap size either way.
        final crossAxisCount = constraints.maxWidth >= 640 ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: apps.length,
          itemBuilder: (context, i) =>
              _AppTile(app: apps[i], onTap: () => onLaunch(apps[i])),
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
          padding: const EdgeInsets.all(14),
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
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.30)),
                ),
                child: Icon(_iconForGroup(app.group), size: 22, color: accent),
              ),
              const SizedBox(height: 12),
              Text(
                app.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  app.tagline,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: s.muted),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (app.category.isNotEmpty)
                    Expanded(
                      child: Text(
                        app.category,
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
                      child: Icon(Icons.dns_outlined, size: 15, color: s.muted),
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
      return Icons.calculate_outlined;
    case 'finance':
      return Icons.account_balance_outlined;
    case 'integrations':
      return Icons.extension_outlined;
    default:
      return Icons.grid_view_rounded;
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
