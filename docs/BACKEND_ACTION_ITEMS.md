# Backend action items — Saqqar mobile

**From:** Mobile (`dh-saqqar-flutter`)
**To:** Web / Backend (`saqqar_ui`)
**Date:** 2026-08-06

Every item below is **backend-owned**. Mobile work is already done and shipped
unless a line says otherwise.

Everything here was **verified**, not assumed — against the live API where the
endpoint is public, against production behaviour where it is not, and against
our own source where the claim is about the client. Each item says how it was
checked so you can reproduce it.

---

## Priority summary

| # | Item | Endpoint | Severity | Needs a mobile release after? |
|---|---|---|---|---|
| **1** | Deploy `saqqar_features` | `GET /usage/` | **P0 — 4 features invisible** | No |
| **2** | Conversations list has no paging | `GET /conversations/` | **P0 — data loss on screen** | No |
| **3** | Billing history currency ≠ checkout currency | `GET /billing/history/` | **P0 — money screen** | No (option 1) |
| **4** | Plan descriptions missing | `GET /plans/` | P1 | Yes, once |
| **5** | `task_prep` is not persisted | `PATCH /conversations/{id}/` | P1 | Yes, once |
| **6** | `/apps/` returns a package web doesn't show | `GET /apps/` | P1 | Removes a mobile release |
| **7** | `/apps/` is English-only | `GET /apps/` | P1 | Depends on shape |
| **8** | Which message shape carries a card? | *(question)* | P1 | Probably not |
| **9** | Does `report_builder` gate the report card? | *(question)* | P2 | Yes, one line |
| **10** | Confirm the batch-scope restriction | *(question)* | P2 | Only if widened |
| **11** | Prompt-bank contents | *(question)* | P2 | Only if server-side |
| **12** | One authenticated smoke test | *(joint)* | P1 | No |

**Items 1, 2 and 3 are user-visible defects today.** The rest are gaps,
questions, or maintenance debt.

---

# P0 — visible defects

## 1. `saqqar_features` is not deployed, so four features are invisible

**Endpoint:** `GET /api/v1/usage/`

### What is wrong

Your 2026-08-06 response document specified a new top-level `saqqar_features`
object and said it was "deploying next web release". **It is not on the
endpoint yet.**

