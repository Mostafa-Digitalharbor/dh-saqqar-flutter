import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;

/// Renders server-authored text in the direction the text itself is written
/// in — the `dir="auto"` behaviour web gets for free — rather than the
/// ambient app locale's direction.
///
/// Two payload fields need exactly this and neither is translatable:
///
///  * an email approval's `subject`/`body`/`to`/`cc`/`bcc`/`in_reply_to` —
///    an English-locale user can easily be approving an Arabic email, and an
///    Arabic-locale user an English one (Task 4, MOBILE_TASKS_2026-09.md);
///  * an app-pulse card's `notes`/`priorities` — the server writes these in
///    Arabic UNCONDITIONALLY, even for an English-locale phone, and printing
///    them through the app's own LTR `Directionality` left punctuation and
///    numerals in an Arabic sentence reading in the wrong order (Task 1).
///
/// [Bidi.detectRtlDirectionality] (already a transitive `intl` dependency —
/// no new package) makes the call per-string rather than trusting the
/// surrounding screen's locale, which is the whole point: the two examples
/// above are exactly the cases where those two facts disagree.
class AutoDirectionText extends StatelessWidget {
  const AutoDirectionText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Bidi.detectRtlDirectionality(text)
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      ),
    );
  }
}
