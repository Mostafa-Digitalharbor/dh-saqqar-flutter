part of 'auth_flow_screen.dart';

enum _OtpKind { signup, signin, reset }

class _OtpPage extends StatefulWidget {
  const _OtpPage({super.key, required this.kind, required this.onBack});

  final _OtpKind kind;
  final VoidCallback onBack;

  @override
  State<_OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<_OtpPage> {
  static const _len = 6;
  static const _cooldown = 60;

  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _wrong = false;
  int _remaining = _cooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remaining = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remaining <= 1) {
        t.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _verify() {
    final code = _controller.text.trim();
    if (code.length != _len) {
      setState(() => _wrong = true);
      return;
    }
    setState(() => _wrong = false);
    final cubit = context.read<AuthFlowCubit>();
    switch (widget.kind) {
      case _OtpKind.signup:
        cubit.verifySignUpOtp(code);
      case _OtpKind.signin:
        cubit.verifySignInOtp(code);
      case _OtpKind.reset:
        cubit.verifyResetOtp(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthFlowCubit>();
    final state = context.watch<AuthFlowCubit>().state;
    // A server-side rejection also paints the boxes red.
    final wrong = _wrong || (state.failure != null && state.isOtpStep);
    final loading = state.loading;
    final code = _controller.text;
    return AuthFrame(
      onBack: widget.onBack,
      pillLabel: context.tr.figSignIn,
      onPill: cubit.toSignIn,
      titleGap: 98,
      subtitleGap: 10,
      bodyGap: 44,
      title: context.tr.figOtpVerification,
      subtitle: context.tr.figEnterOtpCodeSentToYour,
      children: [
        Text(
          context.tr.figOtp,
          style: Fig.t(
            context,
            size: AppFontSizes.reading,
            color: AppColors.figCFF5A6590,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        Stack(
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final w = ((c.maxWidth - 5 * 6) / _len).clamp(30.0, 46.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < _len; i++)
                      _OtpBox(
                        width: w,
                        char: i < code.length ? code[i] : '',
                        active: i == code.length && _focus.hasFocus,
                        error: wrong,
                      ),
                  ],
                );
              },
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_len),
                  ],
                  onChanged: (v) {
                    setState(() => _wrong = false);
                    if (v.length == _len) _verify();
                  },
                  enableInteractiveSelection: false,
                ),
              ),
            ),
          ],
        ),
        if (wrong)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: Text(
              context.tr.figOtpNotCorrect,
              style: Fig.t(context, size: AppFontSizes.caption, color: Fig.dangerText),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: EdgeInsets.only(top: wrong ? 0 : AppSpacing.s8),
            child: GestureDetector(
              onTap: _remaining > 0
                  ? null
                  : () {
                      cubit.resend();
                      _startTimer();
                    },
              child: Text(
                _remaining > 0
                    ? '${context.tr.figResendCode} (${_remaining}s)'
                    : context.tr.figResendCode,
                style: Fig.t(
                  context,
                  size: AppFontSizes.caption,
                  color: _remaining > 0
                      ? AppColors.figCFF5A66A8
                      : AppColors.figCFF3B4A9E,
                ),
              ).withUnderline(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s30),
        FigButton(
          label: context.tr.figVerify,
          loading: loading,
          onPressed: _verify,
        ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.char,
    required this.active,
    required this.error,
    this.width = 46,
  });

  final double width;

  final String char;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final border = error
        ? Fig.danger
        : active
        ? AppColors.figCFF6A7BC8
        : AppColors.figCFFA9B6E6;
    return Container(
      width: width,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.figWhite.withValues(alpha: AppAlphas.a28),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: border, width: AppBorderWidths.medium),
      ),
      child: char.isNotEmpty
          ? Text(
              char,
              style: Fig.t(
                context,
                size: AppFontSizes.crashTitle,
                color: Fig.navy,
                weight: FontWeight.w600,
              ),
            )
          : active
          ? Container(width: 1.4, height: 22, color: border)
          : null,
    );
  }
}
