import 'package:flutter/foundation.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/format/wire_value.dart';
import 'interactive_card_kind.dart';

part 'pulse_actions_finance.dart';
part 'pulse_actions_operations.dart';

/// The action rows an app-pulse card offers — "Customer collection · 13
/// overdue invoices · [Start collection]".
///
/// **Why this exists.** The cards used to render as read-only dashboards on
/// mobile while the web rendered the same payload as a set of rows, each
/// ending in a button that sends a prompt and puts the agent to work. A user
/// on the phone could read that 13 invoices were overdue and had no way to
/// act on it without retyping the request; the team reported exactly that
/// ("مافيش زراير ومافيش اكشن").
///
/// **Where the copy comes from.** The buttons are NOT in the payload — the
/// web builds them client-side from the same `tool_payload` this client
/// already parses, so the wording, the conditions that decide which rows
/// appear, and above all the prompt each button sends are ported from the
/// web's own card builders (`buildFinanceCard`, `buildFactoryCard`, …). The
/// prompt is the contract: it is what the agent receives, so it is matched
/// word for word rather than paraphrased. Copy lives in `app_strings.dart`
/// under `pulse_act_*` keys and is resolved with [AppStrings.format].
///
/// Numbers are formatted the way the web formats them (`formatPulseNumber`:
/// grouped thousands, at most two decimals, an em dash for null) so a row
/// reads identically on both surfaces.
/// One button on an action row.
///
/// Most rows carry exactly one, and [PulseAction.label] / [PulseAction.prompt]
/// are it. The factory's at-risk orders carry two — "Delivery date" and
/// "Cover shortage" — which the web renders side by side under a single
/// heading (`data-fc-promise` and `data-fc-cover` inside one `.fc-risk`).
/// Emitting them as two [PulseAction]s instead printed the order, the
/// customer and the cause twice, which is how it looked on the phone: four
/// at-risk orders read as eight rows.
@immutable
class PulseActionButton {
  const PulseActionButton({
    required this.label,
    required this.prompt,
    this.primary = false,
  });

  final String label;

  /// What the button sends to the agent, in the UI language.
  final String prompt;

  /// Filled rather than ghost.
  final bool primary;

  @override
  bool operator ==(Object other) =>
      other is PulseActionButton &&
      other.label == label &&
      other.prompt == prompt &&
      other.primary == primary;

  @override
  int get hashCode => Object.hash(label, prompt, primary);
}

@immutable
class PulseAction {
  const PulseAction({
    required this.title,
    required this.main,
    required this.label,
    required this.prompt,
    this.cause = '',
    this.primary = false,
    this.extraButtons = const [],
  });

  /// Row heading — "Customer collection".
  final String title;

  /// The one-line reading under it — "13 invoice(s): 1-30 …".
  final String main;

  /// Optional second line naming the biggest contributor. Empty when the
  /// payload carried no item to name.
  final String cause;

  /// Button label — "Start collection".
  final String label;

  /// What the button sends to the agent, in the UI language. Verbatim from
  /// the web so the same tap produces the same run on both clients.
  final String prompt;

  /// The first actionable row gets the filled button; the rest are ghosts.
  final bool primary;

  /// Further buttons on the same row, after this one. Empty for every card
  /// but the factory — see [PulseActionButton].
  final List<PulseActionButton> extraButtons;

  /// Every button on the row, this one first — the order the web renders.
  List<PulseActionButton> get buttons => [
    PulseActionButton(label: label, prompt: prompt, primary: primary),
    ...extraButtons,
  ];

  @override
  bool operator ==(Object other) =>
      other is PulseAction &&
      other.title == title &&
      other.main == main &&
      other.cause == cause &&
      other.label == label &&
      other.prompt == prompt &&
      other.primary == primary &&
      listEquals(other.extraButtons, extraButtons);

