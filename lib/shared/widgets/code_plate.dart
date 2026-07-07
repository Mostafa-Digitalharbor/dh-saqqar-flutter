import 'package:flutter/material.dart';

import '../../core/constants/ui_strings.dart';
import '../extensions/context_extensions.dart';

/// Monospace "plate" for command / stdout / stderr / tool payloads — a
/// bordered, tinted box with selectable monospace text. Shared by the server
/// and tool activity cards so both render identically.
///
/// When [maxLines] is null (expanded view) the content is wrapped in a
/// horizontal scroll view so a single long unbroken token (a file path, URL,
/// JSON blob, base64) scrolls sideways instead of overflowing the card —
/// mirroring the web's `<pre style="overflow-x:auto">`. When [maxLines] is
/// set (collapsed header) the text soft-wraps and clips to that many lines
/// instead, so the card height stays bounded.
class CodePlate extends StatelessWidget {
  const CodePlate({
    super.key,
    required this.text,
    required this.accent,
    this.maxLines,
  });

  final String text;
  final Color accent;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final content = SelectableText(
      text,
      maxLines: maxLines,
      style: context.text.bodySmall?.copyWith(
        fontFamily: UiStrings.monospaceFontFamily,
        color: accent,
        height: 1.5,
        fontSize: 12,
      ),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: s.codePlate,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: s.border),
      ),
      child: maxLines == null
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: content,
            )
          : content,
    );
  }
}
