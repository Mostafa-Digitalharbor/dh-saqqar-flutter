import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../view_model/app_update_cubit.dart';
import 'update_action.dart';

/// Slim "a new version is ready" row, shown under the header wherever
/// [OfflineBanner] is shown.
///
/// This is the part that actually closes the gap the store cannot: Play and
/// the App Store take 1–7 days to push an update onto a device that has
/// auto-update on, and do nothing at all for the users who have it off. One
/// tap here gets the same build in minutes.
///
/// Dismissible, and the dismissal is remembered per build number — see
/// [AppUpdateCubit.dismiss]. A nudge that reappears on every screen after the
/// user has said no is an ad, not a service.
class UpdateNudgeBanner extends StatelessWidget {
  const UpdateNudgeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Nullable lookup, NOT `BlocBuilder<AppUpdateCubit, …>`.
    //
    // This banner sits in [PageScaffold], which is the base of nearly every
    // screen in the app. A `BlocBuilder` here makes an `AppUpdateCubit` a
    // hard requirement of that scaffold, so every widget test, storybook
    // entry and future harness that pumps any screen has to know the update
    // gate exists — twelve existing tests died with
    // `ProviderNotFoundException` the first time this was wired that way.
    //
    // `context.watch<AppUpdateCubit?>()` resolves the same provider element
    // when one is present (so state changes still rebuild this widget) and
    // yields `null` when it is not. A cosmetic banner has no business
    // deciding whether a screen can be built at all.
    final state = context.watch<AppUpdateCubit?>()?.state;
    return AnimatedSize(
      duration: AppDurations.cardIn,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: (state?.showsNudge ?? false)
          ? _NudgeRow(onUpdate: () => runUpdateAction(context))
          : const SizedBox.shrink(),
    );
  }
}

class _NudgeRow extends StatelessWidget {
  const _NudgeRow({required this.onUpdate});

  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
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
          color: s.brandCyan.withValues(
            alpha: context.alpha(AppAlphaPairs.tintBanner),
          ),
          border: Border(
            bottom: BorderSide(
              color: s.brandCyan.withValues(alpha: AppAlphas.a30),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Row(
            children: [
              Icon(
                AppIcons.download,
                color: s.brandCyan,
                size: AppIconSizes.regular,
              ),
              const SizedBox(width: AppSpacing.s10),
              // Expanded, not a bare Column: a Row gives its children
              // unbounded width, so the two text lines below would lay out at
              // their intrinsic width and overflow the moment the copy is
              // longer than the screen — which the Arabic strings are at 320dp.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr.updateOptionalTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge?.copyWith(
                        color: s.brandCyan,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      tr.updateOptionalBody,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: s.muted,
                        fontWeight: FontWeight.w500,
                        fontSize: AppFontSizes.caption,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              // Fixed chrome, so it must not be Expanded — both buttons size
              // to their own text and the flexible column above absorbs
              // whatever is left.
              TextButton(
                onPressed: onUpdate,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s10,
                  ),
                ),
                child: Text(
                  tr.updateAction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    color: s.brandCyan,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => context.read<AppUpdateCubit>().dismiss(),
                visualDensity: VisualDensity.compact,
                iconSize: AppIconSizes.boxGlyphCompact,
                color: s.muted,
                tooltip: tr.updateLater,
                icon: const Icon(AppIcons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
