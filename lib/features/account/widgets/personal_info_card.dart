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

/// Personal-information card (Gap I) — mirrors the web `/profile/` form:
/// editable first / last name, read-only email (the login), and a
/// "Save changes" button. Submits to `PATCH /api/v1/auth/me/` via
/// [AuthCubit.updateProfile]; the refreshed user flows back into state so the
/// hero + chat header update live.
class PersonalInfoCard extends StatefulWidget {
  const PersonalInfoCard({super.key});

  @override
  State<PersonalInfoCard> createState() => _PersonalInfoCardState();
}

class _PersonalInfoCardState extends State<PersonalInfoCard> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  bool _loading = false;
  String? _firstError;
  bool _seeded = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  /// Seed the fields from the hydrated user once. Guarded so a re-render
  /// (e.g. counts refresh) doesn't clobber the user's in-progress edits.
  void _seed() {
    if (_seeded) return;
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    _first.text = user.firstName;
    _last.text = user.lastName;
    _seeded = true;
  }

  Future<void> _submit() async {
    final tr = context.tr;
    final first = _first.text.trim();
    if (first.isEmpty) {
      setState(() => _firstError = tr.authNameRequired);
      return;
    }
    setState(() {
      _firstError = null;
      _loading = true;
    });
    try {
      await context.read<AuthCubit>().updateProfile(
            firstName: first,
            lastName: _last.text.trim(),
          );
      if (!mounted) return;
      AppToast.show(
        context,
        message: tr.profileUpdatedToast,
        variant: ToastVariant.success,
      );
    } catch (e) {
      if (!mounted) return;
      final failure = ApiErrorMapper.toFailure(e);
      if (failure is ValidationFailure) {
        final fErr = failure.firstError('first_name');
        if (fErr != null) {
          setState(() => _firstError = fErr);
          return;
        }
      }
      AppToast.show(
        context,
        message: ApiErrorMapper.message(context, failure),
        variant: ToastVariant.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _seed();
    final s = context.saqqar;
    final tr = context.tr;
    final email = context.read<AuthCubit>().state.user?.email ?? '';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.account, size: 18, color: s.brandPurple),
              const SizedBox(width: 10),
              Text(
                tr.personalInfoTitle,
                style: context.text.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tr.personalInfoHint,
            style: context.text.bodySmall?.copyWith(color: s.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: tr.authFirstName,
                  controller: _first,
                  errorText: _firstError,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: tr.authLastName,
                  controller: _last,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: tr.emailLoginLabel,
            initialValue: email,
            enabled: false,
            helper: tr.emailLoginHint,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: tr.saveChanges,
            icon: AppIcons.save,
            loading: _loading,
            expand: true,
            onPressed: _loading ? null : _submit,
          ),
        ],
      ),
    );
  }
}
