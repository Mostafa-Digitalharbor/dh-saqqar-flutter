# Mobile confirmation — your four fixes are in

**From:** Mobile (`dh-saqqar-flutter`)
**To:** Web / Backend (`saqqar_ui`)
**Re:** `BACKEND_FIXES_RESPONSE.md`
**Date:** 2026-08-09

## TL;DR

All four shipped items are verified and consumed. The client is written, the
analyzer is clean and the suite is green at **1148 tests**.

| # | Item | Verified how | Mobile status |
|---|---|---|---|
| 1 | `saqqar_features` on `/usage/` | code path re-checked against your Appendix A.1 | **Already correct** — no change needed |
| 2 | Conversations `limit`/`offset`/`total` | paging walker re-read against the new contract | **Already correct** — no change needed |
| 5 | `/apps/` returns the same 4 as web | allowlist deleted | **Done** |
| 6 | `/plans/` descriptive copy + `vat` | fetched the live payload, diffed field by field | **Done** — mirror deleted |

Two of those needed no code because we had already built to the shape you have
now confirmed. That is worth stating plainly: it means those two go live for
users **on the build already in review**, with no new release.

Three things still need you. They are in "What we still need" at the bottom —
one is a decision only you can make, one is a schema we cannot invent, and one
is a correction to something in your file.

---

## 1. `saqqar_features` — no change needed, and here's the proof

You were right that we implemented the contract correctly, and you were right
about the timing. Nothing to do on our side.

Two details from your Appendix A.1 worth confirming back, because both were
real bugs at some point and both are already fixed here:

- **`exempt` and `features` are read from inside `windows`**, not the root. We
  hit exactly the failure you describe (an exempt account with all four
  entitlements arriving as not-exempt with everything off) on 2026-08-04 and
  fixed it then. `usage_api.dart` reads `windows['exempt']` and
  `windows['features']`.
- **`saqqar_features` is read from the root**, kept in a holder with its own
  lifetime. This matters more than it looks: the plan object is *also*
  delivered by every conversation snapshot on a 1.5 s poll, and that snapshot
  carries no `saqqar_features`. Merging the two would have blanked the flags
  every 1.5 s and made the new rows blink out mid-session.

The gating rule is implemented as you state it — **absent OR `false` ⇒ hide**,
and "absent" is tracked separately from "false" so a server that predates the
deploy reads as *unknown* rather than as *everything off*.

### Your Q7 — the reviewer account

**Option 1, please: mark one account staff.** Keeping the rollout controlled is
right, and a global un-gate for the sake of a store review is the tail wagging
the dog.

⚠️ **We owe you the email address** — it is a decision on our side, not yours,
and it is not in this document yet. Treat this section as open until we send it.

---

## 2. Conversations paging — no change needed

`listAll()` already walks `offset` and stops on `total`. Against the new
contract an account of ~140 now completes in **one request** (`limit=200`
returns all 140 with `total: 140`, and the walker stops on the total).

**We advance `offset` by rows received, never by rows requested** — your
warning is respected, and we never ask for more than 200 anyway.

Three independent stop conditions remain, and they stay deliberately: they were
written to be safe against a server that *ignores* `offset`, which is what
anyone on an older deployment is still talking to.

### One correction to your file

> *"You reported seeing `"total": 140` already. The old endpoint emitted no
> `total` field at all — so that value came from somewhere else on your side."*

Correct that it did not come from the API, and no, it was not a phantom field
on our side either. **The 140 was counted by hand on saqqaar.com.** Someone
noticed the website listed ~140 conversations and the app listed 100, which is
how the truncation was found at all. Our client parsed `total` as null, exactly
as you'd expect from an endpoint that wasn't sending it.

Nothing to fix — but the record should say the gap was found by eye, not by a
field we were misreading. We've corrected our own code comments accordingly.

### Your Q8

Noted: was a fixed 100 cap / default 20 / no offset; now default 30, up to 200
per request, offset to walk the rest, not per-plan.

---

## 5. `/apps/` — allowlist deleted

Done. `SaqqarApp.shipped()`, `isVisible` and the `visibleKeys` set are gone;
the screen renders the catalogue verbatim.

The test that pinned the allowlist has been **inverted** rather than deleted —
it now asserts that a package this build has never heard of reaches the screen,
so a future allowlist fails a test instead of quietly costing you a release.

### Your Q11

`meetings` — understood, and agreed it never belonged on mobile. Good that
`launch/` 404s on it; we don't construct that route from anything but the
catalogue, so there was no second path, but the belt is welcome.

---

## 6. `/plans/` — the mirror is deleted

Verified against the live endpoint today, tier by tier. Every field you
documented is present and every value matches your example.

**What we now render straight from the wire:** `tagline`, `most_popular`,
`features_intro`, `features_text`, `price_note`, and the top-level `vat`.

**What we deleted:** the slug-keyed copy table added on 2026-08-06. Both
screens that describe a plan — the pricing catalogue and the account card —
read the tier object now, so "the two screens say the same thing" is a
structural fact rather than a convention two files have to keep.

**The proof it worked:** a tier this build has never heard of now renders its
tagline, its ladder header, its bullets and its badge. Under the mirror it
rendered a bare name. There is a test for exactly that.

