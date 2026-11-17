part of 'account_screen.dart';

class _Accordion extends StatelessWidget {
  const _Accordion({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.open,
    required this.onTap,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool open;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      decoration: BoxDecoration(
        color: Fig.cardFill.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE1F1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 16, color: Fig.tileText),
                  ),
                  const SizedBox(width: AppSpacing.s11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Fig.t(
                            context,
                            size: 13.5,
                            weight: FontWeight.w500,
                            color: Fig.navy,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Fig.t(context, size: 8.5, color: Fig.muted),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: AppDurations.fast,
                    child: const Icon(
                      LucideIcons.chevronDown,
                      size: 22,
                      color: Fig.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDurations.expand,
            alignment: Alignment.topCenter,
            curve: Curves.easeOutCubic,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow(this.icon, this.label, this.onTap, {this.last = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFD9E0F5))),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF5B6585)),
            const SizedBox(width: AppSpacing.s14),
            Expanded(
              child: Text(
                label,
                style: Fig.t(
                  context,
                  size: 13.5,
                  weight: FontWeight.w500,
                  color: Fig.navy,
                ),
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? LucideIcons.chevronLeft
                  : LucideIcons.chevronRight,
              size: 18,
              color: Fig.mutedSoft,
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s6,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Fig.t(context, size: 14, color: Fig.dangerText),
              ),
            ),
            Icon(icon, size: 20, color: Fig.dangerText),
          ],
        ),
      ),
    );
  }
}
