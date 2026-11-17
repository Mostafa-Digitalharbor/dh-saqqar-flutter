import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_sizes.dart';
import '../../features/auth/view_model/auth_cubit.dart';
import '../../features/security/view_model/app_lock_cubit.dart';
import '../session/local_session_caches.dart';
import 'app_toast.dart';
import 'blocking_progress_dialog.dart';
import '../fig/account_confirm.dart';

/// Single entry-point for "sign the user out of Saqqar". Shows the
/// destructive confirm (Yes / No), then a compact centred dialog with
/// a thin progress bar while the async work runs (clear vault cache →
/// revoke token), then a success toast. Returns `true` if the user
/// actually signed out, `false` if they cancelled at the confirm step.
Future<bool> showSignOutFlow(BuildContext context) async {
  final tr = context.tr;
  final confirmed = await showFigAccountConfirm(
    context,
    title: context.tr.figSignOutOfSaqqar,
    body: context.tr.figYouLlNeedToSignIn,
    confirmLabel: context.tr.figSignOut,
  );
  if (!confirmed) return false;
  if (!context.mounted) return false;

  // Biometric re-check when the user turned the app lock on. Signing out
  // wipes the local session and is the fastest way for someone holding an
  // unlocked phone to lock the owner out of their own Odoo — so the lock
  // they enabled has to apply here too, not only on cold start.
  //
  // No-op when the lock is off: `confirm` returns true without prompting.
  final unlocked = await context.read<AppLockCubit>().confirm(
    reason: tr.appLockConfirmSignOut,
  );
  if (!unlocked || !context.mounted) return false;

  // Capture references before any awaits — after logout the widget tree
  // is rebuilt by the auth-gate redirect and `context.read` would throw.
  final caches = LocalSessionCaches.of(context);
  final authCubit = context.read<AuthCubit>();
  final navigator = Navigator.of(context, rootNavigator: true);

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.scrimBase.withValues(alpha: AppAlphas.a25),
      builder: (_) => const BlockingProgressDialog(),
    ),
  );

  try {
    // Purge local caches BEFORE revoking the token so the next user
    // signing in on this device can't see the previous user's projects or
    // messages flash on screen while the live fetch runs.
    await caches.clear();
    await authCubit.logout();
  } finally {
    if (navigator.canPop()) navigator.pop();
  }

  if (!context.mounted) return true;
  AppToast.show(
    context,
    message: tr.signedOutToast,
    variant: ToastVariant.success,
  );
  return true;
}
