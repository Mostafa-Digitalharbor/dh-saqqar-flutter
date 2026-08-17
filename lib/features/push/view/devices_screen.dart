import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/colored_icon_box.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/devices_api.dart';

/// Lists the devices registered to receive this account's push notifications
/// (`GET /devices/`) and lets the user sign any of them out
/// (`DELETE /devices/<id>/`) — useful after losing a phone.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  late Future<List<DeviceRow>> _future;
  final _revoking = <String>{};

  @override
  void initState() {
    super.initState();
    _future = context.read<DevicesApi>().list();
  }

  Future<void> _reload() async {
    final f = context.read<DevicesApi>().list();
    // Block body (not an arrow) so the closure returns void — an arrow
    // `() => _future = f` returns the assigned Future, which trips
    // setState's "callback must not return a Future" assert.
    setState(() {
      _future = f;
    });
    await f;
  }

  Future<void> _revoke(DeviceRow device) async {
    final tr = context.tr;
    final ok = await ConfirmDialog.show(
      context,
      title: tr.deviceRevoke,
      body: '${device.tokenPreview} · ${device.platform.wire}',
      confirmLabel: tr.deviceRevoke,
      destructive: true,
      icon: AppIcons.trash,
    );
    if (!ok || !mounted) return;
    setState(() => _revoking.add(device.id));
    try {
      await context.read<DevicesApi>().revoke(device.id);
      if (!mounted) return;
      AppToast.show(context, message: tr.deviceRevoked,
          variant: ToastVariant.success);
      await _reload();
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: tr.deviceRevokeFailed,
          variant: ToastVariant.error);
    } finally {
      if (mounted) setState(() => _revoking.remove(device.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Scaffold(
      backgroundColor: s.bg,
      appBar: AppBar(title: Text(context.tr.devicesTitle)),
      body: AmbientBackground(
        child: RefreshIndicator(
          color: s.brandCyan,
          backgroundColor: s.surface,
          onRefresh: _reload,
          child: FutureBuilder<List<DeviceRow>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: s.muted),
                );
              }
              // Errors MUST be caught before the empty check. `snap.data` is
              // null on failure, so falling straight through to `?? []` would
              // render the "No devices yet" empty state — telling the user, as
              // a statement of fact, that they have no registered devices when
              // the truth is we couldn't ask. A false success is worse than an
              // error: it's confidently wrong, and it hides the retry.
              if (snap.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: AppSpacing.s80),
                    AppErrorState(
                      message: ApiErrorMapper.message(context, snap.error),
                      onRetry: _reload,
                    ),
                  ],
                );
              }
              final devices = snap.data ?? const <DeviceRow>[];
              if (devices.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: AppSpacing.s80),
                    Center(
                      child: EmptyState(
                        icon: AppIcons.bell,
                        title: context.tr.devicesEmptyTitle,
                        body: context.tr.devicesEmptyBody,
                      ),
                    ),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s14,
                  AppSpacing.s14,
                  AppSpacing.s14,
                  AppSpacing.s24,
                ),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: devices.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
                itemBuilder: (context, i) => _DeviceRowTile(
                  device: devices[i],
                  revoking: _revoking.contains(devices[i].id),
                  onRevoke: () => _revoke(devices[i]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DeviceRowTile extends StatelessWidget {
  const _DeviceRowTile({
    required this.device,
    required this.revoking,
    required this.onRevoke,
  });

  final DeviceRow device;
  final bool revoking;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final isIos = device.platform == DevicePlatform.ios;
    final lastSeen = device.lastSeenAt;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: s.cardBg,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: s.cardBorder),
      ),
      child: Row(
        children: [
          ColoredIconBox(
            icon: isIos ? AppIcons.deviceIos : AppIcons.deviceAndroid,
            color: s.brandCyan,
            iconSize: AppIconSizes.boxGlyphDevice,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // `isNotEmpty`, not `!= null`: the server stores "" (not
                  // null) for a device that registered without a version, so
                  // the null-check rendered a bare "Android · v".
                  '${isIos ? UiStrings.platformIos : UiStrings.platformAndroid}'
                  '${(device.appVersion ?? '').isNotEmpty ? ' · v${device.appVersion}' : ''}',
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  device.tokenPreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: s.muted),
                ),
                if (lastSeen != null) ...[
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    context.tr
                        .deviceLastSeen(AppDateFormat.relative(context, lastSeen)),
                    style: context.text.labelSmall?.copyWith(color: s.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          if (revoking)
            SizedBox(
              width: AppControlSizes.spinnerRow,
              height: AppControlSizes.spinnerRow,
              child: CircularProgressIndicator(strokeWidth: 2, color: s.muted),
            )
          else
            IconButton(
              tooltip: context.tr.deviceRevoke,
              icon: Icon(AppIcons.trash, color: s.danger, size: AppIconSizes.action),
              onPressed: onRevoke,
            ),
        ],
      ),
    );
  }
}
