/// Static URLs / paths the mobile client talks to.
///
/// `baseUrl` is read from `--dart-define=SAQQAR_BASE_URL=...` at build time
/// (see `tool/run_dev.ps1` — defaults to production saqqaar.com if unset).
///
/// All paths are pinned to `/api/v1/` per SAQQAR_MOBILE_API.md §0
/// (Versioning). `/api/` still works (back-compat) but `/api/v2/` will be
/// the first to break the v1 contract, so pinning protects us.
class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = String.fromEnvironment(
    'SAQQAR_BASE_URL',
    defaultValue: 'https://saqqaar.com',
  );

  // ── Auth (§1) ─────────────────────────────────────────────────────────
  static const String login = '/api/v1/auth/login/';
  static const String register = '/api/v1/auth/register/';
  static const String logout = '/api/v1/auth/logout/';
  static const String me = '/api/v1/auth/me/';

  // ── Social sign-in (docs/MOBILE_AUTH_GUIDE.md) ───────────────────────
  // Exchange a provider ID token for a Saqqar bearer token. Same response
  // shape as login/register (`{ ok, token, user, created }`). Auto-links to
  // an existing account by verified email.
  /// `POST /api/v1/auth/google/ { id_token }`
  static const String authGoogle = '/api/v1/auth/google/';

  /// `POST /api/v1/auth/web-session/ { next }` → `{ ok, url }`
  ///
  /// One-time login hand-off: exchanges the app's bearer for a short-lived
  /// URL that signs the **browser** in and redirects to `next`. Used before
  /// sending the user to the web checkout so they don't arrive anonymous and
  /// risk signing up a second time on a different provider.
  ///
  /// **Not built yet** — requested in `docs/MOBILE_BACKEND_OPEN_ITEMS.md`
  /// §3.5, currently 404. [WebCheckout] treats any non-200 as "not available"
  /// and falls back to the plain pricing URL, so this starts working the day
  /// the endpoint ships without an app release.
  static const String authWebSession = '/api/v1/auth/web-session/';

  /// `POST /api/v1/auth/apple/ { id_token, user? }` — `user` (name) only on
  /// the first Apple sign-in.
  static const String authApple = '/api/v1/auth/apple/';

  /// Rotates the password and returns a fresh bearer token. Every other
  /// device's token is revoked server-side.
  static const String changePassword = '/api/v1/auth/password/';

  /// `DELETE | POST /api/v1/account/delete/` — irreversibly deletes the
  /// account and all its data. App/Play Store policy requires an in-app
  /// account-deletion path; this is it. Revokes the token server-side.
  static const String accountDelete = '/api/v1/account/delete/';

  // ── Email-OTP auth (Gap D / API_MOBILE_AUTH.md) ──────────────────────
  // Stateless OTP flows designed for mobile. NOTE: these live under the
  // unversioned `/api/auth/` namespace per the binding spec (distinct from
  // the `/api/v1/auth/` session endpoints above). If the backend serves
  // them under `/api/v1/auth/…` instead, flip the prefix here in one place.
  static const String signupStart = '/api/auth/signup/start/';
  static const String signupVerify = '/api/auth/signup/verify/';
  static const String signupResend = '/api/auth/signup/resend/';
  static const String signupComplete = '/api/auth/signup/complete/';

  static const String loginEmailStart = '/api/auth/login/email/start/';
  static const String loginEmailVerify = '/api/auth/login/email/verify/';
  static const String loginEmailResend = '/api/auth/login/email/resend/';

  static const String passwordResetStart = '/api/auth/password/reset/start/';
  static const String passwordResetVerify = '/api/auth/password/reset/verify/';
  static const String passwordResetResend = '/api/auth/password/reset/resend/';
  static const String passwordResetComplete =
      '/api/auth/password/reset/complete/';

  // ── Conversations (§2) ────────────────────────────────────────────────
  static const String conversations = '/api/v1/conversations/';
  static String conversationDetail(String id) =>
      '/api/v1/conversations/$id/';
  static String conversationMessages(String id) =>
      '/api/v1/conversations/$id/messages/';
  static String conversationAttachments(String id) =>
      '/api/v1/conversations/$id/attachments/';
  static String conversationAttachmentStatus(
    String conversationId,
    String attachmentId,
  ) =>
      '/api/v1/conversations/$conversationId/attachments/$attachmentId/status/';

  static String conversationCredentialsActive(String id) =>
      '/api/v1/conversations/$id/credentials/active/';
  static String conversationCredentialsToggle(String id) =>
      '/api/v1/conversations/$id/credentials/toggle/';
  static String conversationDismiss(String id) =>
      '/api/v1/conversations/$id/pending-actions/dismiss/';

  /// Cooperative cancel — sets `stop_requested=true`; the agent worker
  /// exits cleanly between tool rounds. Idempotent.
  static String conversationStop(String id) =>
      '/api/v1/conversations/$id/stop/';

  /// Restarts a run that stopped without finishing and without anything
  /// waiting on the user (`conversation.needs_resume == true`). Returns a
  /// full snapshot, merged the same way a poll response is. The server owns
  /// the retry rate limit — no client-side counter.
  static String conversationResume(String id) =>
      '/api/v1/conversations/$id/resume/';

  static String conversationShare(String id) =>
      '/api/v1/conversations/$id/share/';

  // ── Credentials (§7) ─────────────────────────────────────────────────
  static const String credentials = '/api/v1/credentials/';
  static const String credentialSchemas = '/api/v1/credentials/schemas/';
  static String credentialDetail(String name) =>
      '/api/v1/credentials/$name/';

  /// `POST /api/v1/credentials/test/` — validates a candidate payload
  /// without storing it. Opens a real connection to the target service
  /// (XML-RPC, Postgres, GitHub, etc.). Used by the editor's "Test
  /// connection" button. See SAQQAR_MOBILE_API_xmlrpc.md §2.
  static const String credentialTest = '/api/v1/credentials/test/';

  /// `POST /api/v1/credentials/databases/` — lists the Odoo databases
  /// reachable at a given URL (`{url}` → `{databases:[…], method}`). Powers
  /// the xmlrpc credential form's database picker so the user selects from
  /// a real list instead of typing the db name blind.
  static const String credentialDatabases = '/api/v1/credentials/databases/';

  // ── Projects & Environments (§11) ────────────────────────────────────
  static const String projects = '/api/v1/projects/';

  /// `POST /api/v1/projects/default/` (Gap H) — ensures the caller has a
  /// default project + production environment and returns that env (plus a
  /// `has_credential` flag). Powers the chat "Use My Database" one-click.
  static const String projectsDefault = '/api/v1/projects/default/';
  static String projectDetail(String id) => '/api/v1/projects/$id/';
  static String projectEnvironments(String projectId) =>
      '/api/v1/projects/$projectId/environments/';
  static String environmentDetail(String id) =>
      '/api/v1/environments/$id/';
  static String environmentCredentials(String environmentId) =>
      '/api/v1/environments/$environmentId/credentials/';
  static String environmentCredential(String environmentId, String kind) =>
      '/api/v1/environments/$environmentId/credentials/$kind/';

  // ── Approvals (§8) ───────────────────────────────────────────────────
  /// Flat feed for the Inbox tab. `?status=pending` is the primary call;
  /// response includes `pending_count` for the bottom-nav badge.
  static const String approvals = '/api/v1/approvals/';
  static String approvalDecision(String id) =>
      '/api/v1/approvals/$id/decision/';

  // ── Plans / pricing (Gap L) — public, no bearer required ─────────────
  // Anonymous callers can browse pricing. When a bearer IS sent, the
  // response marks the caller's tier via `current_plan`.
  static const String plans = '/api/v1/plans/';

  // ── Usage (§9) ───────────────────────────────────────────────────────
  /// `GET /api/v1/usage/` — token usage + caps for day / week / month plus
  /// the current plan. Lets the Account screen show usage WITHOUT opening a
  /// conversation (the snapshot-derived plan only lands once a chat polls).
  static const String usage = '/api/v1/usage/';

  // ── Saqqar Odoo tools (§6) — documented by the web team 2026-08-06 ────
  //
  // Each POST runs a READ-ONLY scan against the conversation's bound Odoo
  // credential and posts its report into the conversation as an assistant
  // message, so the ordinary poll surfaces the result. `400` when no
  // environment / XML-RPC credential is bound, `502` when Odoo is
  // unreachable — both with a human `error` string.
  //
  // A 2026-08-05 probe guessed `health-radar` / `what-if` / `business-pulse`
  // and got 404s. The routes were real all along under these names; the
  // probe was sound, the guesses were not.
  static const String radarRun = '/api/v1/radar/run/';
  static const String pulseRun = '/api/v1/pulse/run/';

  /// Posts a "describe your scenario" primer. The user then types the
  /// scenario in plain language and the agent's `simulate_what_if` tool runs
  /// it — which is why mobile does not call [whatIfRun] directly (it needs a
  /// `scenario` enum + `percent` the user never chose in a form).
  static const String whatIfIntro = '/api/v1/whatif/intro/';
  static const String whatIfRun = '/api/v1/whatif/run/';

  /// `GET /api/v1/prompt-memory/` — the saved-task catalogue behind "Task
  /// wording", already `/api/v1/` on the web (it is the one route both
  /// clients call by the same path).
  ///
  /// Query: `limit`, `lang`, optional `q` (the rough task) and
  /// `conversation_id`. Returns `{prompts: [...], draft: {...}|null,
  /// total_saved}` — `prompts` are the user's own past tasks and `draft` is
  /// the structured rewrite of `q`.
  static const String promptMemory = '/api/v1/prompt-memory/';

  // ── Voice support (§8) ───────────────────────────────────────────────
  //
  // NOT telephony. A self-service support workspace: describe a problem in
  // text, an LLM drafts a structured diagnosis plus a reply, and the user can
  // optionally file it as a real Odoo `helpdesk.ticket`.
  static const String voiceSupportDraft = '/api/v1/voice-support/draft/';
  static const String voiceSupportTicket = '/api/v1/voice-support/ticket/';

  // ── Artifacts (§9) ───────────────────────────────────────────────────
  static const String artifacts = '/api/v1/artifacts/';

  // ── Shares (§10) — public, no bearer ─────────────────────────────────
  static String shareTranscript(String token) => '/api/v1/shares/$token/';

  // ── i18n (§13) — public, no bearer ───────────────────────────────────
  static String i18n(String lang) => '/api/v1/i18n/$lang.json';

  // ── Voice transcription (SAQQAR_MOBILE_VOICE.md §2) ─────────────────
  // Multipart upload: field `audio` (m4a recommended, ≤25 MB, ≤120 s),
  // optional `language` ("ar"/"en"/""). Server proxies to OpenAI
  // Whisper and returns `{ ok: true, text: "..." }`.
  static const String transcribe = '/api/v1/transcribe/';

  // ── Devices / push (§12) ─────────────────────────────────────────────
  static const String devices = '/api/v1/devices/';
  static String deviceDetail(String id) => '/api/v1/devices/$id/';

  // ── Health (§10) — public, no bearer ─────────────────────────────────
  /// `GET /api/v1/health/` — liveness/version probe → `{ ok, service, time,
  /// api }`. Useful as a connectivity pre-flight before the splash hands
  /// off to the auth gate.
  static const String health = '/api/v1/health/';

  // ── App version / update gate ────────────────────────────────────────
  /// `GET /api/v1/app/version/?platform=android|ios` → public, no bearer.
  ///
  /// ```json
  /// { "ok": true,
  ///   "min_supported_build": 110,   // below this the app must not be used
  ///   "latest_build": 118,          // newest build live on that store
  ///   "latest_version": "1.2.5",
  ///   "store_url": "https://play.google.com/store/apps/details?id=…" }
  /// ```
  ///
  /// `platform` is required because the two stores run independently — a
  /// build sitting in Apple review is not yet installable by an Android
  /// user, and gating both off one number would either under- or
  /// over-block one of them.
  ///
  /// **Not built yet** — same treatment as [authWebSession]: `AppUpdateApi`
  /// reads any non-200, and any body it cannot parse, as "the server has no
  /// opinion", so the gate stays completely inert until the endpoint ships.
  /// No app release is needed to switch it on.
  static const String appVersion = '/api/v1/app/version/';

  // ── Saqqar Apps (API_MOBILE_NEW_ENDPOINTS.md §1) ─────────────────────
  /// `GET /api/v1/apps/` — the guided implementation packages (ZATCA,
  /// WhatsApp, Chart of Accounts …). Each tile launches a package-tagged
  /// conversation; there is no per-app backend, the agent drives the task.
  static const String apps = '/api/v1/apps/';

  /// `POST /api/v1/apps/<slug>/launch/ { environment_id? }` — creates a
  /// package-tagged conversation seeded with the agent's opening turn and
  /// returns its `conversation_id`. Open that conversation to start.
  static String appLaunch(String slug) => '/api/v1/apps/$slug/launch/';

  // ── Managed Odoo Trial (API_MOBILE_NEW_ENDPOINTS.md §2) ──────────────
  /// `POST /api/v1/trial/ { company_name, … }` — request a hosted trial
  /// Odoo. Idempotent: one trial per user (a second call returns the
  /// existing one).
  static const String trial = '/api/v1/trial/';

  /// `GET /api/v1/trial/status/` — poll provisioning (also kicks it off on
  /// the first call). When `ready`, the body carries live admin credentials
  /// — treat them as a secret.
  static const String trialStatus = '/api/v1/trial/status/';

  // ── Billing history & receipts (API_MOBILE_NEW_ENDPOINTS.md §3) ──────
  /// `GET /api/v1/billing/history/` — the caller's own payments + balances.
  /// Read-only, so store-policy-safe (unlike checkout, which we don't wire).
  static const String billingHistory = '/api/v1/billing/history/';

  /// `GET /api/v1/billing/receipt/<ref>/` — a PDF receipt for a PAID row.
  /// Strictly scoped to the caller; a foreign/unpaid ref returns 404.
  static String billingReceipt(String receiptRef) =>
      '/api/v1/billing/receipt/$receiptRef/';

  // ── Paymob checkout — deliberately absent ────────────────────────────
  // `/billing/plans/`, `/billing/checkout/` and `/billing/payment/<ref>/status/`
  // exist on the server and are NOT declared here on purpose. Payment happens
  // on saqqaar.com; the app never creates an order, never holds a payment
  // reference and never tracks a payment state machine. It opens
  // `/pricing/` (see WebCheckout) and re-reads `/usage/` + `/plans/` on
  // resume — the server is the only thing that says what a user is on.
  //
  // Adding one back would also put a purchase surface in a store binary,
  // which is the thing App Store 3.1.1 and the Play Payments policy forbid.

  // ── Artifact detail (API_MOBILE_NEW_ENDPOINTS.md §4.4) ───────────────
  /// `GET /api/v1/artifacts/<id>/` — one artifact's detail/metadata.
  static String artifactDetail(String id) => '/api/v1/artifacts/$id/';

  // ── Meetings · Vexa transcription (API_MOBILE_NEW_ENDPOINTS.md §4.1) ──
  // Data layer only for now — no UI surface yet. Paths pinned here so the
  // MeetingsApi client has one source of truth.
  static const String meetings = '/api/v1/meetings/';
  static String meetingTranscript(String id) =>
      '/api/v1/meetings/$id/transcript';
  static String meetingStop(String id) => '/api/v1/meetings/$id/stop';
  static String meetingSummarize(String id) => '/api/v1/meetings/$id/summarize';
  static String meetingChat(String id) => '/api/v1/meetings/$id/chat';

  // ── Direct data API · read-only Odoo (API_MOBILE_NEW_ENDPOINTS.md §4.2) ─
  // Deterministic reads against a bound environment — cheaper than an agent
  // turn (no LLM cost). Data layer only for now.
  static String odooSearch(String envId) =>
      '/api/v1/environments/$envId/odoo/search/';
  static String odooCount(String envId) =>
      '/api/v1/environments/$envId/odoo/count/';
  static String odooReadGroup(String envId) =>
      '/api/v1/environments/$envId/odoo/read-group/';
  static String odooRead(String envId) =>
      '/api/v1/environments/$envId/odoo/read/';
  static String odooFields(String envId) =>
      '/api/v1/environments/$envId/odoo/fields/';
  static String envSql(String envId) => '/api/v1/environments/$envId/sql/';
  static const String reportEntities = '/api/v1/report-entities/';
}
