import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/auto_direction_text.dart';

/// §9 — preview of an email an approval is about to send.
///
/// Approving "send this email" from a payload rendered as `key: value` chips
/// means approving a message you never actually read: the body is the one
/// field that matters and the one a chip truncates worst. This lays the same
/// server-sent payload out as a recipient / subject / body block.
///
/// Nothing is invented — every line comes from the payload, and the card
/// falls back to the ordinary chip rendering ([of] returns null) unless the
/// payload really is email-shaped.
@immutable
class EmailApprovalPreview extends StatelessWidget {
  const EmailApprovalPreview({
    super.key,
    required this.to,
    required this.subject,
    required this.body,
    this.cc = '',
    this.bcc = '',
    this.isReply = false,
  });

  final String to;
  final String subject;
  final String body;
  final String cc;

  /// Blind-copy recipients. Rendered as prominently as [to] on purpose: BCC
  /// is the field where an approval can quietly send a customer's data to a
  /// third party, and it is invisible in the sent mail itself.
  final String bcc;

  /// Whether the payload carried `in_reply_to`. The value is an opaque
  /// Message-ID header — useless on screen — but its presence changes what
  /// the user is approving, so it surfaces as a badge rather than a line.
  final bool isReply;

  /// The email tool's payload keys, confirmed by the web team 2026-08-06 §4.
  ///
  /// This list used to carry guesses (`email_to`, `recipients`,
  /// `email_subject`, `body_html`, `message`, `title`). They are gone: none
  /// of them is real, and `title` in particular is shared with half the other
  /// approval types, so keeping it as a subject alias made every titled
  /// approval a candidate for the email layout.
  ///
  /// `to` may hold several addresses as one comma-separated string; it is
  /// displayed verbatim rather than split, so what the user reads is exactly
  /// what the server holds.
  static const kTo = 'to';
  static const kCc = 'cc';
  static const kBcc = 'bcc';
  static const kSubject = 'subject';
  static const kBody = 'body';
  static const kInReplyTo = 'in_reply_to';

  /// Reads an email preview out of [payload], or null when the payload isn't
  /// an email.
  ///
  /// Requires only a recipient. `subject` and `body` may legitimately be
  /// empty (Task 4, MOBILE_TASKS_2026-09.md — the card shows a placeholder
  /// rather than hiding the row), so they can no longer gate whether this is
  /// an email at all. The caller ([ChatApprovalCard]) is what actually
  /// decides that now, off `approval.actionType == 'send_email'` — this
  /// guard is only the fallback for a payload reached with no action-type
  /// context (e.g. a unit test constructing one directly).
  static EmailApprovalPreview? of(Map<String, String> payload) {
    String read(String key) => payload[key]?.trim() ?? '';

    final to = read(kTo);
    if (to.isEmpty) return null;
    return EmailApprovalPreview(
      to: to,
      subject: read(kSubject),
      body: read(kBody),
      cc: read(kCc),
      bcc: read(kBcc),
      isReply: read(kInReplyTo).isNotEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final s = context.saqqar;
    // Subject and body are legitimately empty (the tool schema allows it) —
    // a placeholder says so rather than leaving a blank header or silently
    // dropping the "Message" row entirely.
    final displaySubject =
        subject.isEmpty ? tr.emailPreviewEmptySubject : subject;
    final displayBody = body.isEmpty ? tr.emailPreviewEmptyBody : body;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.s10),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: s.surface2.withValues(alpha: context.alpha(AppAlphaPairs.panelCard)),
        borderRadius: AppRadius.buttonR,
        border: Border.all(color: s.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.mail, size: AppIconSizes.compact, color: s.brandCyan),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: AutoDirectionText(
                  displaySubject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: subject.isEmpty ? s.muted : s.text,
                  ),
                ),
              ),
              // The value itself — an opaque Message-ID header — is never
              // printed; only its PRESENCE is shown, as a badge rather than
              // a plain-text row, because the id is not something a user
              // could ever act on.
              if (isReply) ...[
                const SizedBox(width: AppSpacing.s6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s6,
                    vertical: AppSpacing.s2,
                  ),
                  decoration: BoxDecoration(
                    color: s.surface3,
                    borderRadius: AppRadius.badgeR,
                  ),
                  child: Text(
                    tr.emailPreviewReply,
                    style: context.text.labelSmall?.copyWith(color: s.muted),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          _Line(label: tr.emailPreviewTo, value: to),
          if (cc.isNotEmpty) _Line(label: tr.emailPreviewCc, value: cc),
          if (bcc.isNotEmpty) _Line(label: tr.emailPreviewBcc, value: bcc),
          const SizedBox(height: AppSpacing.s8),
          AutoDirectionText(
            displayBody,
            // Long enough to judge the message, short enough that the card
            // stays a card. The full text is still one tap away under
            // "Show details".
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
              color: s.muted,
              height: AppLineHeights.body,
              fontStyle: body.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.s6),
          Expanded(
            child: AutoDirectionText(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(color: s.text),
            ),
          ),
        ],
      ),
    );
  }
}
