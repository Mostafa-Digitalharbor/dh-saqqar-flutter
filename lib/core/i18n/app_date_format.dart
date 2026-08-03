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
///   * [time] — "11:42 AM" (en) / "11:42 ص" (ar)
///   * [date] — "May 18, 2026" (en) / "18 مايو 2026" (ar)
///   * [dateTime] — "May 18, 2026 · 11:42 AM"
///   * [relative] — "just now" / "5 m ago" / "yesterday" / "3 d ago"
///     in EN, with the matching AR phrasing.
///
/// Use [relative] for chat / artifact / approval timestamps; [date] for
/// formal headers; [time] inline where the date is implicit (today).
///
/// ## Digits
///
/// Arabic renders WESTERN digits (`18 مايو 2026`, not `١٨ مايو ٢٠٢٦`) — the
/// month and meridiem localize, the numerals don't. That's CLDR's own
/// default for `ar` and `ar_SA`: only `ar_EG` selects Arabic-Indic. It also
/// matches the app-wide convention `compactCount` documents, and the Gulf
/// market this ships to.
///
/// So don't "fix" it by forcing an Arabic-Indic numbering system — the whole
/// app would have to move together, and the market doesn't want it. This
/// paragraph exists because the doc here used to CLAIM Arabic-Indic output
/// while the code always produced Western, which sent a reviewer hunting a
/// bug that was never there.
class AppDateFormat {
  AppDateFormat._();

  static String _locale(BuildContext context) =>
      Localizations.localeOf(context).toString();

  // ── Formatter caches ──────────────────────────────────────────────────
  // `DateFormat.xxx(locale)` and `NumberFormat.decimalPattern(locale)` each
  // parse an ICU/CLDR pattern on construction — not free, and these are hit
  // on the hot path: the chat re-adapts every message on each ~1.5 s poll
  // tick, and every conversation card formats a relative time on every list
  // rebuild. Constructing a fresh formatter per call meant dozens of ICU
  // pattern parses per frame. The formatters are stateless once built, so we
  // cache one instance per (kind, locale) and reuse it. Keyed by locale
  // string — at most a handful of locales are ever seen in one session.
  static final _timeJm = <String, DateFormat>{};
  static final _timeHm = <String, DateFormat>{};
  static final _dateYMMMd = <String, DateFormat>{};
  static final _dateMMMd = <String, DateFormat>{};
  static final _decimal = <String, NumberFormat>{};

  static DateFormat _jm(String loc) =>
      _timeJm[loc] ??= DateFormat.jm(loc);
  static DateFormat _hm(String loc) =>
      _timeHm[loc] ??= DateFormat.Hm(loc);
  static DateFormat _yMMMd(String loc) =>
      _dateYMMMd[loc] ??= DateFormat.yMMMd(loc);
  static DateFormat _mMMd(String loc) =>
      _dateMMMd[loc] ??= DateFormat.MMMd(loc);
  static NumberFormat _decimalFor(String loc) =>
      _decimal[loc] ??= NumberFormat.decimalPattern(loc);

  /// "11:42 AM" / "١١:٤٢ ص". When [twentyFour] is true, renders as
  /// "11:42" without the meridiem.
  static String time(BuildContext context, DateTime when,
      {bool twentyFour = false}) {
    final loc = _locale(context);
    final pattern = twentyFour ? _hm(loc) : _jm(loc);
    return pattern.format(when.toLocal());
  }

  /// "May 18, 2026" / "١٨ مايو ٢٠٢٦".
  static String date(BuildContext context, DateTime when) {
    return _yMMMd(_locale(context)).format(when.toLocal());
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

  /// Calendar-day header for a grouped list — "Today" / "Yesterday" /
  /// "May 18" within the current year / "May 18, 2025" outside it.
  ///
  /// Unlike [relative], this buckets by CALENDAR day rather than elapsed
  /// time: a message sent at 23:50 reads "Yesterday" at 00:10, not "20 m
  /// ago". That's what a date separator in a message list needs.
  ///
  /// Lives here so the skeletons stay locale-aware. The chat separator used
  /// to build its own `DateFormat('MMM d', locale)` inline — the only
  /// `DateFormat` constructed outside this file — which pinned an en-US
  /// field order that reads wrong in Arabic.
  static String dayLabel(BuildContext context, DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final local = when.toLocal();
    final stamp = DateTime(local.year, local.month, local.day);
    final delta = today.difference(stamp).inDays;

    if (delta == 0) return context.tr.dateToday;
    if (delta == 1) return context.tr.dateYesterday;
    final loc = _locale(context);
    // Same-year dates drop the year — it's redundant and costs width on
    // the 320 px tier where this pill is centred.
    return stamp.year == today.year
        ? _mMMd(loc).format(stamp)
        : _yMMMd(loc).format(stamp);
  }

  /// Human relative-time. Buckets:
  ///   * <60 s → "just now" / "الآن"
  ///   * <60 m → "5 m ago" / "منذ 5 د"
  ///   * <24 h → "3 h ago" / "منذ 3 س"
  ///   * <48 h → "yesterday" / "أمس"
  ///   * <7 d  → "3 d ago" / "منذ 3 أيام"
  ///   * else  → an absolute date, with the year dropped inside the
  ///     current year ("Jul 25" rather than "Jul 25, 2026").
  ///
  /// That last bucket drops the year for the same reason [dayLabel] does:
  /// it is redundant for a date a few weeks old and it costs width on the
  /// 320 px tier, where this stamp shares a row with the title it must not
  /// starve. Dates in another year keep the year, because there it is the
  /// only part that disambiguates them.
  ///
  /// Counts go through `NumberFormat` rather than raw interpolation so the
  /// numbering system follows the locale rather than being hardcoded. For
  /// `ar` that resolves to Western digits (see the class doc) — the point is
  /// that the DECISION lives in CLDR, so shipping `ar_EG` later would pick
  /// up Arabic-Indic here for free instead of needing a code change.
  static String relative(BuildContext context, DateTime when) {
    final now = DateTime.now();
    final delta = now.difference(when.toLocal());
    final tr = context.tr;
    final loc = _locale(context);
    final n = _decimalFor(loc);

    if (delta.inSeconds < 60) return tr.now;
    if (delta.inMinutes < 60) return tr.relativeMinutesAgo(n.format(delta.inMinutes));
    if (delta.inHours < 24) return tr.relativeHoursAgo(n.format(delta.inHours));
    if (delta.inHours < 48) return tr.dateYesterday;
    if (delta.inDays < 7) return tr.relativeDaysAgo(n.format(delta.inDays));
    final local = when.toLocal();
    return local.year == now.year
        ? _mMMd(loc).format(local)
        : _yMMMd(loc).format(local);
  }
}
