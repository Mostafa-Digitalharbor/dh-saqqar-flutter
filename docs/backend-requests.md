# Backend changes requested by the Saqqar mobile client

This document lists API changes the mobile (Flutter) client needs the
backend team to ship so the experience stays in lockstep with the web
client at [saqqaar.com](https://saqqaar.com). Each section is
self-contained — pick whichever you can land first and the mobile will
benefit immediately.

The mobile code is already written to consume the canonical shapes
described below; once the backend deploys the changes, no follow-up
client release is required.

---

## 1) Persist `deep_think` per-conversation (sync web ↔ mobile)

### What we need

Make `deep_think` a **per-conversation server-side flag** — the same
shape `auto_approve` already has — so flipping the toggle from any
device (web or mobile) shows up on every other device on the next
poll.

### Current state

- `deep_think` is **only accepted per-message** in
  `POST /api/v1/conversations/{id}/messages/` (body field `deep_think`).
- The **conversation PATCH** endpoint
  (`PATCH /api/v1/conversations/{id}/`) does **not** accept
  `deep_think`. Per `docs/backend-api-contract.md` §`PATCH …` the
  whitelist is `title`, `is_archived`, `active_credential`,
  `auto_approve`.
- The conversation **GET** response does **not** include
  `deep_think`.

Result: the web persists the toggle in `localStorage` (device-local),
the mobile persists it in `SharedPreferences` (device-local), and
neither device knows about the other.

### What we want

Treat `deep_think` exactly like `auto_approve` — store it on the
`Conversation` row, accept it on PATCH, return it on GET.

### Required API shape

**`GET /api/v1/conversations/{id}/` response — add field:**

```json
{
  "conversation": {
    "id": "11cced9d-…",
    "title": "…",
    "auto_approve": true,
    "deep_think": false,        // ← NEW. Default false for existing rows.
    "is_running": false,
    "stop_requested": false,
    "context": { … },
    …
  },
  "messages": [ … ],
  …
}
```

**`PATCH /api/v1/conversations/{id}/` request — accept new field:**

```json
PATCH /api/v1/conversations/{id}/
{
  "deep_think": true          // ← NEW. Optional; only flip when supplied.
}

→ 200 OK
{
  "conversation": { …, "deep_think": true, … }
}
```

Whitelist updated: `title`, `is_archived`, `active_credential`,
`auto_approve`, **`deep_think`**.

**Per-message `deep_think` stays as-is** in `POST … /messages/` — it
should *override* the conversation-level setting for that specific
turn. The conversation-level value is the *default* the agent uses
when the message body omits `deep_think`.

### Implementation notes

- Add a `BooleanField(default=False)` column to the `Conversation`
  model. Migration should backfill with `False` for existing rows.
- Same permission / membership checks as the existing `auto_approve`
  PATCH branch — the user must own the conversation.
- Make sure the **web client** is updated in the same release to read
  + write the server-side value instead of `localStorage`. Otherwise
  the web won't sync with the mobile (the mobile change alone is
  half a sync).

### Mobile client status

✅ Already implemented and waiting:
- `Conversation.deepThink` is a nullable `bool?` field parsed from
  the top-level `deep_think` key (with a `context['deep_think']`
  fallback for forward-compat).
- `PATCH` requests already send `deep_think` at the top level **and**
  merged inside `context` (covering both possible persistence
  shapes).
- The chat toggle handler optimistically updates the snapshot and
  refetches from the server, so once the server responds with the
  real value, it wins.

Nothing in mobile needs to change once the backend lands this.

---

## 2) Update `user.last_login` on mobile token login

### What we need

When a user signs in from the mobile app, `auth.User.last_login`
should be updated server-side — same way it updates when they sign
in from the web.

### Current state

- Mobile signs in via `POST /api/v1/auth/login/` (token-based auth).
- This endpoint does **not** call Django's `update_last_login` signal,
  so `user.last_login` stays at whatever the last *web* login set it
  to.
- The mobile account screen surfaces `last_login` from `GET /auth/me/`,
  so the user sees the stale value and gets confused ("I just signed
  in, why is it showing yesterday's date?").
- The web works correctly because `django.contrib.auth.login(
  request, user)` fires `user_logged_in`, which Django wires to
  `update_last_login` by default.

### What we want

Mobile token logins should update `last_login` server-side. After a
successful sign-in, `GET /auth/me/`'s `last_login` field should
reflect the moment the user signed in from the mobile app — and that
value should be visible to the web client too on its next refresh.

### Implementation notes

Inside the existing `POST /api/v1/auth/login/` view, after the user
is authenticated and the bearer token is issued, fire the canonical
signal so any receiver wired up gets it (not just `update_last_login`):

```python
from django.contrib.auth.signals import user_logged_in

user_logged_in.send(
    sender=user.__class__,
    request=request,
    user=user,
)
```

Or, if you'd rather skip the signal and update the column directly:

```python
from django.contrib.auth.models import update_last_login

update_last_login(None, user)
```

Either path updates `last_login`; the signal version is preferable
because any future receiver (audit log, analytics, "you signed in
from a new device" email) hooks in automatically.

### Apply the same fix to `register`, if applicable

`POST /api/v1/auth/register/` already returns an authenticated
session token. If the convention is that account creation also counts
as a login (which is what the web client does), fire the same signal
there too so the first `last_login` matches the moment the account
was created from the mobile.

### Mobile client status

✅ Nothing to change on mobile. The account screen already reads
`last_login` from `GET /auth/me/` ([profile_hero.dart](../lib/features/account/widgets/profile_hero.dart))
and renders it inline. Once the backend updates the column on mobile
login, the user sees the right timestamp without any client change.

---

## Verification checklist (for the backend deploy)

After deploying both changes, run through these manual checks against
staging:

### `deep_think` sync

1. Sign in on **mobile** with account A.
2. Open any conversation — note the deep-think toggle state.
3. Sign in on **web** with the same account A in another tab.
4. Open the same conversation on web.
5. Toggle deep-think **on** from the web.
6. Within ~15 seconds (mobile's idle poll cadence) the mobile toggle
   should flip to **on** without any user input.
7. Toggle deep-think **off** from mobile.
8. Within a few seconds the web should show **off** on its next
   refresh / poll.

### `last_login` update on mobile sign-in

1. On web, note `last_login` shown in the account / profile page —
   call it T0.
2. Sign out on mobile, sign in again — call the moment T1.
3. Open the **mobile** account screen → `last_login` should show T1
   (not T0).
4. Refresh the **web** account page → `last_login` should also show
   T1.

If either step fails, the backend change didn't land cleanly.

---

## Contact / questions

Mobile owner: see the Saqqar mobile repo's CODEOWNERS / README. Ping
on the same channel used for `docs/backend-api-contract.md`
discussions.
