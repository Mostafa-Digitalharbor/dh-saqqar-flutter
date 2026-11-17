import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/state/data_state.dart';
import '../../../shared/fig/fig.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/app_package_models.dart';
import '../data/apps_api.dart';
import '../view_model/apps_cubit.dart';
import '../widgets/app_launch_dialog.dart';
import '../../../core/theme/app_sizes.dart';

/// Saqqar Apps gallery in the redesigned look: dark header, group chips,
/// glass search and white package cards with a "Set up →" affordance.
///
/// Two presentations share this screen: the **Apps tab** (title "Apps", group
/// chips, floating nav from the shell) and the **Workspace → Saqqar Apps**
/// page ([workspace] = true: back button, "WORKSPACE" eyebrow, no chips).
class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key, this.workspace = false});

  final bool workspace;

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  String? _launchingSlug;
  String? _group;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AppsCubit>().load(),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _launch(SaqqarApp app) async {
    if (_launchingSlug != null) return;
    final choice = await AppLaunchDialog.show(context, app: app);
    if (choice == null || !mounted) return;
    setState(() => _launchingSlug = app.slug);
    try {
      final conversationId = await context.read<AppsApi>().launch(
        app.slug,
        environmentId: choice.environmentId,
      );
      if (!mounted) return;
      setState(() => _launchingSlug = null);
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

  static const _tints = [
    (Color(0xFFE2EAFB), Fig.blueSoft),
    (Color(0xFFE2F5EF), Color(0xFF1FA37A)),
    (Color(0xFFFBEFE0), Color(0xFFB8741A)),
  ];

  IconData _icon(SaqqarApp a) {
    final k = '${a.slug} ${a.name}'.toLowerCase();
    if (k.contains('zatca') || k.contains('invoice')) {
      return LucideIcons.fileText;
    }
    if (k.contains('whatsapp') || k.contains('chat')) {
      return LucideIcons.messageSquare;
    }
    if (k.contains('chart') || k.contains('account')) {
      return LucideIcons.building2;
    }
    if (k.contains('stock') || k.contains('inventory')) {
      return LucideIcons.package;
    }
    if (k.contains('pulse') || k.contains('report')) {
      return LucideIcons.chartNoAxesColumn;
    }
    return LucideIcons.layoutGrid;
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: figLightStatusBar,
      child: Scaffold(
        backgroundColor: Fig.pageGrey,
        body: FigBackdrop(
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: BlocBuilder<AppsCubit, DataState<List<SaqqarApp>>>(
                  builder: (context, state) {
                    final apps = state.dataOrPrevious ?? const <SaqqarApp>[];
                    final groups =
                        <String>{
                          for (final a in apps)
                            if (a.group.trim().isNotEmpty) a.group.trim(),
                        }.toList()..sort(
                          (a, b) => tr.appGroup(a).compareTo(tr.appGroup(b)),
                        );
                    final active = groups.contains(_group) ? _group : null;
                    final q = _search.text.trim().toLowerCase();
                    final visible = [
                      for (final a in apps)
                        if ((active == null || a.group == active) &&
                            (q.isEmpty ||
                                a.displayName(tr).toLowerCase().contains(q) ||
                                a.displayTagline(tr).toLowerCase().contains(q)))
                          a,
                    ];
                    return FigTopFade(
                      child: RefreshIndicator(
                        onRefresh: () => context.read<AppsCubit>().refresh(),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
                          children: [
                            if (widget.workspace)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.s18,
                                  left: 0,
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Transform.translate(
                                    offset: const Offset(-12, 0),
                                    child: FigBackButton(
                                      onTap: () => context.canPop()
                                          ? context.pop()
                                          : context.go(RouteNames.homePath),
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 54),
                            if (widget.workspace)
                              Text(
                                context.tr.figWorkspace2,
                                style: Fig.t(
                                  context,
                                  size: 9,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            Text(
                              widget.workspace
                                  ? context.tr.figSaqqarApps
                                  : context.tr.figApps,
                              style: Fig.t(
                                context,
                                size: widget.workspace ? 26 : 32,
                                weight: widget.workspace
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            if (!widget.workspace) ...[
                              Text(
                                context.tr.figReadyMadeSaqqarAgentsForCommon,
                                style: Fig.t(
                                  context,
                                  size: 9.5,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s18),
                              if (groups.length > 1)
                                SizedBox(
                                  height: 36,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    clipBehavior: Clip.none,
                                    children: [
                                      _Chip(
                                        label: tr.appGroupAll,
                                        active: active == null,
                                        onTap: () =>
                                            setState(() => _group = null),
                                      ),
                                      for (final g in groups)
                                        _Chip(
                                          label: tr.appGroup(g),
                                          active: active == g,
                                          onTap: () =>
                                              setState(() => _group = g),
                                        ),
                                    ],
                                  ),
                                ),
                              SizedBox(height: groups.length > 1 ? 24 : 6),
                            ] else
                              const SizedBox(height: AppSpacing.s28),
                            _SearchPill(
                              controller: _search,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: AppSpacing.s18),
                            if (state is DataLoading<List<SaqqarApp>> &&
                                apps.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 60),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (visible.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 50),
                                child: Center(
                                  child: Text(
                                    tr.appsEmptyTitle,
                                    style: Fig.t(
                                      context,
                                      size: 14,
                                      color: Fig.muted,
                                    ),
                                  ),
                                ),
                              )
                            else
                              for (var i = 0; i < visible.length; i++)
                                _AppCard(
                                  title: visible[i].displayName(tr),
                                  body: visible[i].displayTagline(tr),
                                  icon: _icon(visible[i]),
                                  tint: _tints[i % _tints.length],
                                  onTap: () => _launch(visible[i]),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_launchingSlug != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.s8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? null : const Color(0xFFE4E6EE),
            gradient: active ? Fig.primaryGradient : null,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: Fig.t(
              context,
              size: 12.5,
              color: active ? Colors.white : const Color(0xFF4A4F63),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.search,
            size: 18,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: Colors.white,
              style: Fig.t(context, size: 14, color: Colors.white),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: context.tr.figSearch,
                hintStyle: Fig.t(
                  context,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String title;
  final String body;
  final IconData icon;
  final (Color, Color) tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s18),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 20, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE3E7F4)),
            boxShadow: [
              BoxShadow(
                color: Fig.slate.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tint.$1,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, size: 20, color: tint.$2),
                  ),
                  const SizedBox(width: AppSpacing.s14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Fig.t(
                            context,
                            size: 13,
                            weight: FontWeight.w700,
                            color: Fig.ink,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s7),
                        Text(
                          body,
                          style: Fig.t(
                            context,
                            size: 12.5,
                            color: Fig.mutedGrey,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        context.tr.figSetUp,
                        style: Fig.t(
                          context,
                          size: 9.5,
                          weight: FontWeight.w700,
                          color: Fig.blue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? LucideIcons.arrowLeft
                          : LucideIcons.arrowRight,
                      size: 13,
                      color: Fig.blue,
                    ),
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
