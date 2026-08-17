import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/data_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/search_and_filters_bar.dart';
import '../../conversations/widgets/gradient_fab.dart';
import '../data/project_models.dart';
import '../view_model/vault_cubit.dart';
import '../view_model/vault_state.dart';
import '../widgets/widgets.dart';
import '../../../core/theme/app_sizes.dart';

/// Vault tab — Projects → Environments → Credentials hierarchy.
///
/// API-backed via [VaultCubit] (Phase 3 of the migration). The screen
/// owns local-only UI state (search query); the cubit owns everything
/// async. Render flow:
///   * [BlocListener] surfaces mutation toasts + errors (one-shot,
///     consumed on the cubit so they don't fire twice).
///   * [DataStateView] handles the four DataState branches uniformly,
///     so this file doesn't carry a single `isLoading`/`hasError` flag.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Always fire a fresh fetch on screen mount. The cubit's load()
    // guards against duplicate in-flight requests, so this is safe
    // even when hydrateFromCache() has already queued one. Without
    // this, a cached snapshot (e.g. empty list) masks server-side
    // changes (a project created on the web shows up nowhere) — the
    // previous `if (isIdle)` guard prevented load() from running once
    // the cache rendered.
    context.read<VaultCubit>().load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────

  void _openProjectsList() => ProjectsListSheet.show(context);

  void _openProjectDetail(String projectId) =>
      ProjectDetailSheet.show(context, existingProjectId: projectId);

  void _openEnvironmentDetail(Environment env) =>
      EnvironmentDetailSheet.show(context, environmentId: env.id);

  Future<void> _confirmDeleteProject(Project project) async {
    final ok = await ConfirmDialog.show(
      context,
      title: context.tr.deleteProjectTitle,
      body: context.tr.deleteProjectBody(project.name),
      confirmLabel: context.tr.delete,
      destructive: true,
      icon: AppIcons.trash,
    );
    if (!ok || !mounted) return;
    await context.read<VaultCubit>().deleteProject(project.id);
    // Success toast is fired centrally via the BlocListener below.
  }

  /// Long-press on a project card → touch-friendly rename / delete sheet.
  void _showQuickActions(Project project) {
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

  // ── Filtering ───────────────────────────────────────────────────────

  /// A project matches the search query when its name OR any of its envs'
  /// names contain the query — so "production" still finds the project
  /// that hosts it.
  bool _matchesQuery(Project project) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    if (project.name.toLowerCase().contains(q)) return true;
    return project.environments.any(
      (e) => e.name.toLowerCase().contains(q),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VaultCubit, VaultState>(
      // Surface action toasts/errors once each. Consume on the cubit so
      // the same message can't fire on the next unrelated state change.
      listenWhen: (a, b) =>
          a.actionFailure != b.actionFailure ||
          a.actionToast != b.actionToast,
      listener: _onCubitChange,
      builder: (context, state) {
        final data = state.data.dataOrNull;
        final projectCount = data?.projects.length ?? 0;
        final envCount = data?.allEnvironments.length ?? 0;
        final subtitleText = projectCount == 0
            ? null
            : '$projectCount ${context.tr.projectsTitle.toLowerCase()} · '
                '${context.tr.environmentCount(envCount)}';

        return PageScaffold(
          title: context.tr.tabVault,
          subtitle: subtitleText,
          floatingActionButton: GradientFab(
            onPressed: _openProjectsList,
            label: context.tr.addProject,
          ),
          onRefresh: () => context.read<VaultCubit>().refresh(),
          actions: [
            AppIconButton(
              icon: AppIcons.refresh,
              tooltip: context.tr.refreshCredentials,
              bordered: false,
              onPressed: () => context.read<VaultCubit>().refresh(),
            ),
            const SizedBox(width: AppSpacing.s6),
          ],
          children: [
            DataStateView<VaultData>(
              state: state.data,
              loadingLabel: context.tr.loading,
              onRetry: () => context.read<VaultCubit>().load(),
              // Skeleton-during-refresh: previous projects hide while
              // the fetch is in flight, card-shaped shimmers paint in
              // their place until the new snapshot lands. Reads more
              // legibly than a stale list + spinner overlay.
              keepPreviousOnLoading: false,
              onLoading: (context, _) => const Column(
                key: ValueKey('vault-skeleton'),
                children: [
                  ProjectCardSkeleton(),
                  SizedBox(height: AppSpacing.s12),
                  ProjectCardSkeleton(envRows: 1),
                  SizedBox(height: AppSpacing.s12),
                  ProjectCardSkeleton(),
                  SizedBox(height: AppSpacing.s12),
                  ProjectCardSkeleton(envRows: 2),
                ],
              ),
              onData: (context, data) => _ProjectsBody(
                data: data,
                query: _query,
                searchController: _searchController,
                onSearchChanged: (q) => setState(() => _query = q),
                matchesQuery: _matchesQuery,
                onOpenProject: _openProjectDetail,
                onOpenEnv: _openEnvironmentDetail,
                onDeleteProject: _confirmDeleteProject,
                onLongPressProject: _showQuickActions,
                onCreateFirst: _openProjectsList,
              ),
            ),
          ],
        );
      },
    );
  }

  void _onCubitChange(BuildContext context, VaultState state) {
    final cubit = context.read<VaultCubit>();
    final tr = context.tr;
    if (state.actionFailure != null) {
      final f = state.actionFailure!;
      // Title = action context, message = root cause. Reads as two
      // lines so the user understands both *what failed* and *why*.
      AppToast.show(
        context,
        title: _vaultActionLabel(tr, f.action),
        message: ApiErrorMapper.message(context, f.failure),
        variant: ToastVariant.error,
        // For transport-layer failures, attach a one-tap retry so the
        // user doesn't have to navigate back to the FAB or pull-to-
        // refresh just because their wifi blipped.
        action: _retryActionFor(context, f),
      );
      cubit.consumeActionFailure();
    }
    if (state.actionToast != null) {
      AppToast.show(
        context,
        message: _vaultToastMessage(tr, state.actionToast!),
        variant: ToastVariant.success,
      );
      cubit.consumeActionToast();
    }
  }

  /// Returns a one-tap retry action for transport-layer failures only.
  /// Other failure kinds (validation, conflict, forbidden, …) won't
  /// resolve by retrying so we omit the button rather than mislead the
  /// user.
  ToastAction? _retryActionFor(
    BuildContext context,
    VaultActionFailure f,
  ) {
    final retryable = f.failure is NetworkFailure ||
        f.failure is TimeoutFailure ||
        f.failure is ServerFailure;
    if (!retryable) return null;
    final cubit = context.read<VaultCubit>();
    return ToastAction(
      label: context.tr.retry,
      onPressed: () => _retryFor(cubit, f.action),
    );
  }

  /// Each action knows how to retry itself. The load/refresh actions
  /// just re-load; mutation actions can't be safely "retried" without
  /// the original inputs, so they trigger a list refresh instead — that
  /// rescues the user from a broken local state.
  void _retryFor(VaultCubit cubit, VaultAction action) {
    switch (action) {
      case VaultAction.load:
      case VaultAction.loadCredentials:
        cubit.load();
      case VaultAction.createProject:
      case VaultAction.renameProject:
      case VaultAction.deleteProject:
      case VaultAction.createEnvironment:
      case VaultAction.updateEnvironment:
      case VaultAction.deleteEnvironment:
      case VaultAction.saveCredential:
      case VaultAction.deleteCredential:
        cubit.refresh();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Localized labels for the cubit's typed action / toast enums.
//
// Kept at file scope (not as methods on AppStrings) so the i18n table
// only needs one entry per case and the mapping stays inside the feature
// that owns the action enum — adding a new VaultAction enum value only
// requires editing this file + the i18n strings.
// ─────────────────────────────────────────────────────────────────────────

String _vaultActionLabel(AppStrings tr, VaultAction action) {
  return switch (action) {
    VaultAction.load => tr.vaultActionLoadFailed,
    VaultAction.createProject => tr.vaultActionCreateProjectFailed,
    VaultAction.renameProject => tr.vaultActionRenameProjectFailed,
    VaultAction.deleteProject => tr.vaultActionDeleteProjectFailed,
    VaultAction.createEnvironment => tr.vaultActionCreateEnvironmentFailed,
    VaultAction.updateEnvironment => tr.vaultActionUpdateEnvironmentFailed,
    VaultAction.deleteEnvironment => tr.vaultActionDeleteEnvironmentFailed,
    VaultAction.loadCredentials => tr.vaultActionLoadCredentialsFailed,
    VaultAction.saveCredential => tr.vaultActionSaveCredentialFailed,
    VaultAction.deleteCredential => tr.vaultActionDeleteCredentialFailed,
  };
}

String _vaultToastMessage(AppStrings tr, VaultToast toast) {
  return switch (toast) {
    VaultToast.projectCreated => tr.vaultToastProjectCreated,
    VaultToast.projectDeleted => tr.vaultToastProjectDeleted,
    VaultToast.environmentCreated => tr.vaultToastEnvironmentCreated,
    VaultToast.environmentDeleted => tr.vaultToastEnvironmentDeleted,
    VaultToast.credentialSaved => tr.vaultToastCredentialSaved,
    VaultToast.credentialDeleted => tr.vaultToastCredentialDeleted,
  };
}

// ─────────────────────────────────────────────────────────────────────────
// Body — separate widget so the [DataStateView] builder closure stays thin
// ─────────────────────────────────────────────────────────────────────────

class _ProjectsBody extends StatelessWidget {
  const _ProjectsBody({
    required this.data,
    required this.query,
    required this.searchController,
    required this.onSearchChanged,
    required this.matchesQuery,
    required this.onOpenProject,
    required this.onOpenEnv,
    required this.onDeleteProject,
    required this.onLongPressProject,
    required this.onCreateFirst,
  });

  final VaultData data;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final bool Function(Project) matchesQuery;
  final ValueChanged<String> onOpenProject;
  final ValueChanged<Environment> onOpenEnv;
  final ValueChanged<Project> onDeleteProject;
  final ValueChanged<Project> onLongPressProject;
  final VoidCallback onCreateFirst;

  @override
  Widget build(BuildContext context) {
    final allProjects = data.projects;
    final visible = allProjects.where(matchesQuery).toList();
    final showSearch = allProjects.length > 3 || query.isNotEmpty;

    if (allProjects.isEmpty) {
      return EmptyState(
        key: const ValueKey('empty-projects'),
        icon: AppIcons.projects,
        title: context.tr.noStoredCredentialsTitle,
        body: context.tr.noStoredCredentialsBody,
        action: PrimaryButton(
          label: context.tr.addProject,
          icon: AppIcons.plus,
          onPressed: onCreateFirst,
        ),
      );
    }

    return Column(
      children: [
        if (showSearch) ...[
          SearchAndFiltersBar<bool>(
            controller: searchController,
            hintText: context.tr.search,
            query: query,
            onQueryChanged: onSearchChanged,
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        if (visible.isEmpty)
          EmptyState(
            key: const ValueKey('empty-search'),
            icon: AppIcons.search,
            title: context.tr.clearSearch,
            body: query,
          )
        else
          for (final entry in visible.asMap().entries) ...[
            FadeSlideIn(
              key: ValueKey('project-${entry.value.id}'),
              index: entry.key,
              child: ProjectCard(
                project: entry.value,
                environments: entry.value.environments,
                onTap: () => onOpenProject(entry.value.id),
                onEdit: () => onOpenProject(entry.value.id),
                onDelete: () => onDeleteProject(entry.value),
                onLongPress: () => onLongPressProject(entry.value),
                onEnvTap: onOpenEnv,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
          ],
      ],
    );
  }
}
