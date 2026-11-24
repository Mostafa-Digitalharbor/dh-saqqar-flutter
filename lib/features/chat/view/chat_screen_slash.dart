part of 'chat_screen.dart';

/// The composer's slash-command sheet.
extension _ChatSlash on _ChatScreenState {
  /// Opens the slash-command menu (design parity: composer "/" button →
  /// a glass sheet of common Odoo quick-ops). Picking one seeds the
  /// composer with the command token + a trailing space so the user can
  /// type the argument inline. Representative until the API exposes a
  /// real command registry.
  Future<void> _openSlashCommands() async {
    final tr = context.tr;
    final commands = <(IconData, String, String)>[
      (AppIcons.refresh, '/restart', tr.slashRestartDesc),
      (AppIcons.fileText, '/report', tr.slashReportDesc),
      (AppIcons.refresh, '/sync', tr.slashSyncDesc),
      (AppIcons.terminal, '/logs', tr.slashLogsDesc),
      (AppIcons.database, '/backup', tr.slashBackupDesc),
    ];
    final s = context.saqqar;
    final picked = await showFigSheet<String>(
      context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s12,
              AppSpacing.s8,
              AppSpacing.s12,
              AppSpacing.s12,
            ),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: s.cardBg,
                borderRadius: AppRadius.cardR,
                border: Border.all(color: s.cardBorder),
                boxShadow: s.glassShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s16,
                      AppSpacing.s12,
                      AppSpacing.s16,
                      AppSpacing.s12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: s.border)),
                    ),
                    child: Text(
                      tr.commandsHeader,
                      style: TextStyle(
                        fontSize: AppFontSizes.metaLine,
                        height: AppLineHeights.heading,
                        fontWeight: FontWeight.w700,
                        letterSpacing: AppLetterSpacing.capsWide,
                        color: s.muted,
                      ),
                    ),
                  ),
                  for (final c in commands)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(sheetContext).pop(c.$2),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s14,
                            vertical: AppSpacing.s11,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: AppBoxSizes.glyphCompact,
                                height: AppBoxSizes.glyphCompact,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: s.brandCyan.withValues(
                                    alpha: AppAlphas.a12,
                                  ),
                                  borderRadius: AppRadius.buttonR,
                                ),
                                child: Icon(
                                  c.$1,
                                  size: AppIconSizes.inline,
                                  color: s.brandCyan,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              Text(
                                c.$2,
                                style: context.text.titleSmall?.copyWith(
                                  fontFamily: AppTypography.fontMono,
                                  color: s.brandCyan,
                                  fontWeight: FontWeight.w600,
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              Expanded(
                                child: Text(
                                  c.$3,
                                  style: context.text.bodySmall?.copyWith(
                                    color: s.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    final existing = _composer.text;
    final joiner = existing.isEmpty || existing.endsWith(' ') ? '' : ' ';
    final next = '$existing$joiner$picked ';
    _composer.text = next;
    _composer.selection = TextSelection.collapsed(offset: next.length);
    _composerFocus.requestFocus();
  }
}
