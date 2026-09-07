import 'package:flutter/material.dart';

import '../../../../core/i18n/app_date_format.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/auto_direction_text.dart';
import '../../../../shared/widgets/colored_icon_box.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import '../accent_card_chrome.dart';
import 'pulse_helpers.dart';

/// Shared chrome for the seven read-only "app pulse" cards (Task 1,
/// MOBILE_TASKS_2026-09.md): icon + app title + `as_of` date, then either
/// [children] or — when [envelope] reports `status: "error"` — the server's
/// own error text instead of any tile (rule 3: render the error, not an
/// empty card). [notes] render below everything, verbatim and direction-
/// detected (rule 4: already in Arabic from the server, never translated).
///
/// Cyan rail, same as [InteractiveCardShell] — these are informational, not
/// a decision waiting on the user, which is what the amber approval rail
/// means. A dedicated shell rather than reusing [InteractiveCardShell]
/// directly because that widget's own doc comment scopes it to the three
/// "compose a follow-up" cards; this family answers a different question
/// (status/error handling, an as-of date, a notes footer) that those three
/// have no use for.
class PulseCardShell extends StatelessWidget {
  const PulseCardShell({
    super.key,
    required this.kind,
    required this.envelope,
    required this.children,
    this.priorities = const [],
  });

  final InteractiveCardKind kind;
  final PulseEnvelope envelope;
  final List<Widget> children;

  /// Already-Arabic priority lines (inventory/finance/etc.) — kept separate
  /// from [envelope.notes] because a payload can carry both, each under its
  /// own heading.
  final List<String> priorities;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    final asOfRaw = envelope.asOf;
    String? asOf;
    if (asOfRaw != null) {
      // Falls back to the raw string on a format the client doesn't
      // recognise — the date is still shown, just not locale-formatted.
      final parsed = DateTime.tryParse(asOfRaw);
      asOf = tr.pulseAsOf(
        parsed == null ? asOfRaw : AppDateFormat.date(context, parsed),
      );
    }
    return AccentCardChrome(
      accent: s.brandCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ColoredIconBox(
                icon: _iconFor(kind),
                color: s.brandCyan,
                size: AppIconSizes.cardHeader,
                radius: AppRadius.small,
                iconSize: AppIconSizes.boxGlyphCard,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  pulseAppTitle(tr, kind),
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: s.text,
                    letterSpacing: AppLetterSpacing.title,
                  ),
                ),
              ),
            ],
          ),
          if (asOf != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppIconSizes.cardHeader + AppSpacing.s12,
              ),
              child: Text(
                asOf,
                style: context.text.labelSmall?.copyWith(color: s.muted),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          if (envelope.status == PulseStatus.error)
            _PulseError(message: envelope.error)
          else
            ...children,
          if (envelope.notes.isNotEmpty)
            _PulseTextSection(title: tr.pulseNotesTitle, lines: envelope.notes),
          if (priorities.isNotEmpty)
            _PulseTextSection(
              title: tr.pulsePrioritiesTitle,
              lines: priorities,
            ),
        ],
      ),
    );
  }
}

IconData _iconFor(InteractiveCardKind kind) => switch (kind) {
      InteractiveCardKind.factory => AppIcons.factory,
      InteractiveCardKind.inventory => AppIcons.warehouse,
      InteractiveCardKind.finance => AppIcons.bank,
      InteractiveCardKind.purchasing => AppIcons.purchasing,
      InteractiveCardKind.qualityGuard => AppIcons.shieldCheck,
      InteractiveCardKind.accountant => AppIcons.calculator,
      InteractiveCardKind.hr => AppIcons.hr,
      InteractiveCardKind.promptClarify ||
      InteractiveCardKind.reportBuilder ||
      InteractiveCardKind.promptSuggestion =>
        AppIcons.grid,
    };

class _PulseError extends StatelessWidget {
  const _PulseError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: s.danger.withValues(alpha: AppAlphas.a06),
        borderRadius: AppRadius.smallR,
        border: Border.all(color: s.danger.withValues(alpha: AppAlphas.a22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.warning, size: AppIconSizes.compact, color: s.danger),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: AutoDirectionText(
              message.isEmpty ? context.tr.defaultApiError : message,
              style: context.text.bodySmall?.copyWith(color: s.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseTextSection extends StatelessWidget {
  const _PulseTextSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s2),
              child: AutoDirectionText(
                line,
                style: context.text.bodySmall?.copyWith(
                  color: s.text,
                  height: AppLineHeights.body,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
