import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/network/view_model/connectivity_cubit.dart';
import '../../core/theme/app_icons.dart';
import '../extensions/context_extensions.dart';

/// Top-of-screen sticky banner that animates in when the device is offline.
///
/// Reads [ConnectivityCubit] so it stays in lockstep with any other surface
/// that depends on connectivity (e.g., the chat composer disables send when
/// this is shown). Animates a 220 ms ease-out slide + fade so going
/// on/offline feels intentional, not jarring.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, bool>(
      builder: (context, online) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: online
                ? const SizedBox.shrink(key: ValueKey('online'))
                : const _OfflineRow(key: ValueKey('offline')),
          ),
        );
      },
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
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
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
              Icon(AppIcons.cloudOff, color: s.danger, size: 18),
              const SizedBox(width: 10),
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
                        fontSize: 11,
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
