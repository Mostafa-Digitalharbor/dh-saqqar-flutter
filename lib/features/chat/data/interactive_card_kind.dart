/// The `tool_payload.kind` values the chat stream can carry, and the lookup
/// both card families key on.
///
/// Split out of `interactive_cards.dart` (which re-exports this file, so
/// existing imports of it are unaffected) purely to avoid a circular import:
/// `interactive_cards.dart` and `app_pulse_payloads.dart` are two independent
/// card families that both need the enum and neither owns it.
enum InteractiveCardKind {
  // "Compose the next message" cards — parsed in `interactive_cards.dart`,
  // rendered by the widgets under `widgets/`.
  promptClarify('prompt_clarify'),
  reportBuilder('report_builder'),
  promptSuggestion('prompt_suggestion'),
  // Read-only guided-app "pulse" dashboards (Task 1, MOBILE_TASKS_2026-09.md)
  // — parsed in `app_pulse_payloads.dart`, rendered by `widgets/app_pulse/`.
  // None of these compose a follow-up message, so none needs an
  // `onSend`/`onSeed` callback.
  factory('factory'),
  inventory('inventory'),
  finance('finance'),
  purchasing('purchasing'),
  qualityGuard('quality_guard'),
  accountant('accountant'),
  hr('hr');

  const InteractiveCardKind(this.wire);
  final String wire;

  static InteractiveCardKind? fromWire(Object? value) {
    if (value is! String || value.isEmpty) return null;
    for (final k in InteractiveCardKind.values) {
      if (k.wire == value) return k;
    }
    return null;
  }
}

/// The `kind` of an interactive card carried by [payload], or null when the
/// payload is absent / carries no recognised kind.
InteractiveCardKind? interactiveCardKind(Map<String, dynamic>? payload) =>
    payload == null ? null : InteractiveCardKind.fromWire(payload['kind']);
