/// Total, never-throwing coercions from a decoded-JSON `Object?` to the
/// Dart type a model wants.
///
/// **Why these are shared rather than copied.** Five parsers had each grown
/// their own private `_str` / `_int` / `_list`, and the copies had already
/// drifted apart in ways nobody chose:
///
///   * `interactive_cards`, `app_pulse_payloads` and `pulse_actions` did not
///     trim; `voice_support_models` did.
///   * `_int` returned `int?` in two files and `int` (defaulting to 0) in a
///     third, so the same wire value meant "unknown" in one card and "zero"
///     in the next.
///   * `prompt_memory_api._str` was `v.toString()`, which does not screen out
///     maps and lists at all — a `{"title": {"en": …, "ar": …}}` from a
///     backend that starts localizing a field would have rendered the literal
///     text `{en: …, ar: …}` into the prompt bank.
///
/// Those are not four spellings of one helper; they are four different
/// answers to "what does the UI show when the server sends something else".
/// Naming the variants explicitly ([wireString] vs `trim:`, [wireInt] vs
/// [wireIntOr]) makes each call site state which answer it wants instead of
/// inheriting whichever copy happened to be in the file.
///
/// **Why nothing here casts.** These parsers run inside `isVisibleMessage` —
/// over every message of every snapshot, on a 1.5 s poll. An `as String`
/// against one `"truncated": "yes"` from a partial backend rollout would not
/// lose a card; it would throw on every tick and take the whole conversation
/// down with no way back in. Every function below is total: it returns a
/// usable value for any input, including `null`, and never throws.
library;

/// A displayable string.
///
/// Numbers and bools stringify — they are still server-authored values worth
/// showing. Maps and lists become `''`, because rendering `{a: 1}` in a chip
/// helps nobody, and because a field that quietly turns into an object is the
/// shape of a backend that started localizing it.
///
/// Set [trim] when the value is going into a layout that cannot absorb stray
/// whitespace (a chip, a single-line title).
String wireString(Object? value, {bool trim = false}) {
  if (value is String) return trim ? value.trim() : value;
  if (value is num || value is bool) return '$value';
  return '';
}

/// A list, or an empty one. Never throws on a scalar.
List<Object?> wireList(Object? value) => value is List ? value : const [];

/// A string-keyed map, or an empty one. Never throws on a scalar or a list.
Map<String, dynamic> wireMap(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const <String, dynamic>{};

/// An int from a number or a numeric string; `null` for anything else.
///
/// Null means *unknown* — use it where the UI can say "—" rather than
/// claiming a count it does not have. Where the caller genuinely wants a
/// number no matter what, use [wireIntOr] so the substitution is visible at
/// the call site.
int? wireInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// [wireInt] with an explicit stand-in for "not a number".
int wireIntOr(Object? value, int fallback) => wireInt(value) ?? fallback;

/// A num from a number or a numeric string; `null` for anything else.
num? wireNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value.trim());
  return null;
}

/// A double from a number or a numeric string; `null` for anything else.
double? wireDouble(Object? value) => wireNum(value)?.toDouble();

/// Strictly a `true` bool.
///
/// A non-bool reads as false rather than as truthy — for a flag like
/// `truncated` that means under-warning, which beats a warning the user can
/// never clear.
bool wireBool(Object? value) => value is bool && value;
