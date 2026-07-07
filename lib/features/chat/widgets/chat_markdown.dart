import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_toast.dart';

/// Renders an assistant or user message as Markdown that matches the web
/// chat's typography (paragraphs, bold/italic, inline code, fenced code,
/// lists, links). Sized to inherit the bubble's baseline body style so
/// regular text matches the rest of the bubble exactly.
///
/// Tapping a link copies it to the clipboard and toasts a confirmation —
/// we deliberately avoid `url_launcher` here to keep the dependency tree
/// thin and skip the per-platform setup it requires.
class ChatMarkdown extends StatelessWidget {
  const ChatMarkdown({
    super.key,
    required this.data,
    required this.isUser,
  });

  final String data;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final base = context.text.bodyMedium?.copyWith(
      color: s.text,
      height: 1.5,
      fontSize: 15,
    );

    final codeBg = isUser
        ? Colors.white.withValues(alpha: 0.14)
        : s.codePlate;
    final codeBorder = isUser
        ? Colors.white.withValues(alpha: 0.18)
        : s.border;

    final styleSheet = MarkdownStyleSheet(
      p: base,
      h1: base?.copyWith(fontSize: 19, fontWeight: FontWeight.w800),
      h2: base?.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
      h3: base?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      em: base?.copyWith(fontStyle: FontStyle.italic),
      strong: base?.copyWith(fontWeight: FontWeight.w800),
      blockquote: base?.copyWith(
        color: s.muted,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        color: s.surface2.withValues(alpha: 0.35),
        border: BorderDirectional(
          start: BorderSide(color: s.brandCyan, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      a: base?.copyWith(
        color: s.brandCyan,
        decoration: TextDecoration.underline,
        decorationColor: s.brandCyan.withValues(alpha: 0.6),
      ),
      // Inline code — small monospace plate that flows with the line.
      code: TextStyle(
        fontFamily: UiStrings.monospaceFontFamily,
        fontSize: 13,
        color: isUser ? Colors.white : s.brandCyan,
        backgroundColor: codeBg,
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: codeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: codeBorder),
      ),
      listBullet: base?.copyWith(color: s.muted, fontWeight: FontWeight.w700),
      listIndent: 22,
      tableHead: base?.copyWith(fontWeight: FontWeight.w700),
      tableBody: base,
      tableBorder: TableBorder.all(color: s.cardBorder, width: 1),
      // IntrinsicColumnWidth (not the default FlexColumnWidth) makes each
      // column size to its content AND opts the whole table into
      // flutter_markdown's built-in horizontal SingleChildScrollView, so a
      // wide agent table (many Odoo columns) scrolls sideways instead of
      // overflowing the chat bubble. Fenced code blocks already scroll
      // horizontally by default in the package.
      tableColumnWidth: const IntrinsicColumnWidth(),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: s.border)),
      ),
    );

    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      styleSheet: styleSheet,
      onTapLink: (text, href, title) => _openLink(context, href),
    );
  }

  /// Open the link (Gap G). Odoo record deep-links should open in the
  /// browser / Odoo app, so http(s) URLs launch externally. Anything that
  /// can't be launched (odd scheme, no handler) falls back to copying the
  /// URL to the clipboard so the user still gets it.
  Future<void> _openLink(BuildContext context, String? href) async {
    if (href == null || href.isEmpty) return;
    final uri = Uri.tryParse(href);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {
        // Fall through to copy on any launch failure.
      }
    }
    if (!context.mounted) return;
    await _copyLink(context, href);
  }

  Future<void> _copyLink(BuildContext context, String? href) async {
    if (href == null || href.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: href));
    if (!context.mounted) return;
    AppToast.show(
      context,
      message: context.tr.linkCopied,
      variant: ToastVariant.success,
    );
  }
}