Mobile implemented the full contract you specified, including your gating
instruction ("everything except `task_prep` and `prompt_bank` strict — absent
OR `false` ⇒ hide"). That was the right instruction and we followed it. The
consequence is:

> The shipped app **contains** Health Radar, Business Pulse, What-If and the
> Voice Support workspace, and **none of them appear for anyone**, because the
> flag that reveals them does not exist in the response.

### How we verified

The four §6/§8 endpoints themselves are live. We probed all five unauthenticated
and every one answered `401`, not `404` — meaning the route exists and requires
auth, rather than being absent:

```
401  POST /api/v1/radar/run/
401  POST /api/v1/pulse/run/
401  POST /api/v1/whatif/intro/
401  POST /api/v1/voice-support/draft/
401  POST /api/v1/voice-support/ticket/
```

So the features are built on your side and reachable. Only the flag payload is
missing.

### What we need

Ship `saqqar_features` on `GET /api/v1/usage/`, in the shape you specified:

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

### Impact and release note

**No mobile release needed, and no app restart.** Until the field exists the
client treats the flags as *unknown* and re-asks on every chat open, so the
first response carrying it lights the rows up immediately.

### One thing to decide separately

Your sample shows `health_radar`, `what_if`, `business_pulse` and
`voice_support` as `false` for a normal non-staff account (staff-only during
rollout). **So deploying the field alone still leaves these hidden for ordinary
users.** If they should be visible for a store-review account or a demo, the
flags have to be turned on for that account too.

---

## 2. `GET /conversations/` truncates the list with no way to page

**Endpoint:** `GET /api/v1/conversations/`

### What is wrong

An account with roughly **140 conversations sees 140 on the website and 100 in
the app.**

- The client requests `limit=200`.
- The response contains **100** rows and `"total": 140`.
- So the server applies its own page ceiling well below the requested limit —
  and correctly reports that more exist.
- **`/api/v1/conversations/` accepts no `offset`.** Its documented query
  contract is `?limit=&include_archived=` only.

The result is the worst shape for missing data: the list *looks* complete.
There is no gap on screen to notice and no "load more" to reach for. A user
scrolling to the bottom concludes those conversations are gone.

Note that `/api/v1/approvals/` and `/api/v1/artifacts/` **both** accept
`?limit=&offset=`. This endpoint is the outlier.

### What mobile already shipped

The list now pages: it sends `offset` and keeps requesting until `total` is
reached. It is deliberately safe against a server that ignores `offset` — a
page that returns no new ids ends the loop — so **today it costs exactly one
extra request and then stops**, still showing 100. It is written this way so
that the moment you add `offset`, the full list appears with no mobile release.

### What we need — one of

1. **Accept `offset` on this endpoint**, matching `/approvals/`. *Strongly
   preferred:* mobile already sends it, so this needs **no mobile release**,
   and it is the only option that also fixes the account with 900
   conversations.
2. **Raise or remove the page cap**, if ~140 is near the realistic ceiling.
3. **Tell us the real paging parameter** if it is something else (a cursor,
   `page=`) and we will switch to it.

---

## 3. Billing history reports SAR; checkout charges USD

**Endpoints:** `GET /api/v1/plans/` and `GET /api/v1/billing/history/`

### What is wrong

The two endpoints disagree about the currency of the same purchase.

| Endpoint | Field | Value |
|---|---|---|
| `GET /api/v1/plans/` | `price_monthly_cents` | **USD cents** — `API_MOBILE_SUBSCRIPTION.md` §2 calls these "the source of truth (what checkout charges)" |
| `GET /api/v1/billing/history/` | `currency` | **`"SAR"`** — §3 documents it as the default, and production returns it |

So a customer sees **$20** on the plans screen, pays, and then finds the same
payment listed as **75.00 SAR** in their history. Nothing on the screen
connects the two figures, and no conversion rate is provided, so the person
looking at them cannot reconcile them. On a billing screen that is the one
thing that must be beyond doubt.

Your own documentation sample makes the point: it shows `"what": "Professional
— annual"` against `"amount": 75.0, "currency": "SAR"`, while Professional
annual is $120/yr.

### How we verified

We probed `GET /api/v1/plans/` live (it is public) and confirmed the prices are
plain integer cents with no currency field at all:

```json
{"slug": "pro", "name": "Professional",
 "price_monthly_cents": 2000, "price_annual_cents": 1000, "...": "..."}
```

And confirmed in our own source that the history screen prints `amount` and
`currency` **exactly as sent** — mobile invents no conversion and never will.

### What we need — one of

1. **Charge and report in the same currency.** Simplest, and what we would
   pick: if checkout takes USD, then `history.currency` is `"USD"` and `amount`
   is the dollars charged. **This needs no mobile release** — the screen
   already renders whatever you send.
2. **If the gateway genuinely settles in SAR**, say so on both ends: add the
   settled *and* the quoted amount to each history row, e.g.

   ```json
   { "amount": 75.0, "currency": "SAR",
     "charged_amount": 20.0, "charged_currency": "USD", "fx_rate": 3.75 }
   ```

   Mobile will show the charged figure with the settled one beneath it. This
   one needs a mobile release.

We are **not** asking which currency is commercially right — that is your call,
and the "15% VAT is added at checkout" wording suggests SAR may be what Paymob
actually settles in.

---

# P1 — gaps and questions

## 4. `GET /plans/` carries no plan descriptions

**Endpoint:** `GET /api/v1/plans/`

### What is wrong

We probed the live endpoint. It returns the commercial facts and **nothing a
customer would recognise as a plan description**:

```
slug  name  sort  price_monthly_cents  price_annual_cents
daily_tokens  daily_burst_tokens  weekly_tokens  monthly_tokens
max_projects  max_envs_per_project
features{ voice, postgres, github, server_shell }
```

Everything saqqaar.com/pricing actually shows a buyer is absent:

| On the website | On `/plans/` |
|---|---|
| Tagline — "For power users" / "للمستخدمين المتقدمين" | ✗ |
| Feature bullets — "Create and edit Odoo records (with approval)" … | ✗ |
| The "Everything in Solo, plus:" ladder | ✗ |
| The "Most popular" badge | ✗ |
| Arabic tier name — "الاحترافي", "الأعمال" | ✗ (`name` is English-only) |
| "Free for everyone" note on the free tier | ✗ |

### What mobile shipped, and why it is a liability

So the two surfaces stop describing two different products, the app now carries
that copy itself, keyed by wire slug, taken from the live site on 2026-08-06 in
both languages. Prices still come from you and are untouched.

That means **every wording change on the website — a new bullet, a renamed
tier, a reordered list — now needs an app release and a store review to reach
mobile.** Store review is days, not minutes. The two will drift, and they will
drift on the screen where people spend money.

### What we need

Add the descriptive fields to each plan row, ideally honouring
`Accept-Language`:

```json
{
  "slug": "pro",
  "name": "Professional",
  "tagline": "For power users",
  "most_popular": true,
  "inherits_from": "max-5x",
  "features_text": [
    "Build and edit Odoo addons, download as .zip",
    "Trigger server actions and install modules",
    "Higher usage limits",
    "Priority support"
  ],
  "price_note": null
}
```

`inherits_from` is enough for us to render "Everything in Solo, plus:"
ourselves — we do not need the sentence, just the slug. `price_note` carries
the free tier's "Free for everyone"; `null` elsewhere.

**Whichever shape you pick, one rule matters more than the shape: it must be
the same source the website's own pricing page renders from.** A second copy on
your side solves nothing — it moves the drift rather than removing it.

### A clarification worth putting in writing

`price_annual_cents` is **half** `price_monthly_cents`, not twelve times it
(`pro`: 2000 vs 1000). We read it as *"the monthly price when billed
annually"*, so Professional annual renders as **$10/mo ($120/yr)**. Please
confirm — if it were ever meant as an annual total, every price on our pricing
screen would be wrong by 12×.

### Release note

Mobile needs **one** release to read the new fields. After that your wording
changes reach the app with no release at all.

---

## 5. `task_prep` is never persisted, so the toggle does not sync

**Endpoint:** `PATCH /api/v1/conversations/{id}/`

### What is wrong

Turning **Task prep** on in the app does not turn it on in the web UI, and vice
versa. This is **not** a mobile bug — it is a missing contract:

- `task_prep` is a **send-body key only** (`payload.get("task_prep", True)`).
  The server reads it per message, applies it, and forgets it.
- There is **no persisted field anywhere**: it is not on the conversation
  serializer, and `PATCH /api/v1/conversations/{id}/` does not accept it.

Compare `auto_approve`: that **is** a real conversation field, and it therefore
**does** sync between the two clients today. The two toggles sit next to each
other in the UI and behave differently, which is what the user noticed.

So each client necessarily keeps its own copy — mobile in local preferences,
web in its own session state — and neither can see the other's. Any mobile-side
"fix" would mean inventing a storage location and guessing that web reads the
same one.

### What we need — one of

1. **A conversation field.** Serialize `task_prep` on the conversation and
   accept it in `PATCH`, exactly like `auto_approve`. Smallest change, matches
   the pattern already in place, and the two clients then agree per chat.
2. **A user-level preference**, if the intent is one setting for the whole
   account rather than per conversation. Any endpoint that persists and returns
   it works — tell us the shape.

**This is partly a product decision:** auto-approve is per-conversation, task
prep is currently a global client preference. Tell us the target and mobile
matches it in an afternoon.

### Release note

Needs **one** mobile release — nothing in the client reads a `task_prep` field
today, because none exists to read.

---

## 6. `GET /apps/` returns a package the web gallery does not show

**Endpoint:** `GET /api/v1/apps/`

### What is wrong

The catalogue endpoint returns **five** packages. The web Apps gallery shows
**four**:

1. ZATCA e-invoicing
2. WhatsApp integration
3. Chart of Accounts builder
4. Bank reconciliation

So the app was offering a fifth package that no other surface supports.

### What mobile shipped, and why it will rot

Mobile now filters the list to an allowlist of those four, falling back to the
full list if nothing matches (so a mass rename can never produce an empty
gallery).

**This is maintenance debt and worth naming plainly:** the allowlist means **a
genuinely new package you add will not appear on mobile** until someone adds
its key and ships a release. That is the opposite of how the rest of that
screen works.

### What we need — one of

1. **Serve mobile the same list you serve web.** Cleanest.
2. **Tell us the fifth package's slug**, and we will hide that one by name
   instead of allowlisting the four. One line on our side, and it **restores
   "new packages just appear"** — i.e. it removes a future mobile release.

---

## 7. `GET /apps/` is English-only

**Endpoint:** `GET /api/v1/apps/`

### What is wrong

`name`, `tagline` and `category` come back in English whatever the caller's
locale. On an Arabic phone the Saqqar Apps grid was English cards inside an
otherwise Arabic app.

### What mobile shipped

Each field resolves a client string keyed by the package's slug (and, because
slugs are not published to mobile, by the normalized English name as a
fallback), falling back to the server value. The four live packages are
translated using **your own Arabic copy from the website**, so the same package
reads identically on both clients. A package you add tomorrow still renders —
in English — with no mobile release.

