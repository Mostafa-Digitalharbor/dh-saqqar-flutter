# Mobile → Backend: what the core surface still needs

**To:** Backend team lead
**From:** Mobile
**Date:** 2026-07-25
**Re:** Chats / chat / approvals. Every claim below was verified against
production; the method is stated so you can re-run it.

Companion to `MOBILE_BACKEND_GAPS_AND_PAYMENTS.md` (2026-07-23) covering the
§4 endpoints (Apps, Trial, direct data, payments). Those asks stand unchanged.

> **Withdrawn 2026-07-28 — Meetings (§4.1).** Please do not build it. The
> product owner is taking that feature back in-house for now, so the mobile
> entry point has been removed from the Account screen and there is no client
> waiting on those endpoints. Everything else in the companion document is
> still wanted. We'll re-raise it if and when it comes back.

---

## 0. How this was verified

A probe was run **inside the signed-in app**, reusing its own session, against
`https://saqqaar.com` on an account with **100+ conversations** and a
**5,340-message** conversation. Every call was a GET.

Two methodological points, because earlier drafts of this document got things
wrong and were not sent:

- **Per-row claims are checked across all 100 rows**, not one. A field absent
  from a single row may simply be empty on that row.
- **Each "missing field" is cross-referenced against an independent source.**
  For `pending_approvals` we pulled the flat `/approvals/?status=pending` feed,
  found conversations that provably have 1–4 pending approvals, and checked
  those specific rows.

**Net result: the backend ask is small — 3 items. Most of the work is ours.**

---

## 1. ⛔ `pending_approvals` and `is_running` are absent from every list row

**Verified.** Union of keys across **all 100** rows of `GET /conversations/`:

```
created_at  environment  files_count  id  is_archived
last_message_preview  message_count  project  title  updated_at
```

```
"pending_approvals" present on   0/100 rows
"is_running"        present on   0/100 rows
"is_pinned"         present on   0/100 rows
```

Cross-checked against the flat approvals feed — four conversations with
**1, 1, 1 and 4** pending approvals respectively all return `ABSENT` on the
row. So this is not "omitted when zero"; the field does not exist.

### `pending_approvals` — the cost

The Chats list polls every 20 s and fires **three** requests per tick, one of
which exists solely to rebuild a per-row count:

```
GET /api/v1/conversations/         ← the list
GET /api/v1/approvals/?limit=100   ← only to count pending per conversation
GET /api/v1/artifacts/?limit=100   ← only to count files per conversation
```

`files_count` already lets us drop the artifacts call (§4). `pending_approvals`
would let us drop the approvals call, taking the poll from **3 requests to 1**
for every user, every 20 s.

There is a correctness cost too: both feeds are capped at 100 rows, so on a
busy account the derived counts are wrong. Measured — see §4.

### `is_running` — the cost

The client parses `is_running` on list rows; it is never present, so it is
always `false`. The Chats list therefore **cannot show the "Saqqar is working"
indicator for any conversation the user has not opened** — which is precisely
when it would be useful.

---

## 2. ⛔ No pin endpoint

```
GET /api/v1/conversations/{id}/pin/                  → 404
GET /api/v1/conversations/{id}/stop/                 → 405   (registered, wrong verb)
GET /api/v1/conversations/{id}/definitely-not-real/  → 404   (control)
```

The 405 on a route we know exists, against 404 on both `pin` and an invented
path, makes this conclusive: `pin` is unregistered.

