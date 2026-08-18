import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../data/chat_features.dart';
import 'chat_sheet.dart';
import '../../../shared/widgets/tappable_surface.dart';
import '../../../shared/widgets/sheet_action_row.dart';

/// What the user picked out of the Saqqar tools sheet. Toggles are NOT in
/// here — they flip in place and report through the sheet's callbacks, so
/// the user can set a mode and pick an action in one visit.
enum SaqqarTool {
  /// Upload a file — same picker the composer paperclip opens.
  uploadFile,

  /// Saved prompt / task-wording entry (web `prompt_bank`).
  promptBank,

  /// Slash commands — quick Odoo ops. Mobile-only: this used to be a loose
  /// `/` button in the composer action row, which the web has no equivalent
  /// for. Folded in here so the action row keeps only the two hot controls.
  commands,

  /// §6 — read-only scans. Each calls its own endpoint (`/radar/run/`,
  /// `/whatif/intro/`, `/pulse/run/`), which posts the report into the
  /// conversation; see [ChatFeatures.healthRadar].
  healthRadar,
  whatIf,
  businessPulse,

  /// §8 — the support workspace. Opens a screen, not a dialer.
  voiceSupport,

  /// The bound Odoo environment for this chat.
  myDatabase,

  /// Saqqar Apps gallery.
  apps,

  /// Credential vault / Projects.
  credentialVault,
}

/// The composer's `+` menu — web parity for `renderShadowMenu`.
///
/// A bottom sheet, deliberately, not a port of the web's `positionShadowMenu`
/// popover math: on touch the sheet is the idiom, and it can hold the two
/// mode toggles at a comfortable tap size.
///
/// Rows that are already first-class mobile screens (Apps, Projects/Vault,
/// the environment picker) LINK to them rather than reimplementing them.
///
/// Every row is feature-gated through [ChatFeatures]; an off/absent flag
/// omits the row, and a section with no surviving rows omits its header too.
class SaqqarToolsSheet extends StatefulWidget {
  const SaqqarToolsSheet({
    super.key,
    required this.features,
    required this.taskPrep,
    required this.autoApprove,
    required this.onTaskPrepChanged,
    required this.onAutoApproveChanged,
  });

  final ChatFeatures features;
  final bool taskPrep;
  final bool autoApprove;
  final ValueChanged<bool> onTaskPrepChanged;
  final ValueChanged<bool> onAutoApproveChanged;

  /// Opens the sheet. Resolves to the picked [SaqqarTool], or null when the
  /// user only flipped toggles / dismissed.
  static Future<SaqqarTool?> show(
    BuildContext context, {
    required ChatFeatures features,
    required bool taskPrep,
    required bool autoApprove,
    required ValueChanged<bool> onTaskPrepChanged,
    required ValueChanged<bool> onAutoApproveChanged,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<SaqqarTool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SaqqarToolsSheet(
        features: features,
        taskPrep: taskPrep,
        autoApprove: autoApprove,
        onTaskPrepChanged: onTaskPrepChanged,
        onAutoApproveChanged: onAutoApproveChanged,
      ),
    );
  }

  @override
  State<SaqqarToolsSheet> createState() => _SaqqarToolsSheetState();
}

class _SaqqarToolsSheetState extends State<SaqqarToolsSheet> {
  /// Local mirrors so a toggle animates the instant it is tapped. The parent
  /// still owns the truth (and the PATCH / preference write); this only
  /// keeps the sheet from looking frozen while that round-trip lands.
  late bool _taskPrep = widget.taskPrep;
  late bool _autoApprove = widget.autoApprove;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final f = widget.features;

    final modes = <Widget>[
      if (f.promptBank)
        SheetActionRow(
          tint: context.saqqar.brandCyan,
          glyphColor: context.saqqar.brandCyan,
          showChevron: true,
          icon: AppIcons.sparkles,
          label: tr.toolsPromptBank,
          onTap: () => Navigator.of(context).pop(SaqqarTool.promptBank),
        ),
      if (f.taskPrepAvailable)
        _ToggleRow(
          icon: AppIcons.lightbulb,
          label: tr.taskPrep,
          subtitle: tr.taskPrepTitle,
          value: _taskPrep,
          onChanged: (v) {
            setState(() => _taskPrep = v);
            widget.onTaskPrepChanged(v);
          },
        ),
      _ToggleRow(
        icon: AppIcons.shieldCheck,
        label: tr.autoApprove,
        value: _autoApprove,
        onChanged: (v) {
          setState(() => _autoApprove = v);
          widget.onAutoApproveChanged(v);
        },
      ),
    ];