### What we need

Either `name_ar` / `tagline_ar` / `category_ar` alongside the existing fields,
or honour `Accept-Language` on the endpoint. Both are purely additive.

**Until then, every new package is English on Arabic phones** unless someone
remembers to add mobile strings for it.

### Release note

If you honour `Accept-Language` and return a localized `name`, mobile renders
it with no release — but our override for the four known packages would still
win, so tell us and we will drop them in the same release. If you add `_ar`
fields instead, that needs one release to read them.

---

## 8. Which message shape carries an interactive card?

**Asked:** 2026-08-05 and 2026-08-06. **Not yet answered.**

Appendix A says the `tool_payload` arrives "on an assistant/tool message". We
need to know which of these you actually send:

1. `role: "tool"`
2. `role: "assistant"` with empty `content`
3. `role: "assistant"` with prose **and** `tool_payload`

### Why this matters more than it sounds

Our visibility filter used to drop shapes 1 and 2 as agent plumbing. That meant
**every `prompt_clarify` / `report_builder` / `prompt_suggestion` card was
filtered out before it reached the renderer** — while every widget test passed,
because those pump the row directly. The feature was completely dead in the app
and looked healthy in CI.

It is fixed and all three shapes now render. But we are handling shapes you may
never send, and possibly still missing one you do.

