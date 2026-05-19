import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/credential_models.dart';
import '../view_model/vault_cubit.dart';

/// Schema-driven credential form rendered inside a tab of
/// [EnvironmentDetailSheet]. Mirrors the web's `env-credential-form`:
/// label input + per-schema fields + "Last verified" hint + Save/Delete.
///
/// `Save` calls [VaultCubit.saveEnvironmentCredential]; `Delete` calls
/// [VaultCubit.deleteEnvironmentCredential] after a confirm dialog.
class CredentialForm extends StatefulWidget {
  const CredentialForm({
    super.key,
    required this.envId,
    required this.kind,
  });

  final String envId;
  final CredentialKind kind;

  @override
  State<CredentialForm> createState() => _CredentialFormState();
}

class _CredentialFormState extends State<CredentialForm> {
  late final TextEditingController _label;
  final Map<String, TextEditingController> _fieldControllers = {};
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController();
  }

  @override
  void dispose() {
    _label.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(CredentialSchema schema, Credential? saved) {
    if (_initialised) return;
    _label.text = saved?.label ?? '';
    final payload = saved?.payload ?? const <String, dynamic>{};
    for (final field in schema.fields) {
      final raw = payload[field.name];
      final initial = raw?.toString() ??
          // Fall back to the first option for select fields so the user
          // sees a valid choice immediately.
          (field.type == CredentialFieldType.select &&
                  (field.options?.isNotEmpty ?? false)
              ? field.options!.first
              : '');
      _fieldControllers[field.name] = TextEditingController(text: initial);
    }
    _initialised = true;
  }

  Future<void> _save() async {
    final payload = <String, dynamic>{};
    for (final entry in _fieldControllers.entries) {
      payload[entry.key] = entry.value.text.trim();
    }
    await context.read<VaultCubit>().saveEnvironmentCredential(
          envId: widget.envId,
          kind: widget.kind,
          payload: payload,
          label: _label.text.trim().isEmpty ? null : _label.text.trim(),
        );
  }

  Future<void> _delete() async {
    final ok = await ConfirmDialog.show(
      context,
      title: context.tr.deleteCredentialTitle,
      body: context.tr.deleteCredentialBody,
      confirmLabel: context.tr.deleteCredentialButton,
      destructive: true,
      icon: AppIcons.trash,
    );
    if (!ok || !mounted) return;
    await context.read<VaultCubit>().deleteEnvironmentCredential(
          envId: widget.envId,
          kind: widget.kind,
        );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final state = context.watch<VaultCubit>().state;
    final data = state.data.dataOrNull;
    final schema = data?.schemaFor(widget.kind);
    final saved = data?.credentialFor(widget.envId, widget.kind);

    if (schema == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.tr.noFieldsForKind,
          style: context.text.bodySmall?.copyWith(color: s.muted),
        ),
      );
    }

    _ensureControllers(schema, saved);

    final hasCredential = saved != null;
    String hint;
    if (!hasCredential || saved.lastVerifiedAt == null) {
      hint = context.tr.notSavedYet;
    } else {
      hint = context.tr.lastVerifiedAt(
        context.tr.relativeTime(saved.lastVerifiedAt!),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: context.tr.label,
            controller: _label,
            hint: schema.label,
          ),
          const SizedBox(height: 12),
          for (final field in schema.fields) ...[
            _SchemaField(
              field: field,
              controller: _fieldControllers[field.name]!,
            ),
            const SizedBox(height: 10),
          ],
          if (schema.fields.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                context.tr.noFieldsForKind,
                style: context.text.bodySmall?.copyWith(color: s.muted),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: context.text.labelSmall?.copyWith(color: s.muted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: context.tr.saveCredentialButton,
                  icon: AppIcons.save,
                  onPressed: state.actionInFlight ? null : _save,
                ),
              ),
              if (hasCredential) ...[
                const SizedBox(width: 8),
                GhostButton(
                  label: context.tr.deleteCredentialButton,
                  icon: AppIcons.trash,
                  tone: GhostButtonTone.danger,
                  onPressed: state.actionInFlight ? null : _delete,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SchemaField extends StatelessWidget {
  const _SchemaField({
    required this.field,
    required this.controller,
  });

  final CredentialField field;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final input = _buildInput();
    if (field.help.isEmpty) return input;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        input,
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Text(
            field.help,
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInput() {
    switch (field.type) {
      case CredentialFieldType.select:
        final options = field.options ?? const <String>[];
        return DropdownButtonFormField<String>(
          initialValue: controller.text.isNotEmpty
              ? controller.text
              : (options.isNotEmpty ? options.first : null),
          decoration: InputDecoration(labelText: field.label),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (value) {
            if (value == null) return;
            controller.text = value;
          },
        );
      case CredentialFieldType.password:
        return AppPasswordField(
          label: field.label,
          hint: field.placeholder.isEmpty ? null : field.placeholder,
          controller: controller,
        );
      case CredentialFieldType.textarea:
        return AppTextField(
          label: field.label,
          hint: field.placeholder.isEmpty ? null : field.placeholder,
          controller: controller,
          maxLines: 4,
        );
      case CredentialFieldType.number:
        return AppTextField(
          label: field.label,
          hint: field.placeholder.isEmpty ? null : field.placeholder,
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: false,
          ),
        );
      case CredentialFieldType.text:
        return AppTextField(
          label: field.label,
          hint: field.placeholder.isEmpty ? null : field.placeholder,
          controller: controller,
        );
    }
  }
}

