# Mobile → Backend: what is still open

**To:** Backend team lead
**From:** Mobile
**Date:** 2026-08-03 (supersedes the 2026-07-28 revision)
**Status:** payments **decided — web-only**; see §2. No IAP work is requested.
**Updated 2026-08-03 after your deploy:** §3.5 (login hand-off) and §3.3
(catalogue collision) are **done and verified** — see §3.7 for the test
results. **One thing is left and it is the whole loop: payments never
complete** (§3.9, step 7). Three attempts pending, balance zero.
**Re:** Every ask in `MOBILE_BACKEND_GAPS_AND_PAYMENTS.md`, re-checked from
inside the signed-in app against production. What is done, what is withdrawn,
what we fixed on our side, and the short list that is genuinely yours.

---

## 0. Read this first

**The list got shorter, not longer.** Five things changed since the last
revision:

1. **Meetings (§4.1) is withdrawn.** Please do not build or configure it. The
   product owner is keeping that feature in-house for now. The entry point is
   out of the mobile Account screen, so there is no client waiting on those
   endpoints.

2. **Every route in the document exists** — verified this time **with a real
   session**, not by unauthenticated probing. The only one that does not is
   the In-App Purchase verification endpoint, and it is no longer wanted (§2).
   Two routes exist and both work, but reuse each other's slugs for different
   products — §3.3.

3. **Four defects turned out to be ours and are fixed** (§5). Notably
   `GET /report-entities/` was never going to work from the app because we
   called it without `conversation_id`; your 400 was correct and our client
   was wrong.

4. **Payments are settled: sales stay on the web.** The previous revision
   asked you to choose between building In-App Purchase and selling on the
   website only. The team lead chose the website (2026-07-29). **The whole IAP
   ask is withdrawn** — `billing/iap/verify/`, the store notifications, the
   product IDs, all of it. Please don't build any of it. §2 records what we
   changed on our side to match.

5. **The app now shows the plan catalogue and hands off to the web to pay.**
   It reads `GET /api/v1/plans/` — which matches saqqaar.com/pricing exactly,
   so thank you, that one is perfect — and opens
   `saqqaar.com/pricing/?plan=<slug>` in the browser. No payment, no order and
   no payment reference ever touches the app. See §3.3 and §3.5.

**Six things need you, all in §3.** Three are code — §3.1 (over-quota sends),
§3.3 (two catalogues sharing slugs) and §3.5 (the signed-out browser, the one
that decides how finished the payment flow feels). The other three are
questions you can answer in a reply.

---

## 1. How this was checked, and what that does and doesn't prove

A read-only probe was run **inside the signed-in Android app**, so it reuses
the real session rather than a copied token. It issues GETs, plus POSTs for
operations that are reads (Odoo `count` / `search` / `read`). It never calls
`POST /billing/checkout/` — that mints a real Paymob order.

Results, **2026-07-29**, `https://saqqaar.com`, authenticated:

| Endpoint | Status | Latency | Verdict |
|---|---|---|---|
| `GET /api/v1/apps/` | 200 | 307 ms | ✅ works |
| `GET /api/v1/trial/status/` | 200 | 184 ms | ✅ works — `{ok, status:"none", ready:false}` |
| `GET /api/v1/usage/` | 200 | 155 ms | ✅ works — full plan + day/week/month windows |
| `GET /api/v1/billing/plans/` | 200 | 121 ms | ✅ works — `can_pay:true`, `enabled:true` |
| `GET /api/v1/billing/history/` | 200 | 170 ms | ✅ works |
| `GET /api/v1/billing/payment/{ref}/status/` | 404 **JSON** | 120 ms | ✅ **route exists** (`{ok:false,error:"Not found."}` for a bogus ref) |
| `GET /api/v1/report-entities/` | 400 | 116 ms | ✅ route exists — correctly demanded `conversation_id`, see §5.2 |
| `POST /environments/{id}/odoo/count/` | 400 | 138 ms | ✅ route exists — "no Odoo (XML-RPC) credential" |
| `POST /environments/{id}/odoo/search/` (+`offset`,`order`) | 400 | 147 ms | ✅ route exists — same |
| `POST /environments/{id}/odoo/read-group/` | 400 | 113 ms | ✅ route exists — same |
| `POST /environments/{id}/odoo/read/` | 400 | 127 ms | ✅ route exists — same |
| `POST /environments/{id}/odoo/fields/` | 400 | 122 ms | ✅ route exists — same |
| `POST /environments/{id}/sql/` | 400 | 133 ms | ✅ route exists — "no PostgreSQL credential" |
| **`POST /api/v1/billing/iap/verify/`** | **404 HTML** | 144 ms | ❌ **does not exist** |

