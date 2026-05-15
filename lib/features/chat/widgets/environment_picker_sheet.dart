import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../demo/saqqar_demo_data.dart';
import 'chat_sheet.dart';

/// Bottom sheet that lists every project and its environments. Tapping an
/// environment returns its id via Navigator.pop. Mirrors the project +
/// environment selectors visible in the web header at saqqaar.com.
///
/// Tapping the "No environment" row returns an empty string so the chat
/// screen can clear the active env.
class EnvironmentPickerSheet extends StatelessWidget {
  const EnvironmentPickerSheet({
    super.key,
    required this.selectedEnvironmentId,
  });

  final String? selectedEnvironmentId;

  static Future<String?> show(
    BuildContext context, {
    required String? selectedEnvironmentId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => EnvironmentPickerSheet(
        selectedEnvironmentId: selectedEnvironmentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return ChatSheet(
      title: context.tr.pickEnvironment,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
          child: Text(
            context.tr.pickEnvironmentSubtitle,
            style: context.text.bodySmall?.copyWith(color: s.muted, height: 1.4),
          ),
        ),
        _NoneRow(
          selected: selectedEnvironmentId == null ||
              selectedEnvironmentId!.isEmpty ||
              selectedEnvironmentId == 'none',
          onTap: () => Navigator.of(context).pop(''),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Divider(color: s.border, height: 1),
        ),
        for (final project in demoProjects) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              project.name.toUpperCase(),
              style: context.text.labelSmall?.copyWith(
                color: s.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                fontSize: 10,
              ),
            ),
          ),
          for (final env in demoEnvironmentsForProject(project.id))
            _EnvRow(
              env: env,
              project: project,
              selected: env.id == selectedEnvironmentId,
              onTap: () => Navigator.of(context).pop(env.id),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _NoneRow extends StatelessWidget {
  const _NoneRow({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.muted.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(AppIcons.close, size: 18, color: s.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr.noEnvironmentPicked,
                      style: context.text.titleSmall?.copyWith(color: s.muted),
                    ),
                    Text(
                      context.tr.credentialNoneHint,
                      style: context.text.bodySmall?.copyWith(color: s.muted),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(AppIcons.check, color: s.brandCyan),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnvRow extends StatelessWidget {
  const _EnvRow({
    required this.env,
    required this.project,
    required this.selected,
    required this.onTap,
  });

  final DemoEnvironment env;
  final DemoProject project;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final iconColor = env.isLive ? s.danger : s.brandCyan;
    final iconBg = env.isLive
        ? s.danger.withValues(alpha: 0.12)
        : s.brandCyan.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(AppIcons.server, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(env.name, style: context.text.titleSmall),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (env.isLive) MiniChip(context.tr.liveBadge, color: s.danger),
                        if (env.readOnly)
                          MiniChip(context.tr.readOnlyBadge, color: s.muted),
                        if (env.autoApprove)
                          MiniChip(context.tr.autoApproveBadge, color: s.warning),
                        Text(
                          '${env.credentialNames.length} ${context.tr.credentials}',
                          style: context.text.bodySmall?.copyWith(color: s.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (selected) Icon(AppIcons.check, color: s.brandCyan),
            ],
          ),
        ),
      ),
    );
  }
}
