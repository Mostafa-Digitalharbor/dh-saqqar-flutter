part of 'account_screen.dart';

class _ChangePassword extends StatefulWidget {
  const _ChangePassword({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<_ChangePassword> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _curErr, _nextErr, _confErr;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cur = _current.text;
    final nxt = _next.text;
    final cErr = cur.isEmpty ? context.tr.figRequired : null;
    final nErr = nxt.length < 8 ? context.tr.figAtLeast8Characters : null;
    final fErr = _confirm.text != nxt ? context.tr.figPasswordsDonTMatch : null;
    setState(() {
      _curErr = cErr;
      _nextErr = nErr;
      _confErr = fErr;
    });
    if (cErr != null || nErr != null || fErr != null) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthCubit>().changePassword(
        oldPassword: cur,
        newPassword: nxt,
      );
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      widget.onDone();
      await showFigSheet<void>(
        context,
        builder: (_) => const _PasswordChanged(),
      );
    } catch (e) {
      if (!mounted) return;
      final failure = ApiErrorMapper.toFailure(e);
      if (failure is ValidationFailure ||
          failure is UnauthorizedFailure ||
          failure is ForbiddenFailure) {
        setState(() => _curErr = context.tr.figCouldNotUpdateCheckYourCurrent);
      } else {
        AppToast.show(
          context,
          message: ApiErrorMapper.message(context, failure),
          variant: ToastVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _f(String label, String hint, TextEditingController c, String? err) =>
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s6),
        child: FigField(
          label: label,
          hint: hint,
          controller: c,
          error: err,
          obscure: true,
          height: 46,
          labelColor: Fig.navy,
          onChanged: (_) {},
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr.figUseAtLeast8CharactersYou,
          style: Fig.t(context, size: FigMetrics.fontFig11, color: Fig.muted, height: AppLineHeights.label),
        ),
        _f(
          context.tr.figCurrentPassword,
          context.tr.figEnterYourPassword,
          _current,
          _curErr,
        ),
        _f(
          context.tr.figNewPassword,
          context.tr.figAtLeast8Characters,
          _next,
          _nextErr,
        ),
        _f(
          context.tr.figConfirmPassword,
          context.tr.figReEnterNewPassword,
          _confirm,
          _confErr,
        ),
        const SizedBox(height: AppSpacing.s16),
        FigButton(
          label: context.tr.figUpdatePassword,
          height: 48,
          fontSize: AppFontSizes.body,
          loading: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _PasswordChanged extends StatelessWidget {
  const _PasswordChanged();

  @override
  Widget build(BuildContext context) {
    return FigNotchSheet(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s24, 0, AppSpacing.s24, AppSpacing.s28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AssetPaths.successCheck,
              width: 170,
              filterQuality: FilterQuality.medium,
            ),
            Text(
              context.tr.figPasswordChanged,
              style: Fig.t(context, size: FigMetrics.fontFig29, color: Fig.inkDeep),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text.rich(
              TextSpan(
                style: Fig.t(context, size: AppFontSizes.caption, color: Fig.tileText),
                children: [
                  TextSpan(text: context.tr.figYour),
                  TextSpan(
                    text: context.tr.figPassword,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: context.tr.figHasBeenChangedNsuccessfully),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s24),
            FigButton(
              label: context.tr.figDone,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
