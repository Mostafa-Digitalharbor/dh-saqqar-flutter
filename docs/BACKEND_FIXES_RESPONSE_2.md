# Backend fixes — response #2

**From:** Web / Backend (`saqqar_ui`)
**To:** Mobile (`dh-saqqar-flutter`)
**Re:** `BACKEND_CURRENT_ISSUES.md` (2026-08-10 — the 5 open items)
**Date:** 2026-08-12

## TL;DR

| # | Item | Status |
|---|------|--------|
| 1 | Task-prep sync | ✅ **Shipped & live** — `task_prep` is now a per-conversation field; your already-shipped client will start syncing with **no release** |
| 2 | `voice-support/ticket/` contract | 📋 **Documented below** (Appendix B) — captured from the live code; `title`/`priority` were right, but you're missing the body fields |
| 3 | 4 card `kind` shapes | 📋 **Documented below** (Appendix C) — all four *are* emitted, but they're prose-with-a-marker; likely nothing to build |
| 4 | Store-reviewer staff flag | ⏳ **Waiting on you** — send us the account email and it's a one-minute change |
| 5 | `/plans/` Arabic (`Accept-Language`) | ✅ **Shipped & live** — send `Accept-Language: ar` and `/plans/` returns Arabic copy; retire your table |

---

## 1. Task-prep now syncs — shipped

Done exactly as the product owner decided: **`task_prep` is a per-conversation
field, mirroring `auto_approve`/`deep_think`.** Live in production now.

- **Serialized** in the conversation snapshot **and** echoed in the
  `PATCH /api/v1/conversations/{id}/` response (right beside `auto_approve` and
  `deep_think`).
- **Accepted** in `PATCH` — send `{ "task_prep": true|false }`.
- **Applied** to runs: the per-message `task_prep` still wins for a single turn;
  when omitted, the run uses the stored conversation value. The admin feature
  flag can still force it off.

### What you'll see now

```jsonc
// GET /api/v1/conversations/{id}/  → snapshot.conversation
{ "auto_approve": false, "deep_think": false, "task_prep": true, "...": "..." }

// PATCH /api/v1/conversations/{id}/  body {"task_prep": false}  → response.conversation
{ "task_prep": false, "...": "..." }
```

### Your `null` fallback works exactly as you built it

We made the field **nullable, default `null`** — deliberately, not `default:true`
— so your shipped client behaves precisely as designed:

- **`null`** (every conversation today — we reset all existing rows to `null`) →
  your app falls back to its **local preference**, unchanged. **No flip, no
  regression.** Your pinned test ("absent stays `null`, never `false`") holds.
- **`true`/`false`** (only after a user actually flips the toggle) → the server
  is the source of truth, it PATCHes, and both surfaces read the stored value.
- When the field is `null`, the **run** still uses the historical default
  (task-prep on) — so behaviour is identical to before until someone opts to
  change it per conversation.

So nothing changes for anyone until they flip the switch, and from that moment it
syncs. No release needed — this starts working on phones already in the field.

---

## 2. `voice-support/ticket/` — full contract

Short version: **`title` and `priority` were the right field names.** The reason
it looked risky is the *body* — the ticket description is built from the **draft
fields**, none of which you were sending, so a ticket would be created with a
title and an empty description. Send the draft fields through and it's complete.
Full capture in **Appendix B**. Two things that answer your explicit questions:

- **`priority` is a label string, not a numeric code.** Send `"High"`,
  `"Medium"`, `"Normal"`, or `"Low"` (Arabic `عالية/متوسطة/عادية/منخفضة` and
  `"urgent"` also accepted). The server maps it to Odoo's `0`–`3` internally.
  Echo back the draft's `priority` verbatim. Unknown value → `Normal`.
