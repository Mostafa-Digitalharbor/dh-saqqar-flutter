part of 'account_screen.dart';

class _Devices extends StatefulWidget {
  const _Devices();

  @override
  State<_Devices> createState() => _DevicesState();
}

class _DevicesState extends State<_Devices> {
  List<DeviceRow>? _rows;

  @override
  void initState() {
    super.initState();
    context
        .read<DevicesApi>()
        .list()
        .then((v) {
          if (mounted) setState(() => _rows = v);
        })
        .catchError((_) {
          if (mounted) setState(() => _rows = const []);
        });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    Widget card(String title, String sub, {VoidCallback? onRevoke}) =>
        Container(
          margin: const EdgeInsets.only(top: AppSpacing.s8),
          padding: const EdgeInsets.fromLTRB(AppSpacing.s14, AppSpacing.s12, AppSpacing.s10, AppSpacing.s12),
          decoration: BoxDecoration(
            color: AppColors.figWhite,
            borderRadius: BorderRadius.circular(AppRadius.modal),
            border: Border.all(color: Fig.borderBlue),
          ),
          child: Row(
            children: [
              Container(
                width: FigMetrics.size36, height: FigMetrics.size36,
                decoration: BoxDecoration(
                  color: AppColors.figCFFE7ECFB,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: const Icon(
                  LucideIcons.smartphone,
                  size: AppIconSizes.listMark,
                  color: Fig.blueSoft,
                ),
              ),
              const SizedBox(width: AppSpacing.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Fig.t(
                        context,
                        size: AppFontSizes.metaLine,
                        weight: FontWeight.w700,
                        color: Fig.navy,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      sub,
                      style: Fig.t(context, size: FigMetrics.fontFig10, color: Fig.muted),
                    ),
                  ],
                ),
              ),
              if (onRevoke != null)
                GestureDetector(
                  onTap: onRevoke,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.s6),
                    child: Icon(
                      LucideIcons.logOut,
                      size: AppIconSizes.small,
                      color: Fig.dangerText,
                    ),
                  ),
                ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr.figSessions,
          style: Fig.t(
            context,
            size: FigMetrics.fontFig9,
            weight: FontWeight.w500,
            color: Fig.muted,
            letterSpacing: AppLetterSpacing.label,
          ),
        ),
        if (rows == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.s16),
            child: Center(
              child: SizedBox(
                width: FigMetrics.size20, height: FigMetrics.size20,
                child: CircularProgressIndicator(strokeWidth: AppStrokeWidths.spinnerThin),
              ),
            ),
          )
        else if (rows.isEmpty)
          card(context.tr.figThisPhone, context.tr.figSaqqarMobile)
        else
          for (var i = 0; i < rows.length; i++)
            card(
              i == 0
                  ? context.tr.figThisPhone
                  : (rows[i].platform == DevicePlatform.ios
                        ? 'iPhone'
                        : 'Android'),
              'Saqqar mobile${rows[i].appVersion == null ? '' : ' · ${rows[i].appVersion}'}',
              onRevoke: i == 0
                  ? null
                  : () async {
                      final id = rows[i].id;
                      await context.read<DevicesApi>().revoke(id);
                      if (mounted) {
                        setState(
                          () =>
                              _rows = _rows!.where((r) => r.id != id).toList(),
                        );
                      }
                    },
            ),
      ],
    );
  }
}
