import '../i18n/app_strings.dart';

/// Human file size — `842 B`, `13 KB`, `2.4 MB`, `250 MB` (`842 بايت`,
/// `13 ك.ب`, `2.4 م.ب` in Arabic).
///
/// Binary units (1 KB = 1024 B), matching what the OS file pickers report,
/// so a file the user sees as "2.4 MB" in Files reads the same here.
/// Sub-10 MB keeps one decimal (`2.4 MB`) because the difference matters
/// against the 25 MB upload cap; past that it rounds (`250 MB`), where a
/// tenth is noise.
///
/// Western digits in both locales, matching [compactCount] and how the app
/// renders its other numerics — only the unit *word* localizes, which is
/// the same split `AppDateFormat.relative` uses for "5 m ago" / "منذ 5 د".
///
/// Single source of truth for the chat composer's attachment chips and the
/// artifact tiles, which each carried a byte-identical private copy — one a
/// method, one a top-level function, in the same 3,400-line file.
String humanBytes(int bytes, AppStrings tr) {
  if (bytes < kBytesPerKb) return '$bytes ${tr.unitBytes}';
  if (bytes < kBytesPerMb) {
    return '${(bytes / kBytesPerKb).round()} ${tr.unitKilobytes}';
  }
  final mb = bytes / kBytesPerMb;
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} ${tr.unitMegabytes}';
}

/// Binary size steps. Public because the upload-cap checks in the chat
/// composer compare raw byte counts against an MB limit and were
/// re-deriving `1024 * 1024` inline.
const int kBytesPerKb = 1024;
const int kBytesPerMb = 1024 * 1024;
