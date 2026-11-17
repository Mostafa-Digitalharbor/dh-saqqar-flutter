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
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Fig.borderBlue),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7ECFB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.smartphone,
                  size: 17,
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
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: Fig.navy,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      sub,
                      style: Fig.t(context, size: 10, color: Fig.muted),
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
                      size: 16,
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
            size: 9,
            weight: FontWeight.w500,
            color: Fig.muted,
            letterSpacing: 0.4,
          ),
        ),
        if (rows == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.s16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
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
