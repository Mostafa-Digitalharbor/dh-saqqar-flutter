import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/search_and_filters_bar.dart';
import '../../conversations/widgets/gradient_fab.dart';
import '../../demo/saqqar_demo_data.dart';
import '../state/vault_controller.dart';
import '../widgets/widgets.dart';

/// Vault tab — Projects → Environments → Credentials hierarchy.
///
/// Now backed by a search bar that filters projects + their envs by name,
/// a proper [ProjectCardSkeleton] loading state, and an empty state with
/// a "Create your first project" CTA.
class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  static const _initialLoadDelay = Duration(milliseconds: 650);

  bool _loading = true;
  Timer? _loadingTimer;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadingTimer = Timer(_initialLoadDelay, () {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _toast(String text) {
    AppToast.show(context, message: text);
  }

  /// Opens the projects list sheet (web parity for `projectsPopup`).
  /// The sheet hosts a quick "Add project" inline form AND lists every
  /// existing project with a delete button — single entry point for
  /// project management. Tapping a project row pushes the matching
  /// [ProjectDetailSheet] for env management.
  void _openProjectsList() {
    ProjectsListSheet.show(context);
  }

  void _openProjectDetail(String projectId) {
    ProjectDetailSheet.show(context, existingProjectId: projectId);
  }

  Future<void> _confirmDeleteProject(DemoProject project) async {
    final ok = await ConfirmDialog.show(
      context,
      title: context.tr.deleteProjectTitle,
      body: context.tr.deleteProjectBody(project.name),
      confirmLabel: context.tr.delete,
      destructive: true,
      icon: AppIcons.trash,
    );
    if (!ok || !mounted) return;
    ref.read(vaultControllerProvider.notifier).deleteProject(project.id);
    if (!mounted) return;
    _toast(context.tr.projectDeletedToast);
  }

  /// Filters the project list by [_query]. A project matches when its name
  /// contains the query OR any of its envs match — so the user can search
  /// for "production" and still find the project that hosts it.
  bool _matchesQuery(VaultState state, DemoProject project) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    if (project.name.toLowerCase().contains(q)) return true;
    for (final env in state.environmentsForProject(project.id)) {
      if (env.name.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultControllerProvider);
    final allProjects = state.projects;
    final visible =
        allProjects.where((p) => _matchesQuery(state, p)).toList();

    // Subtitle — "N projects · M environments" — gives the user a
    // one-glance view of vault size from the AppBar.
    final projectCount = allProjects.length;
    final envCount = state.environments.length;
    final subtitleText = '$projectCount ${context.tr.projectsTitle.toLowerCase()}'
        ' · ${context.tr.environmentCount(envCount)}';

    return PageScaffold(
      title: context.tr.tabVault,
      subtitle: projectCount == 0 ? null : subtitleText,
      // Pill-shaped FAB mirroring the Chats tab's "New conversation"
      // entry — keeps the primary "create" verb in the same thumb-zone
      // across both tabs so users build muscle memory once.
      floatingActionButton: GradientFab(
        onPressed: _openProjectsList,
        label: context.tr.addProject,
      ),
      onRefresh: () async {
        setState(() => _loading = true);
        final message = context.tr.credentialsRefreshed;
        await Future<void>.delayed(const Duration(milliseconds: 750));
        if (!mounted) return;
        setState(() => _loading = false);
        if (!context.mounted) return;
        AppToast.show(context, message: message);
      },
      actions: [
        // The "+" used to live up here; moved to the bottom-end FAB on
        // 2026-05-16 so the create-verb lives in the same thumb-zone
        // as the Chats tab. Keeping only the refresh icon up top.
        AppIconButton(
          icon: AppIcons.refresh,
          tooltip: context.tr.refreshCredentials,
          bordered: false,
          onPressed: () => _toast(context.tr.credentialsRefreshed),
        ),
        const SizedBox(width: 6),
      ],
      children: [
        if (allProjects.length > 3 || _query.isNotEmpty) ...[
          SearchAndFiltersBar<bool>(
            controller: _searchController,
            hintText: context.tr.search,
            query: _query,
            onQueryChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _loading
              ? const Column(
                  key: ValueKey('vault-skeleton'),
                  children: [
                    ProjectCardSkeleton(),
                    SizedBox(height: 12),
                    ProjectCardSkeleton(envRows: 1),
                    SizedBox(height: 12),
                    ProjectCardSkeleton(),
                  ],
                )
              : allProjects.isEmpty
                  ? EmptyState(
                      key: const ValueKey('empty-projects'),
                      icon: AppIcons.projects,
                      title: context.tr.noStoredCredentialsTitle,
                      body: context.tr.noStoredCredentialsBody,
                      action: PrimaryButton(
                        label: context.tr.addProject,
                        icon: AppIcons.plus,
                        onPressed: _openProjectsList,
                      ),
                    )
                  : visible.isEmpty
                      ? EmptyState(
                          key: const ValueKey('empty-search'),
                          icon: AppIcons.search,
                          title: context.tr.clearSearch,
                          body: _query,
                        )
                      : Column(
                          key: ValueKey('projects-list-${visible.length}'),
                          children: [
                            for (final entry in visible.asMap().entries) ...[
                              FadeSlideIn(
                                key: ValueKey('project-${entry.value.id}'),
                                index: entry.key,
                                child: ProjectCard(
                                  project: entry.value,
                                  environments: state
                                      .environmentsForProject(entry.value.id),
                                  onTap: () =>
                                      _openProjectDetail(entry.value.id),
                                  onEdit: () =>
                                      _openProjectDetail(entry.value.id),
                                  onDelete: () =>
                                      _confirmDeleteProject(entry.value),
                                  onLongPress: () =>
                                      _showQuickActions(entry.value),
                                  onEnvTap: (env) =>
                                      EnvironmentDetailSheet.show(
                                    context,
                                    environmentId: env.id,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
        ),
      ],
    );
  }

  /// Long-press on a project card opens this quick-action sheet — gives
  /// the user a touch-friendly path to rename / delete without aiming
  /// for the small inline icons.
  void _showQuickActions(DemoProject project) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.edit),
              title: Text(sheetContext.tr.rename),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openProjectDetail(project.id);
              },
            ),
            ListTile(
              leading: Icon(
                AppIcons.trash,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                sheetContext.tr.delete,
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDeleteProject(project);
              },
            ),
          ],
        ),
      ),
    );
  }
}
