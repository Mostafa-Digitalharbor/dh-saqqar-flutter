import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/fig/fig.dart';
import '../setup/setup_screens.dart' show FigDropdown;
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/fig_metrics.dart';
import '../../core/theme/app_colors.dart';

/// One recurring agent workflow.
class ScheduledTask {
  const ScheduledTask({
    required this.id,
    required this.title,
    required this.time,
    required this.timezone,
    required this.module,
    required this.frequency,
    required this.prompt,
  });

  final String id;
  final String title;
  final String time;
  final String timezone;
  final String module;
  final String frequency;
  final String prompt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'time': time,
    'timezone': timezone,
    'module': module,
    'frequency': frequency,
    'prompt': prompt,
  };

  factory ScheduledTask.fromJson(Map<String, dynamic> j) => ScheduledTask(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    time: j['time'] as String? ?? '8:00',
    timezone: j['timezone'] as String? ?? 'Riyadh (GMT+3)',
    module: j['module'] as String? ?? 'Sales',
    frequency: j['frequency'] as String? ?? 'Daily',
    prompt: j['prompt'] as String? ?? '',
  );

  IconData get icon {
    final k = '$title $module'.toLowerCase();
    if (k.contains('radar') || k.contains('stock') && k.contains('daily')) {
      return LucideIcons.trendingUp;
    }
    if (k.contains('replen') || k.contains('low')) return LucideIcons.sparkles;
    return LucideIcons.fileText;
  }

  String scheduleLabel(bool ar) {
    final f = switch (frequency) {
      'Daily' => ar ? 'كل يوم' : 'Every day',
      'Weekly' => ar ? 'كل أسبوع' : 'Every week',
      'Monthly' => ar ? 'كل شهر' : 'Every month',
      _ => frequency,
    };
    return '$f · $time';
  }
}

/// Persists the schedule list on-device (no scheduling API exists yet).
class TaskStore {
  static const _key = 'saqqar.scheduled_tasks.v1';

