import 'package:flutter/material.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../demo/saqqar_demo_data.dart';
import 'attachment_chip.dart';
import 'chat_send_button.dart';

/// iMessage-style composer pill: attach icon + auto-growing text field +
/// circular gradient send button. Renders an attachment preview row above the
/// pill when [hasAttachment] is true. Pass `null` for [onSend] to render the
/// send button in its disabled state (used when the device is offline).
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.hasAttachment,
    required this.onAttach,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool hasAttachment;
  final VoidCallback onAttach;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: s.surface,
          border: Border(top: BorderSide(color: s.border)),
        ),
        child: ResponsiveContent(
          maxWidth: 980,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasAttachment)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: AttachmentChip(
                            attachment: DemoAttachment(
                              name: UiStrings.demoAttachmentName,
                              kind: UiStrings.demoAttachmentKind,
                              size: UiStrings.demoAttachmentSize,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onAttach,
                        icon: Icon(AppIcons.close, color: s.muted, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: context.tr.removeAttachment,
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                decoration: BoxDecoration(
                  color: s.surface2,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: s.cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        onPressed: onAttach,
                        icon: Icon(AppIcons.attach, color: s.muted, size: 20),
                        tooltip: context.tr.attachFiles,
                      ),
                    ),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                          style: context.text.bodyMedium?.copyWith(
                            fontSize: 15,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            hintText: context.tr.composerHint,
                            hintStyle: context.text.bodyMedium?.copyWith(
                              color: s.muted,
                              fontSize: 15,
                            ),
                            isCollapsed: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ChatSendButton(onPressed: onSend),
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
