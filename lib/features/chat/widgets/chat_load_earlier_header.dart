import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';

/// "Load earlier messages" header pill at the top of the message list.
///
/// A real list item (not a scroll trigger / overlay) so it's reachable even
/// when the loaded slice is too short to scroll — the case that left a long
/// chat stuck on its last few visible bubbles. Tapping it pages in the
/// previous batch via [ChatCubit.loadOlder]; while a page is in flight it
/// swaps to a spinner. Rebuilds only on the `isLoadingOlder` flag so the
/// 1.5 s poll cadence doesn't churn it.
/// Tap-to-retry pill shown at the head of the message list — **only** after an
/// automatic page has failed.
///
/// Two earlier versions of this were wrong in opposite directions. First it was
/// a "Load earlier messages" button the user had to tap for every page. Then,
/// once paging became automatic, it became a passive status row that still
/// rendered whenever more history existed — which meant the top of every long
/// chat permanently advertised that there was more to fetch, while the app was
/// already fetching it. Users read that as the transcript having stopped.
///
/// So it is now an error state and nothing else. Auto-loading stands down after
/// a failure rather than hammering a failing endpoint on every scroll frame,
/// which is the one situation the automatic path cannot recover from on its
/// own; this is the way back in. Everything else — including the wait while a
/// page is genuinely in flight — is the app's problem, not the user's, and the
/// page-ahead means that wait is usually already over before they reach it.
class ChatLoadEarlierHeader extends StatelessWidget {
  const ChatLoadEarlierHeader({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final s = context.saqqar;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.pillR,
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s9,
            ),
            decoration: BoxDecoration(
              color: s.cardBg,
              borderRadius: AppRadius.pillR,
              border: Border.all(color: s.cardBorder),
              boxShadow: s.glassShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.refresh,
                  size: AppIconSizes.regular,
                  color: s.brandCyan,
                ),
                const SizedBox(width: AppSpacing.s8),
                Flexible(
                  child: Text(
                    tr.chatLoadEarlier,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(
                      color: s.brandCyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
