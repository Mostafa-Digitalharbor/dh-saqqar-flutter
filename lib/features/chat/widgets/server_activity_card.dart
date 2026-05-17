import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../demo/saqqar_demo_data.dart';

/// Collapsible card rendered inside the chat Activity sheet, one per
/// `run_server_command` invocation. Mirrors the web's
/// `buildServerActivityCard()`:
///   - header: status dot (cyan=ok / red=err) + label + timestamp + toggle
///   - body (when expanded): command (mono) + stdout + stderr + exit code
///   - two Copy buttons (command, output) so the user can paste into
///     Slack / a runbook without opening the chat
///
/// Defaults to collapsed because the sheet often lists many cards; only
/// the latest failure-state card auto-expands (caller decides via
/// [initiallyExpanded]).
class ServerActivityCard extends StatefulWidget {
  const ServerActivityCard({
    super.key,
    required this.activity,
    this.initiallyExpanded = false,
  });

  final DemoServerActivity activity;
  final bool initiallyExpanded;

  @override
  State<ServerActivityCard> createState() => _ServerActivityCardState();
}

class _ServerActivityCardState extends State<ServerActivityCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    final a = widget.activity;
    final accent = a.failed ? AppColors.danger : AppColors.brandCyan;
    final label = a.failed ? tr.serverActivityFailed : tr.serverActivity;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.isDark ? 0.62 : 0.92),
        borderRadius: AppRadius.cardR,
        border: Border.all(color: s.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Head row ────────────────────────────────────────────────
          Material(
            color: Colors.transparent,
            borderRadius: AppRadius.cardR,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: context.text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              a.createdLabel,
                              if (a.host != null) a.host!,
                              tr.exitCode(a.returnCode),
                            ].join(' · '),
                            style: context.text.labelSmall?.copyWith(
                              color: s.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: s.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Command (always visible — the user usually needs it even
          //    when collapsed, e.g. to scan across multiple cards) ────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: _CodePlate(
              text: a.command,
              accent: accent,
              maxLines: _expanded ? null : 2,
            ),
          ),

          // ── Expanded body: stdout / stderr / actions ──────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (a.stdout.isNotEmpty) ...[
                          const _SectionLabel(text: 'stdout'),
                          const SizedBox(height: 6),
                          _CodePlate(text: a.stdout, accent: s.text),
                          const SizedBox(height: 10),
                        ],
                        if (a.stderr.isNotEmpty) ...[
                          const _SectionLabel(text: 'stderr', danger: true),
                          const SizedBox(height: 6),
                          _CodePlate(text: a.stderr, accent: AppColors.danger),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            _CopyChip(
                              label: tr.copyCommand,
                              onTap: () => _copy(context, a.command),
                            ),
                            const SizedBox(width: 8),
                            if (a.stdout.isNotEmpty)
                              _CopyChip(
                                label: tr.copyStdout,
                                onTap: () => _copy(context, a.stdout),
                              ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    AppToast.show(context, message: context.tr.copied);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.danger = false});
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Text(
      text.toUpperCase(),
      style: context.text.labelSmall?.copyWith(
        color: danger ? AppColors.danger : s.muted,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _CodePlate extends StatelessWidget {
  const _CodePlate({
    required this.text,
    required this.accent,
    this.maxLines,
  });

  final String text;
  final Color accent;

  /// When non-null, the plate clips after this many lines (with an
  /// ellipsis). Used in the collapsed header so a long command doesn't
  /// blow up the card height — the user still gets the first ~2 lines
  /// and can expand for the full thing.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: s.codePlate,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: s.border),
      ),
      child: SelectableText(
        text,
        maxLines: maxLines,
        style: context.text.bodySmall?.copyWith(
          fontFamily: UiStrings.monospaceFontFamily,
          color: accent,
          height: 1.5,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CopyChip extends StatelessWidget {
  const _CopyChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: s.surface2.withValues(alpha: context.isDark ? 0.55 : 0.92),
      borderRadius: AppRadius.pillR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillR,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillR,
            border: Border.all(color: s.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy_rounded, size: 12, color: s.muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.text.labelSmall?.copyWith(
                  color: s.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