Pinning works in the app but is **local-only** — lost on reinstall, invisible
on web and on the user's other devices. We need `POST` / `DELETE
/conversations/{id}/pin/` and `is_pinned` on the list row.

---

## 3. ❓ One question: what values does `conversation.quota.kind` take?

The snapshot returns:

```jsonc
"conversation": {
  "quota": { "kind": null, "token_balance": 0 }
}
```

and there is **no** top-level `quota_exceeded` key (verified: absent).

The client currently reads `quota_exceeded` from the **top level** — a key that
does not exist — so **the over-quota banner has never been able to fire**.
That's our bug and we'll fix it, but we need to know what to read:

- What values does `kind` take when a turn is blocked (`"day"`/`"week"`/`"month"`?), and is `null` the only "not exceeded" value?
- Does it persist on every poll while the user remains over cap, or only on the
  response to the blocked send?

We could not test the blocked path — the account is not over its cap.

---

## 4. What we're fixing on our side (no backend work)

Listed so you can see which reported symptoms were never yours. Three of these
were wrongly escalated to you in earlier drafts.

### 4.1 Paging — cursor paging already works; we weren't using it

**We were wrong twice about this.** First we reported "users cannot read their
own history" as a backend cap. Then we retracted it after seeing `?limit=200`
work. Both were wrong. The truth:

```
limit=500  → 500 messages
limit=1000 → 500 messages     ← hard server cap at 500
limit=2000 → 500 messages
```

Our client pages by growing `limit`: 40 → 120 → 200 → 280 → 360 → 440 → **520**.
At 520 the server returns 500, our `hasMoreOlder` test (`returned >= requested`)
goes false, and **paging stops permanently at 500 messages**. On the
5,340-message conversation used for this test, **4,840 messages are
unreachable** from the app.

The fix is entirely ours, because you already ship cursor paging:

```
oldest_cursor   = "2026-07-06T12:08:10.875000+00:00|e3920837-…"
has_more_before = true

GET /conversations/{id}/?before=<oldest_cursor>&limit=30
→ 200, 30 messages, strictly older than the previous page ✅
```

The format is `<iso-timestamp>|<message-id>` — your 400 response says so
explicitly, which is genuinely good API design and saved us guessing.

**Consequence for you: the `GET /conversations/{id}/messages/` ask is
withdrawn.** It returns 405 today, but it is redundant — the snapshot endpoint
already does everything we need. Please don't build it.

### 4.2 File counts — ours are wrong today, yours are right

`files_count` on the row disagrees with our `/artifacts/?limit=100`-derived
count on **41 of 100 rows** — e.g. row says `188`, our derivation says `90`;
row says `9`, ours says `0`.

The row is the correct one: the flat feed is truncated at 100 artifacts
account-wide, so it cannot represent a conversation with 188. **The file counts
the app shows today are wrong on ~41% of conversations.** We'll switch to
`files_count` and delete the derivation.

### 4.3 Other client-side work

| Item | Note |
|---|---|
| N+1 project/environment enrichment | Dead code — you've shipped both fields on the row. Deleting. |
| Per-message `tokens` ignored | You send it on every message. Our in-chat usage meter was removed for "no data available". Re-adding. |
| Quota key read from the wrong place | §3 — fixing once you confirm the `kind` values. |

---

## 5. Already shipped — verified, no action needed ✅

| Thing | Status |
|---|---|
| `project`, `environment`, `files_count` on list rows | ✅ 100/100 rows |
| `conversation.plan` | ✅ `day week month features exempt plan plan_name token_balance` |
| `conversation.deep_think` | ✅ closes `backend-requests.md` §1 |
| `model_label` + `record_count` on approvals | ✅ snapshot and flat feed |
| Cursor paging (`before` / `oldest_cursor` / `has_more_before`) | ✅ works |
| Per-message `tokens` | ✅ present |

---

## 6. Smaller items

1. **System-injected user messages.** Verified: message roles across 200 rows
   are `tool: 89, assistant: 94, user: 17` — no distinct role — and the message
   key union is `attachments content created_at id role tokens tool_name
   tool_payload`, i.e. **no `is_system` flag**. Approval acknowledgements and
   `[agent-control]` directives are stored as `role: "user"`, so the client
   **sniffs message content** to hide them (4 such messages in the sample). A
   user who genuinely types "approved" gets their own message hidden. Please
   mark them server-side.

2. **`POST /auth/logout/` returns `200` without a bearer token.** Should be
   `401`.

---

## 7. The ask, in full

1. `pending_approvals` on the conversation-list row.
2. `is_running` on the conversation-list row.
3. `POST`/`DELETE /conversations/{id}/pin/` + `is_pinned` on the row.
4. Answer §3: the values of `conversation.quota.kind`.
5. When convenient: `is_system` on messages (§6.1), and `401` on logout (§6.2).

**Withdrawn from earlier drafts:** `GET /conversations/{id}/messages/` cursor
paging (redundant), a larger `?limit=` ceiling (not needed with `before`), and
`conversation.plan` (already shipped).

Nothing here should interrupt the §4 payments work in flight.
