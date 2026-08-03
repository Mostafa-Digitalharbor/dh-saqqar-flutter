# Payment QA — Pixel 9 Pro — 2026-08-02

Environment: Android `Pixel_9_Pro` (`emulator-5556`), authenticated production
account, production API at `https://saqqaar.com`.

No payment order was created and no charge was attempted. The temporary debug
purchase visibility used for inspection was reverted to `false` after QA.

## Verified working

- Authenticated session survived APK replacement.
- Conversations list rendered production data.
- `GET /api/v1/usage/` rendered real day/week/month usage.
- `GET /api/v1/apps/` rendered five app cards.
- `GET /api/v1/plans/` rendered Free, Starter, Solo, Professional and Business.
- `GET /api/v1/billing/plans/` rendered four purchasable paid plans.
- `GET /api/v1/billing/history/` rendered balances and pending attempts.
- `GET /api/v1/projects/` and `GET /api/v1/credentials/schemas/` rendered the
  authenticated workspace.

## Blocking payment findings

### P0 — Web plan choice is lost

In a browser without a website session, tapping `Choose Professional` on
`/pricing/` navigates to `/signup/`. The URL carries no `plan`, `cycle`, `next`
or opaque checkout handoff. The selected plan is therefore lost, and an app
session does not authenticate the browser session.

Required: preserve the selection through sign-in using a server-side,
short-lived opaque handoff, then return to a confirmation page for that exact
plan and cycle.

### P0 — Conflicting price models

The website and authenticated billing catalogue do not present one canonical
charge model:

- Website annual display: Professional `$10/month`, `$120/year`, plus VAT.
- Website monthly display: Professional `$20/month`, plus VAT.
- Mobile billing catalogue: Professional `75.00 SAR` (monthly parsing).
- Existing history: Professional annual `879.75 SAR` pending.
- Website annual display: Solo `$5/month`, `$60/year`, plus VAT.
- Mobile billing catalogue: Solo `37.50 SAR` (monthly parsing).
- Existing history: Solo annual `5175.00 SAR` pending.

The annual pending amounts do not reconcile with the public USD annual prices
using a normal USD/SAR conversion plus 15% VAT. Checkout must not be enabled
until one server-owned SKU/cycle/amount table feeds website display, Paymob
order creation, receipts and mobile read-only history.

### P0 — Store-policy violation when enabled

The debug purchase screen opens a third-party digital-goods checkout from the
store app. It includes prices and `Buy` buttons. This must remain disabled in
global App Store/Google Play builds unless the app is enrolled in and fully
implements an eligible regional external-purchase program.

### P1 — Current-plan/downgrade protection missing in UI

The authenticated account has Business-level usage limits, but the checkout
screen still offers Starter, Solo, Professional and Business. The UI does not
mark the current plan or suppress current/lower tiers. The backend must reject
current-plan repeats and downgrades even if the UI is fixed.

### P1 — Product terminology conflicts

The public page sells subscriptions/plans; the app calls the same action `Buy
tokens`. `/plans/` shows plan caps while `/billing/plans/` includes token and
price-per-million concepts. Decide whether the product is a recurring plan or
a token top-up and use one contract and vocabulary throughout.

### P1 — Stale pending attempts

Billing history contains pending annual attempts dated 2026-07-26. Pending
Paymob attempts need an expiry/failed transition and reconciliation job; they
must not remain pending indefinitely.

### P1 — Price/checkout disclosure incomplete in debug UI

The mobile debug catalogue displays a SAR number but does not show VAT,
billing cycle, renewal terms or final total beside the Buy button. Its warning
text says only that it is hidden on iOS even though Google Play has equivalent
digital-goods restrictions for the normal global release.

## Observed account state

- Usage caps were consistent with a high/Business tier: daily `212.5M`, weekly
  and monthly `170M`.
- Billing balance and total purchased were both zero.
- Pending history rows do not grant entitlement, which is correct.

## Release decision

Keep `showPaidUpsell == false`. Implement the web/backend contract in
`PAYMOB_WEB_CHECKOUT_BACKEND.md`, reconcile pricing, expire stale attempts and
complete an end-to-end Paymob sandbox test before enabling production sales.

