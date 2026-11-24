part of 'project_detail_sheet.dart';

/// One env row inside the project popup — mirrors the web's layout
/// for an environment card:
///
/// ```
/// ┌────────────────────────────────────────────────────────────┐
/// │ [Test___________]               ☐ Live   ☐ Read-only       │
/// │ 3 credentials                                              │
/// │ ☐ Auto-approve                  [ Open ]    [ Delete ]     │
/// └────────────────────────────────────────────────────────────┘
/// ```
///
///   1. Always-editable name TextField — web parity for the inline
///      rename. Submitting or losing focus commits via
///      [VaultCubit.updateEnvironment].
///   2. Credential count chip — only renders when the env has at least
///      one saved credential so empty envs stay quiet.
///   3. Checkboxes (not switches) for the three flags — match the web
///      "tick what applies" semantics.
///   4. Toggling **Live** false → true pops a confirm dialog (the gate
///      is destructive UX — first-send warning fires from that moment).
///      Toggling true → false is one-tap (lifts a gate, non-destructive).
class _EnvRow extends StatefulWidget {
  const _EnvRow({
    super.key,
    required this.env,
    required this.onOpen,
    required this.onDelete,
  });

  final Environment env;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  State<_EnvRow> createState() => _EnvRowState();
}

class _EnvRowState extends State<_EnvRow> {
  late final TextEditingController _rename;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _rename = TextEditingController(text: widget.env.name);
    _focusNode = FocusNode();
    // Commit on blur — handles the case where the user taps elsewhere
    // without pressing Enter (the most common rename pattern).
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commitRename();
    });
  }

  @override
  void didUpdateWidget(covariant _EnvRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External renames (or a different env scrolling into this slot) need
    // to refresh the controller — but ONLY when the field isn't focused,
    // so we don't yank the cursor while the user is typing.
    if (widget.env.name != _rename.text && !_focusNode.hasFocus) {
      _rename.text = widget.env.name;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _rename.dispose();
    super.dispose();
  }

  void _commitRename() {
    final next = _rename.text.trim();
    if (next.isEmpty || next == widget.env.name) {
      // Empty fall-back — restore the previous name so the field never
      // shows blank (the server would reject empty anyway).
      _rename.text = widget.env.name;
      return;
    }
    context.read<VaultCubit>().updateEnvironment(id: widget.env.id, name: next);
  }

  Future<void> _onLiveChanged(bool value) async {
    // Lifting the gate (true → false) is one-tap; setting it (false →
    // true) needs explicit confirmation because the chat surface will
    // start gating first sends from this moment on.
    if (!value) {
      unawaited(
        context.read<VaultCubit>().updateEnvironment(
          id: widget.env.id,
          isLive: false,
        ),
      );
      return;
    }
    final ok = await ConfirmDialog.show(
      context,
      title: context.tr.markEnvLiveTitle,
      body: context.tr.markEnvLiveBody(widget.env.name),
      confirmLabel: context.tr.markAsLive,
      destructive: true,
      icon: AppIcons.shieldAlert,
    );
    if (!ok || !mounted) return;
    unawaited(
      context.read<VaultCubit>().updateEnvironment(
        id: widget.env.id,
        isLive: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final cubit = context.read<VaultCubit>();
    final env = widget.env;
    final credCount = context.select<VaultCubit, int>(
      (c) => c.state.data.dataOrNull?.credentialsByEnv[env.id]?.length ?? 0,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s12,
          AppSpacing.s10,
          AppSpacing.s14,
          AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: s.surface2.withValues(
            alpha: context.alpha(AppAlphaPairs.panel),
          ),
          borderRadius: AppRadius.cardR,
          border: Border.all(
            // Live envs get a subtle danger border so they're scannable
            // in a long project list. The web does the same via
            // `env-row--live`.
            color: env.isLive
                ? s.danger.withValues(alpha: AppAlphas.a40)
                : s.cardBorder,
            width: env.isLive ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Line 1: env name (editable), full width ──────────────
            //
            // The name and the two flags used to share one `Row`, with the
            // field in an `Expanded`. That overflowed by 15 px at 320 px:
            // `Expanded` shrinks to zero but no further, and "Live" +
            // "Read-only" — each a `Text` in a `mainAxisSize.min` Row, so
            // neither wraps nor ellipsizes — are together wider than the card.
            // No amount of flex on the field could have absorbed it.
            //
            // Giving the field the whole line is also the better layout for
            // what it holds: these are Odoo instance names, routinely 50+
            // characters, and it is an editable field rather than a label.
            _InlineNameField(
              controller: _rename,
              focusNode: _focusNode,
              onSubmitted: (_) {
                _commitRename();
                _focusNode.unfocus();
              },
            ),
            const SizedBox(height: AppSpacing.s8),
            // ── Line 2: the two env flags, flowing ──────────────────
            //
            // `Wrap` rather than `Row` for the same reason as the action band
            // below: at 320 px in Arabic the pair does not fit on one line,
            // and a checkbox label that ellipsizes to "Read-o…" is worse than
            // one that moves down a line.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.s10,
              runSpacing: AppSpacing.s4,
              children: [
                _FlagCheckbox(
                  label: context.tr.flagLive,
                  value: env.isLive,
                  activeColor: s.danger,
                  onChanged: _onLiveChanged,
                ),
                _FlagCheckbox(
                  label: context.tr.flagReadOnly,
                  value: env.readOnly,
                  activeColor: s.muted,
                  onChanged: (v) =>
                      cubit.updateEnvironment(id: env.id, readOnly: v),
                ),
              ],
            ),
            // ── Credential count chip — only when count > 0 ────────
            if (credCount > 0) ...[
              const SizedBox(height: AppSpacing.s6),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: AppSpacing.s4),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.key,
                      size: AppIconSizes.metaTight,
                      color: s.muted,
                    ),
                    const SizedBox(width: AppSpacing.s4),
                    Text(
                      context.tr.credentialCount(credCount),
                      style: context.text.labelSmall?.copyWith(
                        color: s.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: AppFontSizes.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s10),
            // ── Row 2: Auto-approve + Open + Delete ─────────────────
            // Wrap (not Row) so on narrow phones the action buttons
            // can flow to a second line instead of overflowing. The
            // checkbox keeps the start side, Open + Delete sit on the
            // end via the inner Row — they read as a single action
            // group regardless of whether the line wrapped.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                _FlagCheckbox(
                  label: context.tr.flagAutoApprove,
                  value: env.autoApprove,
                  activeColor: s.warning,
                  onChanged: (v) =>
                      cubit.updateEnvironment(id: env.id, autoApprove: v),
                ),
                // A `Wrap`, not a `Row`. The outer `Wrap` hands this child a
                // maxWidth equal to its own, so a `Row(mainAxisSize: min)`
                // here was still 2.8 px too wide at 320 px once the two
                // buttons had taken their natural size — the outer wrap could
                // move the group to a second run, but nothing could split the
                // group itself. Nesting a `Wrap` lets Delete fall under Open
                // on the narrowest phones while they stay side by side
                // everywhere else.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    FigButton.compact(
                      label: context.tr.openEnvironment,
                      height: AppControlSizes.rowMin,
                      onPressed: widget.onOpen,
                    ),
                    FigButton.compact(
                      secondary: true,
                      label: context.tr.delete,
                      height: AppControlSizes.rowMin,
                      dangerOutline: true,
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
