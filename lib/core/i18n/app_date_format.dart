import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';
import '../constants/ui_strings.dart';

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
/// month and meridiem localize, the numerals don't. It matches the app-wide
/// convention `compactCount` documents, the Gulf market this ships to, and
/// every one of the 1,100+ Arabic strings in `app_strings.dart`.
///
/// So don't "fix" it by forcing an Arabic-Indic numbering system — the whole
/// app would have to move together, and the market doesn't want it.
///
/// ### Why [_western] exists
///
/// That paragraph used to end by saying the code "always produced Western"
/// and warning a reviewer off a bug that was never there. The warning was
/// wrong, and it cost this app a visible defect for as long as it stood:
/// **the code produced Arabic-Indic**, and had been doing so on every
/// Arabic device.
///
/// The claim was right about CLDR and wrong about this app. Raw ICU — what
/// you get from `initializeDateFormatting()` — does resolve `ar` and
/// `ar_SA` to Western digits, and a probe written that way agrees with the
/// paragraph. But this app never calls it: `flutter_localizations` installs
/// the date symbols instead, and **its** Arabic symbols carry the
/// Arabic-Indic numbering system. So a test that set up `intl` itself
/// confirmed the doc, while the running app disagreed with it.
///
/// The mixture reached one screen at a time. A conversation row rendered
///
/// ```text
/// ٣٠ يوليو        ← this file, via flutter_localizations' symbols
/// منذ 17 س        ← this file, via NumberFormat  (Western)
/// آخر 7 أيام      ← app_strings.dart             (Western)
/// ```
///
/// — two digit systems from three sources, and the first two from the same
/// method a few lines apart.
///
/// [_western] settles it at the one choke point every rendered date already
/// passes through, which is the reason this class exists at all.
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

  /// Rewrites Arabic-Indic digits to Western ones, leaving every other
  /// character alone.
  ///
  /// Applied to formatter OUTPUT rather than by choosing a different locale,
  /// because the numbering system here does not come from the locale we
  /// pass: `flutter_localizations` supplies the symbols, and its `ar` set is
  /// Arabic-Indic no matter what string reaches [DateFormat]. Passing
  /// `'ar_SA'` would change the month names and not the digits.
  ///
  /// Also maps the Arabic decimal separator (U+066B) and thousands
  /// separator (U+066C), which travel with those digits: a formatter that
  /// emits `٠١٢` emits `٬` between groups, and leaving those behind would
  /// turn one mixed string into another.
  ///
  /// Cheap enough to run unconditionally — it is a single scan, and every
  /// caller is already paying for an ICU format. Running it for English too
  /// keeps the two paths identical, so an English-only test still exercises
  /// the line an Arabic user depends on.
  static String _western(String s) {
    if (!s.contains(_easternDigits)) return s;
    final out = StringBuffer();
    for (final rune in s.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        out.writeCharCode(0x30 + (rune - 0x0660));
      } else if (rune == 0x066B) {
        out.write('.');
      } else if (rune == 0x066C) {
        out.write(',');
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  /// Arabic-Indic digits and the two separators that travel with them.
  static final _easternDigits = RegExp(r'[٠-٩٫٬]');

  static DateFormat _jm(String loc) => _timeJm[loc] ??= DateFormat.jm(loc);
  static DateFormat _hm(String loc) => _timeHm[loc] ??= DateFormat.Hm(loc);
  static DateFormat _yMMMd(String loc) =>
      _dateYMMMd[loc] ??= DateFormat.yMMMd(loc);
  static DateFormat _mMMd(String loc) =>
      _dateMMMd[loc] ??= DateFormat.MMMd(loc);
  static NumberFormat _decimalFor(String loc) =>
      _decimal[loc] ??= NumberFormat.decimalPattern(loc);

  /// Day-first long date for a grouped list header — "15 November 2026" /
  /// "15 نوفمبر 2026". Western digits, like every other date in the app (the
  /// notifications inbox used to build this with a bare `DateFormat`, which
  /// printed Arabic-Indic digits and made it the one screen that disagreed).
  static String longDate(BuildContext context, DateTime when) {
    return _western(
      DateFormat(
        UiStrings.dateLongDayFirst,
        _locale(context),
      ).format(when.toLocal()),
    );
  }

  /// "11:42 AM" / "11:42 ص". When [twentyFour] is true, renders as
  /// "11:42" without the meridiem.
  static String time(
    BuildContext context,
    DateTime when, {
    bool twentyFour = false,
  }) {
    final loc = _locale(context);
    final pattern = twentyFour ? _hm(loc) : _jm(loc);
    return _western(pattern.format(when.toLocal()));
  }

  /// "May 18, 2026" / "18 مايو 2026".
  static String date(BuildContext context, DateTime when) {
    return _western(_yMMMd(_locale(context)).format(when.toLocal()));
  }

  /// "May 18, 2026 · 11:42 AM".
  static String dateTime(BuildContext context, DateTime when) {
    return '${date(context, when)} · ${time(context, when)}';
  }

  /// Web-parity full timestamp: "May 18, 2026 at 06:24 PM" /
  /// "18 مايو 2026 في 06:24 م". Uses a natural-language connector
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
    return _western(
      stamp.year == today.year
          ? _mMMd(loc).format(stamp)
          : _yMMMd(loc).format(stamp),
    );
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
    String num(int v) => _western(n.format(v));

    if (delta.inSeconds < 60) return tr.now;
    if (delta.inMinutes < 60) {
      return tr.relativeMinutesAgo(num(delta.inMinutes));
    }
    if (delta.inHours < 24) return tr.relativeHoursAgo(num(delta.inHours));
    if (delta.inHours < 48) return tr.dateYesterday;
    if (delta.inDays < 7) {
      return tr.relativeDaysAgo(num(delta.inDays), delta.inDays);
    }
    final local = when.toLocal();
    return _western(
      local.year == now.year
          ? _mMMd(loc).format(local)
          : _yMMMd(loc).format(local),
    );
  }
}
