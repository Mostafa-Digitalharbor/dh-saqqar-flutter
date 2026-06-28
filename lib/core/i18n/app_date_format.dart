import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';

/// Locale-aware date / time / relative-time formatting.
///
/// One call site for every "render a DateTime to the user". Reads the
/// active app locale from [BuildContext] so dates appear in the user's
/// language without each caller threading the locale through.
///
/// Three formatters:
///   * [time] — "11:42 AM" (en) / "١١:٤٢ ص" (ar)
///   * [date] — "May 18, 2026" (en) / "١٨ مايو ٢٠٢٦" (ar)
///   * [dateTime] — "May 18, 2026 · 11:42 AM"
///   * [relative] — "just now" / "5 m ago" / "yesterday" / "3 d ago"
///     in EN, with the matching AR phrasing.
///
/// Use [relative] for chat / artifact / approval timestamps; [date] for
/// formal headers; [time] inline where the date is implicit (today).
class AppDateFormat {
  AppDateFormat._();

  static String _locale(BuildContext context) =>
      Localizations.localeOf(context).toString();

  /// "11:42 AM" / "١١:٤٢ ص". When [twentyFour] is true, renders as
  /// "11:42" without the meridiem.
  static String time(BuildContext context, DateTime when,
      {bool twentyFour = false}) {
    final loc = _locale(context);
    final pattern = twentyFour ? DateFormat.Hm(loc) : DateFormat.jm(loc);
    return pattern.format(when.toLocal());
  }

  /// "May 18, 2026" / "١٨ مايو ٢٠٢٦".
  static String date(BuildContext context, DateTime when) {
    return DateFormat.yMMMd(_locale(context)).format(when.toLocal());
  }

  /// "May 18, 2026 · 11:42 AM".
  static String dateTime(BuildContext context, DateTime when) {
    return '${date(context, when)} · ${time(context, when)}';
  }

  /// Web-parity full timestamp: "May 18, 2026 at 06:24 PM" /
  /// "١٨ مايو ٢٠٢٦ في ٠٦:٢٤ م". Uses a natural-language connector
  /// ("at" / "في") instead of the middle-dot — read better when shown
  /// under a chat bubble as the message's authoritative timestamp.
  static String fullDateTime(BuildContext context, DateTime when) {
    final connector = context.tr.dateAtConnector;
    return '${date(context, when)} $connector ${time(context, when)}';
  }

  /// Human relative-time. Buckets:
  ///   * <60 s → "just now" / "الآن"
  ///   * <60 m → "5 m ago" / "منذ ٥ د"
  ///   * <24 h → "3 h ago" / "منذ ٣ س"
  ///   * <48 h → "yesterday" / "أمس"
  ///   * <7 d  → "3 d ago" / "منذ ٣ أيام"
  ///   * else  → falls back to [date] (absolute).
  ///
  /// All numeric values are rendered through `NumberFormat` so AR locales
  /// see Arabic-Indic digits (١٢٣) rather than Western (123).
  static String relative(BuildContext context, DateTime when) {
    final now = DateTime.now();
    final delta = now.difference(when.toLocal());
    final tr = context.tr;
    final loc = _locale(context);
    final n = NumberFormat.decimalPattern(loc);

    if (delta.inSeconds < 60) return tr.now;
    if (delta.inMinutes < 60) return tr.relativeMinutesAgo(n.format(delta.inMinutes));
    if (delta.inHours < 24) return tr.relativeHoursAgo(n.format(delta.inHours));
    if (delta.inHours < 48) return tr.dateYesterday;
    if (delta.inDays < 7) return tr.relativeDaysAgo(n.format(delta.inDays));
    return date(context, when);
  }
}
