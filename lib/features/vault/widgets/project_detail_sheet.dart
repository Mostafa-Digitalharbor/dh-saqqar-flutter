import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/inline_add_form.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/app_card_dialog.dart';
import '../data/project_models.dart';
import '../view_model/vault_cubit.dart';
import 'environment_detail_sheet.dart';
import 'projects_list_sheet.dart';

/// Project popup — web-parity centred dialog for managing one project's
/// environments. Mirrors the desktop site's `projectPopup`:
///
///   • Header: "PROJECT" eyebrow + bold project name + Close button +
///     hairline divider
///   • "← All projects" back link (full-width pill) that returns to the
///     projects list
///   • "PROJECT NAME" labelled TextField — renames the project on blur /
///     submit (no explicit Save button; matches the web's inline edit)
///   • Environment cards — each row carries its own flag checkboxes +
///     Open + Delete actions (see [_EnvRow])
///   • "Add environment…" inline form at the bottom — creates instantly
///
/// Project creation lives in [ProjectsListSheet] now; this sheet is
/// purely a per-project editor (the [existingProjectId] is required).
/// Delete-project lives in [ProjectsListSheet] too — surfacing it here
/// duplicated the surface and made the dialog feel busy.
class ProjectDetailSheet extends StatefulWidget {
  const ProjectDetailSheet({super.key, required this.existingProjectId});

  final String existingProjectId;

  static Future<void> show(
    BuildContext context, {
    required String existingProjectId,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          ProjectDetailSheet(existingProjectId: existingProjectId),
    );
  }

  @override
  State<ProjectDetailSheet> createState() => _ProjectDetailSheetState();
}

class _ProjectDetailSheetState extends State<ProjectDetailSheet> {
  late final TextEditingController _name;
  late final FocusNode _nameFocus;
  final TextEditingController _newEnv = TextEditingController();
  final TextEditingController _envSearch = TextEditingController();

  /// The env search field only appears when the project has enough
  /// environments that scanning visually starts to hurt. 6 is the
  /// threshold the web hits (Default project has 8 staging envs and
  /// became unreadable). Below this count the search field is hidden so
  /// small projects stay quiet.
  static const _envSearchThreshold = 6;

  @override
  void initState() {
    super.initState();
    final initialName = context
            .read<VaultCubit>()
            .state
            .data
            .dataOrNull
            ?.projectById(widget.existingProjectId)
            ?.name ??
        '';
    _name = TextEditingController(text: initialName);
    _nameFocus = FocusNode();
    // Auto-commit the rename on blur so the user never has to hunt for
    // a Save button — matches the web's inline edit (an explicit Save
    // CTA would feel redundant next to a single field).
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _commitRename();
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _name.dispose();
    _newEnv.dispose();
    _envSearch.dispose();
    super.dispose();
  }

  void _commitRename() {
    final next = _name.text.trim();
    final cubit = context.read<VaultCubit>();
    final current = cubit.state.data.dataOrNull
            ?.projectById(widget.existingProjectId)
            ?.name ??
        '';
    if (next.isEmpty || next == current) {
      // Restore the previous value if the user blanked the field or
      // didn't actually change anything — saves a no-op write + keeps
      // the input from looking empty.
      _name.text = current;
      return;
    }
    cubit.renameProject(id: widget.existingProjectId, name: next);
  }

  void _backToProjectsList() {
    Navigator.of(context).pop();
    ProjectsListSheet.show(context);
  }

