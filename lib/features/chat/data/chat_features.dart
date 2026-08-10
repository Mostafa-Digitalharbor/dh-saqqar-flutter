import '../../billing/data/plan_models.dart';
import '../../billing/data/saqqar_features.dart';

/// Chat-surface feature gates.
///
/// Reads TWO independent sources, because the backend keeps them apart on
/// purpose (web team response, 2026-08-06 §0):
///
///   * [_saqqar] — `saqqar_features` from `GET /api/v1/usage/`. Per-user
///     availability, admin-toggled, mostly staff-only during rollout. This is
///     what gates the tools rows.
///   * [_plan] — `plan.features`, the billing entitlement set. Only consulted
///     for `exempt`, which bypasses caps and gates for staff.
///
/// An earlier version of this file read the tools flags off `plan.features`
/// and assumed they would appear there "with no client release". They did
/// not: they ship as a distinct top-level object, under `task_prep` rather
/// than `task_prep_available`. Reading the wrong bag meant every flag came
/// back absent, which the optimistic defaults then rendered as "show
/// everything" — the exact dead rows the gating exists to prevent.
///
/// Each gate answers a THREE-state question — on, off, or not yet known —
/// and picks its own default for the third:
///
///   * A control the app drives on its own, that the server also gates
///     server-side, defaults to VISIBLE while unknown. Hiding it would remove
///     a working feature from every user on every cold start.
///   * A row that routes into a feature the server may refuse defaults to
///     HIDDEN while unknown. The backend confirms `health_radar`, `what_if`,
///     `business_pulse` and `voice_support` are `false` for a normal
///     non-staff account today, so an optimistic default here would show
///     three rows that answer "I can't do that" — and a row that appears then
///     vanishes one poll later is worse than one that fades in.
class ChatFeatures {
  const ChatFeatures(this._plan, [this._saqqar = SaqqarFeatures.unknown]);

  /// Null while a brand-new chat has no snapshot yet, and on older snapshots
  /// that predate the `plan` object. Used only for [PlanSnapshot.exempt].
  final PlanSnapshot? _plan;

  /// [SaqqarFeatures.unknown] until a `/usage/` fetch lands.
  final SaqqarFeatures _saqqar;

  bool get _exempt => _plan?.exempt ?? false;

  /// Visible unless the server explicitly said this account can't use it.
  bool _optimistic(String key) {
    if (_exempt) return true;
    if (!_saqqar.has(key)) return true;
    return _saqqar.enabled(key);
  }

  /// Hidden unless the server explicitly turned it on.
  bool _strict(String key) => _exempt || _saqqar.enabled(key);

  /// Task-prep toggle. Optimistic: the server re-reads `task_prep` on every
  /// send and coerces it to `false` for accounts that lack the feature, so a
  /// toggle shown to an ineligible user is inert, never broken. The backend
  /// reports it on for everyone today, so the optimistic default and the real
  /// value agree — the default only covers the pre-fetch window.
  bool get taskPrepAvailable => _optimistic(SaqqarFeatures.kTaskPrep);

  /// Prompt-bank row. Optimistic: it is driven entirely client-side (the
  /// app's own starter prompts), so there is no server call to be refused
  /// even if the flag were off.
  bool get promptBank => _optimistic(SaqqarFeatures.kPromptBank);

  /// Odoo tool rows (§6).
  ///
  /// STRICT, on the backend's own instruction: "Everything else strict
  /// (absent OR `false` ⇒ hide) is exactly right." A disabled tool is dropped
  /// from the agent's toolset, so the chat path these rows use would answer
  /// with a refusal rather than a report.
  bool get healthRadar => _strict(SaqqarFeatures.kHealthRadar);
  bool get whatIf => _strict(SaqqarFeatures.kWhatIf);
  bool get businessPulse => _strict(SaqqarFeatures.kBusinessPulse);

  /// Voice **support** workspace — NOT the composer mic. The mic is voice
  /// *input* and is gated separately by the billing `voice` entitlement.
  ///
  /// Two different flags, one confusable word: an account with the mic must
  /// not get the support row, and an account with the support row only gets
  /// spoken replies if it ALSO holds billing `voice` (the TTS endpoint 403s
  /// otherwise — see [voiceSupportTts]).
  bool get voiceSupport => _strict(SaqqarFeatures.kVoiceSupport);

  /// Whether the support workspace may speak its reply. Billing entitlement,
  /// not availability — `POST /voice-support/tts/` returns 403 on Free.
  bool get voiceSupportTts => _plan?.feature('voice') ?? false;
}
