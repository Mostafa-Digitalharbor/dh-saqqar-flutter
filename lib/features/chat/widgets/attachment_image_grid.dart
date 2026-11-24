import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../data/chat_view_models.dart';
import 'attachment_open.dart';

/// Pictures sent together, laid out as one tidy block instead of a row you
/// scroll sideways: two side by side, three as one tall plus two stacked, four
/// as a square, and past four the last tile says how many more there are.
///
/// Tapping a tile opens that picture in the viewer, with the download shown on
/// the tile.
class ChatImageGrid extends StatelessWidget {
  const ChatImageGrid({super.key, required this.attachments});

  final List<ChatAttachment> attachments;

  /// Whether [a] can be drawn as a tile — a picture with something to show.
  static bool accepts(ChatAttachment a) =>
      a.isImage && (a.imageUrl ?? '').isNotEmpty;

  static const _gap = AppSpacing.s4;
  static const _maxTiles = 4;

  @override
  Widget build(BuildContext context) {
    final shown = attachments.take(_maxTiles).toList();
    final extra = attachments.length - shown.length;

    Widget tile(int i) => _Tile(
      attachment: shown[i],
      gallery: attachments,
      extra: i == shown.length - 1 ? extra : 0,
    );

    Widget pair(int a, int b) => Row(
      children: [
        Expanded(child: tile(a)),
        const SizedBox(width: _gap),
        Expanded(child: tile(b)),
      ],
    );

    final Widget layout;
    if (shown.length == 2) {
      layout = pair(0, 1);
    } else if (shown.length == 3) {
      layout = Row(
        children: [
          Expanded(child: tile(0)),
          const SizedBox(width: _gap),
          Expanded(
            child: Column(
              children: [
                Expanded(child: tile(1)),
                const SizedBox(height: _gap),
                Expanded(child: tile(2)),
              ],
            ),
          ),
        ],
      );
    } else {
      layout = Column(
        children: [
          Expanded(child: pair(0, 1)),
          const SizedBox(height: _gap),
          Expanded(child: pair(2, 3)),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppLayoutWidths.chipCap),
      child: AspectRatio(
        // Two pictures read best as a wide pair; three and four as a square.
        aspectRatio: shown.length == 2 ? 2 : 1,
        child: layout,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.attachment,
    required this.extra,
    required this.gallery,
  });

  final ChatAttachment attachment;

  /// Every picture in the group, so the viewer can swipe through all of them
  /// and not just the four shown.
  final List<ChatAttachment> gallery;

  /// Pictures hidden behind this tile; 0 draws nothing over it.
  final int extra;

  @override
  Widget build(BuildContext context) {
    return AttachmentOpenTarget(
      attachment: attachment,
      gallery: gallery,
      child: ClipRRect(
        borderRadius: AppRadius.smallR,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              attachment.imageUrl!,
              fit: BoxFit.cover,
              cacheWidth: AppLayoutWidths.chipCap.round(),
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: AppColors.figCFFE6E7EC,
                child: Icon(LucideIcons.image, color: AppColors.figMuted),
              ),
            ),
            if (extra > 0)
              ColoredBox(
                color: AppColors.scrimBase.withValues(alpha: AppAlphas.a55),
                child: Center(
                  child: Text(
                    '+$extra',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.figWhite,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