  /// Case-insensitive substring filter against the env name. When the
  /// search field is empty, returns the list unchanged so we don't pay
  /// for a filter pass on small projects.
  List<Environment> _filterEnvs(List<Environment> all) {
    final q = _envSearch.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _addEnv() async {
    final name = _newEnv.text.trim();
    if (name.isEmpty) return;
    final ok = await context.read<VaultCubit>().createEnvironment(
          projectId: widget.existingProjectId,
          name: name,
        );
    if (!mounted) return;
    if (ok) {
      _newEnv.clear();
      setState(() {});
    }
  }

  Future<void> _deleteEnv(Environment env) async {
    final ok = await ConfirmDialog.show(
      context,
      title: context.tr.deleteEnvironmentTitle,
      body: context.tr.deleteEnvironmentBody(env.name),
      confirmLabel: context.tr.delete,
      destructive: true,
      icon: AppIcons.trash,
    );
    if (!ok || !mounted) return;
    await context.read<VaultCubit>().deleteEnvironment(env.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final state = context.watch<VaultCubit>().state;
    final data = state.data.dataOrNull;
    final project = data?.projectById(widget.existingProjectId);
    final envs = data?.environmentsForProject(widget.existingProjectId) ??
        const <Environment>[];

    // Centred dialog sized like the projects list popup — body grows with
    // content but never past ~70 % screen height; long env lists scroll
    // inside the body. Taller than the list dialog because this one carries
    // an edit field and its environments, not just rows.
    final projectName = project?.name ?? '—';

    return AppCardDialog(
      heightFactor: 0.7,
      minHeight: 420,
      maxHeight: 640,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                // ── Header: eyebrow + project name + Close ──────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.tr.project.toUpperCase(),
                            style: context.text.labelSmall?.copyWith(
                              color: s.brandCyan,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            projectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GhostButton(
                      label: context.tr.close,
                      minHeight: 36,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: s.cardBorder, height: 1),
                const SizedBox(height: 14),
                // ── "← All projects" back link (full-width pill) ────────
                _BackToProjectsPill(onTap: _backToProjectsList),
                const SizedBox(height: 16),
                // ── Body: project name + env list + add-env row ────────
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr.projectName.toUpperCase(),
                          style: context.text.labelSmall?.copyWith(
                            color: s.muted,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          controller: _name,
                          focusNode: _nameFocus,
                          hint: context.tr.addProjectHint,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            _commitRename();
                            _nameFocus.unfocus();
                          },
                        ),
                        // Search field — only appears once the env list
                        // grows past the visual-scan threshold. Keeps
                        // small projects (1–5 envs) quiet.
                        if (envs.length >= _envSearchThreshold) ...[
                          const SizedBox(height: 14),
                          _EnvSearchField(
                            controller: _envSearch,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                        if (envs.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _EnvList(
                            envs: _filterEnvs(envs),
                            onOpen: (env) {
                              Navigator.of(context).pop();
                              EnvironmentDetailSheet.show(
                                context,
                                environmentId: env.id,
                              );
                            },
                            onDelete: _deleteEnv,
                          ),
                        ],
                        const SizedBox(height: 14),
                        // ── Add-environment inline form (always visible,
                        // even when no envs yet — matches screenshot 1)
                        // Disabled until an env name is typed (and no
                        // write in flight) — no empty-tap no-op.
                        InlineAddForm(
                          controller: _newEnv,
                          hint: context.tr.addEnvironmentHint,
                          buttonLabel: context.tr.addEnvironment,
                          enabled: !state.actionInFlight,
                          onSubmit: _addEnv,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

/// Full-width pill button — "← All projects" back link rendered below
/// the dialog divider. Closes the current project detail and reopens the
/// projects list. Web parity (`backToProjects` label + ghost styling).
class _BackToProjectsPill extends StatelessWidget {
  const _BackToProjectsPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.pillR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillR,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.surface2.withValues(alpha: context.isDark ? 0.5 : 0.85),
            borderRadius: AppRadius.pillR,
            border: Border.all(color: s.cardBorder),
          ),
          // The back arrow is an Icon, not a '←' glyph baked into the
          // string. A literal arrow keeps pointing left after the sheet
          // flips to RTL, where "back" is to the *right* — so in Arabic it
          // pointed at the direction the user came from. Resolving the
          // chevron from `isRtl` mirrors it with the layout, the same way
          // `ProjectCard`'s disclosure chevron already does.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                context.isRtl ? AppIcons.chevronRight : AppIcons.chevronLeft,
                size: 16,
                color: s.text,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.tr.backToProjects,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: s.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the env card list as a plain Column. The server doesn't
/// support custom env ordering, so the previous drag-to-reorder affordance
/// was removed.
class _EnvList extends StatelessWidget {
  const _EnvList({
    required this.envs,
    required this.onOpen,
    required this.onDelete,
  });

  final List<Environment> envs;
  final void Function(Environment env) onOpen;
  final void Function(Environment env) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final env in envs)
          _EnvRow(
            key: ValueKey(env.id),
            env: env,
            onOpen: () => onOpen(env),
            onDelete: () => onDelete(env),
          ),
      ],
    );
  }
}

/// One env row inside the project popup — mirrors the web's layout
/// for an environment card:
///
/// ```
/// ┌────────────────────────────────────────────────────────────┐
/// │ [Test___________]               ☐ Live   ☐ Read-only       │
/// │ 3 credentials                                              │
/// │ ☐ Auto-approve                  [ Open ]    [ Delete ]     │
/// └────────────────────────────────────────────────────────────┘
/// ```
///
///   1. Always-editable name TextField — web parity for the inline
///      rename. Submitting or losing focus commits via
///      [VaultCubit.updateEnvironment].
///   2. Credential count chip — only renders when the env has at least
///      one saved credential so empty envs stay quiet.
///   3. Checkboxes (not switches) for the three flags — match the web
///      "tick what applies" semantics.
///   4. Toggling **Live** false → true pops a confirm dialog (the gate
///      is destructive UX — first-send warning fires from that moment).
///      Toggling true → false is one-tap (lifts a gate, non-destructive).
class _EnvRow extends StatefulWidget {
  const _EnvRow({
    super.key,
    required this.env,
    required this.onOpen,
    required this.onDelete,
  });

  final Environment env;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  State<_EnvRow> createState() => _EnvRowState();
}

class _EnvRowState extends State<_EnvRow> {
  late final TextEditingController _rename;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _rename = TextEditingController(text: widget.env.name);
    _focusNode = FocusNode();
    // Commit on blur — handles the case where the user taps elsewhere
    // without pressing Enter (the most common rename pattern).
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commitRename();
    });
  }

  @override
  void didUpdateWidget(covariant _EnvRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External renames (or a different env scrolling into this slot) need
    // to refresh the controller — but ONLY when the field isn't focused,
    // so we don't yank the cursor while the user is typing.
    if (widget.env.name != _rename.text && !_focusNode.hasFocus) {
      _rename.text = widget.env.name;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _rename.dispose();
    super.dispose();
  }

  void _commitRename() {
    final next = _rename.text.trim();
    if (next.isEmpty || next == widget.env.name) {
      // Empty fall-back — restore the previous name so the field never
      // shows blank (the server would reject empty anyway).
      _rename.text = widget.env.name;
      return;
    }
    context
        .read<VaultCubit>()
        .updateEnvironment(id: widget.env.id, name: next);
  }

  Future<void> _onLiveChanged(bool value) async {
    // Lifting the gate (true → false) is one-tap; setting it (false →
    // true) needs explicit confirmation because the chat surface will
    // start gating first sends from this moment on.
    if (!value) {
      unawaited(context
          .read<VaultCubit>()
          .updateEnvironment(id: widget.env.id, isLive: false));
      return;
    }
    final ok = await ConfirmDialog.show(
      context,
      title: context.tr.markEnvLiveTitle,
      body: context.tr.markEnvLiveBody(widget.env.name),
      confirmLabel: context.tr.markAsLive,
      destructive: true,
      icon: AppIcons.shieldAlert,
    );
    if (!ok || !mounted) return;
    unawaited(context
        .read<VaultCubit>()
        .updateEnvironment(id: widget.env.id, isLive: true));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final cubit = context.read<VaultCubit>();
    final env = widget.env;
    final credCount = context.select<VaultCubit, int>(
      (c) =>
          c.state.data.dataOrNull?.credentialsByEnv[env.id]?.length ?? 0,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 12),
        decoration: BoxDecoration(
          color: s.surface2.withValues(alpha: context.isDark ? 0.5 : 0.85),
          borderRadius: AppRadius.cardR,
          border: Border.all(
            // Live envs get a subtle danger border so they're scannable
            // in a long project list. The web does the same via
            // `env-row--live`.
            color: env.isLive
                ? s.danger.withValues(alpha: 0.40)
                : s.cardBorder,
            width: env.isLive ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Line 1: env name (editable), full width ──────────────
            //
            // The name and the two flags used to share one `Row`, with the
            // field in an `Expanded`. That overflowed by 15 px at 320 px:
            // `Expanded` shrinks to zero but no further, and "Live" +
            // "Read-only" — each a `Text` in a `mainAxisSize.min` Row, so
            // neither wraps nor ellipsizes — are together wider than the card.
            // No amount of flex on the field could have absorbed it.
            //
            // Giving the field the whole line is also the better layout for
            // what it holds: these are Odoo instance names, routinely 50+
            // characters, and it is an editable field rather than a label.
            _InlineNameField(
              controller: _rename,
              focusNode: _focusNode,
              onSubmitted: (_) {
                _commitRename();
                _focusNode.unfocus();
              },
            ),
            const SizedBox(height: 8),
            // ── Line 2: the two env flags, flowing ──────────────────
            //
            // `Wrap` rather than `Row` for the same reason as the action band
            // below: at 320 px in Arabic the pair does not fit on one line,
            // and a checkbox label that ellipsizes to "Read-o…" is worse than
            // one that moves down a line.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 4,
              children: [
                _FlagCheckbox(
                  label: context.tr.flagLive,
                  value: env.isLive,
                  activeColor: s.danger,
                  onChanged: _onLiveChanged,
                ),
                _FlagCheckbox(
                  label: context.tr.flagReadOnly,
                  value: env.readOnly,
                  activeColor: s.muted,
                  onChanged: (v) =>
                      cubit.updateEnvironment(id: env.id, readOnly: v),
                ),
              ],
            ),
            // ── Credential count chip — only when count > 0 ────────
            if (credCount > 0) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: Row(
                  children: [
                    Icon(AppIcons.key, size: 11, color: s.muted),
                    const SizedBox(width: 4),
                    Text(
                      context.tr.credentialCount(credCount),
                      style: context.text.labelSmall?.copyWith(
                        color: s.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            // ── Row 2: Auto-approve + Open + Delete ─────────────────
            // Wrap (not Row) so on narrow phones the action buttons
            // can flow to a second line instead of overflowing. The
            // checkbox keeps the start side, Open + Delete sit on the
            // end via the inner Row — they read as a single action
            // group regardless of whether the line wrapped.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _FlagCheckbox(
                  label: context.tr.flagAutoApprove,
                  value: env.autoApprove,
                  activeColor: s.warning,
                  onChanged: (v) =>
                      cubit.updateEnvironment(id: env.id, autoApprove: v),
                ),
                // A `Wrap`, not a `Row`. The outer `Wrap` hands this child a
                // maxWidth equal to its own, so a `Row(mainAxisSize: min)`
                // here was still 2.8 px too wide at 320 px once the two
                // buttons had taken their natural size — the outer wrap could
                // move the group to a second run, but nothing could split the
                // group itself. Nesting a `Wrap` lets Delete fall under Open
                // on the narrowest phones while they stay side by side
                // everywhere else.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PrimaryButton(
                      label: context.tr.openEnvironment,
                      minHeight: 36,
                      onPressed: widget.onOpen,
                    ),
                    GhostButton(
                      label: context.tr.delete,
                      minHeight: 36,
                      tone: GhostButtonTone.danger,
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact search bar surfaced above the env list once it grows past
/// the visual-scan threshold. Mirrors the chat-search pattern (search
/// icon + clear button + dim hint).
class _EnvSearchField extends StatelessWidget {
  const _EnvSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface2.withValues(alpha: context.isDark ? 0.5 : 0.85),
        borderRadius: AppRadius.buttonR,
        border: Border.all(color: s.cardBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: context.text.bodySmall,
        decoration: InputDecoration(
          hintText: context.tr.envSearchHint,
          hintStyle: context.text.bodySmall?.copyWith(color: s.muted),
          prefixIcon: Icon(AppIcons.search, size: 16, color: s.muted),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(AppIcons.close, size: 14, color: s.muted),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  visualDensity: VisualDensity.compact,
                  tooltip: context.tr.clearSearch,
                ),
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

/// Always-editable env-name field. Renders as plain bold text until the
/// user taps; tapping focuses + shows a subtle underline so the user
/// knows it's editable. Submit + blur both commit via the parent.
class _InlineNameField extends StatelessWidget {
  const _InlineNameField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      style: context.text.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      cursorColor: s.brandCyan,
      decoration: InputDecoration(
        isCollapsed: true,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.transparent),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.transparent),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: s.brandCyan, width: 1.4),
        ),
      ),
    );
  }
}

/// Tick-style flag — square Material checkbox + label, hit-target
/// extends across the whole row so the user can tap the label too.
/// Replaces the previous Switch-based design — checkboxes mirror the
/// web and read as "tick what applies" instead of "flip a gate".
class _FlagCheckbox extends StatelessWidget {
  const _FlagCheckbox({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: AppRadius.microR,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: activeColor,
                side: BorderSide(color: s.cardBorder, width: 1.4),
              ),
            ),
            const SizedBox(width: 6),
            // `Flexible`, because a `Row` hands a non-flex child unbounded
            // main-axis width — so this label neither wrapped nor ellipsized
            // however narrow the phone, and a single checkbox overflowed by
            // 14 px at 320 px in Arabic at 1.4× text. Putting the pair of them
            // in a `Wrap` above fixed the pair; it could not fix one child
            // that is wider than the line it sits on.
            //
            // It wraps rather than ellipsizes on purpose: this is a control's
            // label, and "قراءة فق…" leaves the user guessing what they are
            // about to toggle on a live Odoo instance.
            Flexible(
              child: Text(
                label,
                style: context.text.labelMedium?.copyWith(
                  color: value ? activeColor : s.text,
                  fontWeight: value ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
