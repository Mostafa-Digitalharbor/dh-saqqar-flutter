# Paymob web checkout: backend implementation contract

> **Read this first — "checkout" here is the website's, never the app's.**
>
> Nothing in this document is called by the mobile app. Every endpoint below is
> either website→backend or Paymob→backend. As of 2026-08-04 the app has no
> checkout code at all: `checkout_screen.dart`, `checkout_api.dart` and
> `checkout_models.dart` were deleted, and `/billing/checkout/`,
> `/billing/plans/` and `/billing/payment/<ref>/status/` are deliberately not
> declared in `api_endpoints.dart`. `no_in_app_purchase_test.dart` fails the
> build if any of them comes back.
>
> **The entire mobile side is three lines:**
>
> 1. `POST /api/v1/auth/web-session/` → open the returned URL in the browser,
>    landing on `https://saqqaar.com/pricing/` already signed in.
> 2. The user pays there. The app is not involved and holds no reference.
> 3. On resume, re-read `GET /api/v1/usage/` and `GET /api/v1/plans/` and show
>    whatever plan the server reports.
>
> The app never decides what someone is subscribed to — the server does, and the
> app displays it. That is the whole contract on this side, and it is done.
> What follows is the other half.

Status: required before enabling any external-checkout build. The App Store and
Google Play release builds must keep `showPaidUpsell == false` unless Saqqar is
enrolled in, and implements, an applicable regional external-purchase program.

**Correction (2026-08-04, measured against production):** §"Required web flow"
step 8 names `/billing/result/`. That path returns 404; the live page is
`/billing/return/`, and it reads its reference from `?ref=`. It polls
`/api/v1/billing/payment/<ref>/status/`, which is live (401 unauthenticated).
Whether the processed-callback endpoint in §"API contract" exists under some
other path could not be determined from outside — it is configured in the
Paymob dashboard, not in a URL anyone outside the backend can enumerate.

## Product decision

Payment is completed on `https://saqqaar.com`, never inside the Flutter app and
never in a WebView. The website owns plan selection, VAT, currency, terms,
refund/cancellation copy and Paymob UI. The backend is the only component that
may talk to Paymob using secrets.

The current mobile store build is a consumption-only companion: users may sign
in and use a plan bought elsewhere, but it has no price, Buy/Upgrade button,
payment link or wording that steers users to an external purchase. This is the
safe worldwide store configuration.

## Required web flow

1. User signs in on `saqqaar.com` and opens `/pricing/`.
2. Website POSTs the selected `plan_slug` and `cycle` to the backend.
3. Backend reads the authoritative plan price from its own catalogue. Never
   accept an amount, currency or VAT value from the browser.
4. Backend creates a local `PaymentAttempt` in `pending` state with a unique
   reference and idempotency key.
5. Backend creates the Paymob intention/order and returns the hosted checkout
   URL to the website.
6. Browser navigates to Paymob.
7. Paymob's processed callback reaches the backend. The backend verifies HMAC,
   amount, currency, merchant/order IDs and success state, then activates the
   subscription in one database transaction.
8. Paymob's response callback returns the browser to
   `/billing/result/?ref=<opaque-reference>`. This page displays backend state;
   it must not trust query-string success flags from Paymob.
9. App refreshes `GET /api/v1/usage/` and `GET /api/v1/plans/` on resume/login,
   so a web purchase appears without reinstalling or signing out.

## API contract

### POST `/api/v1/billing/web-checkout/`

Authenticated website request. CSRF protection is required when cookie auth is
used.

```json
{
  "plan": "pro",
  "cycle": "monthly",
  "idempotency_key": "uuid-v4"
}
```

Success (`201`, or `200` when the idempotency key already exists):

```json
{
  "ok": true,
  "ref": "pay_opaque_public_reference",
  "checkout_url": "https://accept.paymob.com/...",
  "expires_at": "2026-08-02T17:30:00Z"
}
```

Rules:

