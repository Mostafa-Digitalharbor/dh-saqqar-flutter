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
/// Possible outcomes of [InlineCredentialRequest.show]. Lets the caller
/// branch on whether the user typed in fresh values, asked to pick a saved
/// bundle, dismissed the sheet, or chose the "save and continue" variant
/// (Saqqar resumes immediately; the sheet still pops but the caller
/// surfaces a different toast).
enum InlineCredentialResultKind {
  provided,
  providedContinuing,
  pickSaved,
  cancelled,
}

class InlineCredentialResult {
  const InlineCredentialResult._({
    required this.kind,
    this.credentialKind,
    this.values,
    this.memorize = false,
  });

  final InlineCredentialResultKind kind;
  final DemoCredentialKind? credentialKind;
  final Map<String, String>? values;
  final bool memorize;
}

class InlineCredentialRequest extends StatefulWidget {
  const InlineCredentialRequest({
    super.key,
    required this.onProvide,
    required this.onPickSaved,
    required this.onCancel,
    this.initialKind = DemoCredentialKind.postgres,
    this.initialMemorize = false,
  });

  /// Opens the credential request inside a draggable, keyboard-aware
  /// ModalBottomSheet — preferred over the inline render because the
  /// schema-driven form often runs taller than the available space when
  /// the keyboard is up. The sheet auto-scrolls, dims the underlying
  /// chat, and is dismissable via swipe-down.
  ///
  /// Returns null when the user dismisses without committing. Use the
  /// returned [InlineCredentialResult] to know whether they typed in
  /// fresh values, opted to pick a saved bundle, or just cancelled.
  static Future<InlineCredentialResult?> show(
    BuildContext context, {
    required DemoCredentialKind initialKind,
    bool initialMemorize = false,
  }) {
    return showModalBottomSheet<InlineCredentialResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (sheetContext) {
        // Keyboard-aware padding — the form is mostly password / multi-line
        // fields so the keyboard nearly always pops. `viewInsetsOf` makes
        // the sheet float above the keyboard without rebuilding when
        // unrelated MediaQuery fields change.
        final keyboardInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, controller) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle — Material BottomSheet pattern.
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 6, bottom: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(sheetContext).dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      InlineCredentialRequest(
                        initialKind: initialKind,
                        initialMemorize: initialMemorize,
                        onProvide:
                            (kind, values, memorize, {continuing = false}) {
                          Navigator.of(sheetContext).pop(
                            InlineCredentialResult._(
                              kind: continuing
                                  ? InlineCredentialResultKind
                                      .providedContinuing
                                  : InlineCredentialResultKind.provided,
                              credentialKind: kind,
                              values: values,
                              memorize: memorize,
                            ),
                          );
                        },
                        onPickSaved: () => Navigator.of(sheetContext).pop(
                          const InlineCredentialResult._(
                            kind: InlineCredentialResultKind.pickSaved,
                          ),
                        ),
                        onCancel: () => Navigator.of(sheetContext).pop(
                          const InlineCredentialResult._(
                            kind: InlineCredentialResultKind.cancelled,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Returns the credential kind, the typed-in values, the memorize flag,
  /// and whether the user picked the "save and continue" variant
  /// (`continuing=true` → agent resumes immediately; toast wording
  /// differs). Web parity for the `saveAndContinue` button on the
  /// credential request modal.
  final void Function(
    DemoCredentialKind kind,
    Map<String, String> values,
    bool memorize, {
    bool continuing,
  }) onProvide;

  /// Tapped when the user wants to reuse a saved bundle instead of typing.
  final VoidCallback onPickSaved;

  /// Dismiss the inline request.
  final VoidCallback onCancel;

  final DemoCredentialKind initialKind;
  final bool initialMemorize;

  @override
  State<InlineCredentialRequest> createState() =>
      _InlineCredentialRequestState();
}

class _InlineCredentialRequestState extends State<InlineCredentialRequest> {
  late DemoCredentialKind _kind = widget.initialKind;
  late bool _memorize = widget.initialMemorize;
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

  /// Honours a field's `showWhen` gate by checking the current value of the
  /// referenced sibling field. Returns true (always show) when the field
  /// has no gate.
  bool _shouldShow(DemoCredentialSchema schema, DemoCredentialField field) {
    final rule = field.showWhen;
    if (rule == null) return true;
    final siblingKey = '${schema.kind.name}.${rule.field}';
    final siblingValue =
        _controllers[siblingKey]?.text.trim().toLowerCase() ?? '';
    return rule.values
        .map((v) => v.toLowerCase())
        .contains(siblingValue);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit({bool continuing = false}) {
    final schema = _schema;
    final values = <String, String>{};
    for (final field in schema.fields) {
      final c = _controllers['${schema.kind.name}.${field.name}'];
      values[field.name] = (c?.text ?? '').trim();
    }
    widget.onProvide(_kind, values, _memorize, continuing: continuing);
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
          for (final field in schema.fields)
            if (_shouldShow(schema, field)) ...[
              _InlineSchemaField(
                field: field,
                controller: _controllers['${schema.kind.name}.${field.name}']!,
                onValueChanged: field.options.isNotEmpty
                    ? () => setState(() {})
                    : null,
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 4),
          _MemorizeToggleRow(
            value: _memorize,
            onChanged: (v) => setState(() => _memorize = v),
          ),
          const SizedBox(height: 10),
          // Secondary row — "Use saved" + "Save and continue". Both ghost
          // buttons so the primary action (provide + dismiss) stays the
          // most visually prominent below.
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: context.tr.useExistingCredential,
                  icon: AppIcons.archive,
                  minHeight: 42,
                  onPressed: widget.onPickSaved,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GhostButton(
                  label: context.tr.saveAndContinue,
                  icon: AppIcons.bolt,
                  minHeight: 42,
                  onPressed: () => _submit(continuing: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Primary action — full-width Provide credential. Mirrors the
          // web's "Save Credential" green CTA placement.
          PrimaryButton(
            label: context.tr.provideCredential,
            icon: AppIcons.check,
            minHeight: 46,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// "Memorize this credential for future chats after approval" — Web parity
/// for `rememberCredentialInput`. Pill-style toggle (matches the
/// AppBar/header toggle language used elsewhere in chat) so the whole row
/// reads as one tap target and stays visually consistent with Deep think
/// + Auto-approve. When ON: cyan-tinted plate + filled bookmark glyph.
/// When OFF: muted bookmark outline.
class _MemorizeToggleRow extends StatelessWidget {
  const _MemorizeToggleRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final accent = value ? s.brandCyan : s.muted;
    return Tooltip(
      message: context.tr.memorizeCredential,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.buttonR,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: AppRadius.buttonR,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: value
                  ? s.brandCyan.withValues(alpha: context.isDark ? 0.14 : 0.08)
                  : s.surface2.withValues(
                      alpha: context.isDark ? 0.45 : 0.85,
                    ),
              borderRadius: AppRadius.buttonR,
              border: Border.all(
                color: value
                    ? s.brandCyan.withValues(alpha: 0.45)
                    : s.cardBorder,
                width: value ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    value ? AppIcons.shieldCheck : AppIcons.shield,
                    key: ValueKey<bool>(value),
                    size: 18,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr.memorizeCredential,
                    style: context.text.bodySmall?.copyWith(
                      color: value ? s.text : s.muted,
                      fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders one schema field — text / password / multiline / dropdown.
/// Mirrors the Vault sheet's `_SchemaField` so the two surfaces look the same.
/// When [field.help] is set, an italic hint is appended below the input.
/// [onValueChanged] fires after a dropdown selection so the parent can
/// rebuild and re-evaluate any sibling field's `showWhen` gate.
class _InlineSchemaField extends StatelessWidget {
  const _InlineSchemaField({
    required this.field,
    required this.controller,
    this.onValueChanged,
  });

  final DemoCredentialField field;
  final TextEditingController controller;
  final VoidCallback? onValueChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final input = _buildInput();
    if (field.help == null) return input;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        input,
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Text(
            field.help!,
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
          if (value == null) return;
          controller.text = value;
          onValueChanged?.call();
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
