import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/i18n/app_strings.dart';
import 'app_pulse_payloads.dart'
    show
        AccountantPulsePayload,
        FactoryPulsePayload,
        HrPulsePayload,
        InventoryPulsePayload,
        PurchasingPulsePayload,
        QualityGuardPulsePayload,
        FinancePulsePayload;
import 'interactive_card_kind.dart';

export 'interactive_card_kind.dart';

/// Interactive cards Saqqar can post **inside** the conversation, where the
/// user picks options / edits text right in the stream and that composes the
/// next message.
///
/// The server flags them on the message's `tool_payload.kind`, exactly as the
/// web dispatches (`app.js` `renderMessages`). Anything else — including a
/// tool row with no `kind` — stays on the generic tool-activity card.
///
/// Every parser here is deliberately forgiving: a malformed card must render
/// as an ordinary message, never throw and take the whole chat list down with
/// it. `null` from a `parse` is the signal to fall through.
///
/// [InteractiveCardKind] and [interactiveCardKind] live in
/// `interactive_card_kind.dart` (re-exported above) and are shared with the
/// read-only "pulse" card family in `app_pulse_payloads.dart` — neither file
/// owns the enum, so it sits where both can import it without a cycle.

/// Whether [payload] parses into a card the user can actually act on.
///
/// Stronger than [interactiveCardKind], which only reads the `kind` label.
/// This is what the chat screen's visibility filter keys off, and the two
/// questions are genuinely different: a payload that says
/// `kind: "prompt_clarify"` but carries no questions has a kind and no card.
/// Keeping such a message visible would put an empty bubble in the stream —
/// the filter drops it instead, exactly as it did before cards existed.
bool hasRenderableInteractiveCard(Map<String, dynamic>? payload) {
  return switch (interactiveCardKind(payload)) {
    InteractiveCardKind.promptClarify =>
      PromptClarifyPayload.parse(payload) != null,
    InteractiveCardKind.reportBuilder =>
      ReportBuilderPayload.parse(payload) != null,
    InteractiveCardKind.promptSuggestion =>
      PromptSuggestionPayload.parse(payload) != null,
    InteractiveCardKind.factory => FactoryPulsePayload.parse(payload) != null,
    InteractiveCardKind.inventory =>
      InventoryPulsePayload.parse(payload) != null,
    InteractiveCardKind.finance => FinancePulsePayload.parse(payload) != null,
    InteractiveCardKind.purchasing =>
      PurchasingPulsePayload.parse(payload) != null,
    InteractiveCardKind.accountant =>
      AccountantPulsePayload.parse(payload) != null,
    InteractiveCardKind.hr => HrPulsePayload.parse(payload) != null,
    InteractiveCardKind.qualityGuard =>
      QualityGuardPulsePayload.parse(payload) != null,
    null => false,
  };
}

// ─────────────────────────────────────────────────────────────────────────
// Type-tolerant field readers
// ─────────────────────────────────────────────────────────────────────────
//
// `as String?` and friends THROW on a wrong-typed field, and these parsers
// run inside `isVisibleMessage` — i.e. over every message of every snapshot,
// on a 1.5 s poll. One `"truncated": "yes"` from a partial backend rollout
// would not lose a card; it would throw on every tick and take the whole
// conversation down with no way back in. So nothing here casts.

/// A displayable string. Numbers and bools stringify (they are still
/// server-authored values worth showing); maps and lists become empty,
/// because rendering `{a: 1}` in a chip helps nobody.
String _str(Object? value) {
  if (value is String) return value;
  if (value is num || value is bool) return '$value';
  return '';
}

/// A list, or an empty one. Never throws on a scalar.
List<Object?> _list(Object? value) => value is List ? value : const [];

/// An int from a number or a numeric string; null for anything else.
int? _int(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// Strictly a `true` bool. A non-bool reads as false rather than as truthy —
/// for `truncated` that means under-warning, which beats a warning the user
/// can never clear.
bool _bool(Object? value) => value is bool && value;

// ─────────────────────────────────────────────────────────────────────────
// prompt_clarify (§4a)
// ─────────────────────────────────────────────────────────────────────────

/// One clarifying question — a prompt plus tappable single-select options.
@immutable
class ClarifyQuestion extends Equatable {
  const ClarifyQuestion({
    required this.question,
    this.options = const [],
    this.defaultIndex,
  });

  final String question;
  final List<String> options;

  /// Index of the smart default the server pre-selects, or null for none.
  /// `-1` and out-of-range values are normalised away at parse time so the
  /// card never tries to highlight a chip that isn't there.
  final int? defaultIndex;

  factory ClarifyQuestion.fromJson(Map<String, dynamic> json) {
    final options = _list(json['options'])
        .map(_str)
        .where((e) => e.isNotEmpty)
        .toList();
    final raw = _int(json['default']);
    return ClarifyQuestion(
      question: _str(json['question']),
      options: options,
      defaultIndex:
          raw != null && raw >= 0 && raw < options.length ? raw : null,
    );
  }

  @override
  List<Object?> get props => [question, options, defaultIndex];
}

@immutable
class PromptClarifyPayload extends Equatable {
  const PromptClarifyPayload({
    this.original = '',
    this.intro = '',
    this.questions = const [],
  });

  /// The vague request that triggered the card. Already on screen as the
  /// user's own message above, so the card shows it only as context.
  final String original;

  /// Optional lead-in written by the agent.
  final String intro;

  /// 1–3 questions in practice; the parser does not enforce a count.
  final List<ClarifyQuestion> questions;

  /// Returns null when the payload carries no answerable question — there is
  /// nothing to tap, so the message belongs on the ordinary path.
  static PromptClarifyPayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.promptClarify) {
      return null;
    }
    final questions = _list(payload!['questions'])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => ClarifyQuestion.fromJson(e.cast<String, dynamic>()))
        .where((q) => q.question.isNotEmpty)
        .toList();
    if (questions.isEmpty) return null;
    return PromptClarifyPayload(
      original: _str(payload['original']),
      intro: _str(payload['intro']),
      questions: questions,
    );
  }

  @override
  List<Object?> get props => [original, intro, questions];
}