  @override
  int get hashCode => Object.hash(
    title,
    main,
    cause,
    label,
    prompt,
    primary,
    Object.hashAll(extraButtons),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Payload readers — ported from the web's helpers of the same name
// ─────────────────────────────────────────────────────────────────────────

// Shared with every other wire parser — see `core/format/wire_value.dart`.
const _map = wireMap;
const _list = wireList;

/// `bucketCount` — null when the bucket says it can't answer, else its count
/// (a missing count reads as 0, matching the web's `Number(x) || 0`).
int? _count(Object? bucket) {
  final b = _map(bucket);
  if (b.isEmpty || b['available'] == false) return null;
  final n = b['count'];
  if (n is num) return n.toInt();
  if (n is String) return int.tryParse(n.trim()) ?? 0;
  return 0;
}

/// `bucketTotal` — null when unavailable or absent.
num? _total(Object? bucket) {
  final b = _map(bucket);
  if (b.isEmpty || b['available'] == false) return null;
  final t = b['total'];
  if (t is num) return t;
  if (t is String) return num.tryParse(t.trim());
  return null;
}

/// `firstItem` — the first row of a bucket's `items`, or an empty map.
Map<String, dynamic> _first(Object? bucket) {
  final items = _list(_map(bucket)['items']);
  for (final item in items) {
    if (item is Map) return item.cast<String, dynamic>();
  }
  return const {};
}

const _str = wireString;
const _num = wireNum;

/// Unlike the other parsers' `_int`, a pulse count that is not a number reads
/// as 0 rather than as unknown: these feed counters the web renders with
/// `Number(x) || 0`, and matching that keeps the two clients agreeing.
int _int(Object? value) => wireIntOr(value, 0);

/// `formatPulseNumber` — `Intl.NumberFormat("en-US", {maximumFractionDigits:
/// 2})`, and an em dash for a value the server didn't send. Western digits
/// in both locales, matching both the web and this app's own numerics.
String formatPulseNumber(Object? value) {
  if (value == null || value == '') return '—';
  final n = _num(value);
  if (n == null) return '$value';
  final rounded = (n * 100).round() / 100;
  final negative = rounded < 0;
  final abs = negative ? -rounded : rounded;
  final whole = abs.truncate();
  final fraction = abs - whole;
  final digits = whole.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  var out = grouped.toString();
  if (fraction > 0) {
    // Two decimals at most, trailing zeros dropped — "1,234.5", not
    // "1,234.50", which is what Intl does with maximumFractionDigits.
    var frac = fraction.toStringAsFixed(2).substring(2);
    while (frac.endsWith('0')) {
      frac = frac.substring(0, frac.length - 1);
    }
    if (frac.isNotEmpty) out = '$out.$frac';
  }
  return negative ? '-$out' : out;
}

/// The actions for one pulse card, in the order the web renders them.
///
/// Returns empty for a payload with nothing to act on — the card then shows
/// its numbers and no button row, exactly like the web's empty state.
List<PulseAction> pulseActions(
  InteractiveCardKind kind,
  Map<String, dynamic>? payload,
  AppStrings tr,
) {
  if (payload == null) return const [];
  return switch (kind) {
    InteractiveCardKind.factory => _factory(payload, tr),
    InteractiveCardKind.finance => _finance(payload, tr),
    InteractiveCardKind.purchasing => _purchasing(payload, tr),
    InteractiveCardKind.inventory => _inventory(payload, tr),
    InteractiveCardKind.qualityGuard => _qualityGuard(payload, tr),
    InteractiveCardKind.accountant => _counterDriven(payload, tr, 'accountant'),
    InteractiveCardKind.hr => _counterDriven(payload, tr, 'hr'),
    InteractiveCardKind.promptClarify ||
    InteractiveCardKind.reportBuilder ||
    InteractiveCardKind.promptSuggestion => const [],
  };
}

String _k(String kind, String row, String part) =>
    'pulse_act_${kind}_${row}_$part';

// ── accountant + hr ──────────────────────────────────────────────────────
//
// Both cards are counter-driven: every counter the server sends carries its
// own action, keyed by the counter's `key`. The label and prompt come from
// the string table under `pulse_act_<kind>_<counter key>_*`; a counter whose
// key this client doesn't know yet renders with no button rather than with a
// guessed one.
const _accountantKeys = [
  'journal',
  'invoices',
  'bank',
  'tax',
  'close',
  'stock',
  'diagnosis',
  'closing',
  'cycles',
];

const _hrKeys = [
  'applicants',
  'strong',
  'contracts',
  'payroll',
  'timeoff',
  'attendance',
];

/// The deep-dive chips under a counter-driven card — the checks an
/// accountant (or a recruiter) runs beyond what the counters already say.
/// Order is the web's own.
const _accountantDeep = [
  'brief',
  'transit',
  'statements',
  'ledger',
  'balances',
  'duplicates',
  'chart',
  'setup',
];

const _hrDeep = ['rank', 'interview', 'ops', 'payroll', 'timeoff'];

/// The chips under the inventory card — the web's `EXTRA` array, in its
/// order. These are questions the six stock buckets do not answer on their
/// own (where a shipment is, which transfers are stuck, whether the balances
/// can be trusted, where one product sits), so none of them duplicates a
/// bucket's own button.
const _inventoryDeep = ['track', 'stalled', 'accuracy', 'locate'];

/// The counter keys each counter-driven card knows an action for.
List<String> pulseCounterActionKeys(String kind) =>
    kind == 'hr' ? _hrKeys : _accountantKeys;

/// The deep-dive chip keys for a card that has any.
List<String> pulseDeepActionKeys(String kind) => switch (kind) {
  'hr' => _hrDeep,
  'inventory' => _inventoryDeep,
  _ => _accountantDeep,
};

List<PulseAction> _counterDriven(
  Map<String, dynamic> payload,
  AppStrings tr,
  String kind,
) {
  final known = pulseCounterActionKeys(kind);
  final rows = <PulseAction>[];
  for (final raw in _list(payload['counters'])) {
    if (raw is! Map) continue;
    final counter = raw.cast<String, dynamic>();
    final key = _str(counter['key']);
    if (!known.contains(key)) continue;
    final serverAction = _str(counter['action']);
    // Arabic takes the server's own wording for the button, English takes
    // this client's — exactly the web's rule. The server writes `action` in
    // the conversation's language, so in Arabic it is already the better
    // label; the English table is the fallback when it isn't.
    final label = tr.isArabic && serverAction.isNotEmpty
        ? serverAction
        : tr.lookup(_k(kind, key, 'label'), fallback: serverAction);
    final prompt = tr.lookup(_k(kind, key, 'prompt'));
    if (label.isEmpty || prompt.isEmpty) continue;
    rows.add(
      PulseAction(
        // The counter's own label is server-authored and already in the
        // screen's language (rule 4) — it is the row's title as-is.
        title: _str(counter['label']),
        main: formatPulseNumber(counter['value']),
        label: label,
        prompt: prompt,
        primary: rows.isEmpty,
      ),
    );
  }
  return rows;
}

/// The chip row under an accountant / HR / inventory card.
///
/// Split from [pulseActions] because these are not readings with a number
/// attached — they are standing questions the card can always ask, so they
/// render as a wrap of chips rather than as rows. A chip whose label already
/// appears on one of the row buttons is dropped, matching the web's
/// `dropChipsAlreadyOnTiles`: the same words twice on one card is noise.
List<PulseAction> pulseDeepActions(
  InteractiveCardKind kind,
  Map<String, dynamic>? payload,
  AppStrings tr,
) {
  final name = switch (kind) {
    InteractiveCardKind.accountant => 'accountant',
    InteractiveCardKind.hr => 'hr',
    InteractiveCardKind.inventory => 'inventory',
    _ => '',
  };
  if (name.isEmpty) return const [];
  final taken = pulseActions(kind, payload, tr).map((a) => a.label).toSet();
  final out = <PulseAction>[];
  for (final key in pulseDeepActionKeys(name)) {
    final label = tr.lookup('pulse_act_${name}_deep_${key}_label');
    final prompt = tr.lookup('pulse_act_${name}_deep_${key}_prompt');
    if (label.isEmpty || prompt.isEmpty || taken.contains(label)) continue;
    out.add(
      PulseAction(
        title: '',
        main: '',
        label: label,
        prompt: prompt,
        primary: out.isEmpty,
      ),
    );
  }
  return out;
}

/// What the card says when the payload earns it no action rows — "Liquidity
/// looks calm in the current read; review bank and close hygiene."
///
/// The web prints this instead of the rows, and a real database hits it
/// often: a freshly seeded Odoo answers every question with a zero. Without
/// it the card just ends after its numbers, which reads like something
/// failed to load rather than like good news. Empty for the two
/// counter-driven cards, which the web leaves without one.
String pulseEmptyStateText(InteractiveCardKind kind, AppStrings tr) {
  final key = switch (kind) {
    InteractiveCardKind.factory => 'factory',
    InteractiveCardKind.finance => 'finance',
    InteractiveCardKind.inventory => 'inventory',
    InteractiveCardKind.purchasing => 'purchasing',
    InteractiveCardKind.qualityGuard => 'quality',
    _ => '',
  };
  return key.isEmpty ? '' : tr.lookup('pulse_act_empty_$key');
}

/// The free-text row three cards carry: the accountant's "explain this
/// document number", HR's "shortlist for this job title", and the
/// inventory's "track this shipment". Returns null for every other kind.
///
/// [emptyPromptKey] is what an empty box sends. The accountant and HR boxes
/// have none — "explain ''" is not a question, so the web focuses the input
/// instead — while the inventory tracker reads an empty box as "everything
/// on the move", the same prompt its Track-shipments chip sends.
({String hint, String label, String promptKey, String? emptyPromptKey})?
pulseFreeTextAction(InteractiveCardKind kind) => switch (kind) {
  InteractiveCardKind.accountant => (
    hint: 'pulse_act_accountant_explain_hint',
    label: 'pulse_act_accountant_explain_label',
    promptKey: 'pulse_act_accountant_explain_prompt',
    emptyPromptKey: null,
  ),
  InteractiveCardKind.hr => (
    hint: 'pulse_act_hr_explain_hint',
    label: 'pulse_act_hr_explain_label',
    promptKey: 'pulse_act_hr_explain_prompt',
    emptyPromptKey: null,
  ),
  InteractiveCardKind.inventory => (
    hint: 'pulse_act_inventory_track_hint',
    label: 'pulse_act_inventory_track_label',
    promptKey: 'pulse_act_inventory_track_prompt',
    emptyPromptKey: 'pulse_act_inventory_deep_track_prompt',
  ),
  _ => null,
};
