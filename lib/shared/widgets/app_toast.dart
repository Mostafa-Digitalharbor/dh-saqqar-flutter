import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../extensions/context_extensions.dart';

enum ToastVariant { success, error, info }

/// An inline action button rendered on the trailing edge of a toast.
///
/// Use for retry-style affordances (network errors), undo (after deletes),
/// or "View details" links. Tap auto-dismisses the toast before invoking
/// [onPressed] so navigating away doesn't leave the toast hanging.
class ToastAction {
  const ToastAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// Spec §5.13 — bottom-center toast on mobile.
///
/// Use `AppToast.show(context, ...)` to display. Built on top of Material's
/// `ScaffoldMessenger.showSnackBar` so it composes with route changes.
///
/// Two-line layout when both [title] and [message] are supplied:
///   * **Title** — bold, action-contextual ("Couldn't save the credential").
///   * **Message** — muted weight, the actual error ("Check your connection").
///
/// One-line layout when only [message] is supplied (back-compat with the
/// older single-string call sites).
class AppToast {
  AppToast._();

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    ToastVariant variant = ToastVariant.info,
    Duration? duration,
    ToastAction? action,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    // Wrap the action so the toast dismisses BEFORE the user's callback
    // runs. Any navigation triggered inside the callback would otherwise
    // race with the snackbar's dismiss animation.
    final wrappedAction = action == null
        ? null
        : ToastAction(
            label: action.label,
            onPressed: () {
              messenger.hideCurrentSnackBar();
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => action.onPressed());
            },
          );

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: AppElevations.none,
        margin: const EdgeInsets.only(
          bottom: AppSpacing.s24,
          left: AppSpacing.s16,
          right: AppSpacing.s16,
        ),
        padding: EdgeInsets.zero,
        duration: duration ??
            (variant == ToastVariant.error
                ? AppDurations.toastDwellError
                : AppDurations.toastDwell),
        content: _ToastContent(
          title: title,
          message: message,
          variant: variant,
          action: wrappedAction,
        ),
      ),
    );
  }
}

class _ToastContent extends StatelessWidget {
  const _ToastContent({
    required this.message,
    required this.variant,
    this.title,
    this.action,
  });

  final String? title;
  final String message;
  final ToastVariant variant;
  final ToastAction? action;

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
    final hasTitle = title != null && title!.trim().isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayoutWidths.toast),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s14,
            vertical: AppSpacing.s12,
          ),
          decoration: BoxDecoration(
            color: s.surface,
            borderRadius: AppRadius.toastR,
            border: Border.all(color: c.withValues(alpha: AppAlphas.a45)),
            // Its own shape (tighter than `modalShadow`) because a toast sits
            // close to the surface it annotates, not above a dimmed page —
            // only the hue is shared.
            boxShadow: [
              BoxShadow(
                color: s.shadowBase.withValues(alpha: AppAlphas.a35),
                blurRadius: AppShadowSizes.blurCard,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s2),
                child: Icon(_icon, size: AppIconSizes.regular, color: c),
              ),
              const SizedBox(width: AppSpacing.s10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasTitle) ...[
                      Text(
                        title!,
                        style: (context.text.bodyMedium ?? const TextStyle())
                            .copyWith(
                          color: c,
                          fontWeight: FontWeight.w800,
                          height: AppLineHeights.headingLoose,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        message,
                        style: (context.text.bodySmall ?? const TextStyle())
                            .copyWith(color: s.muted, height: AppLineHeights.label),
                      ),
                    ] else
                      Text(
                        message,
                        style: (context.text.bodyMedium ?? const TextStyle())
                            .copyWith(color: c, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppSpacing.s10),
                _ToastActionButton(action: action!, color: c),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastActionButton extends StatelessWidget {
  const _ToastActionButton({required this.action, required this.color});

  final ToastAction action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: action.onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: AppSpacing.s6,
        ),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(action.label),
    );
  }
}