    // §6. Each row sends a read-only request into the conversation; there is
    // no endpoint to call (see [ChatFeatures.healthRadar]). Ordered as the
    // web orders them, with the mobile-only Commands row last so the shared
    // three read the same on both clients.
    final odooTools = <Widget>[
      if (f.healthRadar)
        SheetActionRow(
          tint: context.saqqar.brandCyan,
          glyphColor: context.saqqar.brandCyan,
          showChevron: true,
          icon: AppIcons.shieldCheck,
          label: tr.toolsHealthRadar,
          onTap: () => Navigator.of(context).pop(SaqqarTool.healthRadar),
        ),
      if (f.whatIf)
        SheetActionRow(
          tint: context.saqqar.brandCyan,
          glyphColor: context.saqqar.brandCyan,
          showChevron: true,
          icon: AppIcons.sparkles,
          label: tr.toolsWhatIf,
          onTap: () => Navigator.of(context).pop(SaqqarTool.whatIf),
        ),
      if (f.businessPulse)
        SheetActionRow(
          tint: context.saqqar.brandCyan,
          glyphColor: context.saqqar.brandCyan,
          showChevron: true,
          icon: AppIcons.bolt,
          label: tr.toolsBusinessPulse,
          onTap: () => Navigator.of(context).pop(SaqqarTool.businessPulse),
        ),
      SheetActionRow(
        tint: context.saqqar.brandCyan,
        glyphColor: context.saqqar.brandCyan,
        showChevron: true,
        icon: AppIcons.slash,
        label: tr.commands,
        onTap: () => Navigator.of(context).pop(SaqqarTool.commands),
      ),
    ];

    final connections = <Widget>[
      SheetActionRow(
        tint: context.saqqar.brandCyan,
        glyphColor: context.saqqar.brandCyan,
        showChevron: true,
        icon: AppIcons.database,
        label: tr.toolsMyDatabase,
        onTap: () => Navigator.of(context).pop(SaqqarTool.myDatabase),
      ),
      SheetActionRow(
        tint: context.saqqar.brandCyan,
        glyphColor: context.saqqar.brandCyan,
        showChevron: true,
        icon: AppIcons.grid,
        label: tr.appsTitle,
        onTap: () => Navigator.of(context).pop(SaqqarTool.apps),
      ),
      SheetActionRow(
        tint: context.saqqar.brandCyan,
        glyphColor: context.saqqar.brandCyan,
        showChevron: true,
        icon: AppIcons.projects,
        label: tr.credentialVault,
        onTap: () => Navigator.of(context).pop(SaqqarTool.credentialVault),
      ),
      // §8. Sits under Connections rather than Odoo tools because filing a
      // ticket reaches into the bound database the same way the other rows
      // here do, and because it is the one row that leaves the chat.
      if (f.voiceSupport)
        SheetActionRow(
          tint: context.saqqar.brandCyan,
          glyphColor: context.saqqar.brandCyan,
          showChevron: true,
          icon: AppIcons.shieldAlert,
          label: tr.toolsVoiceSupport,
          onTap: () => Navigator.of(context).pop(SaqqarTool.voiceSupport),
        ),
    ];

    return ChatSheet(
      title: tr.toolsTitle,
      children: [
        SheetActionRow(
          tint: context.saqqar.brandCyan,
          glyphColor: context.saqqar.brandCyan,
          showChevron: true,
          icon: AppIcons.attach,
          label: tr.toolsUploadFile,
          onTap: () => Navigator.of(context).pop(SaqqarTool.uploadFile),
        ),
        ..._section(context, tr.toolsModesSection, modes),
        ..._section(context, tr.toolsOdooSection, odooTools),
        ..._section(context, tr.toolsConnectSection, connections),
        const SizedBox(height: AppSpacing.s14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AppIcons.shield, size: AppIconSizes.compact, color: context.saqqar.muted),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                tr.toolsReadonlyNote,
                style: context.text.labelSmall?.copyWith(
                  color: context.saqqar.muted,
                  height: AppLineHeights.compact,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// A titled group, or nothing at all when every row in it was gated off.
  List<Widget> _section(BuildContext context, String title, List<Widget> rows) {
    if (rows.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s6,
          AppSpacing.s14,
          AppSpacing.s6,
          AppSpacing.s4,
        ),
        child: Text(
          title,
          style: context.text.labelSmall?.copyWith(
            color: context.saqqar.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: AppLetterSpacing.capsWide,
          ),
        ),
      ),
      ...rows,
    ];
  }
}

/// A mode row — flips in place instead of closing the sheet, so the user can
/// set a mode and then pick an action without reopening the menu.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final sub = subtitle;
    return TappableSurface(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s6,
          vertical: AppSpacing.s8,
        ),
        child: Row(
          children: [
            _ToolGlyph(icon: icon, active: value),
            const SizedBox(width: AppSpacing.s14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.text.bodyMedium?.copyWith(
                      color: s.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      sub,
                      style: context.text.bodySmall?.copyWith(
                        color: s.muted,
                        height: AppLineHeights.snug,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s10),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _ToolGlyph extends StatelessWidget {
  const _ToolGlyph({required this.icon, this.active = false});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final accent = active ? s.brandPurple : s.brandCyan;
    return Container(
      width: AppBoxSizes.sheetRow,
      height: AppBoxSizes.sheetRow,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: AppAlphas.a10),
      ),
      child: Icon(icon, size: AppIconSizes.regular, color: accent),
    );
  }
}
