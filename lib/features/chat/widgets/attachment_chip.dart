import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../demo/saqqar_demo_data.dart';

/// Attachment row used both inside chat bubbles and in the composer preview
/// tray.
///
/// When the attachment is an image and has an [DemoAttachment.imageUrl],
/// renders an inline preview (max 240 px tall) on top of the metadata
/// footer. Non-image kinds fall back to a tight icon + name + meta row.
class AttachmentChip extends StatelessWidget {
  const AttachmentChip({super.key, required this.attachment});

  final DemoAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage && attachment.imageUrl != null) {
      return _ImageAttachment(attachment: attachment);
    }
    return _FileAttachment(attachment: attachment);
  }
}

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({required this.attachment});

  final DemoAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: s.surface,
          border: Border.all(color: s.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: Image.network(
                attachment.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) {
                  return Container(
                    height: 120,
                    color: s.surface2,
                    alignment: Alignment.center,
                    child: Icon(
                      AppIcons.image,
                      color: s.muted,
                      size: 28,
                    ),
                  );
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 120,
                    color: s.surface2,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: s.brandCyan,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: s.brandCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: s.brandCyan.withValues(alpha: 0.26),
                      ),
                    ),
                    child: Text(
                      attachment.kind,
                      style: context.text.labelSmall?.copyWith(
                        color: s.brandCyan,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    attachment.size,
                    style: context.text.labelSmall?.copyWith(
                      color: s.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileAttachment extends StatelessWidget {
  const _FileAttachment({required this.attachment});

  final DemoAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: s.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.brandCyan.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(AppIcons.attach, size: 14, color: s.brandCyan),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${attachment.kind} · ${attachment.size}',
                  style: context.text.labelSmall?.copyWith(
                    color: s.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