  static Future<List<ScheduledTask>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(ScheduledTask.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<ScheduledTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final t in tasks) t.toJson()]),
    );
  }
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, this.initial});

  /// Seed list (tests / previews); null loads from the device.
  final List<ScheduledTask>? initial;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<ScheduledTask>? _tasks;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _tasks = widget.initial;
    } else {
      TaskStore.load().then((v) {
        if (mounted) setState(() => _tasks = v);
      });
    }
  }

  Future<void> _add() async {
    final t = await showFigSheet<ScheduledTask>(
      context,
      builder: (_) => const ScheduleTaskSheet(),
    );
    if (t == null) return;
    setState(() => _tasks = [..._tasks ?? [], t]);
    await TaskStore.save(_tasks!);
  }

  Future<void> _delete(ScheduledTask t) async {
    setState(() {
      _tasks = _tasks!.where((e) => e.id != t.id).toList();
    });
    await TaskStore.save(_tasks!);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: figLightStatusBar,
      child: FigBackdrop(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s24, 0, AppSpacing.s24, AppSpacing.s140),
            children: [
              const SizedBox(height: AppSpacing.s56),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr.figScheduledTasks,
                          style: Fig.t(
                            context,
                            size: FigMetrics.fontFig32,
                            weight: FontWeight.w700,
                            color: AppColors.figWhite,
                            height: AppLineHeights.heading,
                          ),
                        ),
                        Text(
                          context.tr.figRecurringAgentWorkflowsThatKeepYour,
                          style: Fig.t(
                            context,
                            size: FigMetrics.fontFig9U5,
                            color: AppColors.figWhite.withValues(alpha: AppAlphas.a80),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _add,
                    child: Container(
                      width: FigMetrics.size36, height: FigMetrics.size36,
                      decoration: BoxDecoration(
                        color: AppColors.figWhite.withValues(alpha: AppAlphas.a14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.figWhite.withValues(alpha: AppAlphas.a25),
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.plus,
                        size: AppIconSizes.regular,
                        color: AppColors.figWhite,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s36),
              if (tasks != null && tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s40),
                  child: Column(
                    children: [
                      Text(
                        context.tr.figNoScheduledTasksYet,
                        // Sits on the blue part of the backdrop, where the
                        // muted grey vanished; white + the same soft shadow
                        // the sign-in subtitle uses stays legible.
                        style: Fig.t(context, size: AppFontSizes.dense, color: AppColors.figWhite)
                            .copyWith(
                              shadows: const [
                                Shadow(color: Fig.shadowInk, blurRadius: FigMetrics.blur6),
                              ],
                            ),
                      ),
                      const SizedBox(height: AppSpacing.s14),
                      SizedBox(
                        width: 200,
                        child: FigButton(
                          label: context.tr.figScheduleATask,
                          height: 46,
                          fontSize: AppFontSizes.dense,
                          onPressed: _add,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final t in tasks ?? const <ScheduledTask>[])
                  _TaskCard(task: t, onDelete: () => _delete(t)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onDelete});

  final ScheduledTask task;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
      padding: const EdgeInsets.fromLTRB(AppSpacing.s14, AppSpacing.s14, AppSpacing.s10, AppSpacing.s14),
      decoration: BoxDecoration(
        color: AppColors.figWhite,
        borderRadius: BorderRadius.circular(AppRadius.bubble),
        boxShadow: [
          BoxShadow(
            color: Fig.slate.withValues(alpha: AppAlphas.a12),
            blurRadius: FigMetrics.blur14,
            offset: FigOffsets.oU0U4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: FigMetrics.size46, height: FigMetrics.size46,
            decoration: BoxDecoration(
              color: AppColors.figCFFE3EBFB,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Icon(task.icon, size: AppIconSizes.bell, color: Fig.blue),
          ),
          const SizedBox(width: AppSpacing.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Fig.t(
                    context,
                    size: FigMetrics.fontFig11U5,
                    weight: FontWeight.w700,
                    color: Fig.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.s7),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.clock,
                      size: AppIconSizes.metaTight,
                      color: Fig.mutedCool,
                    ),
                    const SizedBox(width: AppSpacing.s5),
                    Expanded(
                      child: Text(
                        task.scheduleLabel(context.tr.isArabic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Fig.t(context, size: FigMetrics.fontFig9, color: Fig.mutedCool),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              LucideIcons.ellipsis,
              size: AppIconSizes.action,
              color: AppColors.figCFF5B6075,
            ),
            onSelected: (v) {
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: Text(context.tr.figDelete2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Schedule a Saqqar task" sheet.
class ScheduleTaskSheet extends StatefulWidget {
  const ScheduleTaskSheet({super.key});

  @override
  State<ScheduleTaskSheet> createState() => _ScheduleTaskSheetState();
}

class _ScheduleTaskSheetState extends State<ScheduleTaskSheet> {
  final _title = TextEditingController();
  final _prompt = TextEditingController();
  String _time = '8:00';
  String _tz = 'Riyadh (GMT+3)';
  String _module = 'Sales';
  String _freq = 'Daily';
  String? _error;

  static const _times = [
    '6:00',
    '7:00',
    '8:00',
    '9:00',
    '12:00',
    '15:00',
    '18:00',
    '21:00',
  ];
  static const _zones = [
    'Riyadh (GMT+3)',
    'Cairo (GMT+2)',
    'Dubai (GMT+4)',
    'London (GMT+0)',
  ];
  static const _modules = [
    'Sales',
    'Accounting',
    'Inventory',
    'CRM',
    'Purchase',
    'HR',
  ];
  static const _freqs = ['Daily', 'Weekly', 'Monthly'];

  String _freqLabel(String v) => switch (v) {
    'Daily' => context.tr.taskFreqDaily,
    'Weekly' => context.tr.taskFreqWeekly,
    'Monthly' => context.tr.taskFreqMonthly,
    _ => v,
  };

  String _moduleLabel(String v) => switch (v) {
    'Sales' => context.tr.taskModSales,
    'Accounting' => context.tr.taskModAccounting,
    'Inventory' => context.tr.taskModInventory,
    'CRM' => context.tr.taskModCrm,
    'Purchase' => context.tr.taskModPurchase,
    'HR' => context.tr.taskModHr,
    _ => v,
  };

  String _zoneLabel(String v) => switch (v) {
    'Riyadh (GMT+3)' => context.tr.taskTzRiyadh,
    'Cairo (GMT+2)' => context.tr.taskTzCairo,
    'Dubai (GMT+4)' => context.tr.taskTzDubai,
    'London (GMT+0)' => context.tr.taskTzLondon,
    _ => v,
  };

  @override
  void dispose() {
    _title.dispose();
    _prompt.dispose();
    super.dispose();
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = context.tr.figGiveTheTaskATitle);
      return;
    }
    Navigator.pop(
      context,
      ScheduledTask(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        time: _time,
        timezone: _tz,
        module: _module,
        frequency: _freq,
        prompt: _prompt.text.trim(),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s7),
    child: Text(
      t,
      style: Fig.t(context, size: AppFontSizes.microCaps, weight: FontWeight.w600, color: Fig.navy),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: FigNotchSheet(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s20, 0, AppSpacing.s20, AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr.figScheduleASaqqarTask,
                style: Fig.t(
                  context,
                  size: AppFontSizes.markdownH2,
                  weight: FontWeight.w500,
                  color: Fig.navy,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                context.tr.figSetUpARecurringAiWorkflow,
                style: Fig.t(context, size: FigMetrics.fontFig9, color: Fig.muted),
              ),
              const SizedBox(height: AppSpacing.s22),
              _label(context.tr.figTaskTitle),
              _filled(
                child: TextField(
                  controller: _title,
                  // A stale "give the task a title" must not outlive the fix.
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  style: Fig.t(context, size: AppFontSizes.caption, color: Fig.navy),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isCollapsed: true,
                    hintText: context.tr.figEGDailySalesReportSync,
                    hintStyle: Fig.t(context, size: AppFontSizes.caption, color: Fig.placeholder),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s5),
                  child: Text(
                    _error!,
                    style: Fig.t(context, size: FigMetrics.fontFig11, color: Fig.dangerText),
                  ),
                ),
              const SizedBox(height: AppSpacing.s16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context.tr.figExecutionTime),
                        FigDropdown(
                          value: _time,
                          options: _times,
                          height: 44,
                          filled: true,
                          onChanged: (v) => setState(() => _time = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context.tr.figTimezone),
                        FigDropdown(
                          value: _tz,
                          labelOf: _zoneLabel,
                          options: _zones,
                          height: 44,
                          filled: true,
                          onChanged: (v) => setState(() => _tz = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context.tr.figOdooModule),
                        FigDropdown(
                          value: _module,
                          labelOf: _moduleLabel,
                          options: _modules,
                          height: 44,
                          filled: true,
                          onChanged: (v) => setState(() => _module = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context.tr.figFrequency),
                        FigDropdown(
                          value: _freq,
                          labelOf: _freqLabel,
                          options: _freqs,
                          height: 44,
                          filled: true,
                          onChanged: (v) => setState(() => _freq = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              _label(context.tr.figAiPromptTaskInstructions),
              Container(
                height: 88,
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: Fig.panelTint,
                  borderRadius: BorderRadius.circular(AppRadius.modal),
                  border: Border.all(color: Fig.panelBorder),
                ),
                child: TextField(
                  controller: _prompt,
                  maxLines: null,
                  style: Fig.t(context, size: AppFontSizes.microCaps, color: Fig.navy),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isCollapsed: true,
                    hintText:
                        context.tr.figDescribeWhatSaqqarShouldFetchAnalyze,
                    hintStyle: Fig.t(context, size: AppFontSizes.microCaps, color: Fig.placeholder),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
              FigButton(
                label: context.tr.figScheduleTask,
                height: 50,
                fontSize: AppFontSizes.body,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filled({required Widget child}) => Container(
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s18),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: Fig.panelTint,
      borderRadius: BorderRadius.circular(FigMetrics.radFig25),
      border: Border.all(color: Fig.panelBorder),
    ),
    child: child,
  );
}
