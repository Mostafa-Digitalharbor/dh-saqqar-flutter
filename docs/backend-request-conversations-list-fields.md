# Backend request — add 2 fields to `GET /conversations/`

**Priority:** high · **Effort:** small · **Blocks:** Chats-list accuracy + speed on mobile

We need **two** fields added to each conversation row in the list response.
Nothing else changes. This is a self-contained, quick win.

---

## The endpoint

```
GET /api/v1/conversations/
```

## What to add — per conversation row

Add these to every item in the list array:

```jsonc
{
  "id": "…",
  "title": "…",
  "updated_at": "…",
  "message_count": 147,          // already returned — unchanged

  // ── ADD #1: project + environment ──────────────────────────
  "project":     { "id": "…", "name": "Default" },       // this conversation's project
  "environment": { "id": "…", "name": "ZAD Staging" },   // this conversation's environment

  // ── ADD #2: produced-documents count ───────────────────────
  "files_count": 9               // number of artifacts produced in THIS conversation
}
```

### Accepted shapes (either works)

- **Project / environment** — either a nested object `{ "id": "...", "name": "..." }`,
  or a flat string pair `"project_name": "Default"`, `"environment_name": "ZAD Staging"`.
  Omit the field (or send `null`) when the conversation has none bound — the app
  hides the tag rather than showing a placeholder.
- **files_count** — a plain integer, counted **server-side per conversation**
  (all artifacts produced in that conversation, not a global slice).

---

## Why (the 2 problems this fixes)

**1. Project · environment is slow to appear on the card.**
The list response omits them today, so the mobile app fetches them **one request
per conversation** (`GET /conversations/{id}/?since=…`) just to read the
project/environment name. For a user with 30 conversations that is ~30 extra
requests every time the Chats tab opens — which is why the tags fade in late.
Returning them in the list makes them appear **instantly**, and collapses those
~30 requests into the single list call.

**2. Document count is inaccurate.**
The app currently derives `files_count` from `GET /artifacts/?limit=100` — the
newest **100 artifacts across the whole account** — then groups them by
conversation. Any account with more than 100 artifacts undercounts (or shows 0)
for older conversations, because their files fall off that global page. A
**per-conversation count computed server-side** is always correct.

---

## Client side — no release needed for #1

The mobile model **already parses** `project` / `environment` (both the nested
and flat shapes) straight from the list row. The moment the backend includes
them, they light up with no new app build. `files_count` on the row needs a
tiny client change to read it from the row instead of the global feed — we ship
that as soon as the field lands.

---

## Acceptance

- [ ] `GET /api/v1/conversations/` returns `project` + `environment` (name) per row.
- [ ] `GET /api/v1/conversations/` returns `files_count` (per-conversation integer) per row.
- [ ] Rows with no bound project/environment omit the field (or send `null`) — no placeholder.