// ─────────────────────────────────────────────────────────────────────────
// prompt_suggestion (§4c)
// ─────────────────────────────────────────────────────────────────────────

@immutable
class PromptSuggestionPayload extends Equatable {
  const PromptSuggestionPayload({required this.improved, this.note = ''});

  /// A tidier version of the user's request. Rendered EDITABLE — the user
  /// may accept it as-is, tweak it, or keep their own wording.
  final String improved;
  final String note;

  static PromptSuggestionPayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.promptSuggestion) {
      return null;
    }
    final improved = _str(payload!['improved']).trim();
    // Nothing to approve without a suggestion — fall through rather than
    // render an empty textarea with an "Approve & use" button under it.
    if (improved.isEmpty) return null;
    return PromptSuggestionPayload(
      improved: improved,
      note: _str(payload['note']),
    );
  }

  @override
  List<Object?> get props => [improved, note];
}

// ─────────────────────────────────────────────────────────────────────────
// report_builder (§4b)
// ─────────────────────────────────────────────────────────────────────────

/// Client i18n key prefixes for report chips, matching the web's
/// (`rbType_<key>`, `rbPeriod_<key>`, `rbLens_<key>`, `rbFormat_<key>`).
///
/// The web resolves a chip's display text through these and falls back to the
/// server's own `label`. Mobile uses the identical rule via
/// [AppStrings.lookup] — see [ReportOption.displayLabel].
///
/// **No entries exist in `app_strings` yet, deliberately.** Populating a few
/// would give a card with "أوامر البيع" next to "Customer aging", which reads
/// as a bug rather than as partial translation. The list of chip keys the
/// backend can emit is the web team's to send; when it arrives this becomes a
/// strings-only change with no code touched.
class ReportLabelKeys {
  ReportLabelKeys._();

  static const type = 'rbType_';
  static const period = 'rbPeriod_';
  static const lens = 'rbLens_';
  static const format = 'rbFormat_';
}

/// One chip in the report card. [label] is the server's own display string;
/// [key] is what the composed request is built from.
@immutable
class ReportOption extends Equatable {
  const ReportOption({required this.key, required this.label});

  final String key;
  final String label;

  /// What the chip actually shows: the client translation when one exists for
  /// `<prefix><key>`, else the server's [label].
  ///
  /// The fallback is what makes this safe to ship with an empty key table — a
  /// report type the backend adds tomorrow renders its server label correctly
  /// instead of leaking `rbType_new_thing` onto the screen.
  String displayLabel(AppStrings tr, String prefix) =>
      tr.lookup('$prefix$key', fallback: label);

  /// Falls back to the key when the server sent no label, so a chip is never
  /// blank. Returns null for an entry with no key at all.
  static ReportOption? fromJson(Map<String, dynamic> json) {
    final key = _str(json['key']);
    if (key.isEmpty) return null;
    final label = _str(json['label']).trim();
    return ReportOption(key: key, label: label.isEmpty ? key : label);
  }

  @override
  List<Object?> get props => [key, label];
}

/// A lens (report angle). Carries the entity family whose records the card
/// should offer for filtering, plus the server-authored submit sentence.
@immutable
class ReportLens extends Equatable {
  const ReportLens({
    required this.key,
    required this.label,
    this.entity = '',
    this.submitEn = '',
    this.submitAr = '',
  });

  final String key;
  final String label;

  /// `customers | vendors | employees` — the families that get a secondary
  /// record multi-select. Empty for lenses that need no record filter.
  final String entity;

  /// Server-authored request text per locale. Preferred over the client's
  /// composed sentence when present: the server knows the exact phrasing the
  /// agent parses best.
  final String submitEn;
  final String submitAr;

  /// Same client-key-then-server-label rule as [ReportOption.displayLabel].
  String displayLabel(AppStrings tr) =>
      tr.lookup('${ReportLabelKeys.lens}$key', fallback: label);