`features_text` vs `features` is respected: bullets from the former,
entitlements from the latter, and a test asserts both on the same row so nobody
"tidies" one into the other.

### VAT

Read from the payload, not assumed. The rider and the footnote render only when
`active && !included_in_price`, and the rate is interpolated — `15.0` prints as
`15`. **A server that sends no `vat` object now claims no tax**, where the old
hardcoded sentence would have gone on asserting 15% forever.

### Two places we still compose text locally, and why

Being explicit so neither reads as an oversight:

1. **The billing-cycle line on paid tiers.** We compose it from the same cents
   the row carries rather than printing `price_note`. Not a mirror — every
   number is interpolated from your payload, so it cannot disagree with you —
   but your string is English-only, and on an Arabic page the bidi algorithm
   reorders `"$2/mo billed monthly ($24/yr)."` into
   `"billed monthly ($24/yr).$2/mo"`. Same content, unreadable.

   **A test asserts our composed line is byte-identical to your `price_note`
   for every paid tier.** If you reword the note, that test fails here rather
   than shipping two different sentences to two surfaces. The free tier has no
   figures to reorder, so it prints your string.

2. **Tier names.** Keyed by slug, since you've confirmed the `name` values stay
   English permanently and the five slugs are stable.

### The Arabic caveat — we've taken **both** options

Your explanation settles it, and thank you for being straight about
`public-i18n.js`: there is no server-side Arabic to mirror.

**Option 1 is shipped.** We translate your English client-side, keyed by the
English text — the same mechanism the website uses, built the same way. The
important property is the fallback: a bullet you add tomorrow renders
immediately **in English on both locales**, and picks up Arabic when we add it.
Never blank, never stale, and never a reason to hold a release.

**Please also do option 2.** `Accept-Language: ar` on `/plans/` is the durable
fix and it retires this table entirely. It is *not* blocking — ship it whenever
suits — but option 1 has one honest failure mode we'd rather not keep forever:
if you **edit** an English string we've already translated, the lookup misses
and that line falls back to your new English. The reader gets the current claim
in the wrong language, which is the better of the two failures, but it is still
a failure that only exists because the Arabic lives on this side.

### Your questions 1–6

All confirmed and now recorded in the code:

1. **`price_annual_cents` is per-month-billed-annually** — thank you for
   putting it in writing. This was the one that could have made every figure on
   our pricing screen wrong by 12× with nothing in the payload to reveal it.
2. Copy is a shared server module both surfaces read. ✅ That was the ask.
3. Slugs stable — we key names on them.
4. `sort` ascending — we already sort by it.
5. VAT added at checkout, `included_in_price: false`. Implemented.
6. No currency field; USD assumed. Fine while #3 is parked.

---

## What we still need from you

Only one of these is blocking anything.

### A. The four card kinds we cannot render — **we need the payload shapes**

Your Q12 answer resolved the message shape completely, and our dispatch was
already correct:

- **assistant + prose + payload**, dispatched on `tool_payload.kind` ✅
- **`tool_payload` with `tool_calls` and no `kind` → plain bubble, payload
  ignored** ✅ — your "critical negative case". Already handled; now pinned by
  a test so it stays handled.

But of the seven kinds you list, **this build renders three**:

| kind | mobile |
|---|---|
| `prompt_clarify` | ✅ renders |
| `report_builder` | ✅ renders |
| `prompt_suggestion` | ✅ renders |
| `odoo_health_radar` | ❌ prose only |
| `executive_brief` | ❌ prose only |
| `what_if_intro` | ❌ prose only |
| `what_if` | ❌ prose only |

The four we don't render degrade safely — the agent's prose shows as an
ordinary message, nothing is lost or blank, and there's a test covering each of
the four kinds to prove it. So this is a **missing card, not a broken screen**.

**What we need:** the field shape of each of those four payloads, the way
Appendix A.1 documented `prompt_clarify`. We're not going to guess at them —
inventing a contract is how the last round of drift started. Send the four
shapes and the cards are a mobile-only change.

Worth flagging: these four are the payloads produced by Health Radar, Business
Pulse and What-If — the same features that are staff-only today. So this
unblocks in the same window as the reviewer-account question, not before.

### B. The reviewer account email

Owed by us, per §1. Option 1.

### C. `Accept-Language: ar` on `/plans/`

Yes please, when convenient. Non-blocking.

---

## Parked items — nothing needed from us

**#3 (USD ↔ SAR)** and **#4 (task_prep sync)** are understood as product
decisions. Confirming what we'll do the day each is decided so neither needs
re-spec'ing:

- **Currency:** we render whatever the billing history rows say. Option 1
  (report in the charged currency) needs only a currency field on the row.
- **task_prep:** if it becomes per-conversation, we mirror `auto_approve`
  exactly — a field on the conversation and a PATCH. If it becomes an account
  preference, we read it once and cache it. The toggle already exists in the
  composer; only its persistence is open.

---

## What this means for the release

The build in store review does **not** need rebuilding for items #1 and #2 —
they were already correct and they light up on the current binary the moment a
user's session hits the new endpoints.

Items #5 and #6 are code changes and ride the next build. Everything they
depend on is already live, so there's no ordering constraint between your
deploy and ours.
