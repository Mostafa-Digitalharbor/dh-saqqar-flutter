import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../vault/data/project_models.dart';
import '../../vault/view_model/vault_cubit.dart';
import 'environment_multi_select_sheet.dart';
import '../../../shared/widgets/tappable_surface.dart';

/// Two-dropdown header strip — Project + Environment pickers only.
///
///   [ Project ▼ ] [ Environment ▼ ]
///
/// The Deep think + Auto-approve toggles used to ride alongside but moved
/// to the AppBar actions (see [ChatAppBarToggles]) on 2026-05-16: at phone
/// widths the four-control strip squeezed the env dropdown into 2–3
/// characters of label space, which broke discoverability. Splitting the
/// strip (pickers stay below the AppBar; toggles go up top) gives each
/// dropdown ~50% of the row.
///
/// Project dropdown is always enabled (or shows "— No projects yet —" when
/// empty). Environment dropdown is disabled until a project is picked and
/// reads "Pick a project first" in that state. Picking a project resets
/// the environment to null so the user re-selects within the new project's
/// envs. Matches `onProjectChange()` / `onEnvironmentChange()` in `app.js`.
class ChatHeaderControls extends StatelessWidget {
  const ChatHeaderControls({
    super.key,
    required this.projectId,
    required this.environmentId,
    required this.selectedEnvironmentIds,
    required this.onProjectChanged,
    required this.onEnvironmentsChanged,
    required this.onCreateEnvironmentRequested,
    required this.onCreateProjectRequested,
  });

  final String? projectId;

  /// Primary bound environment — drives the pill label and project
  /// coherence. Its project is the one whose envs the sheet groups under
  /// first, and it's the env the send-gate reads.
  final String? environmentId;

  /// Full set of environments bound to the conversation (primary included).
  /// A conversation can carry more than one, mirroring the web's multi-select
  /// environment dropdown. The pill shows the primary + "+N more".
  final List<String> selectedEnvironmentIds;

  final ValueChanged<String?> onProjectChanged;

  /// Fired with the full set of checked environment ids when the user
  /// applies a selection in [EnvironmentMultiSelectSheet]. An empty list
  /// clears all bindings.
  final ValueChanged<List<String>> onEnvironmentsChanged;

  /// Fired when the user taps the environment slot while the selected
  /// project has no environments yet. The chat screen wires this to a
  /// confirm dialog → ProjectDetailSheet so the user can add an env
  /// without leaving the chat tab.
  final ValueChanged<String> onCreateEnvironmentRequested;

