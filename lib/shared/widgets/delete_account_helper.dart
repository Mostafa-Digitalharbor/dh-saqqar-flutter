import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_error_mapper.dart';
import '../../core/theme/app_icons.dart';
import '../../features/auth/view_model/auth_cubit.dart';
import '../session/local_session_caches.dart';
import 'app_toast.dart';
import 'blocking_progress_dialog.dart';
import 'confirm_dialog.dart';

/// Single entry-point for "delete my Saqqar account" — the App/Play Store
/// mandated in-app deletion path. Shows a destructive confirm, then a
/// blocking progress dialog while the server irreversibly deletes the
/// account and revokes the token, clears local offline caches, and lets
/// the auth gate redirect to sign-in. Returns `true` if the account was
/// deleted, `false` if the user cancelled or the delete failed.
///
/// Unlike sign-out, the server call must SUCCEED before we wipe anything —
/// a failure keeps the user signed in and surfaces a toast, because
/// silently signing them out would wrongly imply the account was gone.
Future<bool> showDeleteAccountFlow(BuildContext context) async {
  final tr = context.tr;
  final confirmed = await ConfirmDialog.show(
    context,
    title: tr.deleteAccountConfirmTitle,
    body: tr.deleteAccountConfirmBody,
    confirmLabel: tr.deleteAccount,
    cancelLabel: tr.confirmNo,
    icon: AppIcons.trash,
    destructive: true,
  );
  if (!confirmed) return false;
  if (!context.mounted) return false;

  // Capture references before any awaits — the auth-gate redirect rebuilds
  // the tree on success and `context.read` would throw afterwards.
  final caches = LocalSessionCaches.of(context);
  final authCubit = context.read<AuthCubit>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => const BlockingProgressDialog(),
    ),
  );

  var deleted = false;
  Object? error;
  try {
    await authCubit.deleteAccount();
    deleted = true;
    // Only purge local caches once the server confirmed deletion.
    await caches.clear();
  } catch (e) {
    error = e;
  } finally {
    if (navigator.canPop()) navigator.pop();
  }

  if (!context.mounted) return deleted;
  if (deleted) {
    AppToast.show(
      context,
      message: tr.accountDeletedToast,
      variant: ToastVariant.success,
    );
  } else {
    // Prefer the server's reason when it classified one; otherwise the
    // generic "couldn't delete" copy. `messenger` fallback keeps the toast
    // alive even if this frame's context is mid-teardown.
    final message = error == null
        ? tr.deleteAccountFailed
        : ApiErrorMapper.message(context, error);
    if (messenger != null) {
      AppToast.show(context, message: message, variant: ToastVariant.error);
    }
  }
  return deleted;
}
