import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../demo/saqqar_demo_data.dart';
import '../state/vault_controller.dart';

/// Schema-driven credential form rendered inside a tab of
/// [EnvironmentDetailSheet]. Mirrors the web's `env-credential-form`:
/// label input + per-schema fields + "Last verified" hint + Save/Delete.
///
/// `Save` calls [VaultController.saveCredential]; `Delete` calls
/// [VaultController.deleteCredential] after a confirm dialog.
class CredentialForm extends ConsumerStatefulWidget {
  const CredentialForm({
    super.key,
    required this.envId,
    required this.kind,
  });

  final String envId;
  final DemoCredentialKind kind;

  @override
  ConsumerState<CredentialForm> createState() => _CredentialFormState();
}

class _CredentialFormState extends ConsumerState<CredentialForm> {
  late final TextEditingController _label;
  final Map<String, TextEditingController> _fieldControllers = {};
  bool _initialised = false;
  bool _testing = false;

  DemoCredentialSchema? get _schema {
    for (final s in demoCredentialSchemas) {
      if (s.kind == widget.kind) return s;
    }
    return null;
  }

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

  void _ensureControllers(DemoCredentialSchema schema, DemoCredential? saved) {
    if (_initialised) return;
    _label.text = saved?.label ?? '';
    for (final field in schema.fields) {
      _fieldControllers[field.name] = TextEditingController(
        // No saved values in the demo — backend will return the masked
        // payload once it ships `GET /api/environments/{id}/credentials/{kind}/`.
        text: field.options.isNotEmpty ? field.options.first : '',
      );
    }
    _initialised = true;
  }

  Future<void> _save() async {
    final values = <String, String>{};
    for (final entry in _fieldControllers.entries) {
      values[entry.key] = entry.value.text.trim();
    }
    ref.read(vaultControllerProvider.notifier).saveCredential(
          envId: widget.envId,
          kind: widget.kind,
          label: _label.text,
          values: values,
        );
    AppToast.show(
      context,
      message: context.tr.credentialSavedToast,
      variant: ToastVariant.success,
    );
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    // Demo only — pretends to ping the target. Swap for the real
    // POST /api/environments/{id}/credentials/{kind}/verify when it ships.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    ref.read(vaultControllerProvider.notifier).verifyCredential(
          envId: widget.envId,
          kind: widget.kind,
        );
    setState(() => _testing = false);
    if (!mounted) return;
    AppToast.show(
      context,
      message: context.tr.connectionVerified,
      variant: ToastVariant.success,
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
    ref.read(vaultControllerProvider.notifier).deleteCredential(
          envId: widget.envId,
          kind: widget.kind,
        );
    if (!mounted) return;
    AppToast.show(context, message: context.tr.credentialDeletedToast);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final schema = _schema;
    final saved = ref
        .watch(vaultControllerProvider)
        .credentialFor(widget.envId, widget.kind);

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
    if (!hasCredential || saved.lastVerified == null) {
      hint = context.tr.notSavedYet;
    } else {
      // Try parsing as ISO timestamp (set by VaultController._nowLabel).
      // Fall back to the raw string for legacy demo entries that still
      // hold a "May 9, 12:23 AM" formatted label.
      final parsed = DateTime.tryParse(saved.lastVerified!);
      hint = parsed != null
          ? context.tr.lastVerifiedAt(context.tr.relativeTime(parsed))
          : context.tr.lastVerifiedAt(saved.lastVerified!);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: context.tr.label,
            controller: _label,
            hint: demoCredentialKindLabel(widget.kind),
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
                  onPressed: _save,
                ),
              ),
              if (hasCredential) ...[
                const SizedBox(width: 8),
                GhostButton(
                  label: _testing
                      ? context.tr.testingConnection
                      : context.tr.testConnection,
                  icon: AppIcons.bolt,
                  onPressed: _testing ? null : _test,
                ),
                const SizedBox(width: 8),
                GhostButton(
                  label: context.tr.deleteCredentialButton,
                  icon: AppIcons.trash,
                  tone: GhostButtonTone.danger,
                  onPressed: _delete,
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
  const _SchemaField({required this.field, required this.controller});

  final DemoCredentialField field;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    if (field.options.isNotEmpty) {
      return DropdownButtonFormField<String>(
        initialValue: controller.text.isNotEmpty
            ? controller.text
            : field.options.first,
        decoration: InputDecoration(labelText: field.label),
        items: [
          for (final option in field.options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: (value) {
          if (value != null) controller.text = value;
        },
      );
    }
    if (field.obscure) {
      return AppPasswordField(
        label: field.label,
        hint: field.hint,
        controller: controller,
      );
    }
    return AppTextField(
      label: field.label,
      hint: field.hint,
      controller: controller,
      maxLines: field.multiline ? 4 : 1,
    );
  }
}
