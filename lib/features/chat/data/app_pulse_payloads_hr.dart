part of 'app_pulse_payloads.dart';

/// One flagged employee from `operations.items` — a reason already written
/// in Arabic by the server (rule 4), never re-translated.
@immutable
class HrOperationItem extends Equatable {
  const HrOperationItem({
    required this.employee,
    this.reason = '',
    this.type = '',
  });

  final String employee;
  final String reason;
  final String type;

  static HrOperationItem? fromJson(Map<String, dynamic> json) {
    final employee = _str(json['employee']);
    if (employee.isEmpty) return null;
    return HrOperationItem(
      employee: employee,
      reason: _str(json['reason']),
      type: _str(json['type']),
    );
  }

  @override
  List<Object?> get props => [employee, reason, type];
}

@immutable
class HrOperations extends Equatable {
  const HrOperations({
    required this.available,
    this.activeEmployees,
    this.missingManagers,
    this.missingWorkEmail,
    this.items = const [],
  });

  final bool available;
  final int? activeEmployees;
  final int? missingManagers;
  final int? missingWorkEmail;
  final List<HrOperationItem> items;

  static HrOperations fromJson(Object? raw) {
    if (raw is! Map) return const HrOperations(available: false);
    final json = raw.cast<String, dynamic>();
    return HrOperations(
      available: json.containsKey('available')
          ? _bool(json['available'])
          : true,
      activeEmployees: _int(json['active_employees']),
      missingManagers: _int(json['missing_managers']),
      missingWorkEmail: _int(json['missing_work_email']),
      items: _list(json['items'])
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => HrOperationItem.fromJson(e.cast<String, dynamic>()))
          .whereType<HrOperationItem>()
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    available,
    activeEmployees,
    missingManagers,
    missingWorkEmail,
    items,
  ];
}

/// "Recruitment Manager" pulse — applicants, employee/contract hygiene,
/// payroll and time-off readiness, computed from Odoo.
///
/// `counters` is the server's own pre-summarized "what needs a look, and
/// what to do about it" list — already labelled and captioned in the
/// screen's working language — so it carries the headline numbers for
/// recruitment, payroll and time-off without this parser inventing its own
/// tile labels for them. [operations] is kept as its own field only because
/// it names WHO is flagged, which `counters` cannot.
///
/// [recruitment], [payroll] and [timeOff] are the doc's other three
/// top-level keys. Their inner shape is undocumented, so each is read as the
/// same uniform `{available, count, items}` bucket the inventory kind uses:
/// a server that sends that shape gets a real tile and a real list, and one
/// that sends something else gets a section with nothing in it rather than a
/// fabricated number. Null means the key was absent entirely.
@immutable
class HrPulsePayload extends Equatable {
  const HrPulsePayload({
    required this.envelope,
    this.windowDays,
    this.counters = const [],
    required this.operations,
    this.recruitment,
    this.payroll,
    this.timeOff,
  });

  final PulseEnvelope envelope;
  final int? windowDays;
  final List<PulseCounter> counters;
  final HrOperations operations;
  final PulseBucket? recruitment;
  final PulseBucket? payroll;
  final PulseBucket? timeOff;

  static HrPulsePayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.hr) return null;
    PulseBucket? section(String key) =>
        payload!.containsKey(key) ? PulseBucket.fromJson(payload[key]) : null;
    return HrPulsePayload(
      envelope: PulseEnvelope.fromJson(payload!),
      windowDays: _int(payload['window_days']),
      counters: _counters(payload['counters']),
      operations: HrOperations.fromJson(payload['operations']),
      recruitment: section('recruitment'),
      payroll: section('payroll'),
      timeOff: section('time_off'),
    );
  }

  @override
  List<Object?> get props => [
    envelope,
    windowDays,
    counters,
    operations,
    recruitment,
    payroll,
    timeOff,
  ];
}
