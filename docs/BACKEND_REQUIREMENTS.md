# Saqqar Mobile — Backend Requirements

**From:** Mobile team (Flutter app)
**To:** Backend team (Django / `saqqar` web)
**Date:** 2026-06-08

The mobile app has implemented every item in the Sync & Gap Report that it can
own alone. The items below are **blocked on the backend** — mobile cannot finish
them without the server-side work or contract described here. Please implement
these and reply with the exact field names / payload shapes so we can wire the
mobile side immediately.

Ordered by priority.

---

## 1. (Gap K) FCM push delivery — **blocked: needs Firebase project + server send**

**Current mobile state:** device registration already works
(`POST /api/v1/devices/` with `{platform, token, app_version}`), and deep-links
are wired (`saqqar://conversation/<id>` and `saqqar://approval/<id>` already
route correctly inside the app). What's missing is the actual push pipeline.

**What we need from backend:**
1. **A Firebase project** for Saqqar (Android + iOS apps registered) and the
   resulting config files handed to mobile:
   - `google-services.json` (Android)
   - `GoogleService-Info.plist` (iOS)
   - The FCM **server key / service-account JSON** stays on the backend.
2. **Server sends an FCM message** on each of these events, to every active
   device row for the target user:
   - **Approval requested** — a write/shell approval entered `pending`.
   - **Run finished** — the agent finished a run (or errored).
   - **Quota warning** — a usage window crossed ≥80%, and again at 100%.
3. **Notification payload contract** — please send a `data` payload (not just
   `notification`) so we can deep-link on tap. Proposed shape:
   ```jsonc
   {
     "type": "approval | run_finished | quota_warning",
     "conversation_id": "<uuid>",     // for approval / run_finished
     "approval_id": "<uuid>",         // for approval
     "title": "...",                   // already-localized, optional
     "body": "...",                    // already-localized, optional
     "deep_link": "saqqar://approval/<uuid>"  // optional; we can also build it
   }
   ```
   - Localize `title`/`body` server-side per the user's language preference if
     possible; otherwise send a `type` + ids and we'll localize on-device.

**Once delivered:** mobile adds `firebase_messaging`, registers the token on
login, handles foreground/background, and routes taps via the existing
deep-link handler. Mobile work is ~1 day after the Firebase config + a sample
push land.

---

## 2. (Gap C) "Feature-locked" tool outcome — **blocked: needs a structured signal**

**Current mobile state:** mobile already gates by `plan.features` — it hides the
mic when `voice == false`, hides the Vault for Free users, and maps a `403`
from `/transcribe/` to a friendly "Voice is a Pro feature" message.

**What's missing:** when the agent tries a locked tool (postgres / github /
server_shell), the report says the tool "returns a feature-locked outcome." We
need to render that as a friendly inline hint ("Postgres queries need a Pro
plan") instead of raw text — **but the wire shape isn't documented and the
mobile message model doesn't currently carry it.**

**What we need from backend:** the exact shape of a feature-locked tool result
as it appears in the conversation snapshot / `messages/` response. Specifically:
- Is it a normal assistant message with special text, or a structured field?
- If structured, what marks it? e.g. a per-message/tool field like:
  ```jsonc
  {
    "role": "tool",
    "feature_locked": "postgres",   // the locked feature key, or
    "error_code": "feature_locked",
    "feature": "postgres"
  }
  ```
- Which feature keys can appear: `postgres | github | server_shell | voice`?

**Once delivered:** mobile maps the key to a localized upgrade hint with a
"See plans" CTA. ~half a day after we get the shape.

---

## 3. (Gap A, follow-up) Plan + usage on `/auth/me/` (or a `/usage/` endpoint) — **enhancement**

**Why:** today the `plan` object (slug, name, exempt, day/week/month usage
windows, features) is only delivered inside the **conversation snapshot**
(`GET /api/v1/conversations/{id}/`). That means the **Account → "Plan & usage"
card cannot show live usage bars until the user opens a chat**, because there's
no standalone source for it.

**Current mobile workaround:** the Account screen reads the public
`GET /api/v1/plans/` to show the current plan name + tier limits + a pricing
link. But it can only show **plan limits**, not **consumed-vs-cap usage**,
without the live windows.

**What we need from backend (either option works):**
- **Option A (preferred):** add the same `plan` object to
  `GET /api/v1/auth/me/`:
  ```jsonc
  {
    "ok": true,
    "user": { ... },
    "counts": { ... },
    "plan": {            // same shape as conversation.plan
      "plan": "free", "plan_name": "Free", "exempt": false,
      "day":  { "used": 0, "cap": 125000, "pct": 0, "remaining": 125000 },
      "week": { ... }, "month": { ... },
      "features": { "voice": false, "postgres": false, "github": false, "server_shell": false }
    }
  }
  ```
- **Option B:** a dedicated `GET /api/v1/usage/` returning the same `plan`
  object (mirrors the web `/usage/` page).

**Once delivered:** the Account "Plan & usage" card shows live day/week/month
bars + the plan badge **without** needing the user to open a chat first. ~half a
day after the field/endpoint lands.

---

## Summary table

| # | Gap | What backend must do | Mobile follow-up |
|---|-----|----------------------|------------------|
| 1 | K — FCM push | Firebase project + config files + send FCM on approval/run/quota with a `data` payload | Add `firebase_messaging`, register token, handle taps (~1 day) |
| 2 | C — locked-tool hint | Document the feature-locked tool-outcome shape (structured field + feature keys) | Map to localized upgrade hint (~½ day) |
| 3 | A — usage on `/me/` | Add `plan` to `/auth/me/` **or** add `GET /api/v1/usage/` | Show live usage bars on Account without opening a chat (~½ day) |

Everything else in the Sync & Gap Report (A core, B, D, E, F, G, H, I, J, L, M)
is **implemented on mobile and needs no backend change** — the relevant
endpoints (`/conversations/.../messages/`, `/projects/default/`, `/auth/me/`
PATCH, `/plans/`, approvals `model_label`/`record_count`, etc.) are already live
and consumed.
