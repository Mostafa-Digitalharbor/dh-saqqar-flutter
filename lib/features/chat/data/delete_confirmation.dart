/// Type-to-confirm guard for destructive delete approvals.
///
/// The web makes the user type `delete N` (Arabic: `حذف N`) before a delete
/// approval goes through; mobile approved one on a single tap. That is the
/// riskiest one-tap action in the app — on a production Odoo it is
/// unrecoverable — so the phrase gate ships here too.
///
/// The matching rules live in this file, away from any widget, because the
/// interesting part is text normalisation and it must be testable on its own:
/// an Arabic keyboard types ٦, not 6, and a confirmation that silently
/// refuses the digits the user's own keyboard produces is the same bug as
/// having no Arabic translation at all.
library;

/// Wire value of the destructive operation on an `odoo_write` approval.
const kDeleteOperation = 'delete';

/// Arabic-Indic (٠–٩) and Extended/Persian Arabic-Indic (۰–۹) digits, in
/// value order, so index == the Western digit they map to.
const _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';
const _extendedArabicIndicDigits = '۰۱۲۳۴۵۶۷۸۹';

/// Rewrites Arabic-Indic digits as Western ones and collapses whitespace /
/// case, so the phrase compares on meaning rather than on keyboard layout.
String normalizeConfirmation(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    final arabic = _arabicIndicDigits.indexOf(char);
    if (arabic != -1) {
      buffer.write(arabic);
      continue;
    }
    final extended = _extendedArabicIndicDigits.indexOf(char);
    if (extended != -1) {
      buffer.write(extended);
      continue;
    }
    buffer.write(char);
  }
  return buffer
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Whether [typed] confirms the delete, given the phrases the UI offered.
///
/// Accepts ANY of [accepted] — the Arabic phrase and the English one are both
/// valid whatever the UI language is. A bilingual user typing "delete 6" on an
/// Arabic screen meant it just as plainly as "حذف ٦", and refusing them buys
/// no safety.
bool confirmsDelete(String typed, Iterable<String> accepted) {
  final normalized = normalizeConfirmation(typed);
  if (normalized.isEmpty) return false;
  return accepted.any((p) => normalizeConfirmation(p) == normalized);
}