  String submitFor({required bool arabic}) {
    final preferred = arabic ? submitAr : submitEn;
    if (preferred.trim().isNotEmpty) return preferred.trim();
    final other = arabic ? submitEn : submitAr;
    return other.trim();
  }

  static ReportLens? fromJson(Map<String, dynamic> json) {
    final key = _str(json['key']);
    if (key.isEmpty) return null;
    final label = _str(json['label']).trim();
    return ReportLens(
      key: key,
      label: label.isEmpty ? key : label,
      entity: _str(json['entity']),
      submitEn: _str(json['submit_en']),
      submitAr: _str(json['submit_ar']),
    );
  }

  @override
  List<Object?> get props => [key, label, entity, submitEn, submitAr];
}

@immutable
class ReportBuilderPayload extends Equatable {
  const ReportBuilderPayload({
    this.types = const [],
    this.periods = const [],
    this.formats = const [],
    this.lensesByType = const {},
    this.sharedLenses = const [],
  });

  final List<ReportOption> types;
  final List<ReportOption> periods;
  final List<ReportOption> formats;

  /// `lenses` keyed by report-type key. The web ships it as keyed groups, so
  /// picking a type narrows which lenses apply.
  final Map<String, List<ReportLens>> lensesByType;

  /// Lenses the server sent as a flat list instead of keyed groups — they
  /// apply to every type. Kept separate so a deployment that switches shapes
  /// doesn't silently lose the chips.
  final List<ReportLens> sharedLenses;

  /// Lenses to offer once [typeKey] is chosen. Shared lenses always apply.
  List<ReportLens> lensesFor(String? typeKey) => [
        ...sharedLenses,
        if (typeKey != null) ...?lensesByType[typeKey],
      ];

  /// Record families that get the secondary multi-select (Appendix A.2).
  static const entityFamilies = {'customers', 'vendors', 'employees'};

  static ReportBuilderPayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.reportBuilder) {
      return null;
    }
    final types = _options(payload!['types']);
    // A card with no type to pick can't compose a request — fall through.
    if (types.isEmpty) return null;
    final rawLenses = payload['lenses'];
    final byType = <String, List<ReportLens>>{};
    final shared = <ReportLens>[];
    if (rawLenses is Map) {
      for (final entry in rawLenses.entries) {
        final group = _lenses(entry.value);
        if (group.isNotEmpty) byType[entry.key.toString()] = group;
      }
    } else if (rawLenses is List) {
      shared.addAll(_lenses(rawLenses));
    }
    return ReportBuilderPayload(
      types: types,
      periods: _options(payload['periods']),
      formats: _options(payload['formats']),
      lensesByType: byType,
      sharedLenses: shared,
    );
  }

  static List<ReportOption> _options(Object? raw) {
    return _list(raw)
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => ReportOption.fromJson(e.cast<String, dynamic>()))
        .whereType<ReportOption>()
        .toList();
  }

  /// Accepts a group as a list of lens objects, or as a `key → lens` map —
  /// both shapes appear across deployments.
  static List<ReportLens> _lenses(Object? raw) {
    Iterable<Map<String, dynamic>> maps;
    if (raw is List) {
      maps = raw.whereType<Map<dynamic, dynamic>>().map((e) => e.cast<String, dynamic>());
    } else if (raw is Map) {
      maps = raw.entries
          .where((e) => e.value is Map)
          .map((e) => {
                'key': e.key.toString(),
                ...(e.value as Map).cast<String, dynamic>(),
              });
    } else {
      return const [];
    }
    return maps.map(ReportLens.fromJson).whereType<ReportLens>().toList();
  }

  @override
  List<Object?> get props =>
      [types, periods, formats, lensesByType, sharedLenses];
}

/// One record from `GET /api/v1/report-entities/`.
@immutable
class ReportEntity extends Equatable {
  const ReportEntity({required this.id, required this.name});

  final String id;
  final String name;

  static ReportEntity? fromJson(Map<String, dynamic> json) {
    final id = _str(json['id']);
    final name = _str(json['name']).trim();
    // Both are load-bearing: the id is what gets sent back, the name is the
    // only thing the user can recognise the record by.
    if (id.isEmpty || name.isEmpty) return null;
    return ReportEntity(id: id, name: name);
  }

  @override
  List<Object?> get props => [id, name];
}

/// Parsed body of `GET /api/v1/report-entities/`.
@immutable
class ReportEntityPage extends Equatable {
  const ReportEntityPage({this.items = const [], this.truncated = false});

  final List<ReportEntity> items;

  /// `true` when more records exist than were returned (server caps at 1000).
  /// The card shows a "narrow it with search" hint rather than pretending the
  /// list is complete.
  final bool truncated;

  factory ReportEntityPage.fromJson(Map<String, dynamic> json) {
    return ReportEntityPage(
      items: _list(json['items'])
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => ReportEntity.fromJson(e.cast<String, dynamic>()))
          .whereType<ReportEntity>()
          .toList(),
      truncated: _bool(json['truncated']),
    );
  }

  @override
  List<Object?> get props => [items, truncated];
}