- **The response distinguishes created from dropped:** success is
  `{ "ok": true, "ticket_id": <int>, "target": "...", "kind": "helpdesk"|"task" }`.
  A real row exists iff `ok` is true and `ticket_id` is present. Note the
  **fallback**: if Helpdesk isn't installed it creates a `project.task` instead
  (`kind: "task"`) — still a real, saved record, just not a helpdesk ticket.
  Tell the user accordingly from `kind`.

---

## 3. The four undocumented card `kind`s

Full shapes in **Appendix C**. The headline answer to your real question —
*"which do the mobile-reachable tools actually emit?"*:

**All four are emitted**, by the shadow endpoints you already call:
`radar/run/` → `odoo_health_radar`, `pulse/run/` → `executive_brief`,
`whatif/intro/` → `what_if_intro`, `whatif/run/` → `what_if`.

**But** — and this is the useful part — unlike `report_builder`/`prompt_clarify`,
these four carry **almost no structured data**: just the `kind` discriminator
(plus a count for radar, and scenario/percent for what-if). The entire substance
is the **formatted markdown report in the message `content`** — which is exactly
why they already render correctly as prose on your side.

So there's likely **nothing worth building**: you already get the full report as
the message body, and you already get the rich `result` object in the endpoint's
own JSON response when you invoke it. A custom card would only re-style text you
already show. Our recommendation: **leave these as prose** unless you want a
decorative header/badge. That's the "we'd rather know it never carries data than
build against it" answer you asked for.

---

## 4. Store-reviewer account — we need the email

You chose option 1 (mark one account staff). **Send us the account email** the
Apple/Google reviewer will use, and we'll set `is_staff` on it — a one-minute
change that flips Health Radar, What-If, Business Pulse and Voice Support visible
for that login only. Nothing else is blocked on this.

---

## 5. `/plans/` Arabic — shipped

`GET /api/v1/plans/` now does **content negotiation on `Accept-Language`**. Send
a header whose primary tag starts with `ar` (`ar`, `ar-SA`, `ar,en;q=0.9`) and
every descriptive field comes back Arabic; anything else — and no header —
returns the exact English you have today (byte-identical, pinned by a test).

**You can now retire your mirrored Arabic table.**

### What's localized (verified live)

```jsonc
// GET /api/v1/plans/   with   Accept-Language: ar
{
  "slug": "pro",                       // unchanged — key on this
  "name": "الاحترافي",                 // localized (English request → "Professional")
  "tagline": "للمستخدمين المتقدمين",
  "features_intro": "كل ما في الفردي، بالإضافة إلى:",
  "features_text": [ "بناء وتعديل إضافات أودو وتنزيلها بصيغة .zip", "…" ],
  "price_note": "10$ شهريًا بالفوترة السنوية (120$ سنويًا) · 20$ شهريًا بالفوترة الشهرية (240$ سنويًا).",

  "price_monthly_cents": 2000,         // money is NEVER localized — always USD cents
  "features": { "voice": true, "…": true }   // the booleans object — unchanged
}
```

Notes:
- **`name` is localized** too, so you don't keep a names table — but keep keying
  on the stable `slug`, never the name.
- **`price_note` is computed in Arabic** (Western digits, `120$` number-then-symbol,
  matching the site) so it can't drift from the price.
- The Arabic strings are **exactly what saqqaar.com already shows** — we mirrored
  them from the site's own translation map, and a CI test now fails if the two
  ever diverge, so editing the site copy keeps the API in step.
- Everything not descriptive (`slug`, `sort`, cents, caps, `features` booleans,
  `vat`) is identical in both languages.

### One heads-up on the **web** Arabic price note (not your bug, not blocking)

While doing this I found a pre-existing defect on **our** side: the web pricing
page's Arabic **price note** shows in English, because that string is computed
(it embeds the numbers) and the site's client-side translator can only match
fixed strings. Your app is now *better* than the website here — you get a real
Arabic note from the API. We'll fix the web page separately; nothing for you to
do.

---

