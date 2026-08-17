import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/code_plate.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/preview_banner.dart';
import '../view_model/data_explorer_cubit.dart';
import '../view_model/data_explorer_state.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';

/// Read-only Odoo data explorer (API_MOBILE_NEW_ENDPOINTS.md §4.2) — pick a
/// bound environment + an operation, edit the JSON request body, and run it.
/// No agent, no LLM cost. Results render as raw pretty JSON so it's an honest
/// "here's exactly what the server returned" tool.
class DataExplorerScreen extends StatefulWidget {
  const DataExplorerScreen({super.key});

  @override
  State<DataExplorerScreen> createState() => _DataExplorerScreenState();
}

class _DataExplorerScreenState extends State<DataExplorerScreen> {
  final _body = TextEditingController(text: DataOp.count.template);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<DataExplorerCubit>().loadEnvironments());
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Scaffold(
      backgroundColor: s.bg,
      appBar: AppBar(title: Text(context.tr.dataExplorerTitle)),
      body: AmbientBackground(
        child: BlocConsumer<DataExplorerCubit, DataExplorerState>(
          listenWhen: (p, n) =>
              p.operation != n.operation ||
              (p.queryError != n.queryError && n.queryError != null),
          listener: (context, state) {
            // When the operation changes, reset the body to its template.
            if (state.operation.needsBody) {
              _body.text = state.operation.template;
            } else {
              _body.clear();
            }
            if (state.queryError != null) {
              final msg = state.queryError is FormatException
                  ? context.tr.dataExplorerInvalidJson
                  : ApiErrorMapper.message(context, state.queryError);
              AppToast.show(
                context,
                message: msg,
                variant: ToastVariant.error,
              );
            }
          },
          builder: (context, state) {
            if (state.loadingEnvs) {
              return Center(
                child:
                    CircularProgressIndicator(strokeWidth: 2.4, color: s.muted),
              );
            }
            if (state.envError != null) {
              return ListView(
                padding: const EdgeInsets.only(top: AppSpacing.s64),
                children: [
                  AppErrorState(
                    message: ApiErrorMapper.message(context, state.envError),
                    onRetry: () =>
                        context.read<DataExplorerCubit>().loadEnvironments(),
                  ),
                ],
              );
            }
            if (state.environments.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  AppSpacing.s48,
                  AppSpacing.s16,
                  AppSpacing.s28,
                ),
                children: [
                  EmptyState(
                    icon: AppIcons.server,
                    title: context.tr.dataExplorerNoEnvs,
                  ),
                ],
              );
            }
            return _Body(state: state, body: _body);
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.body});

  final DataExplorerState state;
  final TextEditingController body;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final cubit = context.read<DataExplorerCubit>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s28,
      ),
      children: [
        PreviewBanner(text: context.tr.dataExplorerPreviewNote),
        const SizedBox(height: AppSpacing.s14),
        // Environment picker.
        _Label(context.tr.dataExplorerEnv),
        _Dropdown<String>(
          value: state.selectedEnvId,
          items: [
            for (final e in state.environments)
              DropdownMenuItem(value: e.id, child: Text(e.label)),
          ],
          onChanged: (v) => v == null ? null : cubit.selectEnv(v),
        ),
        const SizedBox(height: AppSpacing.s14),
        // Operation picker.
        _Label(context.tr.dataExplorerOperation),
        _Dropdown<DataOp>(
          value: state.operation,
          items: [
            for (final op in DataOp.values)
              DropdownMenuItem(value: op, child: Text(op.label)),
          ],
          onChanged: (v) => v == null ? null : cubit.selectOperation(v),
        ),
        const SizedBox(height: AppSpacing.s14),
        // Every op takes a JSON object; GET ops send theirs as query params.
        if (state.operation.needsBody)
          AppTextField(
            label: context.tr.dataExplorerBody,
            controller: body,
            maxLines: 8,
            minLines: 4,
          ),
        const SizedBox(height: AppSpacing.s16),
        GhostButton(
          label: context.tr.dataExplorerRun,
          icon: AppIcons.play,
          expand: true,
          loading: state.running,
          onPressed: state.running ? null : () => cubit.run(body.text),
        ),
        if (state.result.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s18),
          _Label(context.tr.dataExplorerResult),
          // Long unbroken values (a big record, a URL) scroll sideways inside
          // the plate instead of overflowing; the ListView scrolls vertically.
          CodePlate(text: state.result, accent: s.text),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s6),
      child: Text(
        text,
        style: context.text.labelMedium?.copyWith(color: context.saqqar.muted),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: AppRadius.rowR,
        border: Border.all(color: s.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          dropdownColor: s.surface,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
