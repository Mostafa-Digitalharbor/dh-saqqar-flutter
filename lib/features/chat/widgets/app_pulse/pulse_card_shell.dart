import 'package:flutter/material.dart';

import '../../../../core/i18n/app_date_format.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/auto_direction_text.dart';
import '../../../../shared/widgets/danger_callout.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import '../../data/pulse_actions.dart';
import '../accent_card_chrome.dart';
import 'pulse_action_list.dart';
import 'pulse_helpers.dart';

/// Shared chrome for the seven read-only "app pulse" cards (Task 1,
/// MOBILE_TASKS_2026-09.md): icon + app title + `as_of` date, then either
/// [stats] or — when [envelope] reports `status: "error"` — the server's
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
    required this.stats,
    this.details = const [],
    this.priorities = const [],
    this.actions = const [],
    this.deepActions = const [],
    this.onSend,
    this.toolsFirst = false,
  });

  final InteractiveCardKind kind;
  final PulseEnvelope envelope;

  /// The card's headline numbers. Kept directly above the action rows,
  /// which is the order the web reads in: what is true, then what to do.
  final List<Widget> stats;

  /// The rows behind the numbers — a bucket's products, a check's audit
  /// trail. Below the buttons on purpose: these lists run to dozens of
  /// lines on a real database, and burying the actions under them turned a
  /// one-tap card into a scrolling exercise.
  final List<Widget> details;

  /// The web-parity action rows — "Customer collection · 13 invoices ·
  /// [Start collection]". Empty when the payload gives the card nothing to
  /// act on, which is also the web's empty state.
  final List<PulseAction> actions;

  /// Standing questions with no number of their own (accountant / HR).
  final List<PulseAction> deepActions;

  /// Sends a row's prompt as the next user message. Null on a read-only
  /// surface — the rows then render without buttons rather than with dead
  /// ones.
  final ValueChanged<String>? onSend;

  /// Already-Arabic priority lines (inventory/finance/etc.) — kept separate
  /// from [envelope.notes] because a payload can carry both, each under its
  /// own heading.
  final List<String> priorities;

  /// Puts the chip row and the free-text box directly under the numbers,
  /// above the action rows.
  ///
  /// The counter-driven cards leave it false: on the web their chips sit
  /// under the counter tiles, and each tile carries its own button, so the
  /// buttons genuinely come first. The inventory card sets it true, which is
  /// where the web puts its tracking banner — and where the review looked
  /// for it, above a bucket list that runs to six sections.
  final bool toolsFirst;

  /// The chip row and the free-text box, in that order — one block, so
  /// [toolsFirst] can move both without the two ever separating.
  List<Widget> get _tools => [
        PulseDeepActionChips(actions: deepActions, onSend: onSend),
        if (pulseFreeTextAction(kind) != null)
          PulseFreeTextAction(kind: kind, onSend: onSend),
      ];

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
          CardHeaderRow(
            icon: _iconFor(kind),
            title: pulseAppTitle(tr, kind),
            accent: s.brandCyan,
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
          else ...[
            ...stats,
            // Web parity: the numbers, then what to do about them. Kept
            // above the notes for the same reason the web keeps them there
            // — the notes explain the reading, the buttons continue it.
            if (toolsFirst) ..._tools,
            PulseActionList(
              actions: actions,
              onSend: onSend,
              emptyState: pulseEmptyStateText(kind, tr),
            ),
            if (!toolsFirst) ..._tools,
            ...details,
          ],
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
    return DangerCallout(
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
