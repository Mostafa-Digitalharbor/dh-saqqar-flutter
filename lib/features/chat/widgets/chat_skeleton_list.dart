import 'package:flutter/material.dart';

import '../../../core/theme/app_sizes.dart';
import '../../../shared/widgets/responsive_content.dart';
import 'message_bubble_skeleton.dart';

/// The placeholder transcript shown while a chat's first snapshot is on the
/// wire.
///
/// Six bubbles alternating user / assistant at varying widths, so the wait
/// reads as *a conversation loading* rather than as a spinner in a box. The
/// shape is deliberate: a uniform stack of identical rows reads as a list
/// widget, and the thing arriving is not a list — it is someone's chat.
///
/// Extracted from `_ChatScreenState`, where it was one of the few methods
/// that touched no state at all: a `const` layout table and a `ListView`
/// built from it. Living in a 4,000-line State meant it was rebuilt in every
/// reader's head alongside scroll offsets and poll timers, and could not be
/// pumped on its own.
///
/// Deliberately NOT reversed, unlike the real lane. There is no scroll
/// position to preserve and nothing to page, so the simpler widget is the
/// right one — and a reversed skeleton would render its rows bottom-up,
/// which is a different shape from the transcript it stands in for.
class ChatSkeletonList extends StatelessWidget {
  const ChatSkeletonList({super.key});

  /// Widths and line counts, in render order. A table rather than a loop with
  /// arithmetic so the silhouette can be tuned by reading it.
  static const _layout = <({bool isUser, double width, int lines})>[
    (isUser: false, width: AppSkeletonSizes.bubbleRegular, lines: 2),
    (isUser: true, width: AppSkeletonSizes.bubbleShort, lines: 1),
    (isUser: false, width: AppSkeletonSizes.bubbleWidest, lines: 3),
    (isUser: true, width: AppSkeletonSizes.bubbleMedium, lines: 1),
    (isUser: false, width: AppSkeletonSizes.bubbleWide, lines: 2),
    (isUser: false, width: AppSkeletonSizes.bubbleWider, lines: 2),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final row in _layout)
          ResponsiveContent(
            maxWidth: AppLayoutWidths.chatColumn,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s14,
              AppSpacing.s14,
              AppSpacing.s14,
              0,
            ),
            child: MessageBubbleSkeleton(
              isUser: row.isUser,
              bubbleWidth: row.width,
              linesCount: row.lines,
            ),
          ),
        const SizedBox(height: AppSpacing.s16),
      ],
    );
  }
}
