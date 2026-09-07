import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/auto_direction_text.dart';
import '../../../../shared/widgets/stat_tile.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import 'pulse_card_shell.dart';
import 'pulse_counter_list.dart';
import 'pulse_helpers.dart';
import 'pulse_ranked_list.dart';

/// "Recruitment Manager" pulse — applicants, employees, contracts, payroll,
/// time off and attendance, computed from Odoo (Task 1,
/// MOBILE_TASKS_2026-09.md).
class HrPulseCard extends StatelessWidget {
  const HrPulseCard({super.key, required this.payload});

  final HrPulsePayload payload;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final ops = payload.operations;
    return PulseCardShell(
      kind: InteractiveCardKind.hr,
      envelope: payload.envelope,
      children: [
        if (ops.available)
          Wrap(
            spacing: AppSpacing.s16,
            runSpacing: AppSpacing.s12,
            children: [
              _tile(context, ops.activeEmployees, tr.pulseHrActiveEmployees),
              _tile(context, ops.missingManagers, tr.pulseHrMissingManagers),
              _tile(
                  context, ops.missingWorkEmail, tr.pulseHrMissingWorkEmail),
            ],
          ),
        PulseCounterList(counters: payload.counters),
        PulseRankedList<HrOperationItem>(
          title: tr.pulseHrOperationsTitle,
          items: ops.items,
          itemBuilder: (context, item) => _OperationRow(item: item),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, int? value, String label) {
    final cell = pulseScalarCell(context, value);
    return SizedBox(
      width: AppControlSizes.pulseStatTile,
      child: StatTile(value: cell.value, label: label, valueColor: cell.color),
    );
  }
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
