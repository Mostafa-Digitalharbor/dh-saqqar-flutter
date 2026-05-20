import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/extensions/responsive_breakpoints.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../vault/data/project_models.dart';
import '../../vault/view_model/vault_cubit.dart';

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
    required this.onProjectChanged,
    required this.onEnvironmentChanged,
    required this.onCreateEnvironmentRequested,
  });

  final String? projectId;
  final String? environmentId;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<String?> onEnvironmentChanged;

  /// Fired when the user taps the environment slot while the selected
  /// project has no environments yet. The chat screen wires this to a
  /// confirm dialog → ProjectDetailSheet so the user can add an env
  /// without leaving the chat tab.
  final ValueChanged<String> onCreateEnvironmentRequested;

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
        color: s.surface.withValues(alpha: context.isDark ? 0.62 : 0.95),
        border: Border(bottom: BorderSide(color: s.border)),
      ),
      child: ResponsiveContent(
        maxWidth: 980,
        // Tighter padding than the original — total strip height is now
        // ~52 px instead of ~74 px so the chat gets ~22 px more for
        // messages without losing the project/env discoverability.
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final projectControl = _StackedControl(
              label: context.tr.headerProject,
              child: _DropdownPill(
                enabled: projects.isNotEmpty,
                hint: projects.isEmpty
                    ? context.tr.noProjectsYet
                    : context.tr.headerNoneOption,
                value: projectId,
                items: [
                  for (final p in projects)
                    _DropdownItem(value: p.id, label: p.name),
                ],
                onChanged: onProjectChanged,
              ),
            );
            final envControl = _StackedControl(
              label: context.tr.headerEnvironment,
              // When the selected project has no envs, swap the
              // dropdown (which would render empty + non-functional)
              // for a tappable "+ Add environment" pill that routes
              // the user to the env creation flow. Dropdown stays for
              // every other case.
              child: (projectId != null && envs.isEmpty)
                  ? _CreateEnvironmentPill(
                      onTap: () =>
                          onCreateEnvironmentRequested(projectId!),
                    )
                  : _DropdownPill(
                      enabled: projectId != null,
                      hint: projectId == null
                          ? context.tr.pickProjectFirst
                          : context.tr.headerNoneOption,
                      value: environmentId,
                      items: [
                        for (final e in envs)
                          _DropdownItem(value: e.id, label: e.name),
                      ],
                      onChanged: onEnvironmentChanged,
                    ),
            );
            // On the `tiny` tier (≤340 px), two 50% dropdowns leave each
            // side ~155 px — long Arabic project/env names get chopped
            // aggressively. Stack vertically below the breakpoint so
            // each control has the full strip width; the resulting
            // ~22 px of extra header height is acceptable on tiny phones.
            if (breakpointForWidth(constraints.maxWidth).isTinyOrBelow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  projectControl,
                  const SizedBox(height: 8),
                  envControl,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: projectControl),
                const SizedBox(width: 8),
                Expanded(child: envControl),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Bundle of the two chat-level toggles (Deep think + Auto-approve) sized
/// for the AppBar actions slot. Renders them as a pair so the AppBar code
/// only carries one widget per chat regardless of how many toggles ship
/// later. Tap targets stay 36×36 — Material's minimum recommended.
///
/// Lives in the AppBar (not the dropdown strip) so the dropdowns get the
/// full row width on small phones — see the rationale on
/// [ChatHeaderControls].
class ChatAppBarToggles extends StatelessWidget {
  const ChatAppBarToggles({
    super.key,
    required this.deepThink,
    required this.autoApprove,
    required this.onDeepThinkChanged,
    required this.onAutoApproveChanged,
  });

  final bool deepThink;
  final bool autoApprove;
  final ValueChanged<bool> onDeepThinkChanged;
  final ValueChanged<bool> onAutoApproveChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChatToggleIcon(
          value: deepThink,
          onChanged: onDeepThinkChanged,
          icon: AppIcons.sparkles,
          accent: context.saqqar.brandPurple,
          tooltipOn: context.tr.deepThinkOn,
          tooltipOff: context.tr.deepThinkTitle,
        ),
        const SizedBox(width: 4),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.buttonR,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!value);
          },
          borderRadius: AppRadius.buttonR,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: value
                  ? accent.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: AppRadius.buttonR,
              border: Border.all(
                color: value
                    ? accent.withValues(alpha: 0.40)
                    : Colors.transparent,
              ),
            ),
            child: Icon(icon, size: 18, color: value ? accent : s.muted),
          ),
        ),
      ),
    );
  }
}

/// Eyebrow label + control stacked vertically — mirrors the web's
/// `PROJECT` / `ENVIRONMENT` labels above each dropdown.
class _StackedControl extends StatelessWidget {
  const _StackedControl({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            color: s.muted,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _DropdownItem {
  const _DropdownItem({required this.value, required this.label});
  final String value;
  final String label;
}

/// CTA-styled pill rendered in place of the env dropdown when the
/// selected project has no environments yet. Tapping fires
/// [ChatHeaderControls.onCreateEnvironmentRequested] — the chat screen
/// pops a confirm dialog → ProjectDetailSheet so the user can add an
/// env without losing their place in the chat.
///
/// Visually styled to match the dropdown's footprint (same height +
/// border radius) so the row geometry doesn't jump when the project
/// picker changes.
class _CreateEnvironmentPill extends StatelessWidget {
  const _CreateEnvironmentPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.buttonR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.buttonR,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            // Brand-cyan tinted fill so the "this is the next thing to
            // do" CTA visually pops vs. the muted disabled dropdown
            // state it replaces.
            color: s.brandCyan.withValues(alpha: 0.12),
            borderRadius: AppRadius.buttonR,
            border: Border.all(
              color: s.brandCyan.withValues(alpha: 0.40),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(AppIcons.plus, size: 16, color: s.brandCyan),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.tr.createEnvironmentCta,
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
      ),
    );
  }
}

/// Compact pill-styled dropdown — Material's [DropdownButton] under the hood,
/// reskinned to match the existing chat-header chips.
class _DropdownPill extends StatelessWidget {
  const _DropdownPill({
    required this.enabled,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

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
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: s.surface2.withValues(alpha: context.isDark ? 0.55 : 0.92),
        borderRadius: AppRadius.buttonR,
        border: Border.all(
          color: enabled ? s.cardBorder : s.cardBorder.withValues(alpha: 0.4),
        ),
      ),
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
            size: 16,
            color: enabled ? s.text : s.muted,
          ),
          style: context.text.bodyMedium?.copyWith(
            color: enabled ? s.text : s.muted,
            fontWeight: FontWeight.w600,
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
    );
  }
}
