import '../../../shared/fig/fig.dart' show showLightSheet;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'chat_sheet.dart';
import '../../../shared/widgets/sheet_action_row.dart';

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
    return showLightSheet<AttachmentPickerSource>(
      context,
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
        SheetActionRow(
          tint: context.saqqar.brandCyan,
          glyphColor: context.saqqar.brandCyan,
          icon: AppIcons.image,
          label: tr.attachSourcePhotos,
          subtitle: tr.attachSourcePhotosHint,
          onTap: () => Navigator.of(context).pop(AttachmentPickerSource.photos),
        ),
        if (hasCamera)
          SheetActionRow(
            tint: context.saqqar.brandCyan,
            glyphColor: context.saqqar.brandCyan,
            icon: AppIcons.camera,
            label: tr.attachSourceCamera,
            subtitle: tr.attachSourceCameraHint,
            onTap: () =>
                Navigator.of(context).pop(AttachmentPickerSource.camera),
          ),
        SheetActionRow(
          tint: context.saqqar.brandCyan,
          glyphColor: context.saqqar.brandCyan,
          icon: AppIcons.files,
          label: tr.attachSourceFiles,
          subtitle: tr.attachSourceFilesHint,
          onTap: () => Navigator.of(context).pop(AttachmentPickerSource.files),
        ),
      ],
    );
  }
}
