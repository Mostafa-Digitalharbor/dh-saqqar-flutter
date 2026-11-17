part of 'app_pulse_payloads.dart';

/// One of inventory's six uniform buckets — `available`/`count`/`items`, plus
/// an optional `total`. The doc gives this envelope but not the shape of
/// `items` inside it, so [items] stays a raw JSON list; [PulseRawItemsList]
/// (`app_pulse/pulse_raw_items.dart`) renders it generically until a kind's
/// item shape is confirmed against a live payload and gets its own typed row.
@immutable
class PulseBucket extends Equatable {
  const PulseBucket({
    required this.available,
    this.count,
    this.items = const [],
    this.total,
  });

  /// `false` means "this database can't answer" (rule 1) — render
  /// unavailable, never as a zero-count bucket.
  final bool available;
  final int? count;
  final List<Object?> items;
  final double? total;

  static PulseBucket fromJson(Object? raw) {
    // A bare number is a bucket the server chose to send as just its count
    // (the accountant's five checks do this). Reading it as unavailable
    // would turn a real answer into "this database can't answer".
    if (raw is num) {
      return PulseBucket(available: true, count: raw.toInt());
    }
    if (raw is! Map) return const PulseBucket(available: false);
    final json = raw.cast<String, dynamic>();
    return PulseBucket(
      // Missing `available` reads as available — every field on the bucket
      // is then read as absent-means-zero-ish rather than unavailable,
      // matching a server that predates the flag.
      available: json.containsKey('available')
          ? _bool(json['available'])
          : true,
      count: _int(json['count']),
      items: _list(json['items']),
      total: _double(json['total']),
    );
  }

  @override
  List<Object?> get props => [available, count, items, total];
}

@immutable
class InventoryPulsePayload extends Equatable {
  const InventoryPulsePayload({
    required this.envelope,
    this.salesDays,
    this.productCount,
    required this.inventoryValue,
    required this.lowStock,
    required this.demandShortage,
    required this.stagnantStock,
    required this.overstock,
    required this.fastReorder,
    required this.missingData,
    this.missingDataReasons,
    this.priorities = const [],
  });

  final PulseEnvelope envelope;
  final int? salesDays;
  final int? productCount;
  final PulseBucket inventoryValue;
  final PulseBucket lowStock;
  final PulseBucket demandShortage;
  final PulseBucket stagnantStock;
  final PulseBucket overstock;
  final PulseBucket fastReorder;
  final PulseBucket missingData;

  /// `missing_data.counts` — the reason breakdown behind the missing-data
  /// count (`{no_cost: 8, no_lead_time: 14}`). The doc shows the key with an
  /// empty object, so the reason names are the server's own and are shown
  /// de-underscored rather than translated, exactly like a band label.
  /// Null when the payload carried no `counts` at all.
  final PulseBands? missingDataReasons;

  /// Already in Arabic, same as `envelope.notes` — see rule 4.
  final List<String> priorities;

  static InventoryPulsePayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.inventory) {
      return null;
    }
    final missingData = _map(payload!['missing_data']);
    return InventoryPulsePayload(
      envelope: PulseEnvelope.fromJson(payload),
      salesDays: _int(payload['sales_days']),
      productCount: _int(payload['product_count']),
      inventoryValue: PulseBucket.fromJson(payload['inventory_value']),
      lowStock: PulseBucket.fromJson(payload['low_stock']),
      demandShortage: PulseBucket.fromJson(payload['demand_shortage']),
      stagnantStock: PulseBucket.fromJson(payload['stagnant_stock']),
      overstock: PulseBucket.fromJson(payload['overstock']),
      fastReorder: PulseBucket.fromJson(payload['fast_reorder']),
      missingData: PulseBucket.fromJson(payload['missing_data']),
      missingDataReasons: missingData.containsKey('counts')
          ? PulseBands.fromJson(missingData['counts'])
          : null,
      priorities: _list(
        payload['priorities'],
      ).map(_str).where((s) => s.isNotEmpty).toList(),
    );
  }

  @override
  List<Object?> get props => [
    envelope,
    salesDays,
    productCount,
    inventoryValue,
    lowStock,
    demandShortage,
    stagnantStock,
    overstock,
    fastReorder,
    missingData,
    missingDataReasons,
    priorities,
  ];
}
