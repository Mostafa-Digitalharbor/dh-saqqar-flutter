# Web response to `WEB_UI_PARITY_MOBILE_RESPONSE.md`

**To:** Mobile (`dh-saqqar-flutter`)
**From:** Web team (`saqqar_ui`)
**Date:** 2026-08-06
**Re:** Answers to everything you asked, plus the one backend change you were
blocked on — **now built** and shipping in the next web deploy.

You are **not blocked on §6 or §8** — both already exist on the backend; they
were just undocumented to you. Everything you need is spelled out below with
real endpoint paths, request/response JSON, and exact key names, since you
can't read the backend source.

> **How to read this doc:** every path is under the same host/`baseUrl` you
> already use, and every endpoint uses your existing Bearer auth. Where a
> request needs a conversation, it's the same `conversation_id` (UUID) you
> already hold.

---

## 0. The one thing we built for you — Saqqar feature flags in JSON (your §1)

You noted the six flags (`task_prep`, `prompt_bank`, `health_radar`, `what_if`,
`business_pulse`, `voice_support`) were HTML-template-only. **They now ship in
the JSON API.**

### Where to read them

`GET /api/v1/usage/` — the same endpoint your `UsageApi.fetch()` already calls.
We added a **top-level** object `saqqar_features`:

```jsonc
// GET /api/v1/usage/  →  200
{
  "ok": true,
  "plan": "free",
  "plan_name": "Free",
  "status": "active",
  "cycle": null,
  "expires_at": null,
  "saqqar_features": {          // ← NEW. {feature_key: bool}, per-user availability
    "voice_support": false,
    "task_prep": true,
    "prompt_bank": true,
    "business_pulse": false,
    "health_radar": false,
    "what_if": false,
    "collection_note": false,
    "version_awareness": false,
    "module_management": false,
    "report_builder": false
  },
  "windows": {                  // ← the usage snapshot (unchanged)
    "plan": "free", "plan_name": "Free", "exempt": false,
    "token_balance": 0,
    "day":  { "used": 0, "cap": 0, "pct": 0, "remaining": 0 },
    "week": { "used": 0, "cap": 0, "pct": 0, "remaining": 0 },
    "month":{ "used": 0, "cap": 0, "pct": 0, "remaining": 0 },
    "features": {               // ← BILLING entitlements — a DIFFERENT thing (see below)
      "voice": false, "postgres": false, "github": false, "server_shell": false
    }
  }
}
```

### Two things to get right (important)

1. **`saqqar_features` is NOT `plan.features`.** Your `PlanFeatures` reads the
   billing-entitlement object (`voice`/`postgres`/`github`/`server_shell`) —
   those gate *paid capabilities* by plan tier. The Saqqar flags are a
   **separate, admin-toggle set** that gate *which features are switched on for
   this user*. Read them from the new top-level `saqqar_features`, not from
   `PlanFeatures`. (If your generic bag assumed new keys would appear under
   `features`, that assumption doesn't hold — they're deliberately a distinct
   object so billing vs. feature-availability never collide.)

2. **Heads-up on a pre-existing mismatch in your `UsageApi.fetch()`:** it reads
   `body['features']` and `body['exempt']` at the **top level**, but on the wire
   those live **inside `windows`** (`body['windows']['features']`,
   `body['windows']['exempt']`). So today those two resolve to `null` on your
   side (→ all billing features read `false`, `exempt` reads `false`). Not
   caused by our change — but while you're wiring `saqqar_features`, fix those
   two reads to point at `windows.*`. We left the existing keys where they are
   to avoid breaking the web client; tell us if you'd rather we *also* mirror
   `features`/`exempt` to the top level and we'll add them (purely additive).

### Semantics of each flag

- **`true`** ⇒ feature is on for this user → show its UI.
- **`false`** ⇒ disabled globally, or staff-only and this user isn't staff →
  **hide the row/affordance.**
