import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'chat_sheet.dart';
import '../../../core/theme/app_radius.dart';

/// Where the composer should pull the next attachment from.
enum AttachmentPickerSource { photos, camera, files }

/// Bottom sheet shown when the user taps the composer's paperclip.
///
/// Before this, the paperclip opened one `FileType.custom` picker whose
/// allow-list mixed images with PDFs, spreadsheets and archives — on iOS
/// that resolves to the Files browser, so attaching a photo meant digging
/// through Files → Photos rather than the picker people expect. Testers
/// asked for the WhatsApp shape: pick the *source* first, then the item.
///
/// Returns the chosen [AttachmentPickerSource], or null when dismissed.
class AttachmentPickerSourceSheet extends StatelessWidget {
  const AttachmentPickerSourceSheet({super.key});

  static Future<AttachmentPickerSource?> show(BuildContext context) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<AttachmentPickerSource>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AttachmentPickerSourceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    // Camera capture only exists on the phone targets. Read the platform off
    // the theme rather than `dart:io` so the desktop build hides the row and
    // widget tests can still drive it via `debugDefaultTargetPlatformOverride`.
    final platform = Theme.of(context).platform;
    final hasCamera =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;

    return ChatSheet(
      title: tr.attachSourceTitle,
      children: [
        _SourceRow(
          icon: AppIcons.image,
          label: tr.attachSourcePhotos,
          subtitle: tr.attachSourcePhotosHint,
          onTap: () => Navigator.of(context).pop(AttachmentPickerSource.photos),
        ),
        if (hasCamera)
          _SourceRow(
            icon: AppIcons.camera,
            label: tr.attachSourceCamera,
            subtitle: tr.attachSourceCameraHint,
            onTap: () => Navigator.of(context).pop(AttachmentPickerSource.camera),
          ),
        _SourceRow(
          icon: AppIcons.files,
          label: tr.attachSourceFiles,
          subtitle: tr.attachSourceFilesHint,
          onTap: () => Navigator.of(context).pop(AttachmentPickerSource.files),
        ),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.buttonR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.buttonR,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.brandCyan.withValues(alpha: 0.10),
                ),
                child: Icon(icon, size: 18, color: s.brandCyan),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: context.text.bodyMedium?.copyWith(
                        color: s.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: context.text.bodySmall?.copyWith(color: s.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
