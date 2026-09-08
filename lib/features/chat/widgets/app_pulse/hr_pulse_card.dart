import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/auto_direction_text.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import '../../data/pulse_actions.dart';
import 'pulse_card_shell.dart';
import 'pulse_counter_list.dart';
import 'pulse_helpers.dart';
import 'pulse_ranked_list.dart';
import 'pulse_raw_items.dart';

/// "Recruitment Manager" pulse — applicants, employees, contracts, payroll,
/// time off and attendance, computed from Odoo (Task 1,
/// MOBILE_TASKS_2026-09.md).
class HrPulseCard extends StatelessWidget {
  const HrPulseCard({
    super.key,
    required this.payload,
    this.actions = const [],
    this.deepActions = const [],
    this.onSend,
  });

  final HrPulsePayload payload;

  /// Web-parity action rows, built by `pulseActions` from the same payload.
  /// Empty leaves the card read-only, which is what every non-chat surface
  /// (the storybook, the conformance sweeps) wants.
  final List<PulseAction> actions;
  final List<PulseAction> deepActions;
  final ValueChanged<String>? onSend;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final ops = payload.operations;
    return PulseCardShell(
      kind: InteractiveCardKind.hr,
      envelope: payload.envelope,
      actions: actions,
      deepActions: deepActions,
      onSend: onSend,
      stats: [
        PulseStatGrid(
          tiles: [
            // Rule 1: a database that can't answer says so. Hiding these
            // three tiles when `operations.available` is false left the card
            // looking like an employee list with nothing on it.
            if (!ops.available)
              pulseStatTile(tr.pulseUnavailable, tr.pulseHrOperationsTitle,
                  color: context.saqqar.muted)
            else ...[
              pulseScalarStatTile(
                  context, ops.activeEmployees, tr.pulseHrActiveEmployees),
              pulseScalarStatTile(
                  context, ops.missingManagers, tr.pulseHrMissingManagers),
              pulseScalarStatTile(
                  context, ops.missingWorkEmail, tr.pulseHrMissingWorkEmail),
            ],
            // The doc's other three top-level keys. Each shows a tile only
            // when the server actually sent the key — a card full of em
            // dashes for sections a database doesn't have is noise, not
            // information.
            for (final section in _sections(tr))
              if (section.$2 case final bucket?)
                pulseBucketStatTile(context, bucket, section.$1),
          ],
        ),
      ],
      details: [
        PulseCounterList(counters: payload.counters),
        PulseRankedList<HrOperationItem>(
          title: tr.pulseHrOperationsTitle,
          items: ops.items,
          itemBuilder: (context, item) => _OperationRow(item: item),
        ),
        for (final section in _sections(tr))
          if (section.$2 case final bucket?)
            PulseRawItemsList(title: section.$1, items: bucket.items),
      ],
    );
  }

  /// Recruitment, payroll and time off, paired with their labels. Null
  /// entries are keys the payload didn't carry at all — distinct from a key
  /// that arrived saying `available: false`, which does get a tile.
  List<(String, PulseBucket?)> _sections(AppStrings tr) => [
        (tr.pulseHrRecruitment, payload.recruitment),
        (tr.pulseHrPayroll, payload.payroll),
        (tr.pulseHrTimeOff, payload.timeOff),
      ];
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({required this.item});

  final HrOperationItem item;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.employee,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodyMedium?.copyWith(
            color: s.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (item.reason.isNotEmpty)
          AutoDirectionText(
            item.reason,
            style: context.text.bodySmall?.copyWith(color: s.muted),
          ),
      ],
    );
  }
}
