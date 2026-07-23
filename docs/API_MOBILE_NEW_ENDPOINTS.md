# Saqqar Mobile API — New Endpoints (Apps · Trial · Billing history)

Hand-off for the mobile developer. Documents **three feature areas that the
web app has but the mobile client did not yet have an API for**, now added
server-side:

1. **Saqqar Apps** — the guided implementation packages (ZATCA, WhatsApp,
   Chart of Accounts, Bank reconciliation …).
2. **Managed Odoo Trial** — request a hosted trial Odoo and poll provisioning.
3. **Billing history & receipts** — a user's own past payments + PDF receipts.

For auth, conversations, attachments, etc., see [`API_MOBILE.md`](./API_MOBILE.md).
A separate section at the end ([§4](#4-already-live-server-side--not-yet-in-the-app))
lists endpoints that **already exist** on the server but are missing from the
mobile endpoint map, so the app team can adopt them without new backend work.

**Conventions**

- **Base URL:** `https://saqqaar.com`
- All new endpoints are mounted under **both** `/api/` and `/api/v1/`. Pin the
  app to `/api/v1/`.
- **Auth:** every endpoint here needs `Authorization: Bearer <token>` unless
  stated otherwise. A missing/invalid token returns `401` with
  `{ "ok": false, "error": "Not authenticated.", "auth": false }`.
- **Errors:** JSON endpoints return `{ "ok": false, "error": "<message>" }`
  with an appropriate HTTP status. Wrong HTTP method returns `405`.
- All responses are `application/json` unless noted (the receipt endpoint
  returns a PDF).

**Table of contents**

- [1. Saqqar Apps](#1-saqqar-apps)
- [2. Managed Odoo Trial](#2-managed-odoo-trial)
- [3. Billing history & receipts](#3-billing-history--receipts)
- [4. Already live server-side — not yet in the app](#4-already-live-server-side--not-yet-in-the-app)
- [5. Error matrix](#5-error-matrix)
- [6. Testing checklist](#6-testing-checklist)

---

## 1. Saqqar Apps

Guided setups the user can launch. Each "app" is a pre-built task; launching
one creates a conversation tagged with the package and seeds the agent's
opening message, so the client just opens the chat on the greeting. There is
no per-app backend — the agent drives every task with its existing tools.

### 1.1 List apps

```
GET /api/v1/apps/
Authorization: Bearer <token>
```

**Response `200`**

```json
{
  "ok": true,
  "apps": [
    {
      "slug": "zatca",
      "name": "ZATCA e-invoicing",
      "tagline": "Onboard Saudi Fatoora Phase-2 e-invoicing on your Odoo — CSR, OTP, and go-live.",
      "category": "Compliance · KSA",
      "group": "Finance",
      "accent": "#14B8A6",
      "icon_svg": "<svg viewBox=\"0 0 24 24\" ...>…</svg>",
      "env_required": true
    }
    // … one object per package
  ]
}
```

| Field          | Type    | Notes                                                             |
|----------------|---------|-------------------------------------------------------------------|
| `slug`         | string  | Stable id; use it in the launch call.                             |
| `name`         | string  | Display title.                                                    |
| `tagline`      | string  | One-line description for the tile.                                |
| `category`     | string  | Short chip label (e.g. `Accounting`, `Messaging`).               |
| `group`        | string  | Filter taxonomy: `Accounting` · `Finance` · `Integrations`.       |
| `accent`       | string  | Hex color to tint the tile/icon.                                  |
| `icon_svg`     | string  | Inline 24×24 SVG (`stroke`/`fill="currentColor"`). Render directly, tint with `accent`. |
| `env_required` | boolean | If `true`, the task needs a bound Odoo environment.               |

### 1.2 Launch an app

Creates a package-tagged conversation and seeds the agent's opening turn (an
assistant message — **no** user bubble, **no** background run yet). The run
begins when the user sends their first reply.

```
POST /api/v1/apps/{slug}/launch/
Authorization: Bearer <token>
Content-Type: application/json

{ "environment_id": "<uuid>" }      // optional
```

- `environment_id` *(optional)* — bind an environment the user owns. Anything
  else (missing, malformed, not owned) is ignored and the agent asks the user
  to pick one in-chat.

**Response `201`**

```json
{
  "ok": true,
  "conversation_id": "6f1c…-uuid",
  "app": { "slug": "zatca", "name": "ZATCA e-invoicing", "...": "…" }
}
```

**Then:** open the conversation with
`GET /api/v1/conversations/{conversation_id}/` to load the seeded opening
message, and let the user reply to start the run (normal
`POST …/messages/` flow).

**Errors:** `404` unknown slug · `401` unauthenticated · `405` non-POST.

---

## 2. Managed Odoo Trial

Lets a signed-in user request a hosted trial Odoo (no self-hosting) and poll
until it's ready. Mirrors the web `/trial/` flow, but the API attaches the
request to the **already-authenticated** user (the web page also creates the
account from a form — not needed here). A user has **exactly one** trial.

### 2.1 Request a trial

```
POST /api/v1/trial/
Authorization: Bearer <token>
Content-Type: application/json

{
  "company_name": "Acme Co",   // required
  "full_name":    "Sara N.",   // optional (defaults to the account name)
  "work_email":   "sara@acme.com", // optional (defaults to account email)
  "company_size": "11-50",     // optional
  "industry":     "Retail",    // optional
  "country":      "SA",        // optional
  "phone":        "+9665…"     // optional
}
```

**Response `201`** (new request created)

```json
{ "ok": true, "trial": { "status": "pending", "ready": false } }
```

**Response `200`** (user already had a trial — idempotent, no duplicate)

```json
{ "ok": true, "existing": true, "trial": { "status": "provisioning", "ready": false } }
```

**Errors:** `400` if `company_name` is missing · `401` · `405` non-POST.

### 2.2 Poll trial status

Polling this endpoint also **kicks off provisioning** on the first call (when
an admin has enabled auto-provisioning), exactly like the web status page.

```
GET /api/v1/trial/status/
Authorization: Bearer <token>
```

**Responses `200`** — shape depends on state:

```jsonc
// no trial requested yet
{ "ok": true, "status": "none", "ready": false }

// building
{ "ok": true, "status": "provisioning", "ready": false }

// ready — includes the Odoo credentials
{
  "ok": true, "status": "ready", "ready": true,
  "url": "https://acme-….odoo.com",
  "db": "…-main-…",
  "login": "admin",
  "password": "•••••••"
}

// failed
{ "ok": true, "status": "failed", "ready": false, "error": "…reason…" }
```

| `status`        | Meaning                                              |
|-----------------|------------------------------------------------------|
| `none`          | User has no trial request.                            |
| `pending`       | Queued, provisioning not started.                    |
| `provisioning`  | Building the Odoo (can take several minutes).         |
| `ready`         | Live; credentials included in the response.           |
| `failed`        | Provisioning failed; `error` explains why.            |

**Polling guidance:** poll every ~5 s while `ready` is `false` and `status`
is `pending`/`provisioning`. Stop on `ready` or `failed`.

> ⚠️ **Security:** when `ready`, the response contains live **admin
> credentials**. Treat them like a secret — never log them, and show the
> password only behind a reveal control.

---

## 3. Billing history & receipts

A user's own payments, plus a PDF receipt per paid payment. Strictly scoped to
the caller — a reference belonging to someone else is a `404`, never a
receipt with their name on it.

### 3.1 Payment history

```
GET /api/v1/billing/history/
Authorization: Bearer <token>
```

**Response `200`**

```json
{
  "ok": true,
  "rows": [
    {
      "when": "2026-07-20T10:15:00+00:00",
      "what": "Pro — monthly",
      "amount": 99.0,
      "currency": "SAR",
      "tokens": 5000000,
      "tokens_m": 5.0,
      "status": "paid",
      "is_paid": true,
      "is_failed": false,
      "ref": "A1B2C3D4",
      "receipt_ref": "A1B2C3D4E5F6…"
    }
  ],
  "token_balance": 4200000,
  "total_purchased": 5000000,
  "has_any": true
}
```

| Field             | Type            | Notes                                                     |
|-------------------|-----------------|-----------------------------------------------------------|
| `when`            | string \| null  | ISO-8601 timestamp (paid time, else created time).        |
| `what`            | string          | Human label (`"Pro — monthly"`, `"Token recharge"`, …).   |
| `amount`          | number          | Charged amount in `currency`.                             |
| `currency`        | string          | Defaults to `SAR`.                                        |
| `tokens`          | integer         | Tokens granted.                                           |
| `tokens_m`        | number          | Same, in millions (convenience).                          |
| `status`          | string          | Gateway status (`paid` / `failed` / …).                   |
| `is_paid`         | boolean         | Convenience flag.                                         |
| `is_failed`       | boolean         | Convenience flag.                                         |
| `ref`             | string          | Short (8-char) reference to quote to support.             |
| `receipt_ref`     | string \| null  | Full reference for the receipt call. `null` unless paid.  |
| `token_balance`   | integer (top)   | Current remaining balance.                                |
| `total_purchased` | integer (top)   | Sum of tokens across paid rows.                           |

Rows are newest-first, capped at the last 100.

### 3.2 Download a receipt (PDF)

```
GET /api/v1/billing/receipt/{receipt_ref}/
Authorization: Bearer <token>
```

Use the `receipt_ref` from a **paid** row.

- **Success `200`** → `Content-Type: application/pdf`,
  `Content-Disposition: attachment; filename="saqqar-receipt-<n>.pdf"`.
  Save/preview the bytes.
- **`404`** if the reference isn't the caller's, or the payment isn't paid.
- **`500`** if the PDF couldn't be rendered (retry later).

> **Store-policy note:** paying for plans in-app via Paymob
> (`billing/checkout/`, [§4](#4-already-live-server-side--not-yet-in-the-app))
> may conflict with App Store / Google Play IAP rules. **History and receipts
> are read-only and safe.** Confirm the purchase surface with the store
> guidelines before wiring checkout into the app.

---

## 4. Already live server-side — not yet in the app

These have **working endpoints already** — no backend change needed, they were
just missing from the mobile endpoint map. Adopt as needed.

### 4.1 Meetings (Vexa transcription)

| Method | Path                                        | Purpose                          |
|--------|---------------------------------------------|----------------------------------|
| POST   | `/api/v1/meetings/`                          | Start a meeting transcription.   |
| GET    | `/api/v1/meetings/{id}/transcript`           | Fetch the transcript.            |
| POST   | `/api/v1/meetings/{id}/stop`                 | Stop the meeting.                |
| POST   | `/api/v1/meetings/{id}/summarize`            | Summarize the meeting.           |
| POST   | `/api/v1/meetings/{id}/chat`                 | Chat over the transcript.        |

*(Source: `odoo_agent/views_meetings.py`.)*

### 4.2 Direct data API (read-only Odoo, no agent / no LLM cost)

Deterministic reads against a bound environment — cheaper than an agent turn.

| Method | Path                                                     | Purpose                        |
|--------|----------------------------------------------------------|--------------------------------|
| POST   | `/api/v1/environments/{envId}/odoo/search/`              | Search records.                |
| POST   | `/api/v1/environments/{envId}/odoo/count/`               | Count records.                 |
| POST   | `/api/v1/environments/{envId}/odoo/read-group/`          | Grouped aggregates.            |
| POST   | `/api/v1/environments/{envId}/odoo/read/`                | Read records by id.            |
| POST   | `/api/v1/environments/{envId}/odoo/fields/`              | Field metadata.                |
| POST   | `/api/v1/environments/{envId}/sql/`                      | Read-only SQL.                 |
| GET    | `/api/v1/report-entities/`                               | Entity list for report filter. |

*(Source: `odoo_agent/views_data_api.py`.)*

### 4.3 Billing checkout (see store-policy note above)

| Method | Path                                        | Purpose                          |
|--------|---------------------------------------------|----------------------------------|
| GET    | `/api/v1/billing/plans/`                     | Plans (Paymob view).             |
| POST   | `/api/v1/billing/checkout/`                  | Start a checkout.                |
| GET    | `/api/v1/billing/payment/{ref}/status/`      | Poll a payment's status.         |

### 4.4 Artifact detail

| Method | Path                          | Purpose                         |
|--------|-------------------------------|---------------------------------|
| GET    | `/api/v1/artifacts/{id}/`     | One artifact's detail/metadata. |

---

## 5. Error matrix

| Status | Body                                                        | When                                            |
|-------:|-------------------------------------------------------------|-------------------------------------------------|
| 200    | feature JSON                                                | OK (GET / idempotent trial re-request).         |
| 201    | feature JSON                                                | Created (app launch, new trial request).        |
| 400    | `{ "ok": false, "error": "…" }`                             | Bad input (e.g. trial without `company_name`).  |
| 401    | `{ "ok": false, "error": "Not authenticated.", "auth": false }` | Missing/invalid bearer token.              |
| 404    | `{ "ok": false, "error": "…" }`                             | Unknown app slug / receipt not found or foreign.|
| 405    | Django default                                              | Wrong HTTP method.                              |
| 500    | `{ "ok": false, "error": "…" }`                             | Receipt render failure (retryable).             |

---

## 6. Testing checklist

**Apps**
- [ ] `GET /api/v1/apps/` returns the package list with `icon_svg` + `accent`.
- [ ] `POST /api/v1/apps/{slug}/launch/` returns `201` + `conversation_id`;
      opening the conversation shows one assistant message and no user bubble.
- [ ] Launch with a valid owned `environment_id` binds it; a bogus id is ignored.
- [ ] Unknown slug → `404`.

**Trial**
- [ ] First `POST /api/v1/trial/` → `201 pending`; second → `200 existing`.
- [ ] `POST` without `company_name` → `400`.
- [ ] `GET /api/v1/trial/status/` transitions `none → pending/provisioning →
      ready` (or `failed`); credentials appear only on `ready`.
- [ ] Credentials are never written to logs/analytics.

**Billing**
- [ ] `GET /api/v1/billing/history/` returns rows + balance; empty account →
      `rows: []`, `has_any: false`.
- [ ] `GET /api/v1/billing/receipt/{receipt_ref}/` on a paid row returns a PDF.
- [ ] A foreign/unknown reference → `404`.

---

_New endpoints implemented in `odoo_agent/views_api_apps.py`,
`views_api_trial.py`, `views_api_billing_history.py`; routed in
`odoo_agent/urls.py`. They reuse the same `api_login_required` bearer/session
auth as the rest of the mobile API. Reference for the full route list:
`odoo_agent/urls.py`._
