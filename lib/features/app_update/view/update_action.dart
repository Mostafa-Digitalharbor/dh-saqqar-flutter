import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/store_launcher.dart';
import '../view_model/app_update_cubit.dart';

/// The single "Update now" behaviour, shared by the blocking wall and the
/// dismissible banner.
///
/// One function rather than a copy in each view, because the fallback chain is
/// the part that is easy to get subtly different, and a wall whose button
/// silently does nothing is indistinguishable from a frozen app:
///
///   1. **Install in place** — Play's own updater. Android only, and only when
///      Play reported a permitted flow. Nothing to fall back to on success:
///      the flexible flow restarts the app and the immediate flow never
///      returns.
///   2. **The store listing** — every other case, including all of iOS.
///   3. **Say so** — if even the listing will not open, the user is told. The
///      one outcome that must never happen is a tap that reports nothing.
///
/// [storeUrl] lets a caller that already holds the URL pass it rather than
/// re-reading it — [UpdateRequiredScreen] takes it as a constructor argument
/// so it stays renderable on its own, without a cubit above it.
Future<void> runUpdateAction(BuildContext context, {String? storeUrl}) async {
  final cubit = context.read<AppUpdateCubit?>();

  if (cubit != null && await cubit.launchInPlaceUpdate()) return;

  final url = storeUrl ?? cubit?.state.status?.storeUrl ?? '';
  final opened = await openStoreListing(url);
  if (opened || !context.mounted) return;

  AppToast.show(
    context,
    message: context.tr.updateOpenStoreFailed,
    variant: ToastVariant.error,
  );
}
