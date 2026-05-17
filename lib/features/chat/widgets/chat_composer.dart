import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../demo/saqqar_demo_data.dart';
import 'attachment_chip.dart';
import 'chat_send_button.dart';

/// iMessage-style composer pill: attach icon + auto-growing text field +
/// circular gradient send button. Renders an attachment preview row above
/// the pill when [attachment] is non-null — paperclip taps fire
/// [onAttach] (the chat screen opens the native file picker), the row's
/// close button fires [onRemoveAttachment]. Pass `null` for [onSend] to
/// render the send button in its disabled state (used when the device is
/// offline).
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.attachment,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.onSend,
    this.onStop,
    this.stopping = false,
  });

  final TextEditingController controller;

  /// The currently staged attachment — null when no file is picked.
  /// Renders the [AttachmentChip] row above the pill when set.
  final DemoAttachment? attachment;

  /// Tapped on the paperclip icon. The chat screen opens the native
  /// file picker rooted at Photos / Files.
  final VoidCallback onAttach;

  /// Tapped on the "x" next to the staged attachment chip. Clears
  /// [attachment] back to null.
  final VoidCallback onRemoveAttachment;

  final VoidCallback? onSend;

  /// When non-null the send button morphs into a Stop control — the chat
  /// screen passes a real callback while `_isThinking` so the user can
  /// cancel an in-flight agent reply.
  final VoidCallback? onStop;

  /// Optimistic stop-in-flight state. While true the Stop button shows a
  /// small spinner and becomes non-interactive so the user knows the cancel
  /// is propagating.
  final bool stopping;

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
              if (attachment != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: AttachmentChip(attachment: attachment!),
                        ),
                      ),
                      IconButton(
                        onPressed: onRemoveAttachment,
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
                            // While the agent is running the placeholder
                            // explains why Send is muted — the textarea
                            // stays editable so the user can queue their
                            // next prompt instead of waiting idle.
                            hintText: onStop != null
                                ? context.tr.composerBusy
                                : context.tr.composerHint,
                            hintStyle: context.text.bodyMedium?.copyWith(
                              color: s.muted,
                              fontSize: 15,
                              fontStyle: onStop != null
                                  ? FontStyle.italic
                                  : FontStyle.normal,
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
                    ChatSendButton(
                      onPressed: onSend,
                      onStop: onStop,
                      stopping: stopping,
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
