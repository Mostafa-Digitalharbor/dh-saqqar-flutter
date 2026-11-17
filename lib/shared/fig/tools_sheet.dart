import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/chat/view_model/task_prep_cubit.dart';
import '../widgets/app_toast.dart';
import 'fig.dart';
import '../extensions/context_extensions.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';

/// "Saqqar Tools" bottom sheet (the ⋮ pill): modes, Odoo context and the
/// Odoo tools lists. Task prep is wired to the real [TaskPrepCubit].
Future<void> showSaqqarTools(
  BuildContext context, {
  bool? taskPrep,
  bool? autoApprove,
  ValueChanged<bool>? onTaskPrep,
  ValueChanged<bool>? onAutoApprove,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => _ToolsSheet(
      taskPrep: taskPrep,
      autoApprove: autoApprove,
      onTaskPrep: onTaskPrep,
      onAutoApprove: onAutoApprove,
    ),
  );
}

const _sheetBg = Color(0xFF17181B);
const _tile = Color(0xFF232529);

class _ToolsSheet extends StatefulWidget {
  const _ToolsSheet({
    this.taskPrep,
    this.autoApprove,
    this.onTaskPrep,
    this.onAutoApprove,
  });

  final bool? taskPrep;
  final bool? autoApprove;
  final ValueChanged<bool>? onTaskPrep;
  final ValueChanged<bool>? onAutoApprove;

  @override
  State<_ToolsSheet> createState() => _ToolsSheetState();
}

class _ToolsSheetState extends State<_ToolsSheet> {
  late bool _autoApprove = widget.autoApprove ?? false;
  late bool _taskPrep = widget.taskPrep ?? false;
  int _ctx = 0;
  bool _commands = false;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: AppDurations.expand,
          alignment: Alignment.topCenter,
          child: _commands ? _commandsList(context) : _main(context),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    child: Text(
      t,
      style: Fig.t(
        context,
        size: 9,
        color: Colors.white.withValues(alpha: 0.8),
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _divider() => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 0),
    color: Colors.white.withValues(alpha: 0.08),
  );

  Widget _iconTile(IconData i) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: _tile,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(i, size: 19, color: Colors.white.withValues(alpha: 0.85)),
  );

  Widget _toggle(bool v, ValueChanged<bool> on) => GestureDetector(
    onTap: () => on(!v),
    child: AnimatedContainer(
      duration: AppDurations.menuIn,
      width: 42,
      height: 24,
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: v ? Fig.switchOn : const Color(0xFF3A3C42),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: v ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: v ? Colors.white : const Color(0xFFB9BCC4),
          shape: BoxShape.circle,
        ),
      ),
    ),
  );

  Widget _modeRow(IconData icon, String title, String sub, Widget trailing) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(
          children: [
            _iconTile(icon),
            const SizedBox(width: AppSpacing.s14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Fig.t(
                      context,
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    sub,
                    style: Fig.t(
                      context,
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      );

  Widget _main(BuildContext context) {
    final contexts = [
      context.tr.figSales,
      context.tr.figAccounting,
      context.tr.figInventory,
      'CRM',
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr.figSaqqarTools,
                  style: Fig.t(
                    context,
                    size: 19,
                    weight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(LucideIcons.x, color: Colors.white, size: 26),
              ),
            ],
          ),
        ),
        _divider(),
        _label(context.tr.figModes),
        widget.onTaskPrep != null
            ? _modeRow(
                LucideIcons.penLine,
                context.tr.figTaskPrep,
                context.tr.figReviewAClearPlanBeforeExecution,
                _toggle(_taskPrep, (v) {
                  setState(() => _taskPrep = v);
                  widget.onTaskPrep!(v);
                }),
              )
            : BlocBuilder<TaskPrepCubit, bool>(
                builder: (context, on) => _modeRow(
                  LucideIcons.penLine,
                  context.tr.figTaskPrep,
                  context.tr.figReviewAClearPlanBeforeExecution,
                  _toggle(on, (v) => context.read<TaskPrepCubit>().set(v)),
                ),
              ),
        const SizedBox(height: AppSpacing.s10),
        _modeRow(
          LucideIcons.check,
          context.tr.figAutoApprove2,
          context.tr.figRunTrustedActionsAutomatically,
          _toggle(_autoApprove, (v) {
            setState(() => _autoApprove = v);
            widget.onAutoApprove?.call(v);
          }),
        ),
        const SizedBox(height: AppSpacing.s14),
        _divider(),
        _label(context.tr.figOdooContext),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          child: Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < contexts.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _ctx = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: i == _ctx ? const Color(0xFFE3E8F5) : Fig.navyDeep,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: i == _ctx
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      contexts[i],
                      style: Fig.t(
                        context,
                        size: 10.5,
                        weight: FontWeight.w600,
                        color: i == _ctx ? Fig.navy : Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s10),
        _divider(),
        _label(context.tr.figOdooTools),
        _navRow(
          LucideIcons.check,
          context.tr.figCommands,
          context.tr.figCommandsSub,
          () => setState(() => _commands = true),
        ),
        _navRow(
          LucideIcons.unplug,
          context.tr.figConnections,
          context.tr.figConnectionsSub,
          () => AppToast.show(
            context,
            message: context.tr.figManageConnectionsFromYourProfileWorks,
            variant: ToastVariant.info,
          ),
        ),
        const SizedBox(height: AppSpacing.s14),
      ],
    );
  }

  Widget _navRow(IconData i, String t, String sub, VoidCallback onTap) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _modeRow(
          i,
          t,
          sub,
          Icon(
            LucideIcons.chevronRight,
            size: 20,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      );

  Widget _commandsList(BuildContext context) {
    final cmds = [
      (LucideIcons.check, 'restart', context.tr.figRestartAnOdooWorker),
      (LucideIcons.unplug, 'report', context.tr.figGenerateAReport),
      (LucideIcons.unplug, 'sync', context.tr.figSyncInventoryOrData),
      (LucideIcons.unplug, 'logs', context.tr.figFetchRecentServerLogs),
      (LucideIcons.unplug, 'backup', context.tr.figSnapshotTheEnvironment),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _commands = false),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 22, 16, 12),
            child: Row(
              children: [
                Icon(context.chevronBack, color: Colors.white, size: 22),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  context.tr.figBack,
                  style: Fig.t(context, size: 17, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        _divider(),
        _label(context.tr.figCommands2),
        for (final c in cmds)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => AppToast.show(
              context,
              message: context.tr.figAskSaqqarInChat(c.$2),
              variant: ToastVariant.info,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              child: _modeRow(c.$1, c.$2, c.$3, const SizedBox.shrink()),
            ),
          ),
        const SizedBox(height: AppSpacing.s14),
      ],
    );
  }
}
