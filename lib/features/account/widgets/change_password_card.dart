import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../auth/view_model/auth_cubit.dart';

/// Spec §9.3 — change password card placed inside the Account screen.
///
/// Collapsed by default: only the title + a chevron toggle is visible so the
/// account surface stays calm. Tapping the header expands the form (current
/// password, new password, confirm) with an [AnimatedRotation] chevron and
/// [AnimatedCrossFade] body so the transition reads as a single motion.
///
/// Submits to `POST /api/v1/auth/password/` via [AuthCubit]. The endpoint
/// rotates the bearer token (and revokes every other device's token); the
/// cubit stores the fresh one so this device stays signed in seamlessly.
class ChangePasswordCard extends StatefulWidget {
  const ChangePasswordCard({super.key});

  @override
  State<ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<ChangePasswordCard> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _expanded = false;
  bool _loading = false;
  String? _currentError;
  String? _nextError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    // Rebuild as the user types so the button can flip enabled/disabled
    // against the fields-filled + new==confirm rule below.
    _current.addListener(_onFieldChanged);
    _next.addListener(_onFieldChanged);
    _confirm.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  /// Enough is entered to be worth a request: all three fields filled and
  /// the new password matches its confirmation. The ≥8-chars rule stays in
  /// [_validate] (shown as an inline error on submit) so the user learns why
  /// a too-short password bounces rather than facing a silently-dead button.
  bool get _canSubmit =>
      _current.text.isNotEmpty &&
      _next.text.isNotEmpty &&
      _confirm.text.isNotEmpty &&
      _next.text == _confirm.text;

  @override
  void dispose() {
    _current.removeListener(_onFieldChanged);
    _next.removeListener(_onFieldChanged);
    _confirm.removeListener(_onFieldChanged);
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (!_expanded) {
        // Collapsing — clear any errors so the next open starts clean.
        _currentError = null;
        _nextError = null;
        _confirmError = null;
      }
    });
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
    try {
      await context.read<AuthCubit>().changePassword(
            oldPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      AppToast.show(
        context,
        message: context.tr.passwordUpdatedToast,
        variant: ToastVariant.success,
      );
      _current.clear();
      _next.clear();
      _confirm.clear();
      // Auto-collapse on success — the action is done, the calm card state
      // is the resting position.
      setState(() => _expanded = false);
    } catch (e) {
      if (!mounted) return;
      _surface(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Routes any thrown error through the typed [AppFailure] pipeline so
  /// the user-facing message is always localized. Two screen-specific
  /// overrides on top of the generic mapper:
  ///   * [UnauthorizedFailure] (401) → inline error on the "current
  ///     password" field with the password-specific wording.
  ///   * [ValidationFailure] (400) → per-field errors landed on the
  ///     matching input; otherwise falls through to a toast.
  void _surface(Object error) {
    final failure = ApiErrorMapper.toFailure(error);
    final tr = context.tr;
    if (failure is UnauthorizedFailure) {
      setState(() => _currentError = tr.currentPasswordWrong);
      return;
    }
    if (failure is ValidationFailure) {
      final newErr = failure.firstError('new_password');
      final oldErr = failure.firstError('old_password');
      setState(() {
        if (oldErr != null) _currentError = oldErr;
        if (newErr != null) _nextError = newErr;
      });
      if (oldErr != null || newErr != null) return;
    }
    AppToast.show(
      context,
      message: ApiErrorMapper.message(context, failure),
      variant: ToastVariant.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return GlassCard(
      // Flat opaque Account backdrop → the backdrop blur has no visible
      // subject; dropping it removes a saveLayer with pixel-identical output.
      blur: false,
      // Tighter padding so the collapsed header reads as a single row, not
      // a card with a lot of empty space underneath.
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tap-target header: title on the start side, animated chevron on
          // the end side (mirrored automatically in RTL by Flutter).
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Row(
                children: [
                  Icon(AppIcons.lock, size: 18, color: s.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr.changePassword,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: _expanded ? 0.5 : 0,
                    child: Icon(
                      AppIcons.chevronDown,
                      size: 20,
                      color: s.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 8, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.tr.changePasswordHint,
                      style: context.text.bodySmall
                          ?.copyWith(color: s.muted, height: 1.4),
                    ),
                    const SizedBox(height: 14),
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
                      onPressed:
                          (_loading || !_canSubmit) ? null : _submit,
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            ),
          ),
        ],
      ),
    );
  }
}
