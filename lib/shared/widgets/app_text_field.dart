import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../extensions/context_extensions.dart';
import 'eyebrow_label.dart';

/// Spec §5.3 input field with optional eyebrow label, leading/trailing
/// icons, helper, and error.
///
/// For passwords, use [AppPasswordField] instead — it owns the eye toggle.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.controller,
    this.initialValue,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.autofillHints,
  });

  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool enabled;
  final int maxLines;
  final int? minLines;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[EyebrowLabel(label!), const SizedBox(height: 6)],
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofocus: autofocus,
          enabled: enabled,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          style: context.text.bodyMedium,
          cursorColor: s.brandCyan,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            helperText: helper,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 18, color: s.muted),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

/// Password variant with eye toggle.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.controller,
    this.textInputAction,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final TextEditingController? controller;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return AppTextField(
      label: widget.label,
      hint: widget.hint,
      helper: widget.helper,
      errorText: widget.errorText,
      controller: widget.controller,
      textInputAction: widget.textInputAction,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      obscureText: _hidden,
      autofillHints: widget.autofillHints,
      prefixIcon: AppIcons.lock,
      suffixIcon: IconButton(
        icon: Icon(
          _hidden ? AppIcons.eye : AppIcons.eyeOff,
          size: 18,
          color: s.muted,
        ),
        onPressed: () => setState(() => _hidden = !_hidden),
        tooltip: _hidden ? context.tr.showPassword : context.tr.hidePassword,
      ),
    );
  }
}
