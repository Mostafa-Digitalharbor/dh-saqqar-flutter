# Saqqar Mobile API — Plan, Usage & Billing

Everything the mobile app needs for the **"My Plan / Billing"** screen: current
plan, expiration/renewal date, consumed & remaining tokens, billing history, and
receipt download.

- **Base URL:** `https://saqqaar.com`
- **Auth:** every endpoint below takes the app's bearer token —
  `Authorization: Bearer <token>` (the token returned by `/api/v1/auth/login/`,
  `/auth/google/`, etc.). Unauthenticated → `401 {"ok": false, "error": "…"}`.
- **Versioning:** use the `/api/v1/…` prefix.
- **Payments are web-only.** The app never processes a payment; to buy/upgrade,
  open the web (`/pricing/?plan=<slug>`, ideally via the one-time handoff in
  §5). The endpoints below are all **read-only** except the handoff.

---

## 1. Current plan + usage — `GET /api/v1/usage/`

One call returns the current plan, its status/cycle, the period-end date, the
prepaid balance (**left tokens**), and per-window **consumption**.

**Response**

```json
{
  "ok": true,
  "plan": "pro",
  "plan_name": "Professional",
  "status": "active",
  "cycle": "annual",
  "expires_at": "2027-03-04T10:00:00+00:00",
  "windows": {
    "plan": "pro",
    "plan_name": "Professional",
    "exempt": false,
    "token_balance": 1250000000,
    "day":   { "used": 163927,   "cap": 15000000,   "pct": 1,  "remaining": 14836073 },
    "week":  { "used": 900000,    "cap": 60000000,   "pct": 2,  "remaining": 59100000 },
    "month": { "used": 3200000,   "cap": 170000000,  "pct": 2,  "remaining": 166800000 },
    "features": { "voice": true, "postgres": true, "github": true, "server_shell": true }
  }
}
```

**Map to the screen**

| Screen item | Field |
|---|---|
| Current plan | `plan` (slug) · `plan_name` (display) |
| Plan status | `status` — `active` \| `trialing` \| `canceled` \| `past_due` |
| Billing cycle | `cycle` — `monthly` \| `annual` |
| **Expiration date** | `expires_at` (see note) |
| **Left tokens** | `windows.token_balance` (prepaid), and each window's `remaining` |
| **Consumed tokens** | `windows.month.used` (or `day` / `week`) |
| Usage bars | per window: `used` / `cap` / `pct` / `remaining` |

> **Note on `expires_at`.** Saqqar billing is **prepaid** — access is governed by
> `token_balance` + the day/week/month caps, so a plan is **not** cut off on a
> date. `expires_at` is the informational *"current period ends / renews on"* date
> (derived from the last paid plan payment + its cycle, or the stored period end).
> It is **`null`** for free / never-paid accounts. Display it as *"Renews on …"* /
> *"Current period ends …"*, not a hard cutoff. Entitlement = `token_balance` and
> the window caps.

---

## 2. Plan catalogue (for the upgrade screen) — `GET /api/v1/plans/`

Matches `saqqaar.com/pricing`. Use it to render the tiers a user can move to.

```json
{
  "ok": true,
  "current": "pro",
  "plans": [
    {
      "slug": "pro",
      "name": "Professional",
      "price_monthly_cents": 2000,
      "price_annual_cents": 1000,
      "daily_tokens": 0, "weekly_tokens": 0, "monthly_tokens": 35000000,
      "features": { "…": "…" }
    }
  ]
}
```

Prices are in **USD cents** and are the source of truth (what checkout charges).
Slugs: `free`, `starter`, `max-5x` (Solo), `pro` (Professional), `max-20x`
(Business).

---

## 3. Billing history — `GET /api/v1/billing/history/`

The caller's most recent **100** payments (no pagination) + current balance.

```json
{
  "ok": true,
  "rows": [
    {
      "when": "2026-08-01T09:12:00+00:00",
      "what": "Professional — annual",
      "amount": 75.0,
      "currency": "SAR",
      "tokens": 250000000,
      "tokens_m": 250.0,
      "status": "paid",
      "is_paid": true,
      "is_failed": false,
      "ref": "A1B2C3D4",
      "receipt_ref": "pay_9f3c…full-reference"
    }
  ],
  "token_balance": 1250000000,
  "total_purchased": 250000000,
  "has_any": true
}
```

- `when` — ISO-8601 (paid time, else created time).
- `what` — human description (plan + cycle, or `"Token recharge"`). Plan/cycle/kind
  are folded into this string; there are no separate fields.
- `amount` — decimal in `currency` (default `SAR`).
- `ref` — short reference to show / quote to support.
- **`receipt_ref`** — pass to §4 to download the PDF. `null` when not paid (no receipt).

---

## 4. Download a receipt — `GET /api/v1/billing/receipt/<receipt_ref>/`

- `<receipt_ref>` = the `receipt_ref` from a **paid** history row.
- **Returns a PDF** — `Content-Type: application/pdf`,
  `Content-Disposition: attachment; filename="saqqar-receipt-<n>.pdf"`. Includes a
  ZATCA Phase-1 QR + VAT details.
- Bearer-authed and **scoped to the caller** — another user's ref → `404`. Only
  paid payments have a receipt (others → `404`).
- **Mobile:** stream the response bytes to a file and open with a PDF viewer /
  share sheet. On error it returns JSON `{"ok": false, "error": "…"}` (404/500).

---

## 5. Pay on the web without re-logging-in — `POST /api/v1/auth/web-session/`

When the user taps "Upgrade / Manage plan", mint a one-time hand-off URL and open
it in the system browser so they land on the web **already signed in**.

**Request** (bearer)

```json
{ "next": "/pricing/?plan=pro" }
```

**Response**

```json
{ "ok": true, "url": "https://saqqaar.com/auth/handoff/?t=<one-time-token>" }
```

Open `url` in the external browser. The token is **single-use** and valid ~120s;
`next` must be a same-site relative path (server-validated). After payment, the
app should **re-fetch `/api/v1/usage/` and `/api/v1/billing/history/` on resume**
to reflect the new plan (no callback/webhook to mobile).

---

## Error shape

All JSON endpoints use `{"ok": false, "error": "<message>"}` with an appropriate
status: `401` (unauthenticated), `404` (not found / not yours), `400`
(bad request), `402` (over quota, on message send). The receipt endpoint returns
the PDF on success, or a JSON error on failure.