**One line in a reply closes this. A sample payload is better.**

---

## 12. One authenticated smoke test (joint)

Three response shapes have **never been exercised against a real server**,
because doing so needs an authenticated account with a bound Odoo credential:

1. The `POST /voice-support/draft/` payload — we built to your prose
   description (`title`, `module`, `category`, `priority`, `questions[]`,
   `steps[]`, `reply`).
2. The `batch` object on an approval decision (`resolved_count`,
   `scope_added`).
3. A real `tool_payload` interactive card.

All three parse defensively — a wrong-typed or missing field degrades to
"feature hidden", never to a crash — but *parses defensively* is not the same
as *confirmed correct*.

**One authenticated smoke test on staging closes all three**, and we would much
rather do that than discover it during store review.

---

# P2 — questions, no urgency

## 9. Does `report_builder` gate the report card?

Your `saqqar_features` sample introduced four flags we had not seen:
`collection_note`, `version_awareness`, `module_management`, `report_builder`.
Mobile stores all of them and gates on none.

`report_builder` is the one that matters: **if it is meant to gate the §4
report card, we will wire it in one line.** If it gates a web page of that
name, we leave it alone. Right now the card renders whenever a payload arrives,
which is wrong if the feature is off for that account.

Same question, lower stakes, for the other three — do any correspond to
something mobile should show?

## 10. Confirm the batch-scope restriction

Your §11 answer excludes only deletes from `scope: "batch"`. Taken literally
that permits batch-approving a `server_command` or a `credential_storage`
approval — one tap that silently pre-approves **future shell commands of the
same shape**.

Mobile restricted the offer to `action_type == "odoo_write"`, because your own
wording is "future same-shape **writes** auto-approve silently", and because a
shell command is the approval most worth reading one at a time.

**If the server really does intend to batch every action type, say so** and we
will widen it. If not, consider rejecting `scope: "batch"` server-side for
non-write types too, so a future client cannot re-open this.

## 11. Prompt-bank contents

`prompt_bank` is a server flag, but there is no saved-prompt endpoint. Mobile
shows the app's own four starter prompts. **If the flag implies server-side
content, tell us where it lives**; otherwise we leave it as is.

---

# What is NOT on this list

For completeness, so nothing here is read as a complete parity checklist:

- **App tile icons.** `GET /apps/` sends `icon_svg` correctly and mobile does
  not render it (no SVG renderer bundled), so tiles fall back to a generic
  per-group icon. **Mobile-owned, needs no backend work.**
- **Voice-support TTS.** `POST /voice-support/tts/` exists; mobile does not
  call it, deliberately — it needs the billing `voice` entitlement (403 on
  Free) and returns audio the app has no player for. **Mobile-owned. Tell us if
  spoken replies matter commercially.**
- Six defects mobile found and fixed in its own code on 2026-08-06 (a `null`
  rendering as the text "null" on email approvals, a Stop button that could not
  stop, a cross-account flag leak, and three others). All fixed and
  regression-tested.

---

# The single most useful reply

If bandwidth is short, these three cost you the least and unblock the most:

1. **Deploy `saqqar_features`** → four features become visible, no mobile
   release.
2. **Accept `offset` on `/conversations/`** → the missing 40 conversations
   appear, no mobile release.
3. **Send the fifth app package's slug** → removes a future mobile release
   entirely.

Items 1 and 2 are the two the user has already noticed.