- allow-list plan and cycle; reject Free/current/downgrade purchases;
- calculate subtotal, 15% VAT and total server-side in integer minor units;
- bind the attempt to `request.user`, never an email supplied by the client;
- make `(user_id, idempotency_key)` unique;
- return only HTTPS Paymob URLs whose host is allow-listed;
- rate-limit creation and expire abandoned attempts.

### GET `/api/v1/billing/payment/<ref>/status/`

Authenticated and owner-scoped. A foreign reference returns `404`.

```json
{
  "ok": true,
  "ref": "pay_opaque_public_reference",
  "status": "pending",
  "plan": "pro",
  "cycle": "monthly",
  "paid_at": null
}
```

Allowed states: `pending`, `paid`, `failed`, `expired`, `refunded`,
`chargeback`. State transitions are monotonic; a duplicated or late webhook
must not grant a second subscription period.

### POST `/api/v1/billing/paymob/webhook/`

Public only because Paymob calls it. It must:

- read the raw/canonical Paymob fields and verify the HMAC with a constant-time
  comparison before doing any work;
- reject unknown merchant/order IDs, currency or amount mismatches;
- store the provider transaction ID with a unique constraint;
- lock the `PaymentAttempt` row and update payment + subscription atomically;
- acknowledge duplicate valid callbacks with `200`;
- log references and provider IDs, never card data, tokens or full payload PII;
- enqueue email receipt/analytics after commit, not before it.

The processed callback is the source of truth. The browser redirect is UX only.

## Minimum data model

`PaymentAttempt`

- `public_ref` (random, unique; no sequential database ID)
- `user_id`, `plan_slug`, `cycle`
- `subtotal_minor`, `vat_minor`, `total_minor`, `currency`
- `status`, `idempotency_key`
- `paymob_order_id`, `paymob_intention_id`, `paymob_transaction_id` (unique
  where applicable)
- `checkout_url`, `expires_at`, `paid_at`
- timestamps plus a redacted provider response for support/audit

`Subscription`

- `user_id`, `plan_slug`, `status`
- `current_period_start`, `current_period_end`
- `payment_attempt_id`
- cancellation/refund fields

Keep an append-only payment-event table if support or financial reconciliation
needs the full transition history.

## Website requirements

- Monthly/annual amounts must come from one backend catalogue. The current
  public `/api/v1/plans/` response has separate monthly and annual cent values;
  the Paymob catalogue must not maintain conflicting prices.
- Show currency, 15% VAT, exact charged total, renewal behavior, cancellation,
  refund policy, merchant legal name and support contact before redirecting.
- Require login before creating checkout so payment is credited to the correct
  Saqqar account.
- Provide success, pending, failed and expired result states and a retry that
  creates a new idempotency key.
- Provide subscription management, invoices/receipts and refund/support paths.
- Set CSP, HSTS, secure/HttpOnly/SameSite cookies and `Referrer-Policy` so no
  authentication material leaks to Paymob.

## Mobile synchronization

No Paymob secret, iframe ID, integration ID or payment key belongs in the app.
After returning to Saqqar, refresh plan/usage on app resume. The server remains
authoritative for every feature gate; a local "payment successful" flag must
never unlock a paid feature.

If regional external-link programs are adopted later, add a separate build and
runtime eligibility service based on the user's App Store/Play country, not GPS
or device locale. That build must use the required StoreKit/Play external-link
APIs and disclosure screens. Do not enable it by changing the global visibility
getter alone.

## Acceptance checklist

- webhook HMAC pass/fail and altered-field tests;
- duplicate/out-of-order callback tests;
- amount, currency, plan and ownership tampering tests;
- idempotent checkout creation under concurrent requests;
- payment activates exactly one subscription period;
- refund/chargeback removes or schedules removal of entitlement correctly;
- app reflects a completed web purchase after resume;
- store release binary contains no purchase CTA or external payment URL;
- production monitoring alerts on pending attempts older than the Paymob TTL
  and reconciles provider transactions against local records daily.

