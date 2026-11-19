part of 'project_detail_sheet.dart';

/// Full-width pill button — "← All projects" back link rendered below
/// the dialog divider. Closes the current project detail and reopens the
/// projects list. Web parity (`backToProjects` label + ghost styling).
class _BackToProjectsPill extends StatelessWidget {
  const _BackToProjectsPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.pillR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillR,
        child: Container(
          height: AppControlSizes.pillRowHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.surface2.withValues(
              alpha: context.alpha(AppAlphaPairs.panel),
            ),
            borderRadius: AppRadius.pillR,
            border: Border.all(color: s.cardBorder),
          ),
          // The back arrow is an Icon, not a '←' glyph baked into the
          // string. A literal arrow keeps pointing left after the sheet
          // flips to RTL, where "back" is to the *right* — so in Arabic it
          // pointed at the direction the user came from. Resolving the
          // chevron from `isRtl` mirrors it with the layout, the same way
          // `ProjectCard`'s disclosure chevron already does.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                context.chevronBack,
                size: AppIconSizes.small,
                color: s.text,
              ),
              const SizedBox(width: AppSpacing.s6),
              Flexible(
                child: Text(
                  context.tr.backToProjects,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: s.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the env card list as a plain Column. The server doesn't
/// support custom env ordering, so the previous drag-to-reorder affordance
/// was removed.
class _EnvList extends StatelessWidget {
  const _EnvList({
    required this.envs,
    required this.onOpen,
    required this.onDelete,
  });

  final List<Environment> envs;
  final void Function(Environment env) onOpen;
  final void Function(Environment env) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final env in envs)
          _EnvRow(
            key: ValueKey(env.id),
            env: env,
            onOpen: () => onOpen(env),
            onDelete: () => onDelete(env),
          ),
      ],
    );
  }
}

/// Always-editable env-name field. Renders as plain bold text until the
/// user taps; tapping focuses + shows a subtle underline so the user
/// knows it's editable. Submit + blur both commit via the parent.
class _InlineNameField extends StatelessWidget {
  const _InlineNameField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      style: context.text.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: AppLineHeights.heading,
      ),
      cursorColor: s.brandCyan,
      decoration: InputDecoration(
        isCollapsed: true,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.transparent),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.transparent),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: s.brandCyan,
            width: AppBorderWidths.medium,
          ),
        ),
      ),
    );
  }
}

/// Tick-style flag — square Material checkbox + label, hit-target
/// extends across the whole row so the user can tap the label too.
/// Replaces the previous Switch-based design — checkboxes mirror the
/// web and read as "tick what applies" instead of "flip a gate".
class _FlagCheckbox extends StatelessWidget {
  const _FlagCheckbox({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: AppRadius.microR,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2,
          vertical: AppSpacing.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: AppIconSizes.regular,
              height: AppIconSizes.regular,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: activeColor,
                side: BorderSide(
                  color: s.cardBorder,
                  width: AppBorderWidths.medium,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s6),
            // `Flexible`, because a `Row` hands a non-flex child unbounded
            // main-axis width — so this label neither wrapped nor ellipsized
            // however narrow the phone, and a single checkbox overflowed by
            // 14 px at 320 px in Arabic at 1.4× text. Putting the pair of them
            // in a `Wrap` above fixed the pair; it could not fix one child
            // that is wider than the line it sits on.
            //
            // It wraps rather than ellipsizes on purpose: this is a control's
            // label, and "قراءة فق…" leaves the user guessing what they are
            // about to toggle on a live Odoo instance.
            Flexible(
              child: Text(
                label,
                style: context.text.labelMedium?.copyWith(
                  color: value ? activeColor : s.text,
                  fontWeight: value ? FontWeight.w700 : FontWeight.w500,
                  fontSize: AppFontSizes.footnote,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
