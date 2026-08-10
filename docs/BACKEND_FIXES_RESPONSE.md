# Backend fixes — response

**From:** Web / Backend (`saqqar_ui`)
**To:** Mobile (`dh-saqqar-flutter`)
**Re:** `BACKEND_CURRENT_ISSUES.md`
**Date:** 2026-08-09

## TL;DR

Four of the six are **done and live in production right now**. Release impact
differs per item (matching your own analysis — #6 needs a build to read the new
fields; the other three don't):

| # (your file) | Item | Status | Mobile release? |
|---|---|---|---|
| 1 | `saqqar_features` on `/usage/` | ✅ **Live** — was already deployed when you probed; re-check now | **None** |
| 2 | Conversations paging | ✅ **Live** — endpoint now takes `?limit=&offset=` and returns `total` | **None** (you already send offset) |
| 5 | `/apps/` 5th package | ✅ **Live** — endpoint now returns the same 4 as web | **None** for correctness; one to delete the allowlist |
| 6 | `/plans/` copy | ✅ **Live** — rows carry tagline/bullets/badge/intro/note + VAT | **One** to read the fields — then wording flows with no release |
| 3 | USD vs SAR | ⏸️ **Parked** by product owner (commercial decision) | — |
| 4 | task_prep sync | ⏸️ **Parked** by product owner (product decision) | — |

Everything below verified against the live endpoints today.

---

## 1. `saqqar_features` — it's live; here's how to use it

You were right that you implemented the contract correctly. The reason you saw
nothing is timing: the field was deployed **the same day** you probed, so your
probe hit the pre-deploy endpoint. **It is on `GET /api/v1/usage/` now** —
please re-fetch.

### Confirmed live shape (top-level key on `/api/v1/usage/`)

For a **normal (non-staff)** account today, verified in production:

```jsonc
{
  "ok": true,
  "saqqar_features": {
    "task_prep": true,
    "prompt_bank": true,
    "health_radar": false,
    "what_if": false,
    "business_pulse": false,
    "voice_support": false,
    "report_builder": false,
    "collection_note": false,
    "version_awareness": false,
    "module_management": false
  },
  "windows": { "...": "unchanged" }
}
```

### The gating rule (unchanged — your reading was correct)

- **absent OR `false` ⇒ hide** the feature. Keep doing exactly this.
- The map is **per-user**. It already accounts for staff-only rollout, plan,
  and admin kill-switches server-side — you don't compute anything, just read
  the boolean.
- Server-side enforcement is independent of what you read here: even if a client
  showed a hidden feature, the tool/endpoint refuses it. So the flag is purely a
  UI-visibility hint; you can trust it without defensive double-checks.

### Your Q7 — which account sees the four features

Not empty flags — this is a **deliberate staff-only rollout**. In production
right now: `health_radar`, `what_if`, `business_pulse`, `voice_support` (and
also `report_builder`, `collection_note`, `version_awareness`,
`module_management`) are **enabled but staff-only**. `task_prep` and
`prompt_bank` are open to everyone.

So to make the four visible for the **store reviewer / a demo account**, pick one
and tell us:

1. **Mark that specific account as staff** — instant, no code, and it flips all
   staff-only features on for just that login. Give us the account email.
2. **We globally un-gate specific features** (flip `staff_only → false` for,
   say, `health_radar` + `what_if`) so *every* user sees them. Tell us which
   features are cleared for general availability.

Default recommendation: **option 1 for the reviewer account** (keeps the rollout
controlled), then option 2 per-feature as each is ready for GA.

---

## 2. Conversations paging — `?limit=&offset=` + `total`, live now

`GET /api/v1/conversations/` now behaves like `/approvals/` and `/artifacts/`.

### New contract

```
GET /api/v1/conversations/?limit=30&offset=0&include_archived=0&q=<search>
```

| Param | Default | Notes |
|---|---|---|
| `limit` | **30** | Page size. You may raise it per request; **capped at 200** (so your existing `limit=200` request returns a full 200 in one shot). |
| `offset` | `0` | Row to start at. This is the fix — walk the whole list. |
| `include_archived` | `0` | unchanged |
| `q` | — | unchanged (title/body search) |

> **Advance `offset` by the row count you *received* (or by the echoed `limit`),
> never by the number you *requested*.** We clamp `limit` to 200, so if you ask
> for more than that and then step `offset` by your requested number, you'll skip
> rows. The response echoes the effective `limit`, and `returned == len(conversations)`
> — increment by either of those. (At `limit ≤ 200` this is moot; the note is
> here so a future larger request can't silently skip.)

### New response fields

```jsonc
{
  "ok": true,
  "total": 140,        // NEW — full count after filters; use it to stop "show more"
  "limit": 30,         // NEW — echoes the effective page size
  "offset": 0,         // NEW — echoes the offset
  "conversations": [ /* unchanged row shape */ ]
}
```

### For your "show more" button

- First load: `offset=0` (30 rows).
- Each tap: `offset += limit` → 30, 60, 90… until `offset + returned >= total`,
  then hide the button.
- Page size is 30 by default; if you want a different first page or a bigger
  "show more" chunk, just send `?limit=N` (≤200). No release needed to change it.

### Two honest notes

- **You reported seeing `"total": 140` already.** The old endpoint emitted no
  `total` field at all — so that value came from somewhere else on your side.
  It's a real field **now**; key off this one.
- **Offset paging is a moving window.** If a conversation is touched (bumped to
  the top by a new message) between your page 1 and page 2 requests, the window
  shifts by one — inherent to offset paging, not a bug. It's what you asked for
  and it's fine for a "show more" list; just don't treat the pages as a frozen
  snapshot. (We added a stable `-id` tiebreaker so equal timestamps don't
  reshuffle, which removes the *common* duplicate/skip case.)

### Your Q8 — the page cap

It **was** a fixed hard cap of 100 with a default of 20 and no offset. Now:
default 30, per-request `limit` up to 200, and `offset` to reach everything
beyond the first page. Not per-plan.

---

## 5. `/apps/` — now the same 4 as web; remove your allowlist

### What changed

`GET /api/v1/apps/` now applies the **same visibility gate as the web gallery**
and additionally omits **direct-launch apps**. Verified live: it returns exactly

```
zatca · whatsapp · chart-of-accounts · bank-reconciliation
```

### Your Q11 — the 5th package

It's **`meetings`** (the "Meeting notetaker"). It is **not a guided package** —
it's a *direct-launch* app that opens an internal web route (`/meetings/`), and
on web it's gated behind staff + a configured Vexa integration. It was never
meant to appear as a chat-launching package, and the mobile app has no surface
for it. The JSON API now filters it out for you, unconditionally.

### Please remove the client-side allowlist

Now that the endpoint is authoritative, **delete your four-item allowlist**.
This restores "a new package we add just appears on mobile" with no release —
which is the behaviour you flagged the allowlist as breaking. Launch of a
filtered slug (`POST /api/v1/apps/meetings/launch/`) now returns **404**, so
you can't accidentally open one either.

---

## 6. `/plans/` — descriptive copy, from the same source the website renders

### What changed

`GET /api/v1/plans/` rows now carry the marketing copy, pulled from a **single
shared server module that the web pricing page also renders from** — so the two
can no longer drift. Verified live on the `pro` tier:

```jsonc
{
  "slug": "pro",
  "name": "Professional",
  "sort": 3,
  "price_monthly_cents": 2000,
  "price_annual_cents": 1000,

  // NEW descriptive fields ↓
  "tagline": "For power users",
  "most_popular": true,
  "features_intro": "Everything in Solo, plus:",
  "features_text": [
    "Build and edit Odoo addons, download as .zip",
    "Trigger server actions and install modules",
    "Higher usage limits",
    "Priority support"
  ],
  "price_note": "$10/mo billed annually ($120/yr) · $20/mo billed monthly ($240/yr).",

  // UNCHANGED — the boolean entitlements object (do NOT confuse with features_text)
  "features": { "voice": true, "postgres": true, "github": true, "server_shell": true },

  // UNCHANGED — the token/limit caps you already read (real values, elided here)
  "daily_tokens": "…", "weekly_tokens": "…", "monthly_tokens": "…",
  "max_projects": "…", "max_envs_per_project": "…"
}
```

Plus a new top-level object on the response:

```jsonc
{ "ok": true, "plans": [ ... ], "current_plan": "pro",
  "vat": { "active": true, "included_in_price": false, "rate_percent": 15.0 } }
```

### Field notes

- **`features_text`** (list of bullet strings) is the buyer-facing feature list.
  It is **deliberately named differently** from the existing **`features`**
  object (the voice/postgres/github/server_shell booleans your `PlanFeatures`
  reads) — we did not touch that object. Render bullets from `features_text`;
  keep reading entitlements from `features`.
- **`features_intro`** is the full sentence ("Everything in Solo, plus:") — we
  send the whole string so you don't reconstruct it from a slug. It's `null`
  on the Free tier.
- **`most_popular`** replaces the badge you hardcoded.
- **`price_note`** is **computed from the same cents `/plans/` already sends**,
  so it's byte-identical to the pricing page and can't drift. `null` for a $0
  non-Free tier; the Free tier reads `"Free for everyone"`.

### Please drop your mirrored copy table

The whole point: **delete the hardcoded plan copy you mirrored on 2026-08-06**
and read these fields. Any wording change we make now reaches the app with no
release.

### The Arabic caveat — read this, it kills your Q's for good

The web pricing page is **English-only on the server**. It renders Arabic
**client-side**, via a static English→Arabic string map
(`public-i18n.js`) keyed by the English text — the site literally translates the
English strings in the browser. So **there is no server-side Arabic source for
us to mirror into the API**; the English we now send *is* the source, and web's
Arabic is a presentation-layer map.

Two clean options for your Arabic screen, your call:

1. **Translate our English `features_text`/`tagline` client-side**, exactly as
   the website does (key by the English string). This is *parity* with web, not
   a hack — web does the same thing.
2. **We add `Accept-Language: ar` support to `/plans/`** as a fast follow, so
   the API returns Arabic copy directly. Say the word and we'll wire it; it's
   additive and needs no change on your side beyond sending the header.

Either way, **the tier `name` values stay English** (`Free`…`Business`) on both
the DB and the API — matching what you observed.

---

## Answers to your questions

Grouped as in your file.

**On #6 — plans**

1. **Is `price_annual_cents` the monthly price when billed annually?** **Yes.**
   It is the *per-month* price on the annual plan. E.g. Professional:
   `price_monthly_cents 2000` = $20/mo; `price_annual_cents 1000` = $10/mo
   billed annually = $120/yr. Your reading is correct; now confirmed in writing.
2. **Where does the plan copy live?** It *was* inline in the pricing page code;
   it's now a **shared server module that both the pricing page and `/plans/`
   read**. So `/plans/` now *is* that source. ✅
3. **Are the slugs stable?** Yes — `free`, `starter`, `max-5x` (Solo), `pro`
   (Professional), `max-20x` (Business) are stable identifiers. Key on slug.
4. **Is `sort` the display order?** **Yes** — render ascending by `sort`.
   Free=0, Starter=1, Solo=2, Professional=3, Business=4.
5. **Is VAT inside `price_*_cents` or added after?** **Added at checkout** —
   prices exclude VAT. Now explicit in the payload:
   `vat.included_in_price = false`, `vat.rate_percent = 15.0`. Render "+ VAT"
   when `vat.active && !vat.included_in_price`.
6. **Regional pricing / currency field on `/plans/`?** No currency field today;
   assume **USD**. (This ties into your #3, which is parked — see below.)

**On #1 — feature flags**

7. Answered in §1 above — staff-only rollout; give us the reviewer email (option
   1) or tell us which features to un-gate globally (option 2).

**On #2 — conversations**

8. Answered in §2 — was a fixed 100 cap / default 20; now default 30, per-request
   up to 200, offset to walk all. Not per-plan.

**On #3 — currency**  (parked)

9. **Does Paymob settle in SAR or USD?** This is the commercial decision the
   product owner has **parked** for now. When it's decided we'll implement your
   option 1 (report in the charged currency) or option 2 (dual-amount + fx_rate)
   accordingly. No action from you until then.

**On #4 — task prep**  (parked)

10. **Per-conversation or per-account?** Also **parked** as a product decision.
    When decided we'll mirror `auto_approve`'s pattern (per-conversation field +
    PATCH) or add a user preference. No change from you until then.

**On #5 — apps**

11. Answered in §5 — the 5th slug is `meetings`, a web-only direct-launch app,
    now filtered out server-side.

**General**

12. **Which message shape carries a `tool_payload` interactive card?** Verified
    in the code: it's an **assistant message with BOTH prose `content` AND a
    `tool_payload` object**. Concretely:

    ```jsonc
    {
      "role": "assistant",
      "content": "A couple of quick questions before I start 👇",  // real prose, not empty
      "tool_payload": {
        "kind": "prompt_clarify",     // discriminator — see the full list below
        "questions": [ /* card-specific fields */ ],
        "original": "..."
      }
    }
    ```

    So: **assistant + prose + payload** (your third guess). Dispatch on
    `tool_payload.kind`; render the prose as the message bubble and the card from
    the rest of `tool_payload`. It is **not** `role:"tool"` and **not** an
    empty-content assistant.

    **The card `kind` values** (render a card only for these):
    `prompt_clarify`, `report_builder`, `prompt_suggestion`, `odoo_health_radar`,
    `executive_brief`, `what_if_intro`, `what_if`.

    **Critical negative case:** `tool_payload` is *also* present on ordinary
    assistant messages as `{"tool_calls": [...]}` — internal tool-call plumbing,
    **no `kind`**. Do **not** render that as a card. The rule that covers both:
    *render a card only when `tool_payload.kind` is one of the values above;
    otherwise treat the message as plain prose.* A `tool_payload` with `tool_calls`
    and no `kind` → normal bubble, ignore the payload.

---

## What's parked, and why

Items **#3 (USD↔SAR)** and **#4 (task_prep sync)** are held by the product
owner — the first is a commercial/Paymob decision, the second a product decision
about per-conversation vs per-account. Both are understood and specced; nothing
is blocked on you. We'll pick them up when those calls are made.

Everything else in your file is shipped and live. Re-probe the four endpoints
and you should be unblocked on all of them without a release.

---

## Appendix A — complete endpoint reference

Everything below is the **exact live shape** (captured from production today), so
you can build against it without seeing any server code. All routes are mounted
under **both** `/api/` and `/api/v1/` — use `/api/v1/`.

**Auth:** same as today — `Authorization: Bearer <token>` (the account/session
token you already use). Unauthenticated calls return `401`. All responses carry
`"ok": true` on success; errors are `{ "ok": false, "error": "<message>" }` with
a 4xx status.

### A.1 `GET /api/v1/usage/`

```jsonc
{
  "ok": true,

  // ── TOP-LEVEL fields ──
  "plan": "free",              // slug of the current plan
  "plan_name": "Free",
  "status": "active",          // subscription status | null
  "cycle": "monthly",          // "monthly" | "annual" | null
  "expires_at": null,          // ISO-8601 period end (informational) | null
  "saqqar_features": {         // {feature_key: bool} — the #1 fix
    "task_prep": true, "prompt_bank": true,
    "health_radar": false, "what_if": false, "business_pulse": false,
    "voice_support": false, "report_builder": false, "collection_note": false,
    "version_awareness": false, "module_management": false
  },

  // ── NESTED under "windows" ──
  "windows": {
    "plan": "free",
    "plan_name": "Free",
    "exempt": false,           // ⚠️ HERE, not top-level (see note)
    "token_balance": 0,        // prepaid credits
    "day":   { "used": 0, "cap": 625000,   "pct": 0, "remaining": 625000 },
    "week":  { "used": 0, "cap": 3500000,  "pct": 0, "remaining": 3500000 },
    "month": { "used": 0, "cap": 15000000, "pct": 0, "remaining": 15000000 },
    "features": {              // ⚠️ HERE, not top-level — billing entitlements
      "voice": false, "postgres": false, "github": false, "server_shell": false
    }
  }
}
```

> **⚠️ This fixes the null bug you flagged.** `exempt` and `features` (the
> billing entitlements) are **nested inside `windows`**, not at the top level.
> If your `UsageApi.fetch()` reads `body['features']` / `body['exempt']` at the
> top level they'll be `null` — read `body['windows']['features']` and
> `body['windows']['exempt']`. (`saqqar_features` **is** top-level; don't confuse
> the two `features` objects — `windows.features` = billing booleans;
> `saqqar_features` = Saqqar-feature visibility.)

### A.2 `GET /api/v1/conversations/`

Request: `?limit=30&offset=0&include_archived=0&q=<optional search>`

```jsonc
{
  "ok": true,
  "total": 140,       // full count after filters — page until offset+returned >= total
  "limit": 30,        // effective page size (echoed; clamped to ≤ 200)
  "offset": 0,
  "conversations": [
    {
      "id": "6f1c…",                       // string uuid
      "title": "Production Audit",         // "Untitled Conversation" if unset
      "created_at": "2026-08-01T10:00:00Z",
      "updated_at": "2026-08-09T12:00:00Z",
      "is_archived": false,
      "message_count": 12,
      "files_count": 3,
      "project":     { "id": "…", "name": "Acme" },   // or null
      "environment": { "id": "…", "name": "Prod" },   // or null
      "last_message_preview": "first 120 chars of the newest message…"
    }
  ]
}
```

### A.3 `GET /api/v1/apps/`

Returns only the guided packages the account may see (the #5 fix). No params.

```jsonc
{
  "ok": true,
  "apps": [
    {
      "slug": "zatca",
      "name": "ZATCA e-invoicing",
      "tagline": "Onboard Saudi Fatoora Phase-2 e-invoicing on your Odoo — CSR, OTP, and go-live.",
      "category": "Compliance · KSA",
      "group": "Finance",              // taxonomy chip: Accounting | Finance | Integrations | ...
      "accent": "#14B8A6",             // hex — tints the icon tile
      "icon_svg": "<svg …>…</svg>",    // 24×24 inline SVG, stroke=currentColor
      "env_required": true             // whether an Odoo env must be bound to launch
    }
    // … whatsapp, chart-of-accounts, bank-reconciliation
  ]
}
```

### A.4 `POST /api/v1/apps/{slug}/launch/`

Body (optional): `{ "environment_id": "<uuid you own>" }` — binds that env;
omit and the agent asks in-chat. Creates a package-tagged conversation and seeds
the agent's opening message.

```jsonc
// 201 Created
{
  "ok": true,
  "conversation_id": "…",   // open the chat on this id
  "app": { /* same row shape as A.3 */ }
}
// 404 for an unknown / gated / direct-launch slug (e.g. "meetings")
```

### A.5 `GET /api/v1/plans/`

Public (no auth needed; if authed, `current_plan` is set). The #6 fix adds the
descriptive fields.

```jsonc
{
  "ok": true,
  "current_plan": "pro",        // slug of caller's plan, or null if anonymous
  "vat": { "active": true, "included_in_price": false, "rate_percent": 15.0 },
  "plans": [
    {
      // identity + price (source of truth — checkout charges from these)
      "slug": "pro",
      "name": "Professional",
      "sort": 3,                          // render tiers ascending by sort
      "price_monthly_cents": 2000,        // USD cents ($20/mo)
      "price_annual_cents": 1000,         // USD cents — the PER-MONTH price on annual ($10/mo → $120/yr)

      // caps you already read — real per-tier integers (elided here); null max_* = unlimited
      "daily_tokens": 123, "daily_burst_tokens": 123,
      "weekly_tokens": 123, "monthly_tokens": 123,
      "max_projects": 5, "max_envs_per_project": 3,

      // billing entitlement booleans (UNCHANGED — your PlanFeatures reads these)
      "features": { "voice": true, "postgres": true, "github": true, "server_shell": true },

      // ── NEW descriptive copy (render the pricing screen from these) ──
      "tagline": "For power users",
      "most_popular": true,               // the "Most popular" badge
      "features_intro": "Everything in Solo, plus:",   // null on Free
      "features_text": [                  // buyer-facing bullets (≠ `features` booleans)
        "Build and edit Odoo addons, download as .zip",
        "Trigger server actions and install modules",
        "Higher usage limits",
        "Priority support"
      ],
      "price_note": "$10/mo billed annually ($120/yr) · $20/mo billed monthly ($240/yr)."
      // Free tier: price_note = "Free for everyone"; a $0 non-Free tier: null
    }
    // … other tiers, in `sort` order: free, starter, max-5x (Solo), pro, max-20x (Business)
  ]
}
```

**Slugs (stable — key your copy on these):** `free`, `starter`, `max-5x`
(Solo), `pro` (Professional), `max-20x` (Business).
