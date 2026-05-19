import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../../features/auth/view_model/auth_cubit.dart';
import '../../features/vault/data/vault_repository.dart';
import '../extensions/context_extensions.dart';
import 'app_toast.dart';
import 'confirm_dialog.dart';

/// Single entry-point for "sign the user out of Saqqar". Shows the
/// destructive confirm (Yes / No), then a compact centred dialog with
/// a thin progress bar while the async work runs (clear vault cache →
/// revoke token), then a success toast. Returns `true` if the user
/// actually signed out, `false` if they cancelled at the confirm step.
Future<bool> showSignOutFlow(BuildContext context) async {
  final tr = context.tr;
  final confirmed = await ConfirmDialog.show(
    context,
    title: tr.signOutConfirmTitle,
    body: tr.signOutConfirmBody,
    confirmLabel: tr.confirmYes,
    cancelLabel: tr.confirmNo,
    icon: AppIcons.signOut,
    destructive: true,
  );
  if (!confirmed) return false;
  if (!context.mounted) return false;

  // Capture references before any awaits — after logout the widget tree
  // is rebuilt by the auth-gate redirect and `context.read` would throw.
  final vaultRepo = context.read<VaultRepository>();
  final authCubit = context.read<AuthCubit>();
  final navigator = Navigator.of(context, rootNavigator: true);

  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (_) => const _SignOutProgressDialog(),
  ));

  try {
    // Clear feature-level offline caches BEFORE revoking the token so
    // the next user signing in on the same device doesn't see the
    // previous user's projects flash on screen while the live fetch
    // runs. Repositories that don't have an offline cache wired no-op.
    await vaultRepo.clearOfflineCache();
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

/// Compact centred dialog — just a thin indeterminate progress bar in
/// a small pill so the user sees that logout is in flight without a
/// big loading card dominating the screen. Disables the system back
/// gesture; the async chain resolves in well under a second.
class _SignOutProgressDialog extends StatelessWidget {
  const _SignOutProgressDialog();

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return PopScope(
      canPop: false,
      child: Center(
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: s.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: s.cardBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 2.5,
              child: LinearProgressIndicator(
                backgroundColor: s.border.withValues(alpha: 0.35),
                valueColor: AlwaysStoppedAnimation<Color>(s.brandCyanStrong),
                minHeight: 2.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
