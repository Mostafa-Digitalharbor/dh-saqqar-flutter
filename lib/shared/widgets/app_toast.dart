import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../extensions/context_extensions.dart';

enum ToastVariant { success, error, info }

/// Spec §5.13 — bottom-center toast on mobile.
///
/// Use `AppToast.show(context, ...)` to display. Built on top of Material's
/// `ScaffoldMessenger.showSnackBar` so it composes with route changes.
class AppToast {
  AppToast._();

  static void show(
    BuildContext context, {
    required String message,
    ToastVariant variant = ToastVariant.info,
    Duration? duration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        padding: EdgeInsets.zero,
        duration:
            duration ??
            (variant == ToastVariant.error
                ? const Duration(seconds: 5)
                : const Duration(seconds: 3)),
        content: _ToastContent(message: message, variant: variant),
      ),
    );
  }
}

class _ToastContent extends StatelessWidget {
  const _ToastContent({required this.message, required this.variant});

  final String message;
  final ToastVariant variant;

  Color _color(BuildContext context) {
    final s = context.saqqar;
    return switch (variant) {
      ToastVariant.success => s.success,
      ToastVariant.error => s.danger,
      ToastVariant.info => s.brandCyan,
    };
  }

  IconData get _icon => switch (variant) {
    ToastVariant.success => AppIcons.success,
    ToastVariant.error => AppIcons.error,
    ToastVariant.info => AppIcons.info,
  };

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final c = _color(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: s.surface,
            borderRadius: AppRadius.toastR,
            border: Border.all(color: c.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF020617).withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 18, color: c),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: (context.text.bodyMedium ?? const TextStyle())
                      .copyWith(color: c, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
