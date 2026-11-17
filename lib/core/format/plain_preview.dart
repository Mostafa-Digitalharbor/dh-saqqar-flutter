/// Turns the Markdown the agent writes into the one plain line a list row can
/// show.
///
/// A conversation's `last_message_preview` is the raw start of the last reply,
/// so a list row printed `**Saqqar Apps · WhatsApp integration**` with its
/// asterisks. This drops the markup and keeps the words; it is for previews
/// only, never for the transcript (which renders Markdown properly).
String plainPreview(String markdown) {
  var s = markdown;
  // Images and links keep their label.
  s = s.replaceAllMapped(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), (m) => m[1] ?? '');
  // Fenced / inline code markers.
  s = s.replaceAll(RegExp(r'```[a-zA-Z0-9]*'), ' ').replaceAll('`', '');
  // Line-leading markers: headings, quotes, bullets, numbering.
  s = s.replaceAll(
    RegExp(r'^\s{0,3}(#{1,6}|>+|[-*+]|\d+[.)])\s+', multiLine: true),
    '',
  );
  // Emphasis runs.
  s = s.replaceAll(RegExp(r'(\*\*|__|~~)'), '');
  s = s.replaceAllMapped(
    RegExp(r'(^|\s)[*_]([^*_\n]+)[*_](?=\s|[.,!?;:]|$)'),
    (m) => '${m[1]}${m[2]}',
  );
  // One line.
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
