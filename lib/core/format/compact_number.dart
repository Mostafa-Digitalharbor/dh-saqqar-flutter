/// Compact ST (token) count — `950`, `12.3K`, `2.5M`. Keeps caps readable
/// when they run into the millions (Pro = 2.5M burst). One decimal place,
/// with a trailing `.0` dropped so `12.0K` renders as `12K`. Western digits
/// in both locales, matching how the app renders its other numerics.
///
/// Single source of truth for the pricing screen + the plan-usage and
/// current-plan cards, which each carried a byte-identical private copy that
/// could silently drift.
String compactCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) return '${_trim(value / 1000)}K';
  return '${_trim(value / 1000000)}M';
}

String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
