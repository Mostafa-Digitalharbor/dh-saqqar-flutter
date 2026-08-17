import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/network/view_model/connectivity_cubit.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../extensions/context_extensions.dart';

/// Top-of-screen sticky banner that animates in when the device is offline.
///
/// Reads [ConnectivityCubit] so it stays in lockstep with any other surface
/// that depends on connectivity (e.g., the chat composer disables send when
/// this is shown). Animates a 220 ms ease-out slide + fade so going
/// on/offline feels intentional, not jarring.
///
/// On the offline → online transition the banner briefly flashes a green
/// "back online" row before sliding out, so the user gets a moment of
/// confirmation that work is safe to resume instead of the banner just
/// vanishing.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  /// Tracks whether the *previous* connectivity tick was offline. The
  /// celebratory "back online" flash only fires on the falling edge —
  /// not on first paint when the user happens to already be online.
  bool _wasOffline = false;

  /// While non-null, the banner shows the green confirmation row. A
  /// timer set in `_showBackOnline` clears this back to null so the
  /// AnimatedSwitcher can slide everything offscreen.
  Timer? _backOnlineTimer;
  bool _showBackOnline = false;

  static const _flashDuration = Duration(milliseconds: 1400);

  @override
  void dispose() {
    _backOnlineTimer?.cancel();
    super.dispose();
  }

  void _scheduleBackOnlineFlash() {
    _backOnlineTimer?.cancel();
    setState(() => _showBackOnline = true);
    _backOnlineTimer = Timer(_flashDuration, () {
      if (!mounted) return;
      setState(() => _showBackOnline = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, bool>(
      listener: (_, online) {
        if (_wasOffline && online) _scheduleBackOnlineFlash();
        _wasOffline = !online;
      },
      builder: (context, online) {
        final Widget body;
        if (!online) {
          body = const _OfflineRow(key: ValueKey('offline'));
        } else if (_showBackOnline) {
          body = const _BackOnlineRow(key: ValueKey('back-online'));
        } else {
          body = const SizedBox.shrink(key: ValueKey('online'));
        }
        return AnimatedSize(
          duration: AppDurations.cardIn,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: AppDurations.cardIn,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: body,
          ),
        );
      },
    );
  }
}

/// Brief green confirmation row shown right after the device flips
/// offline → online. Auto-dismisses ~1.4 s later via the parent's
/// timer, then the AnimatedSwitcher slides everything out — so the
/// user sees "Back online" momentarily instead of the offline row
/// just disappearing into nothing.
class _BackOnlineRow extends StatelessWidget {
  const _BackOnlineRow({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s14,
          AppSpacing.s10,
          AppSpacing.s14,
          AppSpacing.s10,
        ),
        decoration: BoxDecoration(
          color: s.success.withValues(alpha: context.isDark ? 0.18 : 0.10),
          border: Border(
            bottom: BorderSide(color: s.success.withValues(alpha: 0.32)),
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Row(
            children: [
              Icon(AppIcons.success, color: s.success, size: AppIconSizes.regular),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Text(
                  context.tr.backOnline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge?.copyWith(
                    color: s.success,
                    fontWeight: FontWeight.w800,
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

class _OfflineRow extends StatelessWidget {
  const _OfflineRow({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s14,
          AppSpacing.s10,
          AppSpacing.s14,
          AppSpacing.s10,
        ),
        decoration: BoxDecoration(
          color: s.danger.withValues(alpha: context.isDark ? 0.18 : 0.10),
          border: Border(
            bottom: BorderSide(color: s.danger.withValues(alpha: 0.32)),
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Row(
            children: [
              Icon(AppIcons.cloudOff, color: s.danger, size: AppIconSizes.regular),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr.offlineTitle,
                      style: context.text.labelLarge?.copyWith(
                        color: s.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      context.tr.offlineBody,
                      style: context.text.labelSmall?.copyWith(
                        color: s.danger,
                        fontWeight: FontWeight.w500,
                        fontSize: AppFontSizes.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
