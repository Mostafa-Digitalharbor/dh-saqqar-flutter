import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_error_mapper.dart';
import '../../core/theme/app_icons.dart';
import '../../features/auth/view_model/auth_cubit.dart';
import '../../features/conversations/data/conversations_repository.dart';
import '../../features/vault/data/vault_repository.dart';
import '../extensions/context_extensions.dart';
import 'app_toast.dart';
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
  final vaultRepo = context.read<VaultRepository>();
  final conversationsRepo = context.read<ConversationsRepository>();
  final authCubit = context.read<AuthCubit>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (_) => const _DeleteAccountProgressDialog(),
  ));

  var deleted = false;
  Object? error;
  try {
    await authCubit.deleteAccount();
    deleted = true;
    // Only purge local caches once the server confirmed deletion.
    await vaultRepo.clearOfflineCache();
    conversationsRepo.clearSnapshotCache();
    await conversationsRepo.clearListCache();
    await conversationsRepo.clearDiskCache();
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

/// Compact centred progress dialog — a thin indeterminate bar while the
/// delete round-trip runs. Mirrors the sign-out progress dialog so the two
/// destructive flows feel identical. Blocks the system back gesture.
class _DeleteAccountProgressDialog extends StatelessWidget {
  const _DeleteAccountProgressDialog();

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final screenW = MediaQuery.sizeOf(context).width;
    final dialogW = screenW * 0.8 < 220 ? screenW * 0.8 : 220.0;
    return PopScope(
      canPop: false,
      child: Center(
        child: Container(
          width: dialogW,
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
