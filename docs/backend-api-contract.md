# Saqqar Mobile — Backend API Contract

> **Audience:** Saqqar backend team (Django / DRF).
> **Status:** Binding spec for v1 of the mobile client.
> **Last updated:** 2026-05-14.
> **Counterpart:** Mobile client lives at `e:\mostafa\Companies\Digital_Harbor\Saqqar\saqqar_app`. Endpoint paths it expects are declared in [`lib/core/network/api_endpoints.dart`](../lib/core/network/api_endpoints.dart) — this document is the source of truth those paths track.

---

## 1. Overview

Saqqar is a chat-driven AI agent that operates Odoo ERP systems. Web client lives at [https://saqqaar.com](https://saqqaar.com). This document defines the HTTP/SSE contract the **mobile** client (Flutter, iOS + Android) needs the backend to expose so it can render the same conversations, vault, approvals, and artifacts a user sees on the web.

Three product invariants drive the contract:

1. **Per-user encrypted credential vault.** Credentials never leave the server in plaintext; the agent receives them only via the backend.
2. **Per-conversation credential toggle.** Each conversation independently enables/disables each saved credential bundle. The agent only sees enabled bundles.
3. **Approval-gated destructive actions.** Anything that writes (Odoo writes, server commands, credential storage, report exports) is gated behind a typed `ApprovalRequest` the user must accept or reject.

The mobile client mirrors all three; backend must surface them in the API.

---

## 2. Conventions

### Base URL
Same origin as web: `https://saqqaar.com`. The mobile client reads the base URL from `String.fromEnvironment('SAQQAR_BASE_URL', defaultValue: 'https://saqqaar.com')` so a staging URL can be injected at build time. All endpoints below are relative to that.

### Authentication
- All endpoints require `Authorization: Bearer <access_token>` **except** those explicitly marked **public** below.
- Token format: JWT (or DRF SimpleJWT-equivalent). Mobile is opaque to the token's internals.
- Lifetimes (proposed, backend may adjust): access **60 min**, refresh **14 days**.
- Mobile persists both tokens in OS keychain / Keystore via `FlutterSecureStorage`. Keys: `saqqar.auth.access`, `saqqar.auth.refresh`.
- On `401`, mobile attempts `POST /api/auth/refresh/` once with the refresh token; if that also fails, clears storage and routes to sign-in.

### Content types
- Request and response bodies are `application/json; charset=utf-8` unless stated (e.g. multipart for uploads, SSE for streaming).
- Timestamps are **ISO-8601 UTC** strings (e.g. `"2026-05-14T12:04:32Z"`). Mobile formats locally.
- IDs are **strings** (UUIDs preferred). Mobile treats them as opaque.

### Pagination
List endpoints use **cursor pagination**:

```
GET /api/conversations/?limit=30&cursor=<opaque>

200 {
  "results": [...],
  "next_cursor": "abc123" | null,
  "total": 192
}
```

Mobile passes `next_cursor` from the previous response. `null` means end of results. Default `limit` is `30`; max enforced server-side at `100`.

### Unified error format
Every non-2xx response uses this exact shape:

```json
{
  "error": {
    "code": "credential_required",
    "message": "Saqqar needs your XML-RPC password.",
    "field_errors": { "password": "This field is required." },
    "approval_id": "ap_01HXY..."
  }
}
```

- `code` — machine-readable string the mobile can branch on. See the [Error codes catalog](#9-error-codes-catalog).
- `message` — human-readable, **already localized** to the request's `Accept-Language` header (default `en`).
- `field_errors` — optional; present on `400` validation failures. Keys map to request body field names.
- `approval_id` — optional; present when an action is blocked pending user approval. Mobile resolves it then retries.

The mobile [`ErrorInterceptor`](../lib/core/network/error_interceptor.dart) maps this directly onto its `ApiException` type.

### Localization
Honour `Accept-Language: en` or `Accept-Language: ar` on every request. Error messages, validation messages, and any user-visible strings the API returns (e.g. `approval.title`, `pending_action.body`) must be localized.

---

## 3. Authentication

> **Important context for the backend team:** The web client at [saqqaar.com](https://saqqaar.com) currently uses Django's standard **session-based** auth (HTML form at `/accounts/login/`, session cookie). The mobile client **cannot** consume that — it needs a parallel **token-based** API under `/api/auth/`. The web's session auth stays as-is for browser users; this section adds a separate JSON+JWT surface alongside it. Both backends (sessions + tokens) coexist; mobile only ever talks to `/api/auth/...`.

All four endpoints under `/api/auth/` are **public** (no Authorization header required).

### `POST /api/auth/login/`

```http
POST /api/auth/login/
Content-Type: application/json

{ "username": "test", "password": "test" }
```

Success:
```json
200 {
  "access": "eyJhbGci...",
  "refresh": "eyJhbGci...",
  "user": {
    "id": "u_01HXY...",
    "username": "test",
    "email": "test@digital-harbor.net",
    "is_staff": false,
    "is_superuser": false,
    "date_joined": "2026-01-12T09:14:01Z",
    "last_login": "2026-05-14T08:22:11Z"
  }
}
```

Failure:
- `400 { error: { code: "invalid_credentials", message: "..." } }` for bad username/password (no field_errors — don't leak which one was wrong).
- `429` for rate-limit (mobile shows "Try again in a moment").

### `POST /api/auth/refresh/`

```json
POST /api/auth/refresh/  →  { "refresh": "<refresh_token>" }

200 { "access": "<new_access_token>" }
401 { "error": { "code": "refresh_expired", "message": "..." } }
```

If you adopt **refresh rotation** (new refresh per call), include `refresh` in the response too — call it out so mobile rotates its stored token.

### `POST /api/auth/logout/`

```json
POST /api/auth/logout/  →  { "refresh": "<refresh_token>" }

204 No Content
```

Server-side revoke the refresh token. Mobile clears its tokens regardless of the response.

### `POST /api/auth/register/`

```json
POST /api/auth/register/
{ "username": "...", "email": "...", "password": "...", "password_confirm": "..." }

201 { "access": "...", "refresh": "...", "user": { ... } }
400 { "error": { "code": "validation_failed", "field_errors": { ... } } }
```

If self-registration is disabled in the deployment, return `403 { code: "registration_disabled" }`.

### `GET /api/auth/me/`

```json
200 {
  "user": {
    "id": "u_01HXY...",
    "username": "test",
    "email": "test@digital-harbor.net",
    "is_staff": false,
    "is_superuser": false,
    "date_joined": "2026-01-12T09:14:01Z",
    "last_login": "2026-05-14T08:22:11Z"
  },
  "stats": {
    "conversations": 6,
    "credentials": 7,
    "approvals_pending": 2,
    "artifacts": 8
  }
}
```

Mobile calls this after sign-in to seed cached profile data. The `stats` block powers the 2×2 grid on the Account tab (currently hardcoded — see [`lib/features/account/widgets/stats_grid.dart`](../lib/features/account/widgets/stats_grid.dart)). Mobile refetches this when the Account tab is opened or pulled-to-refresh.

### `POST /api/auth/password/change/`

```json
POST /api/auth/password/change/
Authorization: Bearer <access>
{ "old_password": "...", "new_password": "...", "new_password_confirm": "..." }

204
400 { error: { code: "validation_failed", field_errors: { old_password: "Incorrect." } } }
```

Should **not** invalidate existing access/refresh tokens (the spec UI says "You'll stay signed in after the update").

---

## 4. Conversations

### `GET /api/conversations/`

```
GET /api/conversations/?include_archived=1&q=icg&limit=30&cursor=<opaque>
```

Query params:
- `include_archived` (bool, default `0`) — when `1`, archived conversations are included.
- `q` (string, optional) — server-side fuzzy search across `title`, `preview`, `active_credential`. Mobile currently filters client-side, but pushes this when the list grows past a page.
- `limit` (int, default `30`, max `100`).
- `cursor` (string, optional) — pagination cursor from the previous page.

Response:
```json
200 {
  "results": [
    {
      "id": "c_01HXY...",
      "title": "ICG staging — user count",
      "preview": "199 internal users active.",
      "updated_at": "2026-05-14T12:36:00Z",
      "message_count": 14,
      "active_credential": "icg-staging",
      "is_archived": false
    }
  ],
  "next_cursor": null,
  "total": 6
}
```

- `preview` — first 120 chars of the most recent assistant message, stripped of markdown.
- `active_credential` — the credential bundle currently scoped to this conversation, or `"none"` if the user has unset it.

### `POST /api/conversations/`

Create a fresh conversation. Body is optional.

```json
POST /api/conversations/
{ "title": "Optional initial title" }

201 { id, title, preview, updated_at, message_count: 0, active_credential: "none", is_archived: false }
```

### `GET /api/conversations/{id}/`

Full conversation detail with messages, pending actions, and the per-chat credential state.

```json
200 {
  "id": "c_01HXY...",
  "title": "ICG staging — user count",
  "is_archived": false,
  "is_running": false,
  "auto_approve": false,
  "share_token": null,
  "active_credential": "icg-staging",
  "enabled_credentials": ["icg-staging", "postgres-prod"],
  "messages": [
    {
      "id": "m_01HXZ...",
      "role": "user",
      "content": "how many users in Odoo?",
      "created_at": "2026-05-14T12:04:00Z",
      "attachments": []
    },
    {
      "id": "m_01HXZ...",
      "role": "assistant",
      "content": "Checking Odoo data with icg-staging.",
      "tool_name": null,
      "created_at": "2026-05-14T12:04:02Z",
      "attachments": []
    },
    {
      "id": "m_01HXZ...",
      "role": "tool",
      "tool_name": "count_odoo_records",
      "content": "{\"model\":\"res.users\",\"count\":199}",
      "created_at": "2026-05-14T12:04:04Z",
      "attachments": []
    }
  ],
  "pending_actions": [
    {
      "id": "pa_01HY0...",
      "kind": "request_credentials",
      "title": "Provide Postgres credentials",
      "body": "Saqqar needs read-only Postgres access to verify the migration.",
      "created_at": "2026-05-14T12:05:00Z"
    }
  ],
  "created_at": "2026-05-14T11:58:11Z",
  "updated_at": "2026-05-14T12:36:00Z"
}
```

- `role` ∈ `"user" | "assistant" | "tool"`.
- `content` for `role ∈ {"user", "assistant"}` is **markdown** — supported subset per spec §6.3: paragraphs, **bold**, *italic*, `inline code`, fenced code blocks, ordered/unordered lists, links. Mobile renders via `flutter_markdown`. Backend should NOT pre-render HTML.
- For `role == "tool"`, `content` is the raw tool output (JSON / log lines / SQL result). Mobile renders it in a monospace plate with no markdown processing.
- `tool_name` is set on `role == "assistant"` when the agent invoked a tool to generate the reply (used as a small badge above the body), and on `role == "tool"` to identify the tool that produced the output.
- `is_running: true` → the agent is currently mid-task for this conversation. Mobile disables the composer's send button and exposes a Stop button instead (see [§4.13 stop endpoint](#post-apiconversationsidstop)). When the SSE stream emits `done`, mobile flips this to `false` locally; on re-open, the API value is authoritative.
- `auto_approve: true` → for this conversation only, destructive actions execute without the approval gate. Per-conversation flag (NOT global). Toggle via the PATCH endpoint below.
- `active_credential: "none"` is the special sentinel for "no credential picked" — the agent will issue a `request_credentials` pending action when it needs one.
- `pending_actions[].kind` ∈ `"request_credentials" | "review_data" | "confirm_export" | "other"`. When `kind == "request_credentials"`, the pending action additionally carries `"requested_kind": "xmlrpc" | "postgres" | "server_shell" | "github"` so the mobile can render the schema-driven form inline at the bottom of the chat (spec §6.7) without an extra fetch.
- `404 { code: "conversation_not_found" }` if the user isn't a member.

### `PATCH /api/conversations/{id}/`

Mutate title, archive state, active credential, or auto-approve flag. All fields optional; only the supplied ones change.

```json
PATCH /api/conversations/{id}/
{
  "title": "new title",          // optional
  "is_archived": true,           // optional
  "active_credential": "none",   // optional — "none" or a saved bundle name
  "auto_approve": true           // optional — per-conversation flag
}

200 { ...full conversation... }
```

Mobile uses this for the conversation row's overflow menu (Rename, Archive) and for the chat status strip's auto-approve toggle.

### `DELETE /api/conversations/{id}/`

Hard-delete a conversation and its messages, tool calls, pending actions, and approval requests.

```
204
```

- Returns `409 { code: "agent_running" }` if `is_running == true`. Mobile surfaces "Stop and delete?" confirmation per spec §14, calls `POST /stop/`, then retries the DELETE.
- Optional alternative: accept a `?force=1` query param that internally invokes `stop` and proceeds in one call — backend's choice.

### `GET /api/conversations/{id}/messages/`

Page older messages (back-fill). The conversation detail returns the **last 50 messages** by default — for longer histories, mobile pages backwards with this endpoint.

```
GET /api/conversations/{id}/messages/?before=m_01HXZ...&limit=50
```

Query params:
- `before` (string, optional) — return messages older than this message id. If omitted, returns the latest page.
- `limit` (int, default `50`, max `200`).

```json
200 {
  "results": [ ...messages, oldest first... ],
  "has_more": true
}
```

`has_more: false` means we've reached the start of the conversation. Mobile uses this to disable the "load older" trigger.

### `POST /api/conversations/{id}/messages/`

Send a user message. **Two-step pattern**: this endpoint returns immediately with the persisted user message + the URL of the SSE stream the mobile must open to receive the assistant reply.

```json
POST /api/conversations/{id}/messages/
{
  "content": "Show active users",
  "attachment_ids": ["att_01HY0..."]   // optional, from POST /attachments/
}

202 {
  "user_message": {
    "id": "m_01HY0...",
    "role": "user",
    "content": "Show active users",
    "created_at": "2026-05-14T12:40:01Z",
    "attachments": [ { "id": "att_01HY0...", "name": "users.csv", "kind": "CSV", "size": "24 KB", "url": "..." } ]
  },
  "stream_url": "/api/conversations/c_01HXY.../stream/m_01HY0.../"
}
```

The `stream_url` is **relative to base URL** and resolves with the same `Authorization` header. See [§7. Streaming](#7-streaming).

### `POST /api/conversations/{id}/attachments/`

Multipart upload. The user may attach images/PDFs/spreadsheets to the *next* message; the returned `attachment_id` is then passed to `POST /messages/`.

```http
POST /api/conversations/{id}/attachments/
Content-Type: multipart/form-data; boundary=...

(file part: name="file", filename="users.csv", content-type="text/csv")

201 {
  "id": "att_01HY0...",
  "name": "users.csv",
  "kind": "CSV",
  "size": "24 KB",
  "size_bytes": 24576,
  "url": "https://saqqaar.com/media/attachments/.../users.csv",
  "preview_url": null
}
```

Constraints:
- Accept `image/*`, `application/pdf`, `text/csv`, `text/tab-separated-values`, and Excel MIME types (`application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`, `application/vnd.ms-excel`, `application/vnd.ms-excel.sheet.macroEnabled.12`).
- Max size **50 MB**; return `413 { code: "attachment_too_large" }` above that.
- `preview_url` returned for images; `null` for other kinds.

### `POST /api/conversations/{id}/credentials/toggle/`

Enable or disable a saved credential bundle for **this conversation only**. The agent only sees enabled bundles. This is the load-bearing per-conversation isolation invariant.

```json
POST /api/conversations/{id}/credentials/toggle/
{ "name": "icg-staging", "enabled": false }

200 { "enabled_credentials": ["postgres-prod"] }
```

`name` is the bundle name (the user-chosen slug, e.g. `"icg-staging"`, not the bundle UUID).

### `POST /api/conversations/{id}/pending-actions/dismiss/`

Dismiss an agent request without acting on it.

```json
POST /api/conversations/{id}/pending-actions/dismiss/
{ "action_id": "pa_01HY0..." }

204
```

If the user later asks the agent something that re-raises the same need, the backend creates a new `PendingAction` (this isn't a "permanent reject"). Returns `404 { code: "pending_action_not_found" }` if the action is already dismissed or never existed.

### `POST /api/conversations/{id}/stop/`

Interrupt a running agent. Server-side: cancels the in-flight tool calls, persists any partial assistant message, sets `is_running=false`, and closes the active SSE stream with an `error` event of code `cancelled_by_user`.

```
204
```

Returns `409 { code: "agent_not_running" }` if there's nothing to stop. Mobile uses this for:
- The "Stop" button that replaces "Send" in the chat composer while `is_running == true` (spec §14).
- "Stop and delete?" confirmation dialog when the user tries to delete a conversation mid-run.

### `POST /api/conversations/{id}/share/`

Generate (or rotate) a public read-only share token.

```json
POST /api/conversations/{id}/share/

200 { "token": "shr_01HY1..." }
```

### `DELETE /api/conversations/{id}/share/`

Revoke the current share token.

```
204
```

### `GET /share/{token}/`  *(public)*

**Unauthenticated**. Returns a read-only conversation view for embedding / sharing.

```json
200 {
  "title": "ICG staging — user count",
  "created_at": "...",
  "messages": [ ...same shape as the authenticated detail, minus tool args... ]
}
```

Tool calls in the public view should redact sensitive arguments (e.g. credential values). Approval payloads are stripped.

---

## 5. Credentials

The vault is the second load-bearing invariant. The mobile **must not** hard-code credential field shapes — every form is rendered from `GET /api/credentials/schemas/`. Adding a new credential kind on the server immediately lights up that kind in the mobile UI without any code change.

### `GET /api/credentials/schemas/`

Source of truth for the Add / Edit credential form.

```json
200 {
  "ok": true,
  "schemas": [
    {
      "kind": "xmlrpc",
      "label": "Odoo XML-RPC",
      "fields": [
        { "name": "url",      "label": "Url",      "type": "text",     "placeholder": "https://odoo.example.com", "required": true,  "help": null },
        { "name": "db",       "label": "Database", "type": "text",     "placeholder": "",                          "required": true,  "help": null },
        { "name": "username", "label": "Username", "type": "text",     "placeholder": "",                          "required": true,  "help": null },
        { "name": "password", "label": "Password", "type": "password", "placeholder": "",                          "required": true,  "help": null }
      ]
    },
    {
      "kind": "postgres",
      "label": "PostgreSQL",
      "fields": [
        { "name": "host",     "type": "text",     "required": true },
        { "name": "port",     "type": "number",   "required": true },
        { "name": "database", "type": "text",     "required": true },
        { "name": "username", "type": "text",     "required": true },
        { "name": "password", "type": "password", "required": true },
        { "name": "sslmode",  "type": "select",   "options": ["disable","prefer","require"], "required": false }
      ]
    },
    { "kind": "server_shell", "label": "Server Shell", "fields": [ ... ] },
    { "kind": "github",       "label": "GitHub",       "fields": [ ... ] }
  ]
}
```

Field `type` values mobile supports: `"text"`, `"password"`, `"number"`, `"select"` (with `options: string[]`), `"textarea"`. Anything else is treated as `text`. `help` is rendered under the input as 11pt muted text.

### `GET /api/credentials/`

List the signed-in user's saved bundles.

```json
200 {
  "results": [
    {
      "name": "icg-staging",                            // user-chosen unique slug
      "label": "ICG Staging",                           // display name
      "kind": "xmlrpc",
      "source": "dh.password #19",                      // where backend got it from
      "last_verified": "2026-05-09T00:40:00Z" | null,
      "is_memorized": true,                             // false → session-only, true → persisted via approval
      "created_at": "2026-04-12T..."
    }
  ]
}
```

**Never** include credential field values in this response. The mobile renders only the metadata; the actual secrets stay on the server.

### `POST /api/credentials/`

Save a new credential bundle.

```json
POST /api/credentials/
{
  "name": "icg-staging",
  "label": "ICG Staging",
  "kind": "xmlrpc",
  "payload": { "url": "...", "db": "...", "username": "...", "password": "..." },
  "remember": true
}
```

Two response modes:

- **`remember: false`** (session-only) → `201 { ...credential metadata... }` immediately.
- **`remember: true`** (persist) → `202 { "approval_id": "ap_01HY..." }`. The bundle is **not yet saved**. Mobile shows the user "Saqqar wants to remember this credential. Approve?", calls `POST /api/approvals/<approval_id>/decision/ { approved: true }`, then **re-POSTs this same body with an additional `approval_id` field**:

```json
POST /api/credentials/
{
  "name": "icg-staging",
  "label": "ICG Staging",
  "kind": "xmlrpc",
  "payload": { ... },
  "remember": true,
  "approval_id": "ap_01HY..."   // resolved approval, ready to persist
}

201 { ...credential metadata... }
```

Validation errors return `400 { code: "validation_failed", field_errors: { ... } }`. Duplicate name returns `409 { code: "credential_name_taken" }`.

### `PATCH /api/credentials/{name}/`

Update label or rotate payload. The same memorize/approval flow applies if the user re-enables `remember`.

```json
PATCH /api/credentials/{name}/
{ "label": "ICG Staging — production", "payload": { ... } }

200 { ...credential metadata... }
```

### `DELETE /api/credentials/{name}/`

```
204
```

---

## 6. Approvals

The third invariant. Five approval kinds, one decision endpoint.

### Approval kinds

Returned in the `kind` field of every approval. Matches the existing `ApprovalRequest.kind` in `odoo_agent/models.py`:

| Kind | Mobile copy | Triggered by |
|---|---|---|
| `credential_storage` | "Saqqar wants to remember credentials." | User toggled `remember:true` on a new credential |
| `credential_usage` | "Saqqar wants to use credential X for this request." | Agent needs to dereference a stored credential |
| `server_command` | "Saqqar wants to run `<cmd>` on the server." | Shell tool invocation |
| `odoo_write` | "Saqqar wants to write to Odoo: …" | Any Odoo XML-RPC write |
| `report_export` | "Saqqar wants to generate an Excel report." | Export tool invocation |

### Pending approval shape

Returned in `GET /api/conversations/{id}/` (under a top-level `pending_approvals: [...]` if you choose to expose them there) and via `GET /api/approvals/` (see below).

```json
{
  "id": "ap_01HY...",
  "kind": "odoo_write",
  "conversation_id": "c_01HXY...",
  "title": "Update partner record",
  "prompt": "Saqqar wants to set partner #4521 'is_company' to true.",
  "payload": { "model": "res.partner", "id": 4521, "vals": { "is_company": true } },
  "risk": "medium",                  // "low" | "medium" | "high"
  "action_type": "odoo_write",       // matches `kind`; kept for display
  "status": "pending",               // "pending" | "approved" | "rejected" | "expired"
  "created_at": "2026-05-14T12:38:00Z",
  "expires_at": "2026-05-14T12:48:00Z" | null
}
```

`payload` is rendered as collapsible monospace text. For `server_command` and `odoo_write`, mobile shows it collapsed by default with a "Show details" toggle.

### `GET /api/approvals/`

Inbox feed.

```json
GET /api/approvals/?status=pending&limit=30

200 {
  "results": [ ...approval objects... ],
  "next_cursor": null,
  "pending_count": 2          // convenience for the badge — counts ALL pending across conversations
}
```

`pending_count` powers the mobile's bottom-tab badge. Update it when approvals are created/decided.

### `POST /api/approvals/{id}/decision/`

```json
POST /api/approvals/{id}/decision/
{ "approved": true, "resolution_note": "Looks good, proceed." }

200 {
  "approval": { ...updated approval with status, decided_at... },
  "side_effect": {
    "credential": { ...credential metadata if this resolved a credential_storage approval... },
    "message_id": "m_01HY..."  // if approving resumed an agent run, the new message produced
  }
}
```

`409 { code: "approval_already_decided" }` if status was not `pending`.

---

## 7. Streaming

### Why SSE

The mobile renders incremental assistant tokens (typing animation, then real tokens replace the dots) and live "server activity" cards as the agent invokes tools. Server-Sent Events (`text/event-stream`) over plain HTTP is the simplest fit:

- Plays well with `StreamingHttpResponse` in Django (use Gunicorn `--worker-class gthread` or async views).
- Survives standard proxies (must `Cache-Control: no-cache`, `X-Accel-Buffering: no` if behind nginx).
- Mobile consumes via `Dio` with `ResponseType.stream` + `utf8.decoder` + `LineSplitter`.

### Endpoint
The stream URL is returned by `POST /api/conversations/{id}/messages/` as the `stream_url` field. Canonical form:

```
GET <stream_url>
Authorization: Bearer <access>
Accept: text/event-stream
```

Response headers:
```
Content-Type: text/event-stream
Cache-Control: no-cache
X-Accel-Buffering: no
Connection: keep-alive
```

### Event protocol

Each event uses the standard SSE `event:` + `data:` lines, blank line terminated. `data:` is a JSON object on a single line.

#### `event: token`
Incremental text chunks for the *current* assistant message. Concatenate into the existing assistant bubble.
```
event: token
data: {"text":"Checking "}
```

#### `event: tool_call`
The agent invoked a tool. Mobile inserts a new `tool` message into the chat:
```
event: tool_call
data: {
  "id": "tc_01HY...",
  "tool": "list_users",
  "args": { "active_only": true, "limit": 100 },
  "started_at": "2026-05-14T12:40:05Z"
}
```

#### `event: tool_result`
The tool returned. Mobile updates the corresponding `tool_call` message with the output:
```
event: tool_result
data: {
  "id": "tc_01HY...",
  "content": "{\"count\":199}",
  "duration_ms": 423,
  "ok": true
}
```

#### `event: approval_required`
Run is paused. Mobile renders the approval card inline and stops accepting tokens until decided.
```
event: approval_required
data: {
  "approval_id": "ap_01HY...",
  "tool_call_id": "tc_01HY..." | null,
  "kind": "odoo_write",
  "title": "...",
  "prompt": "...",
  "payload": { ... }
}
```

`tool_call_id` links the approval back to a specific tool call already emitted via `tool_call`. When present, the mobile decorates that tool activity card with a "Pending approval" warning chip in the header until the user decides (spec §6.6). When `null`, the approval is standalone (e.g. `credential_storage`) and rendered as a top-level chat card.

After the user decides, the run resumes — backend opens a fresh stream or continues this one (see "Reconnect contract" below).

#### `event: done`
End of the run.
```
event: done
data: { "assistant_message_id": "m_01HY..." }
```
Mobile closes the stream.

#### `event: error`
```
event: error
data: { "code": "tool_timeout", "message": "...", "tool_id": "tc_01HY..." }
```

#### Keepalive
Backend sends `:` lines (SSE comments) every ~15 s so corporate proxies don't drop the connection. Mobile ignores them.

### Reconnect contract

If the mobile loses the connection mid-stream, it can re-open the same `stream_url`:
- If the run is still in progress, backend resumes from the last persisted token (so re-opening doesn't duplicate text). Send `{ "resume": true }` as the first `meta` event, then continue.
- If the run already finished, backend immediately emits `event: done` with the final `assistant_message_id`. Mobile fetches the full message via `GET /api/conversations/{id}/` to reconcile.

---

## 8. Artifacts (files)

Files the agent produced or the user uploaded. Cross-conversation list view in the mobile Files tab.

### `GET /api/artifacts/`

```
GET /api/artifacts/?kind=EXCEL&conversation=c_01HXY...&limit=30&cursor=...
```

Both filters are optional.

```json
200 {
  "results": [
    {
      "id": "art_01HY...",
      "name": "active-users-export.xlsx",
      "kind": "EXCEL",
      "size": "1.2 MB",
      "size_bytes": 1258291,
      "created_at": "2026-05-09T12:50:00Z",
      "conversation": "ICG staging — user count",
      "conversation_id": "c_01HXY...",
      "mime": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    }
  ],
  "next_cursor": null,
  "total": 8
}
```

`kind` values mobile knows: `"EXCEL"`, `"CSV"`, `"LOG"`, `"IMAGE"`, `"JSON"`, `"MARKDOWN"`. Unknown kinds render with a generic file icon — safe to extend without coordination.

### `GET /api/artifacts/{id}/download/`

Stream the file body.

```
GET /api/artifacts/{id}/download/

200
Content-Type: <mime>
Content-Disposition: attachment; filename="active-users-export.xlsx"
Content-Length: 1258291

<bytes>
```

Mobile reads the stream into a temp file then hands it to the OS share sheet or "Open in..." picker.

---

## 9. Error codes catalog

Mobile branches on `error.code`. Stable identifiers — never rename in a non-breaking release.

| Code | HTTP | Meaning |
|---|---|---|
| `validation_failed` | 400 | Form input failed — see `field_errors` |
| `invalid_credentials` | 400 | Sign-in failed |
| `registration_disabled` | 403 | Self-register turned off |
| `unauthorized` | 401 | Missing or invalid access token; mobile attempts refresh once |
| `refresh_expired` | 401 | Refresh token invalid → mobile signs the user out |
| `forbidden` | 403 | User is signed in but not allowed |
| `not_found` | 404 | Generic |
| `conversation_not_found` | 404 | Conversation doesn't exist or user isn't a member |
| `agent_running` | 409 | Action would interrupt a running agent run |
| `approval_already_decided` | 409 | This approval was already approved/rejected |
| `credential_name_taken` | 409 | `name` already exists for this user |
| `attachment_too_large` | 413 | File exceeded 50 MB |
| `attachment_unsupported_type` | 415 | MIME type not allowed |
| `rate_limited` | 429 | Slow down |
| `server_error` | 500 | Unhandled |
| `tool_timeout` | — (SSE) | Tool call exceeded timeout |
| `agent_internal_error` | — (SSE) | Agent crashed mid-run |

When mobile encounters an unknown `code`, it falls back to `message` for display.

---

## 10. Internationalization

### `GET /api/i18n/{lang}.json`

Optional but strongly recommended. Returns a flat string map so web and mobile copy stay in sync.

```
GET /api/i18n/en.json
```

Response headers:
```
ETag: "v3-en-2026-05-14"
Cache-Control: public, max-age=3600
```

```json
200 {
  "auto_approve": "Auto-approve",
  "auto_approve_subtitle": "Skip approval prompts for this conversation only.",
  "approval_pending": "Approval pending",
  "credential_none": "— None —",
  "...": "..."
}
```

Mobile fetches once on startup with `If-None-Match: <last_etag>`. Backend returns `304 Not Modified` when the strings haven't changed since that ETag, otherwise `200` with the new payload. Mobile merges over its compiled-in defaults, caches the body + the ETag in `SharedPreferences` for offline use. Keys are stable identifiers; values are localized.

If you don't ship this, mobile uses its bundled translations — but web and mobile will drift over time.

---

## 11. Out of scope for v1

The mobile spec calls out these as deferred. Backend does **not** need to ship them in the initial integration:

- **Push notifications.** Mobile polls `GET /api/approvals/?status=pending` on resume instead of receiving FCM/APNs pushes. v2 work: `POST /api/devices/register/ { platform, token, locale }` + dispatcher on `ApprovalRequest` create. Endpoint paths are reserved in [`api_endpoints.dart`](../lib/core/network/api_endpoints.dart) for v2.
- **Users admin** screen (spec §3.1, §9.4). Web has `users_admin.html` with `GET /users/`, `POST /users/{id}/toggle-active/`, `POST /users/{id}/delete/`. The mobile MVP does NOT implement this screen — backend can defer the JSON variants of these to v2. If/when mobile adds it, paths will be `GET /api/users/`, `PATCH /api/users/{id}/`, `DELETE /api/users/{id}/`.
- **Self-registration via the mobile app.** UI present but the "Create an account" button surfaces a toast ("Create account unavailable in v1") — `POST /api/auth/register/` is reserved but not yet called from mobile.
- **Voice input** — no web precedent.
- **Multi-user shared conversations** — single-user invariant for v1.
- **Native widgets / Live Activities** — defer.

---

## 12. Quick implementation checklist

A backend-side TODO list to ship Phase A → Phase F of the mobile migration (see [the mobile plan](https://saqqaar.com) for sequencing).

### Auth (Phase A — unblocks everything)
- [ ] `POST /api/auth/login/` returns `{access, refresh, user}`
- [ ] `POST /api/auth/refresh/` returns `{access}` (and rotated `refresh` if you choose rotation)
- [ ] `POST /api/auth/logout/` revokes the supplied refresh
- [ ] `GET /api/auth/me/` returns `{user, stats:{conversations, credentials, approvals_pending, artifacts}}`
- [ ] `POST /api/auth/password/change/` (does NOT invalidate active tokens)
- [ ] Unified error format on **every** non-2xx response
- [ ] `Accept-Language` honoured on errors + approval titles + pending-action bodies
- [ ] CSRF turned **off** for token-authed `/api/...` routes

### Conversations (Phase B + C)
- [ ] `GET /api/conversations/?include_archived=…&q=…&limit=…&cursor=…` (cursor paginated)
- [ ] `POST /api/conversations/` (create empty)
- [ ] `GET /api/conversations/{id}/` includes `is_running`, `auto_approve`, `enabled_credentials`, `share_token`, last 50 messages, `pending_actions`
- [ ] `GET /api/conversations/{id}/messages/?before=…&limit=…` for back-fill paging
- [ ] `PATCH /api/conversations/{id}/` accepts `title`, `is_archived`, `active_credential`, `auto_approve` (any subset)
- [ ] `DELETE /api/conversations/{id}/` — `409 agent_running` when applicable
- [ ] `POST /api/conversations/{id}/messages/` returns `{user_message, stream_url}`
- [ ] `POST /api/conversations/{id}/attachments/` (multipart, 50 MB cap, accepted MIME types in §4)
- [ ] `POST /api/conversations/{id}/credentials/toggle/`
- [ ] `POST /api/conversations/{id}/pending-actions/dismiss/` (body `{action_id}`)
- [ ] `POST /api/conversations/{id}/stop/` — cancels a running agent, returns `409 agent_not_running` if idle
- [ ] `POST/DELETE /api/conversations/{id}/share/` + public `GET /share/{token}/`
- [ ] **SSE stream endpoint** with the full event protocol in §7 — `tool_call` events carry an `id`, `approval_required` references that id via `tool_call_id`
- [ ] Reconnect contract on the stream endpoint (resume mid-run, or `done` if already finished)

### Credentials (Phase D)
- [ ] `GET /api/credentials/schemas/` — the rendering contract for the Add form
- [ ] `GET /api/credentials/`
- [ ] `POST /api/credentials/` — with `remember:true` returns `202 {approval_id}`; mobile re-POSTs same body + `approval_id` after approval
- [ ] `PATCH /api/credentials/{name}/`
- [ ] `DELETE /api/credentials/{name}/`
- [ ] Pending-action carries `requested_kind` when `kind == "request_credentials"` so mobile renders the inline form

### Approvals (Phase E)
- [ ] `GET /api/approvals/?status=pending&limit=…&cursor=…` (response includes a `pending_count` for the bottom-nav badge)
- [ ] `POST /api/approvals/{id}/decision/` — returns `{approval, side_effect}`
- [ ] All 5 approval kinds wired (`credential_storage`, `credential_usage`, `server_command`, `odoo_write`, `report_export`)

### Artifacts (Phase F)
- [ ] `GET /api/artifacts/?kind=…&conversation=…&limit=…&cursor=…`
- [ ] `GET /api/artifacts/{id}/download/` (streamed, `Content-Disposition: attachment`)

### i18n (parallel)
- [ ] `GET /api/i18n/en.json` and `/api/i18n/ar.json` with `ETag` + `304 Not Modified` on revalidation

### v2 (deferred, do NOT need now)
- [ ] Push notifications (`POST /api/devices/register/`, dispatcher on approval-create)
- [ ] Users admin (`GET /api/users/`, etc.)
- [ ] Self-registration via mobile (`POST /api/auth/register/` already reserved)

Ship in the order **Auth → Conversations → SSE → Credentials → Approvals → Artifacts** so the mobile team can integrate phase-by-phase.

---

## 13. Local development handshake

To unblock end-to-end testing on a developer's machine:

```bash
# Backend
python manage.py runserver 0.0.0.0:8000

# Mobile (Android emulator routes 10.0.2.2 to host)
flutter run --dart-define=SAQQAR_BASE_URL=http://10.0.2.2:8000
```

For physical devices, expose the backend over the LAN IP and use that. CORS isn't a mobile concern (no browser), but please **don't gate** the mobile API behind a CORS-only `Access-Control-Allow-Origin: https://saqqaar.com` — mobile requests come without an `Origin` header.

---

## 14. Versioning

When a breaking change is needed:

- Bump under a new prefix (`/api/v2/...`) — keep `/api/...` (v1) running for at least 60 days.
- Mobile sends `X-Saqqar-Client: mobile/<semver>` on every request so backend can introspect old clients server-side.
- Any breaking change ships with an entry in `CHANGELOG.md` under **API contract** with the deprecation date.

---

## Questions / sign-off

Reach the mobile owner (Mostafa, `ai-tools@digital-harbor.net`) with:

1. **Token lifetimes** — confirm the 60 min / 14 day proposal or override.
2. **Refresh rotation** — single long-lived refresh, or rotating refresh per call?
3. **SSE feasibility** on the current Gunicorn config — yes, or do we fall back to long-poll?
4. **File upload size cap** — 50 MB OK or smaller?
5. **CSRF on `/api/...`** — confirm it's **off** for token-authed routes (CSRF is only for the cookie-authed web client at `/accounts/login/`).
6. **`active_credential` semantics** — when set to `"none"`, does the agent immediately surface a `request_credentials` pending action, or does it wait until the user sends a message that actually needs creds? Mobile assumes the latter; please confirm.
7. **Stop semantics** — does `POST /stop/` immediately kill the agent (drop partial output), or let the current tool call finish and then halt? Mobile defaults to "drop", surfaces a toast.
8. **`PendingAction.requested_kind` for inline credential request** — confirm this field is added when `kind == "request_credentials"` so the mobile can render the schema-driven form inline without an extra fetch.
9. **Message back-fill paging** — confirm `GET /api/conversations/{id}/messages/?before=…` returns messages oldest-first within the page (so mobile prepends them).
10. **Error message localization** — confirm `Accept-Language` is honoured on `error.message`, `approval.title`, `approval.prompt`, and `pending_action.body`.

Once these are settled, this document is the source of truth. The mobile client tracks it via [`lib/core/network/api_endpoints.dart`](../lib/core/network/api_endpoints.dart) — if you change a path here, file an issue so the mobile catalog tracks.

## Appendix A — Coverage proof (so we know mobile is complete on backend ready-day)

This table maps every mobile screen / interaction to the endpoint that powers it. If a row has no checkmark on backend ready-day, the mobile is blocked.

| Mobile surface | Source | Endpoint(s) |
|---|---|---|
| Sign-in form submit | [`sign_in_screen.dart`](../lib/features/auth/presentation/sign_in_screen.dart) | `POST /api/auth/login/` |
| Cold-start, refresh access | [`auth_interceptor.dart`](../lib/core/network/auth_interceptor.dart) | `POST /api/auth/refresh/` |
| Sign-out | [`account_screen.dart`](../lib/features/account/presentation/account_screen.dart) | `POST /api/auth/logout/` |
| Account hero username | [`profile_hero.dart`](../lib/features/account/widgets/profile_hero.dart) | `GET /api/auth/me/` |
| Account stats grid (4 tiles) | [`stats_grid.dart`](../lib/features/account/widgets/stats_grid.dart) | `GET /api/auth/me/` (the `stats` block) |
| Conversations list | [`conversations_screen.dart`](../lib/features/conversations/presentation/conversations_screen.dart) | `GET /api/conversations/?include_archived=…&q=…` |
| Conversation row archive toggle | [`conversation_row_menu.dart`](../lib/features/conversations/widgets/conversation_row_menu.dart) | `PATCH /api/conversations/{id}/` |
| Conversation row delete | same | `DELETE /api/conversations/{id}/` |
| Conversation row rename | same | `PATCH /api/conversations/{id}/` |
| Conversation row share | same | `POST /api/conversations/{id}/share/` |
| Open conversation | [`chat_screen.dart`](../lib/features/chat/presentation/chat_screen.dart) | `GET /api/conversations/{id}/` |
| Load older messages on scroll-up | (Phase C polish) | `GET /api/conversations/{id}/messages/?before=…` |
| Send a message + receive reply | [`chat_screen.dart`](../lib/features/chat/presentation/chat_screen.dart) | `POST /api/conversations/{id}/messages/` → SSE on `stream_url` |
| Attach an image / file | [`chat_composer.dart`](../lib/features/chat/widgets/chat_composer.dart) | `POST /api/conversations/{id}/attachments/` |
| Long-press to copy a bubble | [`message_bubble.dart`](../lib/features/chat/widgets/message_bubble.dart) | (mobile-only, no API) |
| Tool activity expand | [`tool_activity_card.dart`](../lib/features/chat/widgets/tool_activity_card.dart) | (renders `tool_call` + `tool_result` events) |
| Pending approval card | [`chat_approval_card.dart`](../lib/features/chat/widgets/chat_approval_card.dart) | `POST /api/approvals/{id}/decision/` |
| Inline credential request | [`chat_welcome.dart`](../lib/features/chat/widgets/chat_welcome.dart) + agent request | `POST /api/credentials/` (with `requested_kind` from pending action) |
| Credential picker — None option | [`chat_screen.dart::_openCredentialPicker`](../lib/features/chat/presentation/chat_screen.dart) | `PATCH /api/conversations/{id}/` `{active_credential: "none"}` |
| Credential picker — pick bundle | same | `PATCH /api/conversations/{id}/` `{active_credential: "<name>"}` |
| Auto-approve toggle | [`auto_approve_switch.dart`](../lib/features/chat/widgets/auto_approve_switch.dart) | `PATCH /api/conversations/{id}/` `{auto_approve: …}` |
| Stop running agent | (composer "Stop" button when `is_running`) | `POST /api/conversations/{id}/stop/` |
| Dismiss pending action | [`inbox_screen.dart`](../lib/features/inbox/presentation/inbox_screen.dart) + chat sheet | `POST /api/conversations/{id}/pending-actions/dismiss/` |
| Approve / reject from chat sheet | [`chat_approval_card.dart`](../lib/features/chat/widgets/chat_approval_card.dart) | `POST /api/approvals/{id}/decision/` |
| Approve / reject from Inbox | [`approval_decision_card.dart`](../lib/features/inbox/widgets/approval_decision_card.dart) | `POST /api/approvals/{id}/decision/` |
| Inbox tab badge | [`home_shell.dart`](../lib/navigation/home_shell.dart) | `GET /api/approvals/?status=pending` (`pending_count`) |
| Vault list | [`vault_screen.dart`](../lib/features/vault/presentation/vault_screen.dart) | `GET /api/credentials/` |
| Add credential form fields | [`credential_sheet.dart`](../lib/features/vault/widgets/credential_sheet.dart) | `GET /api/credentials/schemas/` |
| Save credential (`remember:false`) | same | `POST /api/credentials/` |
| Save credential (`remember:true`) | same | `POST /api/credentials/` → 202 → `POST /api/approvals/{id}/decision/` → re-POST credentials |
| Edit credential | same | `PATCH /api/credentials/{name}/` |
| Delete credential | [`credential_row.dart`](../lib/features/vault/widgets/credential_row.dart) | `DELETE /api/credentials/{name}/` |
| Files tab list | [`files_screen.dart`](../lib/features/files/presentation/files_screen.dart) | `GET /api/artifacts/` |
| Download artifact | [`artifact_card.dart`](../lib/features/files/widgets/artifact_card.dart) | `GET /api/artifacts/{id}/download/` |
| Offline banner | [`offline_banner.dart`](../lib/shared/widgets/offline_banner.dart) | (mobile-only, `connectivity_plus`) |
| Theme & language toggles | [`preferences_card.dart`](../lib/features/account/widgets/preferences_card.dart) | (mobile-only, SharedPreferences) |
| Localized strings | [`AppStrings`](../lib/core/i18n/app_strings.dart) | `GET /api/i18n/{lang}.json` (optional but recommended) |

**Coverage rule**: every row above must have its endpoint live before that mobile surface is wired in. If a row is checked but the endpoint isn't, the screen will fall back to the demo repo behind a `SAQQAR_LIVE_FEATURES` flag.