- The **server enforces every flag regardless** of what you render (a disabled
  tool is dropped from the agent's toolset and a direct call is refused), so a
  stale client can never *use* a disabled feature — it can only show a dead row.
  Hiding on `false` is purely cosmetic correctness.

> **Current production reality:** as the sample above shows, for a regular
> (non-staff) user most of these are `false` right now — `business_pulse`,
> `health_radar`, `what_if`, `voice_support`, `report_builder`, etc. are
> **staff-only** in the flag table during rollout. `task_prep` and
> `prompt_bank` are on for everyone. So on a normal account you should expect to
> **hide** most of these rows today; they'll flip on for everyone when we clear
> the staff-only flag — **no mobile release needed**, since you're reading them
> live.

Your gating rules map cleanly: keep `task_prep` **optimistic** if you like
(absent ⇒ show), but note it's now always present so the value is authoritative.
Everything else **strict** (absent OR `false` ⇒ hide) is exactly right.

---

## 1. §6 — Health Radar / Business Pulse / What-If (you were "blocked")

Not blocked. There are **real dedicated endpoints**, and the *same* features
also run through normal chat (type a question → the agent invokes the tool).
Use whichever fits your UI — a deterministic button (endpoints below) or just
let the user ask in chat.

**All four require the conversation to have a bound Odoo XML-RPC credential**
(same binding the chat uses). With none bound they return `400` (no env / no
XML-RPC creds) or `502` (couldn't connect) with an Arabic `error` string.

**"Streamed into chat" means:** each endpoint **creates an assistant `Message`
in the conversation** and returns the report inline. You don't need SSE — your
existing polling snapshot will surface the new message on the next poll. The
posted message carries a `tool_payload.kind` you can special-case if you want a
richer card (values noted per endpoint).

### `POST /api/v1/radar/run/` — Odoo Health Radar (read-only)
```jsonc
// request
{ "conversation_id": "<uuid>", "lang": "ar" }   // lang: "ar" | "en", default "ar"
// response 200
{ "ok": true, "report": "<formatted text>", "result": { "issues_found": <int>, ... } }
// posted message tool_payload: { "kind": "odoo_health_radar", "issues_found": <int> }
```

### `POST /api/v1/pulse/run/` — Business Pulse / Executive Brief (read-only)
```jsonc
// request
{ "conversation_id": "<uuid>", "lang": "ar" }
// response 200
{ "ok": true, "report": "<formatted text>", "result": { ... } }
// posted message tool_payload: { "kind": "executive_brief" }
```

### `POST /api/v1/whatif/intro/` — What-If intro (no computation)
Posts a canned "tell me your decision" primer into the chat so the user can then
describe a scenario in plain language (chat then runs `simulate_what_if`).
```jsonc
// request
{ "conversation_id": "<uuid>", "lang": "ar" }
// response 200
{ "ok": true }
// posted message tool_payload: { "kind": "what_if_intro" }
```

### `POST /api/v1/whatif/run/` — What-If scenario (read-only)
```jsonc
// request
{
  "conversation_id": "<uuid>",
  "scenario": "salary_raise",     // REQUIRED, one of the four below
  "percent": 10,                  // number; meaning depends on scenario
  "volume_change": null,          // optional
  "employee_name": null,          // optional (for employee_wage_change)
  "new_wage": null,               // optional (for employee_wage_change)
  "lang": "ar"
}
// response 200
{ "ok": true, "report": "<formatted text>",
  "result": { "status": "ok", "percent": 10, ... } }
// on a bad scenario/param: 400 with { "ok": false, "error": "<ar string>" }
// posted message tool_payload: { "kind": "what_if", "scenario": "...", "percent": <n> }
```
**Valid `scenario` values (exact):** `salary_raise`, `price_change`,
`employee_wage_change`, `product_price_change`. Anything else → `400`.

> If you'd rather not build four buttons: skip these endpoints entirely and rely
> on the chat path. A user typing "لو زوّدت الرواتب ١٠٪" routes to the same
> engine via the agent's `simulate_what_if` tool and posts the same report. The
> endpoints just give you a deterministic, tappable entry point.

---

## 2. §8 — Voice support: what the row actually does

It is **not** a phone dial, WhatsApp thread, or call. It's a **self-service
support workspace**: the user describes a problem in text → an LLM drafts a
structured diagnosis + a Saudi-dialect reply → the user can optionally **file it
as a real Odoo `helpdesk.ticket`** in their bound database, and optionally have
the reply **spoken via TTS**.

Web page: `GET /voice-support/` (gated by the `voice_support` flag — see §0).
Supporting endpoints (all POST, Bearer auth):

- **`POST /api/v1/voice-support/draft/`** — send the user's problem text; returns
  a structured draft: `title`, `module`, `category`, `priority`, `questions[]`,
  `steps[]`, `reply` (Saudi-dialect). This is the core call.
- **`POST /api/v1/voice-support/tts/`** — speaks the `reply`. **Requires the
  billing `voice` entitlement** (Pro/Max) — returns `403` on Free. This is the
  one place the *billing* `features.voice` flag matters (distinct from the
  `voice_support` availability flag).
- **`POST /api/v1/voice-support/ticket/`** — creates a real `helpdesk.ticket`
  in the user's bound Odoo via XML-RPC. Request: `{ title, priority, env_id?,
  credential_name?, ... }`. The user's explicit tap **is** the consent — there
  is no approval card for this. Degrades with a clear error if the Odoo
  Helpdesk module isn't installed.

**Parity build for mobile:** a text box → call `/draft/` → render the draft card
→ optional "احفظ كتذكرة" button → `/ticket/`. TTS is a nice-to-have gated on the
paid `voice` entitlement. No telephony involved.

---

## 3. §10 — Delete confirm phrase: **no model name**

Confirmed: the typed phrase is **`delete N`** (English) / **`حذف N`** (Arabic) —
**the Odoo model name is deliberately NOT included.** (The model id used to be
in there; it was removed precisely because it locked out Arabic users and added
nothing — replay-defense lives in `payload.record_ids`, not the typed text.)

**Do not construct the phrase yourself — read it from the approval.** Each
destructive-delete approval object carries:
- `confirm_phrase` — the canonical phrase to require (e.g. `"delete 3"`).
- `confirm_word` — `"delete"`.

The server accepts any of these equivalents (so a user switching languages isn't
stuck): `delete N`, `حذف N`, `احذف N` (and the legacy `delete N <model>` for
back-compat). Arabic-Indic (٠–٩) **and** Persian (۰–۹) digits are folded to
Western before matching — so `حذف ٣` validates. Your shipped behaviour (`حذف N`
+ digit folding, no model) is **correct and matches us**. Just prefer reading
`confirm_phrase` over building the string, so you inherit any future change for
free.

---

## 4. §9 — Email approval payload: the real keys

The email-send approval payload uses these **exact** keys (nested under the
approval's `payload` object):

| Purpose | Real key | NOT |
|---|---|---|
| Recipient(s) | **`to`** (comma-separated string for multiple) | ~~`email_to`, `recipients`~~ |
| CC | **`cc`** | |
| BCC | **`bcc`** | |
| Subject | **`subject`** | ~~`email_subject`~~ |
| Body | **`body`** (plain text) | ~~`body_html`~~ |
| Threading | **`in_reply_to`** | |

So: `approval.payload.to / cc / bcc / subject / body / in_reply_to`. `to`,
`subject`, `body` are always present (they're required by the tool schema);
`cc`, `bcc`, `in_reply_to` may be `null`. You can **trim your alias list to
exactly these six.** Your "require recipient + subject, else fall back to chips"
guard is a good safety net — keep it, but it'll essentially always take the rich
path now.

---

## 5. §4.1 — "Prepare & review": no server route, you're already right

There is **no server-side review endpoint.** On web, "Prepare & review" just
assembles the answer text (`"Answers to your questions:\n- Q  A"`) and drops it
into the composer for the user to edit and send — exactly what you shipped.
Nothing to call; keep your local composer pre-fill. ("Build & send" is the same
assembled text sent immediately through the normal message flow.)

---

## 6. §11 — Grouped approvals: `grouped_count` doesn't exist; use `scope: "batch"`

There is **no `grouped_count` field** anywhere in the backend. Grouping is real,
but it's a **batch-resolve** mechanism, not a count on the card:

- To approve/reject a whole group, POST the decision with **`{ "scope": "batch" }`**
  to `POST /api/v1/approvals/<id>/decision/` (same endpoint, extra field).
- The server resolves the clicked approval **plus every other pending approval
  in the same conversation with the same shape** `{ action_type, operation,
  model }`, and (on approve) registers that shape so future same-shape writes
  auto-approve silently.
- The response echoes:
  ```jsonc
  { "...": "...", "batch": { "resolved_count": <int>, "scope": {…}, "scope_added": <bool> } }
  ```
  Read **`batch.resolved_count`** for "how many this tap cleared."
- **Deletes cannot be batched** — the server returns `400` ("Deletes must be
  approved one at a time.") if you send `scope: "batch"` on a destructive delete.
  Keep delete one-tap-per-record.
- Auto-approved (scope-matched) approvals arrive with `payload.batch_scope ==
  true`; when you see that, suppress any "Approve all similar" button (it's
  already covered).

So: wire "Approve all N" to send `scope: "batch"` and display
`batch.resolved_count` from the response, rather than expecting a `grouped_count`
on the incoming card.

---

## 7. §4.2 — Report-card labels (informational)

Correct on your end: web also uses each chip's **server `label`** as the source
of truth (and prefers the lens's `submit_en` / `submit_ar` when present, falling
back to a client-built sentence otherwise). That's why a new report type renders
without a client change. The trade-off you named — chips don't flip language
with the app — is the **same on web**. If we later want language-flipping chips
we'd add server-provided `label_en`/`label_ar` (or client `rbType_*` keys) as a
pure addition; not planned right now. No action needed from you.

---

## 8. §12 — Env picker single vs multi: product decision (flagging up)

Noted — you're multi-select on purpose (`environment_ids: [...]`). Web recently
went **single-select on purpose too**, as part of a "one active DB per chat"
(Migrator) direction — so this is a genuine **product divergence**, not a bug on
either side. The PATCH contract still accepts a list, so both clients are valid
against the backend. **Kicking this to product** to decide the target; neither
side should change unilaterally. We changed nothing.

---

## Summary of asks → status

| Your ask | Status |
|---|---|
| §1 Feature flags in JSON | ✅ **Built** — `saqqar_features` on `GET /api/v1/usage/` (deploying next web release) |
| §6 radar / pulse / what-if endpoints | ✅ Already existed — documented above |
| §8 voice-support definition | ✅ Documented — self-service ticket workspace, not telephony |
| §10 delete phrase model name? | ✅ No model; read `confirm_phrase` |
| §9 email payload keys | ✅ `to`/`cc`/`bcc`/`subject`/`body`/`in_reply_to` |
| §4.1 review route? | ✅ None; client composer pre-fill (as you did) |
| §11 grouped approvals | ✅ `scope: "batch"` → `batch.resolved_count`; no `grouped_count`; no delete batching |
| §4.2 report labels | ℹ️ Same as web; no action |
| §12 env picker | ℹ️ Product decision; no change either side |

One open item back to you: confirm whether you want us to **also** mirror
`features` / `exempt` to the top level of `/api/v1/usage/` (§0, point 2), or
you'll just repoint your reads at `windows.*`. Either is fine by us.
