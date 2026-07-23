# Mobile → Backend: Gaps & Payment Requirements

**To:** Backend team lead
**From:** Mobile
**Date:** 2026-07-23
**Re:** What's left to make everything in `API_MOBILE_NEW_ENDPOINTS.md` work **for real** in the app, and how to enable **paid token purchases** on the App Store + Google Play.

---

## 0. TL;DR

The mobile app now implements **every** endpoint from the hand-off. I tested them **live** against `https://saqqaar.com` with a real signed-in account. Most work end-to-end. Three areas still need backend work before we can remove the "Preview" warning banners and ship:

1. **Meetings (§4.1)** — endpoint returns `409 "Meetings are not configured yet."` → needs to be **enabled/configured** + payload schemas documented.
2. **Direct data API (§4.2)** — `count` is confirmed working; need the exact **request-body keys** for the other 6 operations.
3. **Payments (§4.3)** — the current Paymob web-checkout **will be rejected by Apple and Google** for in-app token sales. To sell tokens in the apps we need **native In-App Purchase (IAP)** + a **backend receipt-verification endpoint**. Details in §3.

---

## 1. Status from live testing

| Feature | Endpoint | Live result | Status |
|---|---|---|---|
| Saqqar Apps | `GET /api/v1/apps/` | `200` — 5 apps | ✅ Works |
| App launch | `POST /api/v1/apps/{slug}/launch/` | `201` + `conversation_id` | ✅ Works |
| Trial status | `GET /api/v1/trial/status/` | `200` `status:"none"` | ✅ Works (see §4) |
| **Meetings** | `POST /api/v1/meetings/` | **`409` "Meetings are not configured yet."** | ⛔ Blocked (§2.1) |
| Data — count | `POST /api/v1/environments/{id}/odoo/count/` | `200` `{count: 2913}` | ✅ **Schema confirmed** |
| Data — others | search/read-group/read/fields/sql/report-entities | not exercised | ⚠️ Confirm schema (§2.2) |
| Billing history | `GET /api/v1/billing/history/` | `200` | ✅ Works |
| Billing plans | `GET /api/v1/billing/plans/` | `200` | ✅ Works (see §3.1) |
| Checkout / payment | `POST /billing/checkout/`, `GET /billing/payment/{ref}/status/` | not exercised | ⚠️ Confirm schema + **store policy (§3)** |

---

## 2. Missing backend work (non-payment)

### 2.1 Meetings (§4.1) — enable + document

- `POST /api/v1/meetings/` currently returns:
  ```json
  { "ok": false, "error": "Meetings are not configured yet." }   // HTTP 409
  ```
  → The Vexa (or equivalent) meeting integration is **not configured** on our tenant. Please enable it for the tenants we'll use.

- The hand-off only listed method + path for §4. Please **document the request/response payloads** so we can drop the "Preview" banner and stop guessing. The app currently assumes:

  | Endpoint | App currently sends | App currently reads | Please confirm |
  |---|---|---|---|
  | `POST /meetings/` | `{ "url": "<meeting link>" }` | `{ id, status }` (or `{ meeting: {...} }`) | key name for the link; required fields (title? language?); response shape |
  | `GET /meetings/{id}/transcript` | — | `{ status, transcript }` where transcript is a string **or** `[{speaker, text}]` | exact transcript shape |
  | `POST /meetings/{id}/stop` | `{}` | `{ status }` | — |
  | `POST /meetings/{id}/summarize` | `{}` | `{ summary }` | key name (`summary`?) |
  | `POST /meetings/{id}/chat` | `{ "message": "<q>" }` | `{ reply }` | request + response key names |

### 2.2 Direct data API (§4.2) — confirm request-body keys

- **Confirmed working live:** `POST /environments/{envId}/odoo/count/` with body `{ "model": "res.partner", "domain": [] }` → `{ "ok": true, "count": 2913 }`. 👍 The Odoo-ORM convention is right.
- Please confirm the body keys for the remaining operations (we expose a JSON-body editor, so exact keys matter):

  | Operation | Endpoint | App template body | Confirm keys |
  |---|---|---|---|
  | search | `.../odoo/search/` | `{ model, domain, fields, limit }` | `offset`, `order` supported? |
  | read-group | `.../odoo/read-group/` | `{ model, domain, groupby, fields }` | `lazy`? key names |
  | read | `.../odoo/read/` | `{ model, ids, fields }` | — |
  | fields | `.../odoo/fields/` | `{ model }` | `attributes` filter? |
  | sql | `.../sql/` | `{ query }` | key name; is read-only enforced server-side? |
  | report-entities | `GET /report-entities/` | — | response shape (list of `{model, name}`?) |

---

## 3. Payments (§4.3) — the important one

### 3.1 `GET /billing/plans/` — confirmed shape (already adapted)

