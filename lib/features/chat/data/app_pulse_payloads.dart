import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'interactive_card_kind.dart'
    show interactiveCardKind, InteractiveCardKind;
import '../../../core/format/wire_value.dart';

part 'app_pulse_payloads_factory.dart';
part 'app_pulse_payloads_inventory.dart';
part 'app_pulse_payloads_finance.dart';
part 'app_pulse_payloads_purchasing.dart';
part 'app_pulse_payloads_hr.dart';
part 'app_pulse_payloads_accountant.dart';

/// Parsed payloads for the seven guided-app "pulse" cards (Task 1,
/// MOBILE_TASKS_2026-09.md) — a read-only dashboard rendered from
/// `tool_payload` on the final assistant message of a turn, exactly like the
/// interactive cards in `interactive_cards.dart`, but a different family:
/// nothing here composes a follow-up message, so no kind in this file needs
/// an `onSend`/`onSeed` callback.
///
/// Every parser follows the same forgiving rule as the rest of this app's
/// card payloads: a malformed or unrecognised shape returns `null` and the
/// message falls through to an ordinary text bubble, never throws. These run
/// inside `isVisibleMessage` on every poll tick, so a partial backend
/// rollout must not take a whole conversation down.
///
/// Four rules apply to every kind here, straight from the server's own
/// documented behaviour:
///  1. A bucket's `available: false` means "this database can't answer" —
///     render it as unavailable, never as a zero.
///  2. A scalar can be `null` when the underlying Odoo app isn't installed;
///     the server explains why in `notes`.
///  3. `status` can be `"error"`, with an `error` string and empty buckets —
///     render the error, not an empty card.
///  4. `notes` / `priorities` arrive already written in Arabic. Print them
///     verbatim — never through `context.tr`, never re-translated.

// Shared with every other wire parser — see `core/format/wire_value.dart`
// for why these are one implementation rather than a copy per file.
const _str = wireString;
const _list = wireList;
const _int = wireInt;
const _double = wireDouble;
const _bool = wireBool;

/// `status` on every pulse payload — `"ok"` or `"error"` per the doc; an
/// unrecognised value degrades to `ok` so a payload with real numbers is
/// never hidden behind an error screen over a wording drift.
enum PulseStatus {
  ok,
  error;

  static PulseStatus fromWire(Object? value) =>
      value == 'error' ? PulseStatus.error : PulseStatus.ok;
}

/// The one note the server sends that no card shows: a standing disclaimer
/// that the reading came from a stock Odoo install. It says nothing about
/// THIS database, and it arrives on every card of every app, so the web
/// drops it (`renderCardNotes`) and so does this.
///
/// A wire literal, not UI copy: it is matched against what the server
/// writes, never rendered, so it belongs with the parser rather than in
/// `AppStrings`. A substring match, because the sentence continues
/// differently per app.
const _boilerplateNote = 'القراءة الحالية مبنية على Standard Odoo';

/// Common envelope every pulse payload shares: `status`, `as_of`, `error`,
/// `notes`. Each typed payload below embeds one rather than extending it —
/// Dart has no multiple inheritance and these are `Equatable` value types,
/// so composition keeps `props` honest without a mixin's boilerplate.
@immutable
class PulseEnvelope extends Equatable {
  const PulseEnvelope({
    required this.status,
    this.asOf,
    this.error = '',
    this.notes = const [],
  });

  final PulseStatus status;

  /// Raw `YYYY-MM-DD` (or similar) from the server. Parsed for display by
  /// the widget, which falls back to the raw string on a format the client
  /// doesn't recognise — never hidden.
  final String? asOf;

  /// Set when [status] is [PulseStatus.error]. Server-authored, shown as-is.
  final String error;

  /// Already written in Arabic by the server — see rule 4 above.
  final List<String> notes;

  factory PulseEnvelope.fromJson(Map<String, dynamic> json) => PulseEnvelope(
    status: PulseStatus.fromWire(json['status']),
    asOf: _str(json['as_of']).isEmpty ? null : _str(json['as_of']),
    error: _str(json['error']),
    notes: _list(json['notes'])
        .map(_str)
        .where((s) => s.isNotEmpty && !s.contains(_boilerplateNote))
        .toList(),
  );

  @override
  List<Object?> get props => [status, asOf, error, notes];
}

const _map = wireMap;

/// One row of the accountant's and HR's shared `counters` list: a label, the
/// count that earned it a place on the list, and the server's own suggested
/// next step — all already written in the screen's working language by the
/// server. Rendered verbatim (rule 4), never through `context.tr`, which is
/// exactly why this card needs almost no new translation keys of its own.
@immutable
class PulseCounter extends Equatable {
  const PulseCounter({
    required this.key,
    required this.label,
    this.value,
    this.action = '',
  });

  final String key;
  final String label;
  final int? value;
  final String action;

  static PulseCounter? fromJson(Map<String, dynamic> json) {
    final label = _str(json['label']);
    if (label.isEmpty) return null;
    return PulseCounter(
      key: _str(json['key']),
      label: label,
      value: _int(json['value']),
      action: _str(json['action']),
    );
  }

  @override
  List<Object?> get props => [key, label, value, action];
}

List<PulseCounter> _counters(Object? raw) => _list(raw)
    .whereType<Map<dynamic, dynamic>>()
    .map((e) => PulseCounter.fromJson(e.cast<String, dynamic>()))
    .whereType<PulseCounter>()
    .toList();

// ─────────────────────────────────────────────────────────────────────────
// finance
// ─────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────
// purchasing
// ─────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────
// hr (Recruitment Manager)
// ─────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────
// accountant
// ─────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────
// quality_guard
// ─────────────────────────────────────────────────────────────────────────
