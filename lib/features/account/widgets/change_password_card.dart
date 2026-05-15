import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/primary_button.dart';

/// Spec §9.3 — change password card placed inside the Account screen.
///
/// Wired to a mock submit today; once backend ships
/// `POST /api/auth/password/change/`, replace `_submit` with the real call.
/// The endpoint returns fresh tokens so the user stays signed in.
class ChangePasswordCard extends StatefulWidget {
  const ChangePasswordCard({super.key});

  @override
  State<ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<ChangePasswordCard> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  String? _currentError;
  String? _nextError;
  String? _confirmError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _validate() {
    final tr = context.tr;
    setState(() {
      _currentError = _current.text.isEmpty ? tr.passwordTooShort : null;
      _nextError = _next.text.length < 8 ? tr.passwordTooShort : null;
      _confirmError =
          _confirm.text != _next.text ? tr.passwordsDoNotMatch : null;
    });
    return _currentError == null &&
        _nextError == null &&
        _confirmError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _loading = false);

    AppToast.show(
      context,
      message: context.tr.passwordUpdatedToast,
      variant: ToastVariant.success,
    );

    _current.clear();
    _next.clear();
    _confirm.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.tr.changePassword, style: context.text.titleMedium),
          const SizedBox(height: 6),
          Text(
            context.tr.changePasswordHint,
            style: context.text.bodySmall?.copyWith(color: s.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPasswordField(
                  label: context.tr.currentPassword,
                  controller: _current,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                  errorText: _currentError,
                ),
                const SizedBox(height: 12),
                AppPasswordField(
                  label: context.tr.newPassword,
                  controller: _next,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  errorText: _nextError,
                ),
                const SizedBox(height: 12),
                AppPasswordField(
                  label: context.tr.confirmPassword,
                  controller: _confirm,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  errorText: _confirmError,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: context.tr.updatePassword,
            icon: AppIcons.lock,
            loading: _loading,
            expand: true,
            onPressed: _loading ? null : _submit,
          ),
        ],
      ),
    );
  }
}