## Appendix B — `POST /api/v1/voice-support/ticket/`

Exact contract, from the live code.

### Request body

```jsonc
{
  // ── ticket header ──
  "title": "مشكلة في فواتير المبيعات",   // optional; default "تذكرة دعم فني"; truncated to 180 chars
  "priority": "High",                     // optional; default "Normal". LABEL string, not a code:
                                          //   High | Medium | Normal | Low
                                          //   (also: urgent, and Arabic عالية/متوسطة/عادية/منخفضة)

  // ── ticket body: pass the draft fields straight through from /voice-support/draft/ ──
  "summary": "…",                 // problem summary  (falls back to "transcript" if summary is empty)
  "transcript": "…",              // optional; used as the summary only if "summary" is absent
  "reproduction_steps": ["…"],    // list of strings
  "questions": ["…"],             // list of strings (the draft's missing-info questions)
  "customer_reply": "…",          // Saqqar's suggested reply to the customer
  "module": "المبيعات",           // optional; shown in the ticket meta line (default "عام")
  "category": "دعم",              // optional; shown in the ticket meta line (default "دعم")

  // ── which bound Odoo DB to write to (optional; falls back to the user's first) ──
  "env_id": "<environment id>",           // the env the user picked
  "credential_name": "<xmlrpc cred name>" // alternative selector
}
```

Notes:
- Only `title` and `priority` touch Odoo's ticket fields directly. Everything
  under "ticket body" is composed into the Odoo `description` (HTML) by the
  server — so **send the whole draft object** and the ticket reads fully.
- The draft endpoint returns exactly these keys, so the clean pattern is:
  `POST /voice-support/ticket/` with `{...draftResponse.draft, title, env_id}`.

### Success response

```jsonc
{
  "ok": true,
  "ticket_id": 42,                 // the real Odoo record id — presence ⇒ created
  "name": "مشكلة في فواتير المبيعات",
  "target": "helpdesk.ticket",     // or "project.task" if Helpdesk isn't installed
  "kind": "helpdesk"               // or "task"
}
```

### Error responses (all `{ "ok": false, "error": "<arabic message>" }`)

| Status | When |
|---|---|
| `403` | Voice Support feature disabled for this account |
| `400` | No Odoo database bound, **or** neither Helpdesk nor Project installed to save into |
| `502` | Couldn't connect to Odoo, or the create call failed |

> Sibling for reference — `POST /voice-support/draft/` returns
> `{ "ok": true, "draft": { "diagnosis"?, "priority", "summary", "questions": [],
> "reproduction_steps": [], "customer_reply", "category"?, "module"? } }`. The
> reply is nested under `draft` (as you found), and its fields are the ones the
> ticket body consumes above.

---

## Appendix C — the four card payloads

Each is an **assistant message** whose `content` is the full formatted report
(markdown, in the request's `lang`), plus this `tool_payload`:

```jsonc
// from POST /api/v1/radar/run/   (Health Radar)
{ "kind": "odoo_health_radar", "issues_found": 7 }     // issues_found: int

// from POST /api/v1/pulse/run/   (Business Pulse)
{ "kind": "executive_brief" }                           // no other fields

// from POST /api/v1/whatif/intro/   (What-If intro prose)
{ "kind": "what_if_intro" }                             // no other fields

// from POST /api/v1/whatif/run/   (What-If result)
{ "kind": "what_if",
  "scenario": "salary_raise",                           // one of the 4 below
  "percent": 10 }                                       // number | null
```

`what_if.scenario` ∈ `salary_raise` · `price_change` · `employee_wage_change` ·
`product_price_change`.

Reminder: these endpoints **also** return the full data in their own JSON
response — `radar/run/` and `pulse/run/` and `whatif/run/` each return
`{ "ok": true, "report": "<markdown>", "result": { … } }`. So you already hold
everything; the chat message is a mirror for history. That's why we suggest not
building bespoke cards for these four.
