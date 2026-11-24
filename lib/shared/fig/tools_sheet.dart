import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/chat/view_model/task_prep_cubit.dart';
import '../../core/constants/ui_strings.dart';
import 'fig.dart';
import '../extensions/context_extensions.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/routing/route_names.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/fig_metrics.dart';
import '../../core/theme/app_colors.dart';

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
    // The sheet content is its own rounded surface; the theme's handle
    // would float above it on the transparent route.
    showDragHandle: false,
    barrierColor: AppColors.figBlack.withValues(alpha: AppAlphas.a50),
    builder: (_) => _ToolsSheet(
      taskPrep: taskPrep,
      autoApprove: autoApprove,
      onTaskPrep: onTaskPrep,
      onAutoApprove: onAutoApprove,
    ),
  );
}

const _sheetBg = AppColors.figCFF17181B;
const _tile = AppColors.figCFF232529;

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(FigMetrics.radFig30)),
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
    padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s14, AppSpacing.s16, AppSpacing.s8),
    child: Text(
      t,
      style: Fig.t(
        context,
        size: FigMetrics.fontFig9,
        color: AppColors.figWhite.withValues(alpha: AppAlphas.a80),
        letterSpacing: AppLetterSpacing.capsWide,
      ),
    ),
  );

  Widget _divider() => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 0),
    color: AppColors.figWhite.withValues(alpha: AppAlphas.a08),
  );

  Widget _iconTile(IconData i) => Container(
    width: FigMetrics.size46, height: FigMetrics.size46,
    decoration: BoxDecoration(
      color: _tile,
      borderRadius: BorderRadius.circular(AppRadius.input),
    ),
    child: Icon(i, size: AppIconSizes.bell, color: AppColors.figWhite.withValues(alpha: AppAlphas.a85)),
  );

  Widget _toggle(bool v, ValueChanged<bool> on) => GestureDetector(
    onTap: () => on(!v),
    child: AnimatedContainer(
      duration: AppDurations.menuIn,
      width: FigMetrics.size42, height: FigMetrics.size24,
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: v ? Fig.switchOn : AppColors.figCFF3A3C42,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      alignment: v ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: FigMetrics.size18, height: FigMetrics.size18,
        decoration: BoxDecoration(
          color: v ? AppColors.figWhite : AppColors.figCFFB9BCC4,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );

  Widget _modeRow(IconData icon, String title, String sub, Widget trailing) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s6, AppSpacing.s16, AppSpacing.s6),
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
                      size: AppFontSizes.metaLine,
                      weight: FontWeight.w600,
                      color: AppColors.figWhite,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    sub,
                    style: Fig.t(
                      context,
                      size: FigMetrics.fontFig10,
                      color: AppColors.figWhite.withValues(alpha: AppAlphas.a80),
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
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s22, AppSpacing.s16, AppSpacing.s14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr.figSaqqarTools,
                  style: Fig.t(
                    context,
                    size: AppFontSizes.markdownH1,
                    weight: FontWeight.w500,
                    color: AppColors.figWhite,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(LucideIcons.x, color: AppColors.figWhite, size: AppIconSizes.tile),
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
          padding: const EdgeInsets.fromLTRB(AppSpacing.s10, 0, AppSpacing.s10, AppSpacing.s6),
          child: Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (var i = 0; i < contexts.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _ctx = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s14,
                      vertical: AppSpacing.s8,
                    ),
                    decoration: BoxDecoration(
                      color: i == _ctx ? AppColors.figCFFE3E8F5 : Fig.navyDeep,
                      borderRadius: BorderRadius.circular(AppRadius.bubble),
                      border: Border.all(
                        color: i == _ctx
                            ? Colors.transparent
                            : AppColors.figWhite.withValues(alpha: AppAlphas.a08),
                      ),
                    ),
                    child: Text(
                      contexts[i],
                      style: Fig.t(
                        context,
                        size: FigMetrics.fontFig10U5,
                        weight: FontWeight.w600,
                        color: i == _ctx ? Fig.navy : AppColors.figWhite,
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
          () {
            // The sheet sits on the root navigator; close it, then open the
            // vault above the tab the user is on so Back returns there.
            final router = GoRouter.of(context);
            // The current *location* of a pushed route is its base page's, so
            // ask for the top match to know whether a chat is open.
            final matches = router.routerDelegate.currentConfiguration.matches;
            final inChat =
                matches.isNotEmpty &&
                matches.last.matchedLocation.startsWith(
                  '${RouteNames.chatsPath}/',
                );
            Navigator.pop(context);
            if (!inChat) {
              router.push(RouteNames.vaultPath);
            } else {
              // A chat sits above the tab shell, not in it: pushing the
              // shell's /vault over it mounts the shell twice (same page key,
              // the screen stays blank). Replace the stack with the vault.
              router.go(RouteNames.vaultPath);
            }
          },
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
            size: AppIconSizes.action,
            color: AppColors.figWhite.withValues(alpha: AppAlphas.a85),
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.s14, AppSpacing.s22, AppSpacing.s16, AppSpacing.s12),
            child: Row(
              children: [
                Icon(context.chevronBack, color: AppColors.figWhite, size: AppIconSizes.navBar),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  context.tr.figBack,
                  style: Fig.t(context, size: AppFontSizes.markdownH2, color: AppColors.figWhite),
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
            // The toast this used to show sat under the sheet, so a tap
            // looked dead. Now it closes the sheet and opens a new chat with
            // the command typed in, ready to finish and send.
            onTap: () {
              final router = GoRouter.of(context);
              Navigator.pop(context);
              router.push(
                Uri(
                  path: RouteNames.chatPath(UiStrings.newConversationId),
                  queryParameters: {RouteNames.chatDraftQuery: '/${c.$2} '},
                ).toString(),
              );
            },
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
