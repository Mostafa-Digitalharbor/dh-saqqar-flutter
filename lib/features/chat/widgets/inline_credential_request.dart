import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/eyebrow_label.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../demo/saqqar_demo_data.dart';

/// Spec §6.7 — schema-driven mini form rendered INLINE in the chat the
/// moment the agent calls `request_credentials`. Uses the same schema source
/// as the Vault sheet so the field set stays consistent across surfaces.
///
/// Shape today:
/// - Cyan-tinted plate (matches §6.7 description).
/// - Title + body header.
/// - Kind dropdown that swaps the field block.
/// - "Use a saved credential" ghost button (opens picker).
/// - "Provide credential" primary button (submits).
///
/// Caller wires [onPickSaved] to open the credential picker sheet and
/// [onProvide] to receive the filled bundle. [onCancel] dismisses the row.
class InlineCredentialRequest extends StatefulWidget {
  const InlineCredentialRequest({
    super.key,
    required this.onProvide,
    required this.onPickSaved,
    required this.onCancel,
    this.initialKind = DemoCredentialKind.postgres,
  });

  /// Returns the credential kind + values the user typed in.
  final void Function(DemoCredentialKind kind, Map<String, String> values)
      onProvide;

  /// Tapped when the user wants to reuse a saved bundle instead of typing.
  final VoidCallback onPickSaved;

  /// Dismiss the inline request.
  final VoidCallback onCancel;

  final DemoCredentialKind initialKind;

  @override
  State<InlineCredentialRequest> createState() =>
      _InlineCredentialRequestState();
}

class _InlineCredentialRequestState extends State<InlineCredentialRequest> {
  late DemoCredentialKind _kind = widget.initialKind;
  final Map<String, TextEditingController> _controllers = {};

  DemoCredentialSchema get _schema =>
      demoCredentialSchemas.firstWhere((s) => s.kind == _kind);

  @override
  void initState() {
    super.initState();
    _ensureControllersFor(_schema);
  }

  void _ensureControllersFor(DemoCredentialSchema schema) {
    for (final field in schema.fields) {
      _controllers.putIfAbsent(
        '${schema.kind.name}.${field.name}',
        TextEditingController.new,
      );
    }
  }

  void _switchKind(DemoCredentialKind kind) {
    setState(() => _kind = kind);
    _ensureControllersFor(_schema);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final schema = _schema;
    final values = <String, String>{};
    for (final field in schema.fields) {
      final c = _controllers['${schema.kind.name}.${field.name}'];
      values[field.name] = (c?.text ?? '').trim();
    }
    widget.onProvide(_kind, values);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final schema = _schema;

    return Container(
      decoration: BoxDecoration(
        color: s.brandCyan.withValues(alpha: context.isDark ? 0.08 : 0.05),
        borderRadius: AppRadius.cardR,
        border: Border.all(color: s.brandCyan.withValues(alpha: 0.30)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(AppIcons.key, size: 18, color: s.brandCyan),
              const SizedBox(width: 8),
              const Expanded(child: EyebrowLabel('Saqqar')),
              IconButton(
                icon: const Icon(AppIcons.close, size: 18),
                onPressed: widget.onCancel,
                tooltip: context.tr.cancel,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr.inlineCredentialRequestTitle,
            style: context.text.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.tr.inlineCredentialRequestBody,
            style: context.text.bodySmall?.copyWith(color: s.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DemoCredentialKind>(
            initialValue: _kind,
            decoration: InputDecoration(labelText: context.tr.kind),
            items: [
              for (final item in demoCredentialSchemas)
                DropdownMenuItem(value: item.kind, child: Text(item.label)),
            ],
            onChanged: (value) {
              if (value != null) _switchKind(value);
            },
          ),
          const SizedBox(height: 12),
          for (final field in schema.fields) ...[
            _InlineSchemaField(
              field: field,
              controller: _controllers['${schema.kind.name}.${field.name}']!,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: context.tr.useExistingCredential,
                  icon: AppIcons.archive,
                  minHeight: 44,
                  onPressed: widget.onPickSaved,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: context.tr.provideCredential,
                  icon: AppIcons.check,
                  minHeight: 44,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Renders one schema field — text / password / multiline / dropdown.
/// Mirrors the Vault sheet's `_SchemaField` so the two surfaces look the same.
class _InlineSchemaField extends StatelessWidget {
  const _InlineSchemaField({required this.field, required this.controller});

  final DemoCredentialField field;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    if (field.options.isNotEmpty) {
      // The dropdown has no controller binding; we keep the text controller
      // so the parent can still read a value (we set it on change).
      final initial = controller.text.isNotEmpty
          ? controller.text
          : field.options.first;
      if (controller.text.isEmpty) controller.text = initial;
      return DropdownButtonFormField<String>(
        initialValue: initial,
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