  /// Fired when the user taps the project slot while they have NO projects
  /// at all (brand-new account). The chat screen wires this to the
  /// "Use My Database" one-click — it creates a default project + production
  /// environment server-side and selects it, so the user can start chatting
  /// without manually building the Vault hierarchy first.
  final VoidCallback onCreateProjectRequested;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final vault = context.watch<VaultCubit>().state;
    final data = vault.data.dataOrNull;
    final projects = data?.projects ?? const <Project>[];
    final envs = (projectId == null || data == null)
        ? const <Environment>[]
        : data.environmentsForProject(projectId!);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface.withValues(
          alpha: context.alpha(AppAlphaPairs.panelHeader),
        ),
        border: Border(bottom: BorderSide(color: s.border)),
      ),
      child: ResponsiveContent(
        maxWidth: AppLayoutWidths.chatShell,
        // Compact strip — eyebrow labels moved inline with the dropdown
        // (left-side mini caption inside the pill) so the strip height
        // drops to ~46 px total and the dropdowns stay side-by-side at
        // every width. Earlier revision stacked them on phones ≤340 px,
        // which testers (2026-05-23) flagged as eating too much vertical
        // space — chat surface gets the height back here.
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s10,
          AppSpacing.s6,
          AppSpacing.s10,
          AppSpacing.s8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              // Brand-new account with zero projects: swap the disabled
              // "— No projects yet —" dropdown for a "Use My Database" CTA
              // that creates a default project + prod env in one tap, so the
              // user is guided into a usable state instead of hitting a dead
              // end. Mirrors the env slot's create pill below.
              child: projects.isEmpty
                  ? _CreateCtaPill(
                      icon: AppIcons.database,
                      label: context.tr.envHintUseMyDatabase,
                      onTap: onCreateProjectRequested,
                    )
                  : _DropdownPill(
                      caption: context.tr.headerProject,
                      enabled: true,
                      hint: context.tr.headerNoneOption,
                      value: projectId,
                      items: [
                        for (final p in projects)
                          _DropdownItem(value: p.id, label: p.name),
                      ],
                      onChanged: onProjectChanged,
                    ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              // When the selected project has no envs, swap the
              // dropdown for a tappable "+ Add environment" pill so
              // the user can land in the env creation flow without
              // backtracking out of the chat.
              child: (projectId != null && envs.isEmpty)
                  ? _CreateCtaPill(
                      icon: AppIcons.plus,
                      label: context.tr.createEnvironmentCta,
                      onTap: () => onCreateEnvironmentRequested(projectId!),
                    )
                  : _MultiEnvPill(
                      caption: context.tr.headerEnvironment,
                      enabled: projectId != null,
                      hint: projectId == null
                          ? context.tr.pickProjectFirst
                          : context.tr.headerNoneOption,
                      primaryLabel: environmentId == null
                          ? null
                          : data?.environmentById(environmentId!)?.name,
                      extraCount: selectedEnvironmentIds
                          .where((id) => id != environmentId)
                          .length,
                      onTap: () async {
                        final result = await EnvironmentMultiSelectSheet.show(
                          context,
                          projectId: projectId,
                          selectedEnvironmentIds: selectedEnvironmentIds,
                        );
                        if (result != null) onEnvironmentsChanged(result);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bundle of the chat-level toggles sized for the AppBar actions slot.
/// Renders them as a group so the AppBar code only carries one widget per
/// chat regardless of how many toggles ship later. Tap targets stay 36×36 —
/// Material's minimum recommended.
///
/// Deep think used to sit beside auto-approve here; it was removed with the
/// rest of the deep-think surface (web parity — the backend now escalates
/// hard tasks to the stronger model on its own, with no manual toggle).
///
/// Lives in the AppBar (not the dropdown strip) so the dropdowns get the
/// full row width on small phones — see the rationale on
/// [ChatHeaderControls].
class ChatAppBarToggles extends StatelessWidget {
  const ChatAppBarToggles({
    super.key,
    required this.autoApprove,
    required this.onAutoApproveChanged,
  });

  final bool autoApprove;
  final ValueChanged<bool> onAutoApproveChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChatToggleIcon(
          value: autoApprove,
          onChanged: onAutoApproveChanged,
          icon: autoApprove ? AppIcons.shieldCheck : AppIcons.shield,
          accent: context.saqqar.brandCyan,
          tooltipOn: context.tr.autoApproveOn,
          tooltipOff: context.tr.autoApproveOff,
        ),
      ],
    );
  }
}

/// Compact AppBar-sized icon toggle. Shared shape for Deep think +
/// Auto-approve so the two read as a pair.
class _ChatToggleIcon extends StatelessWidget {
  const _ChatToggleIcon({
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.accent,
    required this.tooltipOn,
    required this.tooltipOff,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final Color accent;
  final String tooltipOn;
  final String tooltipOff;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Tooltip(
      message: value ? tooltipOn : tooltipOff,
      child: TappableSurface(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: Container(
          width: AppBoxSizes.headerControl,
          height: AppBoxSizes.headerControl,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: value
                ? accent.withValues(alpha: AppAlphas.a14)
                : Colors.transparent,
            borderRadius: AppRadius.buttonR,
            border: Border.all(
              color: value
                  ? accent.withValues(alpha: AppAlphas.a40)
                  : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            size: AppIconSizes.regular,
            color: value ? accent : s.muted,
          ),
        ),
      ),
    );
  }
}

class _DropdownItem {
  const _DropdownItem({required this.value, required this.label});
  final String value;
  final String label;
}

/// CTA-styled pill rendered in place of a dropdown when the next action is
/// to *create* something rather than pick it:
///   * project slot, brand-new account with no projects → "Use My Database"
///   * env slot, selected project has no environments → "+ Add environment"
///
/// Tapping fires [onTap]. Visually styled to match the dropdown's footprint
/// (same height + border radius) so the row geometry doesn't jump when the
/// picker state changes.
class _CreateCtaPill extends StatelessWidget {
  const _CreateCtaPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return TappableSurface(
      onTap: onTap,
      child: Container(
        height: AppControlSizes.headerControlHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
        decoration: BoxDecoration(
          // Brand-cyan tinted fill so the "this is the next thing to
          // do" CTA visually pops vs. the muted disabled dropdown
          // state it replaces.
          color: s.brandCyan.withValues(alpha: AppAlphas.a12),
          borderRadius: AppRadius.buttonR,
          border: Border.all(
            color: s.brandCyan.withValues(alpha: AppAlphas.a40),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppIconSizes.small, color: s.brandCyan),
            const SizedBox(width: AppSpacing.s6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(
                  color: s.brandCyan,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Environment slot rendered as a multi-select trigger (not a dropdown):
/// tapping opens [EnvironmentMultiSelectSheet] so the conversation can bind
/// to several environments at once. Matches the dropdown's footprint (same
/// height + radius) so the row geometry stays put.
///
/// The label reads "Environment · primary-name" plus a "+N" chip when extra
/// environments are bound, or the [hint] when nothing is selected.
class _MultiEnvPill extends StatelessWidget {
  const _MultiEnvPill({
    required this.caption,
    required this.enabled,
    required this.hint,
    required this.primaryLabel,
    required this.extraCount,
    required this.onTap,
  });

  final String caption;
  final bool enabled;
  final String hint;
  final String? primaryLabel;
  final int extraCount;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final hasSelection = primaryLabel != null && primaryLabel!.isNotEmpty;
    return TappableSurface(
      onTap: enabled ? onTap : null,
      child: Container(
        height: AppControlSizes.headerControlHeight,
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.s10,
          0,
          AppSpacing.s10,
          0,
        ),
        decoration: BoxDecoration(
          color: s.surface2.withValues(
            alpha: context.alpha(AppAlphaPairs.panelSheet),
          ),
          borderRadius: AppRadius.buttonR,
          border: Border.all(
            color: enabled
                ? s.cardBorder
                : s.cardBorder.withValues(alpha: AppAlphas.a40),
          ),
        ),
        child: Row(
          children: [
            // `Flexible`, not a bare `Text`. A `Row` lays its NON-flexible
            // children out first against an unbounded main-axis constraint,
            // so a bare caption takes its full intrinsic width and leaves the
            // `Expanded` beside it whatever is left — which is negative on a
            // 320 px phone, where each pill only gets ~146 px. It overflowed
            // by 50 px in English at 1.0× text, i.e. the mildest cell in the
            // matrix, whenever the vault had no project selected.
            //
            // Loose fit rather than `Expanded`: at normal widths the caption
            // still takes its natural size and the value keeps the rest, so
            // this only changes what happens once there genuinely is not room.
            Flexible(
              child: Text(
                '$caption · ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: s.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: AppFontSizes.caption,
                ),
              ),
            ),
            Expanded(
              child: Text(
                hasSelection ? primaryLabel! : hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  color: hasSelection ? (enabled ? s.text : s.muted) : s.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: AppFontSizes.dense,
                ),
              ),
            ),
            if (extraCount > 0) ...[
              const SizedBox(width: AppSpacing.s6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s6,
                  vertical: AppSpacing.s2,
                ),
                decoration: BoxDecoration(
                  color: s.brandCyan.withValues(alpha: AppAlphas.a14),
                  borderRadius: AppRadius.pillR,
                ),
                child: Text(
                  '+$extraCount',
                  style: context.text.labelSmall?.copyWith(
                    color: s.brandCyan,
                    fontWeight: FontWeight.w800,
                    fontSize: AppFontSizes.caption,
                  ),
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.s4),
            Icon(
              AppIcons.chevronDown,
              size: AppIconSizes.small,
              color: enabled ? s.text : s.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact pill-styled dropdown — Material's [DropdownButton] under the hood,
/// reskinned to match the existing chat-header chips.
///
/// [caption] renders as a small inline eyebrow at the start of the pill
/// (e.g. "Project · Mostafa"). It replaces the old stacked "PROJECT" /
/// "ENVIRONMENT" labels above each dropdown — same information, half the
/// vertical space, so the two pickers fit side-by-side even on narrow
/// phones without the header eating into the message list.
class _DropdownPill extends StatelessWidget {
  const _DropdownPill({
    required this.caption,
    required this.enabled,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String caption;
  final bool enabled;
  final String hint;
  final String? value;
  final List<_DropdownItem> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    // Guarantee the current `value` exists in the items list — otherwise
    // DropdownButton throws. Pass null when missing so the hint shows.
    final hasValue = value != null && items.any((i) => i.value == value);
    return Container(
      height: AppControlSizes.headerControlHeight,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.s10,
        0,
        AppSpacing.s10,
        0,
      ),
      decoration: BoxDecoration(
        color: s.surface2.withValues(
          alpha: context.alpha(AppAlphaPairs.panelSheet),
        ),
        borderRadius: AppRadius.buttonR,
        border: Border.all(
          color: enabled
              ? s.cardBorder
              : s.cardBorder.withValues(alpha: AppAlphas.a40),
        ),
      ),
      child: Row(
        children: [
          // Flexible for the same reason as `_MultiEnvPill`'s caption above:
          // a bare `Text` here is laid out unbounded and squeezes the
          // `Expanded` beside it into negative space on a narrow phone.
          Flexible(
            child: Text(
              '$caption · ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                color: s.muted,
                fontWeight: FontWeight.w700,
                fontSize: AppFontSizes.caption,
              ),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: hasValue ? value : null,
                hint: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: s.muted),
                ),
                icon: Icon(
                  AppIcons.chevronDown,
                  size: AppIconSizes.small,
                  color: enabled ? s.text : s.muted,
                ),
                style: context.text.bodyMedium?.copyWith(
                  color: enabled ? s.text : s.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: AppFontSizes.dense,
                ),
                dropdownColor: s.surface,
                borderRadius: AppRadius.buttonR,
                onChanged: enabled ? onChanged : null,
                items: [
                  for (final item in items)
                    DropdownMenuItem<String>(
                      value: item.value,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
