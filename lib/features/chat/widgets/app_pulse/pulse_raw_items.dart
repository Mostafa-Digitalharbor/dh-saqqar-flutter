import 'package:flutter/material.dart';

import '../../../../core/format/compact_number.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/auto_direction_text.dart';
import 'pulse_ranked_list.dart';

/// The rows inside a pulse bucket whose item shape the server has never
/// documented — inventory's six buckets, purchasing's `vendor_delay_summary`,
/// the accountant's audit trail, HR's recruitment/payroll/time-off lists.
///
/// **Why generic rather than a typed row per kind.** The doc's own
/// instruction for these arrays is "read the live payload before you write
/// the widget", and a client that hard-codes fields it has never seen drops
/// every row the moment the server names something differently. So each row
/// is summarised from whatever it actually carries: the first field that
/// reads like a name, then up to [_maxFacts] of its remaining scalars as
/// `key: value`. A row with nothing recognisable still prints — as its own
/// JSON — because a bucket that says "12 items" and then lists eleven is a
/// worse answer than an ugly line.
///
/// The `key: value` line is the same shape [ChatApprovalCard] already uses
/// for an approval's raw payload under "Show details", including the wire
/// key going untranslated: it is the server's field name, not app copy, and
/// inventing an Arabic word for a field this client has never seen would be
/// a guess printed as fact.
class PulseRawItemsList extends StatelessWidget {
  const PulseRawItemsList({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<Object?> items;

  @override
  Widget build(BuildContext context) => PulseRankedList<Object?>(
    title: title,
    items: items,
    itemBuilder: (context, item) => _RawRow(item: item),
  );
}

/// How many `key: value` facts a row shows before it stops. Three keeps the
/// row two lines tall on a 320 px phone, which is what lets the list stay
/// scannable rather than becoming a table.
const _maxFacts = 3;

/// Fields that read as "what this row is about", most specific first.
const _nameKeys = [
  'name',
  'display_name',
  'product',
  'product_name',
  'partner',
  'partner_name',
  'vendor',
  'vendor_name',
  'customer',
  'employee',
  'order',
  'move',
  'invoice',
  'reference',
  'ref',
  'default_code',
  'code',
  'label',
  'title',
  'description',
];

/// Never worth a line: database ids the user cannot act on, and the keys
/// already consumed by the row's own name.
bool _isNoise(String key) =>
    key == 'id' || key.endsWith('_id') || key.endsWith('_ids');

/// One number as the rest of the app writes numbers: compacted past a
/// thousand, and a whole double printed without its `.0`.
String _num(num value, BuildContext context) {
  if (value is int || value == value.roundToDouble()) {
    final rounded = value.round();
    return rounded.abs() >= 1000
        ? compactCount(rounded, context.tr)
        : '$rounded';
  }
  return value.toStringAsFixed(1);
}

class _RawRow extends StatelessWidget {
  const _RawRow({required this.item});

  final Object? item;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final map = item is Map ? (item! as Map).cast<String, dynamic>() : null;
    final name = map == null ? null : _name(map);
    final allFacts = map == null
        ? const <String>[]
        : _facts(context, map, name);
    // A row with no name-ish field is led by its first fact rather than by
    // `{qty: 4}` — Dart's own map syntax is not something to show a user.
    final String title;
    final List<String> facts;
    if (name != null) {
      title = name;
      facts = allFacts;
    } else if (allFacts.isNotEmpty) {
      title = allFacts.first;
      facts = allFacts.sublist(1);
    } else {
      title = '$item';
      facts = const [];
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoDirectionText(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodyMedium?.copyWith(
            color: s.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (facts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s2),
            child: AutoDirectionText(
              facts.join('  ·  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(color: s.muted),
            ),
          ),
      ],
    );
  }

  /// What this row is about: its name field, else its first printable
  /// string, else null for a row that names nothing.
  String? _name(Map<String, dynamic> map) {
    for (final key in _nameKeys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      // Odoo many2one fields arrive as `[id, "Name"]`.
      if (value is List && value.length == 2 && value[1] is String) {
        return (value[1] as String).trim();
      }
    }
    for (final entry in map.entries) {
      if (_isNoise(entry.key)) continue;
      final value = entry.value;
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  /// Up to [_maxFacts] `key: value` pairs from the row's remaining scalars,
  /// numbers first — a shortage row's quantity matters more than its state.
  List<String> _facts(
    BuildContext context,
    Map<String, dynamic> map,
    String? headline,
  ) {
    final numbers = <String>[];
    final rest = <String>[];
    for (final entry in map.entries) {
      if (_isNoise(entry.key)) continue;
      final value = entry.value;
      if (value == null) continue;
      if (value is num) {
        numbers.add(context.tr.keyValue(entry.key, _num(value, context)));
      } else if (value is bool) {
        rest.add(context.tr.keyValue(entry.key, value));
      } else if (value is String) {
        final text = value.trim();
        if (text.isEmpty || text == headline) continue;
        rest.add(context.tr.keyValue(entry.key, text));
      }
    }
    return [...numbers, ...rest].take(_maxFacts).toList();
  }
}
