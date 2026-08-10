import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';

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
  /// Requires BOTH a recipient and a subject. The server marks `to`, `subject`
  /// and `body` required in the tool schema, so this now essentially always
  /// takes the rich path — it stays as a guard because a payload missing them
  /// is not an email, and falling back to chips shows the raw truth rather
  /// than an email card with blank fields.
  static EmailApprovalPreview? of(Map<String, String> payload) {
    String read(String key) => payload[key]?.trim() ?? '';

    final to = read(kTo);
    final subject = read(kSubject);
    if (to.isEmpty || subject.isEmpty) return null;
    return EmailApprovalPreview(
      to: to,
      subject: subject,
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
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.surface2.withValues(alpha: context.isDark ? 0.55 : 0.9),
        borderRadius: AppRadius.buttonR,
        border: Border.all(color: s.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.mail, size: 14, color: s.brandCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: s.text,
                  ),
                ),
              ),
              if (isReply) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
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
          const SizedBox(height: 8),
          _Line(label: tr.emailPreviewTo, value: to),
          if (cc.isNotEmpty) _Line(label: tr.emailPreviewCc, value: cc),
          if (bcc.isNotEmpty) _Line(label: tr.emailPreviewBcc, value: bcc),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              body,
              // Long enough to judge the message, short enough that the card
              // stays a card. The full text is still one tap away under
              // "Show details".
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: s.muted,
                height: 1.5,
              ),
            ),
          ],
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
      padding: const EdgeInsets.only(bottom: 2),
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
          const SizedBox(width: 6),
          Expanded(
            child: Text(
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