Live response (this is what the app now parses):
```jsonc
{
  "ok": true, "enabled": true, "can_pay": true,
  "currency": "SAR", "price_per_million_halalas": 500, "token_balance": 0,
  "plans": [
    { "slug": "pro",   "name": "Pro",
      "cycles": { "monthly": {"price_halalas":7500,"price_sar":75.0,"price_usd":20.0,"tokens":250000000},
                  "annual":  {"price_halalas":76500,"price_sar":765.0,"price_usd":204.0,"tokens":3000000000} } },
    { "slug": "max-5x","name": "Max",
      "cycles": { "monthly": {"price_sar":375.0,...}, "annual": {"price_sar":4500.0,...} } }
  ]
}
```
> Note: our first cut assumed a flat `price` field and showed **0.00 SAR**. We fixed the app to read `cycles.monthly.price_sar` + top-level `currency`. Please keep this shape stable, or tell us if it changes.

### 3.2 Confirm the checkout + status shapes

We haven't exercised these live (we don't want to trigger a real charge). Please confirm:

| Endpoint | App currently sends | App currently reads | Confirm |
|---|---|---|---|
| `POST /billing/checkout/` | `{ "plan": "<slug>" }` | `{ url, ref }` (also accepts `payment_url`/`checkout_url`, `reference`/`payment_ref`) | Does it need **`cycle` (monthly/annual)**? quantity? exact response keys |
| `GET /billing/payment/{ref}/status/` | — | `{ status, is_paid }` | status enum values (`paid`/`failed`/`pending`…) |

### 3.3 ⛔ **Store-policy blocker — Paymob web checkout is not allowed for in-app token sales**

This is the key blocker for "payments working on Android + iOS":

- **Apple App Store — Guideline 3.1.1 (In-App Purchase):** digital content/credits consumed inside the app (our tokens) **must** be sold via Apple **In-App Purchase (StoreKit)**. A Paymob/web payment for tokens = **rejection**. (This is why the app currently hides the buy surface entirely on iOS.)
- **Google Play — Payments policy:** in-app digital goods **must** use **Google Play Billing**. Paymob for token purchases violates Play policy too and risks removal.

So the Paymob `billing/checkout/` flow **cannot ship as an in-app purchase** on either store. Two ways forward:

#### Option A (recommended) — Native IAP + backend receipt verification
Sell tokens through Apple StoreKit + Google Play Billing. This needs, **from the backend team**:

1. **A verification endpoint**, e.g.:
   ```
   POST /api/v1/billing/iap/verify/
   Authorization: Bearer <token>
   {
     "platform": "ios" | "android",
     "product_id": "saqqar_tokens_pro_monthly",
     "purchase_token": "<Android purchase token>",   // Android
     "receipt_data":  "<base64 / JWS transaction>",   // iOS
     "transaction_id": "<store transaction id>"
   }
   ```
   Server verifies the purchase with the store:
   - **iOS:** App Store Server API (`Get Transaction Info` / JWS) — or legacy `verifyReceipt`.
   - **Android:** Google Play Developer API `purchases.products.get` (needs a service account with Play access).

   Then **credits tokens idempotently keyed by `transaction_id`** (never double-credit on retries) and returns:
   ```json
   { "ok": true, "credited_tokens": 250000000, "token_balance": 250000000 }
   ```

2. **Product → tokens mapping** (each store product id → token grant), managed server-side so the app never decides the grant.

3. **Store server-to-server notifications** to handle refunds/chargebacks → debit tokens:
   - Apple **App Store Server Notifications v2**.
   - Google **Real-time Developer Notifications** (Pub/Sub).

4. A Play service-account JSON + App Store Connect API key (backend infra).

#### Option B — Keep Paymob, but web-only (no in-app sale)
Tokens are sold **only on the website**, with **no** prices/buy buttons in the mobile apps (this is already how iOS behaves). No store violation because nothing is sold in-app. Downside: users must leave the app to buy.

> **Recommendation:** Option A for a real in-app purchase experience. Until the verify endpoint + store products exist, we keep the buy surface **hidden** (iOS today; we can hide it on Android too on request).

---

## 4. Trial (§2) — works, one note

`GET /trial/status/` returns `200 { status: "none" }` for a fresh user (correct). For a trial to actually **provision**, an admin must have **auto-provisioning enabled** (per the hand-off). Please confirm it's on for the environments we'll demo, so we can test the full `pending → provisioning → ready` flow and the credentials payload.

---

## 5. What the mobile app already does (so you know where the seam is)

- Every endpoint above is **wired with UI + typed models + error handling**; the three "Preview" banners come off automatically once the schemas are confirmed / features enabled.
- Error envelopes (`{ ok:false, error }`) and `401/4xx/5xx` are already handled and surfaced to the user (verified live — e.g. the Meetings `409` shows its message cleanly).
- For **IAP (Option A)** the mobile side will add the `in_app_purchase` plugin and call `POST /billing/iap/verify/`. **We're blocked on:** the verify endpoint + the store products being created in App Store Connect / Play Console.

---

## 6. Checklist for the team lead

- [ ] Enable Meetings/Vexa on our tenants + send the §2.1 payload schemas.
- [ ] Confirm the §2.2 direct-data request-body keys (search/read-group/read/fields/sql/report-entities).
- [ ] Confirm the §3.2 checkout + payment-status shapes.
- [ ] **Decide payment strategy: Option A (native IAP + verify endpoint) or Option B (web-only).**
- [ ] If Option A: build `POST /api/v1/billing/iap/verify/` + product→tokens map + store S2S notifications; provide the store product IDs.
- [ ] Confirm trial auto-provisioning is enabled for the demo environments.
