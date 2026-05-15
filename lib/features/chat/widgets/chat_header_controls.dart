import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../demo/saqqar_demo_data.dart';
import '../../vault/state/vault_controller.dart';

/// Three-control header strip mirroring the web's chat header:
///
///   [ Auto-approve toggle ] [ Project ▼ ] [ Environment ▼ ]
///
/// Sits between the AppBar and the message list. Project dropdown is
/// always enabled (or shows "— No projects yet —" when empty). Environment
/// dropdown is disabled until a project is picked and reads "Pick a
/// project first" in that state. Picking a project resets the environment
/// to null so the user re-selects within the new project's envs. Matches
/// `onProjectChange()` / `onEnvironmentChange()` in `app.js`.
class ChatHeaderControls extends ConsumerWidget {
  const ChatHeaderControls({
    super.key,
    required this.projectId,
    required this.environmentId,
    required this.autoApprove,
    required this.onProjectChanged,
    required this.onEnvironmentChanged,
    required this.onAutoApproveChanged,
  });

  final String? projectId;
  final String? environmentId;
  final bool autoApprove;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<String?> onEnvironmentChanged;
  final ValueChanged<bool> onAutoApproveChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.saqqar;
    final vault = ref.watch(vaultControllerProvider);
    final projects = vault.projects;
    final envs = projectId == null
        ? const <DemoEnvironment>[]
        : vault.environmentsForProject(projectId!);

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Auto-approve — compact icon button. Tooltip + colour change
            // already convey on/off; the eyebrow label "AUTO-APPROVE" was
            // dropped to free up horizontal space for the env dropdown.
            _AutoApproveIconToggle(
              value: autoApprove,
              onChanged: onAutoApproveChanged,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StackedControl(
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
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StackedControl(
                label: context.tr.headerEnvironment,
                child: _DropdownPill(
                  enabled: projectId != null,
                  hint: projectId == null
                      ? context.tr.pickProjectFirst
                      : (envs.isEmpty
                          ? context.tr.noEnvironmentsForProject
                          : context.tr.headerNoneOption),
                  value: environmentId,
                  items: [
                    for (final e in envs)
                      _DropdownItem(value: e.id, label: e.name),
                  ],
                  onChanged: onEnvironmentChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact 36×36 toggle that flips Auto-approve on/off. Uses a shield icon
/// (filled when on, outlined when off) tinted brand-cyan. Replaces the
/// labeled `AUTO-APPROVE` slot to save horizontal space on phone widths.
class _AutoApproveIconToggle extends StatelessWidget {
  const _AutoApproveIconToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final color = value ? s.brandCyan : s.muted;
    return Tooltip(
      message: value ? context.tr.autoApproveOn : context.tr.autoApproveOff,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.buttonR,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: AppRadius.buttonR,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: value
                  ? s.brandCyan.withValues(alpha: 0.14)
                  : s.surface2.withValues(alpha: context.isDark ? 0.55 : 0.92),
              borderRadius: AppRadius.buttonR,
              border: Border.all(
                color: value ? s.brandCyan.withValues(alpha: 0.40) : s.cardBorder,
              ),
            ),
            child: Icon(
              value ? AppIcons.shieldCheck : AppIcons.shield,
              size: 18,
              color: color,
            ),
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