> **The honest caveat.** The demo environment on this account has **no Odoo
> and no PostgreSQL credential**, so the six Odoo routes were only exercised
> as far as the credential check. That proves the routes exist and that our
> request bodies are shaped acceptably; it does **not** prove the response
> shapes. Point us at an environment with a working credential (or say the
> word and we'll attach one) and we'll confirm the responses and send you the
> results rather than ask you to write them out.
>
> The 404 on `iap/verify/` is a different kind of 404 from the one on
> `payment/{ref}/status/`: the first is Django's HTML "Page not found", the
> second is your JSON error envelope. That distinction is the whole finding —
> one route is unrouted, the other is routed and simply had nothing to find.

---

## 2. ✅ Payments — decided: sales stay on the web

The previous revision opened this section with a blocker — build In-App
Purchase or decide not to sell in the apps. **That blocker is closed, and it
closed by decision rather than by work: no IAP, on either platform.**

Nothing in *this section* needs building. §3 still has asks, and one of them
(§3.5, the signed-out browser) belongs to this flow — it makes the hand-off
below feel finished rather than half-built.

### 2.1 The decision

**Team lead, 2026-07-29: subscriptions are sold on saqqaar.com only.** Paymob
stays exactly where it is; no In-App Purchase is built on either platform.

The reasoning worth recording, because it is the part that will still matter in
six months: payment is the piece of this product most likely to change —
processor, pricing model, cycles, currencies, VAT. Keeping it on one surface
means a change ships the day it's made. Putting it in the apps as well means
every change waits on two store review queues and a minimum-version rollout.

It also settles a store question in our favour. Both stores require their own
billing for digital content sold **inside** an app (App Store 3.1.1, Google
Play Payments), and neither policy is engaged by an app that sells nothing.
Worth correcting one thing the previous revision got wrong: it described iOS as
protected and Android as exposed. The honest reading is that **Android was one
submission away from the same problem** and only looked safe because nobody had
submitted it yet.

### 2.2 What the mobile app does now

Shipped 2026-08-03:

1. Reads `GET /api/v1/plans/` and renders the five tiers — same names, prices,
   caps, features, monthly/annual switch and VAT note as saqqaar.com/pricing.
2. On "Subscribe on the web", opens `saqqaar.com/pricing/?plan=<slug>` in the
   **external system browser** and forgets about it.
3. When the user returns to the app, it re-reads `/usage/` and `/plans/` on
   resume and shows the new plan. There is no payment state on this side to
   reconcile and nothing for you to notify us about — see §3.9, step 8.

### 2.3 What the mobile app no longer calls — please note

These all still work and the **web should keep using them** — we are only
telling you that no mobile client touches them any more, so mobile is not a
consideration if you ever change them:

| Endpoint | Mobile status |
|---|---|
| `POST /api/v1/billing/checkout/` | **not called.** The app opens a URL instead of minting an order. |
| `GET /api/v1/billing/payment/{ref}/status/` | **not called.** The app never holds a payment reference. |
| `GET /api/v1/billing/plans/` | **not called** — and see §3.3, it reuses `/plans/` slugs for a different product. |
| `GET /api/v1/plans/` | **called.** This is now the app's only price source. |
| `GET /api/v1/billing/history/` | called (read-only receipts). |

No card, no order and no payment reference ever touches the app. Eight tests
pin that (`test/no_in_app_purchase_test.dart`), including one asserting no
store-billing package is declared in `pubspec.yaml` — that being the one change
that would quietly make the statement filed with Apple untrue without touching
a single widget.

`CheckoutApi` and `CheckoutScreen` are still in the tree and still tested, but
unreachable: `/billing/checkout` redirects to the catalogue. **A switch, not a
demolition** — the whole purchase surface is behind one build flag
(`SAQQAR_WEB_SUBSCRIBE`) so it can be turned off per platform if a store
objects, without a code change. Our own analysis of what each store needs is in
`docs/STORE_PAYMENTS_COMPLIANCE.md`; nothing in it needs anything from you.

**Therefore: `POST /api/v1/billing/iap/verify/` is withdrawn.** So are the
store server-to-server notifications, the product-id → tokens map, and the
request for store product IDs. Its 404 is no longer a blocker for anyone.

---

## 3. What we need answered

### 3.1 Over-quota sends are accepted and then silently do nothing

**This is the one behaviour we'd most like changed, and it is small.**

Reproduced deliberately on 2026-07-29 by exhausting the Free daily cap
(`/usage/` → `day: {used: 640659, cap: 625000, remaining: 0}`) and then
sending eight more turns:

| Observed | Every time (8/8) |
|---|---|
| `POST /conversations/{id}/messages/` | **200 OK** |
| User message persisted | yes |
| `conversation.is_running` over the next 45 s (≈25 polls) | never `true` |
| Assistant reply | **never arrives** |

So an over-cap send is accepted, stored, and then abandoned with no signal on
that request. Credit where it is due: the snapshot *does* carry
`conversation.quota.kind`, and our chat screen paints "Usage limit reached"
and disables Send off it — so a user who is *looking at the chat* is told.
The gap is the send itself.

**Ask:** refuse an over-cap send at the point of sending —
`402` (or `{ok:false, error:…}` with the quota kind) instead of `200`. A `200`
means "accepted, a reply is coming", and here nothing is coming. Right now the
only thing distinguishing "the agent is thinking" from "this turn is never
going to be answered" is a banner elsewhere on the screen.

### 3.2 `POST /environments/{id}/sql/` — is read-only enforced server-side?

The mobile client exposes a free-text JSON body editor. If a `DELETE`/`UPDATE`
reaches Odoo's database because the client sent it, that is a data-loss bug
with a mobile app pointed at it. Please confirm the statement is validated or
the connection is read-only. We will keep our own guard either way — we are
asking because a client-side guard is not a security control.

### 3.3 ⚠️ `/plans/` and `/billing/plans/` share slugs but sell different things

Found while wiring the app's plan catalogue.

> **Correction to an earlier draft of this file.** It said both tables below
> were re-fetched live on 2026-08-03. Only `/plans/` was — it needs no bearer.
> `/billing/plans/` does, so its figures are from an authenticated capture on
> **2026-07-29**, and a QA pass on **2026-08-02** saw **four** paid rows there
> where we had recorded two. **So treat our `/billing/plans/` table as dated,
> not as a bug report.** The point below survives either way: the two
> endpoints share slugs while describing different products, and that is true
> whether it currently returns two rows or four.

`GET /api/v1/plans/` — re-fetched live 2026-08-03; matches saqqaar.com/pricing
exactly. **Thank you, this one is perfect and it is what the app now reads.**

| slug | name | monthly | annual (per month) | monthly tokens |
|---|---|---|---|---|
| `free` | Free | $0 | $0 | 15 M |
| `starter` | Starter | $2 | $1 | 15 M |
| `max-5x` | **Solo** | **$10** | $5 | 18 M |
| `pro` | **Professional** | $20 | $10 | 35 M |
| `max-20x` | Business | $98 | $49 | 170 M |

`GET /api/v1/billing/plans/` — what the mobile checkout was built against.
**Captured 2026-07-29; see the correction above.**

| slug | name | monthly | tokens |
|---|---|---|---|
| `pro` | **"Pro"** | 75 SAR ($20) | 250 M |
| `max-5x` | **"Max"** | **375 SAR ($100)** | 1 250 M |

Independent data point, from the QA pass on 2026-08-02 (`PAYMENT_QA_2026-08-02.md`):
Professional read as `75.00 SAR` and Solo as `37.50 SAR` there, and billing
history held pending annual attempts of **879.75 SAR** (Professional) and
**5175.00 SAR** (Solo) — neither of which reconciles with the public USD annual
price plus 15% VAT. Three readings of the same catalogue, three sets of
numbers. **We are not claiming to know which is right. That is the ask.**

**The stable part of the finding, across all three readings: the two endpoints
share slugs while describing different things.** In our 2026-07-29 capture the
billing catalogue priced out at a flat **$0.08 per million tokens** on both
rows — internally consistent, and unrelated to the subscription tiers, whose
allowances are 5–7× smaller for the same money. It reads like a prepaid token
pack rather than a subscription.

If that is what it is, fine — but **it reuses the subscription slugs**. So:

- `max-5x` was "Solo, $10/month" in one endpoint and "Max, $100" in the other,
  and nothing in either payload says which is which.
- A client that lists from one and posts to the other buys the wrong thing at
  the wrong price, silently. That is what our checkout screen was about to do.

**Not blocking us.** The app reads `/plans/` only and calls no checkout at
all. We are raising it because:

1. If the **web** checkout reads `/billing/plans/`, this is live right now
   with real money attached — and the pending attempts above suggest it might.
2. Whoever wires up billing next will hit the same trap.

**Ask — smallest useful fix first:** give the two catalogues distinct slugs,
or add a `kind` field (`"subscription"` / `"token_pack"`) so they can't be
confused. If `/billing/plans/` is dead, retiring it is even better. A
one-paragraph note in the API docs saying what it is would also do.

### 3.4 Trial auto-provisioning

`GET /trial/status/` works and returns `status: "none"` for a fresh user. To
exercise the real `pending → provisioning → ready` flow and the credentials
payload we need auto-provisioning **enabled** on the demo tenants. Is it on?

### 3.5 🔑 The browser opens signed out — this is the one that decides how good the flow feels

**The biggest gap in the payment hand-off, and the only new build we're
asking for.**

What happens today when a signed-in app user taps "Subscribe on the web":

1. The app opens `saqqaar.com/pricing/?plan=pro` in the **system browser**.
2. The browser has its own cookie jar. The app's bearer token is in the app's
   keychain and cannot be shared with it.
3. So the user arrives **anonymous**, taps a plan, and is sent to sign in —
   on a phone, on a page that then asks for a card.
4. Worst case they sign in with a different method than they used in the app
   (email vs Google vs Apple) and **create a second account**, then pay on the
   wrong one.

We checked before asking. None of these exist:
`/api/v1/auth/web-session/`, `/auth/handoff/`, `/auth/web-login/`,
`/auth/session-token/`, `/auth/login-link/` — all 404.

**Ask: a one-time login hand-off.** Roughly:

```jsonc
POST /api/v1/auth/web-session/          // bearer, the app's existing token
{ "next": "/pricing/?plan=pro" }        // relative path, validated server-side

→ 200 { "ok": true,
        "url": "https://saqqaar.com/auth/handoff/?t=<one-time-token>" }
```

Opening that URL sets the web session cookie and 302s to `next`. The app then
opens **that** URL instead of the plain pricing page, and the user lands on
the price list already signed in as themselves.

The properties that matter, in the order we'd worry about them:

- **Single use, short life** (60–120 s is plenty — the app opens it
  immediately). A hand-off URL is a bearer credential in a query string: it
  will end up in browser history, and on Android in whatever the user's
  default browser syncs.
- **Bound to the issuing user**, and invalid after the first redemption.
- **`next` must be validated as a same-site relative path**, not echoed back
  raw. An unvalidated `next` on an endpoint that authenticates you first is an
  open redirect that hands a live session to wherever the attacker points it.
- No refresh semantics, no long-lived web token. One trip, one page.

**This is not a blocker** — the flow works without it, just badly. If it is
more than a small job, say so and we will ship as-is; the friction is
survivable and the duplicate-account risk is the part we would want to fix
first.

### 3.6 One question about the web pricing page

The app now sends users to `https://saqqaar.com/pricing/?plan=<slug>`, where
`<slug>` is the server's own (`starter`, `max-5x`, `pro`, `max-20x`) straight
from `GET /api/v1/plans/` — the app does not invent identifiers.

**Does the pricing page read `?plan=` and preselect that tier?** If it uses a
different parameter name, tell us and we'll match it in a build. If it ignores
the query entirely nothing breaks — the user lands on the full price list and
picks again — but a user who tapped "Professional" in the app and arrives at a
generic page has to make the same choice twice.

### 3.7 ✅ Verified 2026-08-03 — and one mismatch found

Swept every payment API from inside the signed-in app after you shipped
§3.5. **The hand-off is correct and well built** — thank you:

| Check | Result |
|---|---|
| `POST /auth/web-session/` | ✅ `200 {ok, url}` in ~110 ms |
| A fresh token per call | ✅ never repeats |
| **Single use** | ✅ `302 → /pricing/?plan=pro`, then **400**, then **400** |
| Redirect target | ✅ exactly the `next` we sent |
| `next: https://example.com/…` | ✅ `400` |
| `next: //example.com/…` | ✅ `400` (protocol-relative — the one people miss) |
| `next: /\example.com` | ✅ `400` (backslash normalisation) |
| `next: javascript:…` | ✅ `400` |
| `/plans/` vs `/billing/plans/` | ✅ four paid tiers, names and prices now agree |
| `/billing/receipt/<ref>/` on an unpaid row | ✅ `404 {ok:false,error:"No such receipt."}` — correct and clearly worded |

Opening the hand-off URL in a real browser lands on `/pricing/?plan=pro`
**signed in** — the Business card reads "Your current plan". End to end, it
works.

**The mismatch — `ref` from history is not accepted by the status endpoint:**

```
GET /billing/history/   → rows[0].ref = "7EA02D5F"
GET /billing/payment/7EA02D5F/status/ → 404 {ok:false,error:"Not found."}
```

`PAYMOB_WEB_CHECKOUT_BACKEND.md` pairs those two ( `public_ref` on the
attempt, `GET /billing/payment/<ref>/status/` to read it), so whoever
implements that section will hit this. Either history should return the
reference the status endpoint accepts, or the two need different names so it's
obvious they aren't interchangeable. **Not blocking mobile** — nothing in the
app polls payment status any more.

Two smaller notes, neither urgent:

- `GET /billing/payment/..%2F..%2Fadmin/status/` answers the **HTML** 404 page
  rather than the JSON envelope. No traversal happens, so it isn't a hole —
  but a malformed reference gives an API client HTML where it expects JSON.
- `next: "/pricing/?plan=pro#@example.com"` is accepted (`200`). We checked:
  the fragment stays client-side and the browser keeps the origin, so this
  looks correct rather than a gap. Flagging only so you know it was tested.

### 3.8 Closed — the checkout schema question

The previous revision asked whether `POST /billing/checkout/` takes a
`cycle` parameter. **Withdrawn: no mobile client calls `checkout/` any more.**
Payment happens entirely on the web; the app opens a URL. See
`docs/STORE_PAYMENTS_COMPLIANCE.md`.

### 3.9 What the finished flow looks like

Written out so we can both check we mean the same thing. Re-checked against
production on **2026-08-03**, after your §3.5 deploy.

| # | Step | Who | Status |
|---|---|---|---|
| 1 | User opens Account → Plans & pricing | app | ✅ shipped |
| 2 | App reads `GET /api/v1/plans/` and renders the five tiers | app + you | ✅ working |
| 3 | User taps "Subscribe on the web" on a tier | app | ✅ shipped |
| 4 | App gets a one-time hand-off URL and opens the browser | app + you | ✅ **works — verified end to end** |
| 5 | Browser lands on `/pricing/?plan=…` **signed in** | web | ✅ works (the tier isn't preselected — §3.6, cosmetic) |
| 6 | User pays through Paymob | web | ✅ order is created, correct amount + 15% VAT |
| 7 | **Paymob confirms → attempt flips to paid → subscription activates** | you | ❌ **the gap** |
| 8 | User returns to the app; it re-reads `/usage/` and `/plans/` on resume | app | ✅ shipped |

**Step 7 is the only thing left, and it is the whole loop.** Billing history
on our QA account holds **three attempts, all `pending`** — one from
2026-08-03 and two from 2026-07-26 — with `token_balance: 0` and
`total_purchased: 0`. Orders open correctly and never close. That is what
`PAYMOB_WEB_CHECKOUT_BACKEND.md` §"processed callback" describes; the webhook
path in that document (`/api/v1/billing/paymob/webhook/`) is currently a 404,
as is `/billing/result/`.

**Step 8 needs nothing from you.** The app holds no payment reference and
takes no callback — coming back to the foreground is its only signal, and it
re-fetches then. **No push, no webhook to mobile, no polling endpoint. Please
don't build one.**

Until step 7 lands, the honest state is: a user can tap Subscribe, reach a
correct checkout, pay — and nothing happens. We are not shipping the store
update before that closes.

---

## 4. Measured, for your reference

From 30 + 8 real turns and a 99-message transcript on production, from an
emulator on ordinary broadband:

| Operation | Latency |
|---|---|
| `POST /conversations/` (create) | 107 ms |
| `POST /conversations/{id}/messages/` | 209–1385 ms, median ≈ 290 ms |
| Assistant reply end-to-end (short prompt, no tools) | ≈ 3.4 s |
| `GET /conversations/{id}/?limit=40` | 214–727 ms |
| `GET /conversations/{id}/?limit=40&before=<cursor>` | 195–755 ms |

Cursor paging is correct end to end: 99 rows came back as 40 + 40 + 19 with
`has_more_before` flipping false exactly on the last page. **No complaints
here — this part is solid.**

One contract note, not a request: sending a second turn 1.5–3 s after the
first is rejected `409 "The agent is still working on the previous request"`
in roughly a quarter of cases (8 of 30). That is reasonable behaviour and the
app handles it; we mention it only because it means a run can be in flight
before any snapshot has shown it, which is worth knowing if you ever key
anything client-facing off `is_running` alone.

---

## 5. What we fixed on our side

So this is not read as "mobile is waiting on you for everything". All four
were found this week by driving the real app against production.

**5.1 The chat waited 15 s before looking for a reply.** After a send we
scheduled the next poll off `is_running` in the send response. When a run
isn't visible yet, that picks the *idle* 15 s cadence for a reply that lands
in ~3.4 s. The chat now keeps the fast cadence for a bounded window after a
send, dropped the moment a run is confirmed.

**5.2 `report-entities` could never have worked.** We called
`GET /report-entities/` with no parameters. Your 400 was right. The client now
sends `?conversation_id=…`.

**5.3 Opening a chat could show a stale tail.** We paint the cache first, then
reconcile against a bounded `?limit=` window. A guard meant to stop a short
response from truncating a long transcript was throwing the *whole* fresh
window away — so a chat whose cache held 95 rows opened on a nine-minute-old
tail until the next poll. It now stitches the new rows in.

**5.4 The in-app purchase flow is gone; the plan catalogue took its place.**
See §2.2. The app was pointed at the wrong price list (§3.3) and at a checkout
neither store would accept; it now reads `/api/v1/plans/` and opens the web to
pay. Eight tests hold the "no payment in this app" property.

Also still true from the last revision: all seven direct-data operations are
wired with UI, typed models and error handling; billing history is live and
the checkout/payment-status clients are implemented but dormant; the
`{ok:false, error}` envelope and 401/4xx/5xx handling are done and verified
live; Meetings is out of the UI.

---

## 6. Checklist

**Build — remaining:**

- [ ] ⛔ **Close the payment loop: the Paymob confirmation callback (§3.9, step 7).** Three attempts sit `pending`, balance is zero, money goes nowhere. This is now the only thing between us and a working product. Spec is `PAYMOB_WEB_CHECKOUT_BACKEND.md`.
- [ ] `ref` from `/billing/history/` is rejected by `/billing/payment/<ref>/status/` (§3.7). Not blocking mobile; will bite whoever wires the status polling.

**Done — verified against production 2026-08-03, thank you:**

- [x] **One-time web-session hand-off (§3.5)** — single-use confirmed, all four open-redirect probes refused, browser lands signed in.
- [x] **`/plans/` and `/billing/plans/` reconciled (§3.3)** — four paid tiers, names and prices agree.
- [x] **Over-cap sends (§3.1)** — 402 is handled client-side and surfaces the quota reason; we could not exhaust a cap on the QA account to see it fire, so this is "wired, not observed".

**Answer in a reply — no code:**

- [ ] Is `sql/` read-only server-side (§3.2)? Safety, not convenience.
- [ ] Is trial auto-provisioning on for the demo tenants (§3.4)?
- [ ] Does the pricing page read `?plan=<slug>` (§3.6)? One build to match if it's a different name.
- [ ] *(optional, helps us not you)* An environment with a live Odoo/PostgreSQL credential, so we can confirm the six data-API *response* shapes ourselves (§1).

Withdrawn — **please do not build any of these**:

- [x] ~~`POST /api/v1/billing/iap/verify/`~~ — sales are web-only (§2.1).
- [x] ~~Store S2S notifications (Apple v2, Google RTDN)~~ — same.
- [x] ~~Store products / product IDs~~ — same.
- [x] ~~Confirm the `checkout/` cycle parameter~~ — no mobile client calls it (§3.7).
- [x] ~~Enable Meetings / send Meetings schemas~~ — withdrawn 2026-07-28.
