/// When the composer should offer to structure what is being typed.
///
/// Mirrors the web's `normalizePromptIntent` / `parseTaskPromptCommand` /
/// `looksLikeLongTaskPrompt` trio. Kept out of the widget so the threshold
/// and the Arabic normalisation can be tested without a screen.
library;

/// Strips the diacritics and letter variants that make two spellings of the
/// same Arabic word compare unequal, so word counting and command matching
/// see one form. Same table as the web's `normalizePromptIntent`.
String normalizePromptIntent(String text) {
  return text
      .toLowerCase()
      // Diacritics only: U+064B-U+065F plus the superscript alef U+0670.
      // Written as escapes because the literal range spelled with the
      // characters themselves also swallows U+0660-U+0669 -- the Arabic-Indic
      // digits -- which would erase every number from a task before counting
      // its words, and make two tasks differing only in a figure share one
      // dismissal key.
      .replaceAll(RegExp('[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Phrases that mean "rewrite my task", in both languages.
const _commandPhrases = <String>[
  'صياغه التاسك',
  'صيغ التاسك',
  'رتب التاسك',
  'رتبلي التاسك',
  'ظبط التاسك',
  'صياغه المهمه',
  'صيغ المهمه',
  'رتب المهمه',
  'رتبلي المهمه',
  'ظبط المهمه',
  'صياغه البرومبت',
  'صيغ البرومبت',
  'رتب البرومبت',
  'ظبط البرومبت',
  'اكتب البرومبت',
  'task wording',
  'draft prompt',
  'rewrite prompt',
  'clean prompt',
  'structure task',
];

const _taskWords = <String>[
  'تاسك',
  'التاسك',
  'مهمه',
  'المهمه',
  'برومبت',
  'البرومبت',
  'prompt',
  'task',
  'mission',
];

const _refineSignals = <String>[
  'صياغ',
  'صيغ',
  'رتب',
  'رتبلي',
  'نظم',
  'ظبط',
  'اكتب',
  'اكتبي',
  'حول',
  'حوّل',
  'خلي',
  'خل ',
  'rewrite',
  'clean',
  'structure',
  'draft',
  'wording',
];

/// True when the text is itself an instruction to structure a task.
///
/// The web uses this only to SUPPRESS the hint — offering "shall I structure
/// this?" to someone who just typed "رتب المهمة" is the app not listening.
bool isTaskWordingCommand(String text) {
  final clean = normalizePromptIntent(text);
  if (clean.isEmpty) return false;
  for (final phrase in _commandPhrases) {
    if (clean == phrase ||
        clean.startsWith('$phrase ') ||
        clean.startsWith('$phrase:')) {
      return true;
    }
  }
  final hasTaskWord = _taskWords.any(clean.contains);
  final hasRefineSignal = _refineSignals.any(clean.contains);
  return hasTaskWord && hasRefineSignal;
}

/// The web's bar: with task-prep on, more than ten words is a task worth
/// organising. No keyword needed — the hint is an offer, and dismissing it
/// silences it for that text.
bool looksLikeLongTaskPrompt(String text) {
  final raw = text.trim();
  if (raw.isEmpty) return false;
  if (isTaskWordingCommand(raw)) return false;
  final clean = normalizePromptIntent(raw);
  final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  return words > 10;
}

/// Identity for "this exact text was already dismissed". Truncated the same
/// way the web truncates so a long task does not key on its tail.
String taskWordingHintKey(String text) {
  final clean = normalizePromptIntent(text);
  return clean.length <= 180 ? clean : clean.substring(0, 180);
}
