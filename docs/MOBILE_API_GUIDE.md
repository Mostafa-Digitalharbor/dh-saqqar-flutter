# Saqqar API — Flutter Developer Guide

Complete reference for the Saqqar backend HTTP API consumed by the mobile app.

- **Base URL:** `https://saqqaar.com`
- **Namespaces:** most endpoints are under **`/api/v1/`**. The email-OTP auth flow is also exposed under **`/api/auth/`** (unversioned) — both work; prefer `/api/v1/`.
- **Auth:** Bearer token — `Authorization: Bearer <token>`. Tokens are returned by the login/signup endpoints and **do not expire** (revoked only by logout, password change, or account deletion).
- **Content type:** send and expect `application/json` unless noted (file upload uses `multipart/form-data`).
- **Auth column:** ✅ = Bearer token required · ⬜ = public.

### Standard response & errors
Success bodies always include `"ok": true`. Errors return:
```json
{ "ok": false, "error": "Human-readable message", "auth": false }
```
- `401` → token missing/invalid (clear the token and re-auth). `403` → quota/permission. `404` → not found. `400` → bad input. `409` → conflict (e.g. agent already running). `502` → upstream (Odoo) connection failed.

### Quick start
1. `POST /api/v1/auth/login/email/start/` → `{email}` → user gets a 6-digit code.
2. `POST /api/v1/auth/login/email/verify/` → `{email, code}` → returns `{token, user}`. Store the token.
3. Send `Authorization: Bearer <token>` on every authed call.
4. `GET /api/v1/projects/` → pick a Project + Environment → bind it to a conversation.
5. Chat: `POST /api/v1/conversations/{id}/messages/` then poll `GET /api/v1/conversations/{id}/?since=...`.

---

## 1) Auth — sessions & account

| Method | Path | Auth | Purpose |
|---|---|:--:|---|
| POST | `/api/v1/auth/register/` | ⬜ | Create account with email + password. |
| POST | `/api/v1/auth/login/` | ⬜ | Login with email + password. |
| POST | `/api/v1/auth/logout/` | ✅ | Revoke the current token. |
| GET | `/api/v1/auth/me/` | ✅ | Current user + counts. |
| PATCH | `/api/v1/auth/me/` | ✅ | Update profile (first_name, last_name…). |
| POST | `/api/v1/auth/password/` | ✅ | Change password (returns a **new** token, revokes others). |
| **DELETE** \| POST | **`/api/v1/account/delete/`** | ✅ | **Delete the account and all its data** (App Store requirement). |

**`register` / `login` / OTP-verify response:**
```json
{ "ok": true, "token": "abcd…", "user": { "id": 12, "email": "a@b.com", "username": "a@b.com", "first_name": "Ali", "last_name": "" } }
```
**`GET /auth/me/`:** `{ "ok": true, "user": {…}, "counts": { "conversations": 4, "credentials": 2 } }`

---

## 2) Email-OTP auth (passwordless) — `/api/v1/auth/…` (also at `/api/auth/…`)

| Method | Path | Auth | Purpose |
|---|---|:--:|---|
| POST | `/api/v1/auth/signup/start/` | ⬜ | Send a signup code to the email. `{email}` |
| POST | `/api/v1/auth/signup/verify/` | ⬜ | Verify code → `{signup_token, ttl_seconds}`. `{email, code}` |
| POST | `/api/v1/auth/signup/resend/` | ⬜ | Resend signup code. `{email}` |
| POST | `/api/v1/auth/signup/complete/` | ⬜ | Finish signup → `{token, user}`. `{signup_token, password?, first_name?, last_name?}` |
| POST | `/api/v1/auth/login/email/start/` | ⬜ | Send a login code. `{email}` → `{resend_in}` (silent if no account). |
| POST | `/api/v1/auth/login/email/verify/` | ⬜ | Verify login code → `{token, user}`. `{email, code}` |
| POST | `/api/v1/auth/login/email/resend/` | ⬜ | Resend login code. `{email}` |
| POST | `/api/v1/auth/password/reset/start/` | ⬜ | Send reset code. `{email}` |
| POST | `/api/v1/auth/password/reset/verify/` | ⬜ | Verify → `{reset_token, ttl_seconds}`. `{email, code}` |
| POST | `/api/v1/auth/password/reset/resend/` | ⬜ | Resend reset code. |
| POST | `/api/v1/auth/password/reset/complete/` | ⬜ | Set new password. `{reset_token, password}` |

> Codes are 6 digits, expire ~10 min. `resend_in` is the cooldown (seconds). Start endpoints are **silent on non-existent accounts** (always return ok) to avoid account enumeration.

---

## 3) Conversations & chat (the agent)

The agent runs **asynchronously**: you POST a message, the server queues a background run, and you **poll** the conversation for new messages/artifacts.

| Method | Path | Auth | Purpose |
|---|---|:--:|---|
| GET | `/api/v1/conversations/` | ✅ | List conversations (`?limit=&include_archived=`). |
| POST | `/api/v1/conversations/` | ✅ | Create a conversation → `{conversation_id}`. |
| GET | `/api/v1/conversations/{id}/` | ✅ | Full snapshot + messages. **Poll with `?since=<ISO ts>&limit=`** for deltas; `?before=<ts|id>` to load older. |
| PATCH | `/api/v1/conversations/{id}/` | ✅ | Update: `{title?, is_archived?, auto_approve?, deep_think?, environment_ids?:[uuid]}`. |
| DELETE | `/api/v1/conversations/{id}/` | ✅ | Delete the conversation. |
| POST | `/api/v1/conversations/{id}/messages/` | ✅ | Send a user message (queues the agent). |
| POST | `/api/v1/conversations/{id}/stop/` | ✅ | Cooperatively stop the running agent (idempotent). |
| POST | `/api/v1/conversations/{id}/attachments/` | ✅ | Upload a file (multipart `file`). Returns attachment(s) with `status`. |
| GET | `/api/v1/conversations/{id}/attachments/{attId}/status/` | ✅ | Poll attachment OCR/extraction status. |
| POST | `/api/v1/conversations/{id}/pending-actions/dismiss/` | ✅ | Dismiss pending action prompts. |
| POST \| DELETE | `/api/v1/conversations/{id}/share/` | ✅ | Create / revoke a public share link. |
| POST | `/api/v1/conversations/{id}/credentials/active/` | ✅ | Set the active credential for the conversation. |
| POST | `/api/v1/conversations/{id}/credentials/toggle/` | ✅ | Enable/disable a credential for the conversation. |

**Send a message:** `POST .../messages/`
```json
{ "content": "How many active users?", "attachment_ids": ["uuid"], "model": "deepseek-chat", "deep_think": false }
```
→ `{ "ok": true, "queued": true, "conversation": {…}, "messages": [...] }`

**Poll loop:** `GET /api/v1/conversations/{id}/?since=<cursor>&limit=50`
- Response includes `conversation` (with `is_running`, `run_progress`, `run_error`, `environment`, `environments`, `project`, `needs_environment`, `plan`), `messages[]`, `cursor` (latest ts — feed back as `since`), `artifacts[]`, `approvals[]`.
- Keep polling (~2–3 s) while `conversation.is_running == true`. Stop when it flips to `false`. Render new `messages` (role: `user|assistant|system|tool`) and any new `artifacts`.

**Message object:** `{ id, role, content, tool_name, tool_payload, created_at, attachments }`

---

## 4) Credentials (Vault)

| Method | Path | Auth | Purpose |
|---|---|:--:|---|
| GET | `/api/v1/credentials/schemas/` | ✅ | Form schemas per credential kind (drive dynamic forms). |
| GET | `/api/v1/credentials/` | ✅ | List the user's credentials (metadata only). |
| GET | `/api/v1/credentials/{name}/` | ✅ | One credential incl. decrypted `payload`. |
| POST | `/api/v1/credentials/` | ✅ | Create a credential (may return `approval_required`). |
| PATCH | `/api/v1/credentials/{name}/` | ✅ | Update a credential. |
| DELETE | `/api/v1/credentials/{name}/` | ✅ | Delete a credential. |
| POST | `/api/v1/credentials/test/` | ✅ | Test a connection **without saving**. |
| POST | `/api/v1/credentials/databases/` | ✅ | **List Odoo databases for a URL.** `{url}` → `{databases:[…], method}`. |

Kinds: `xmlrpc` (Odoo), `postgres`, `server_shell`, `github`. The `xmlrpc` payload is `{url, db, username, password}`.

---

## 5) Projects & Environments

| Method | Path | Auth | Purpose |
|---|---|:--:|---|
| GET | `/api/v1/projects/` | ✅ | Projects with nested `environments[]`. |
| POST | `/api/v1/projects/` | ✅ | Create project. |
| POST | `/api/v1/projects/default/` | ✅ | Ensure a default project/env ("Use My Database"). |
| GET\|PATCH\|DELETE | `/api/v1/projects/{id}/` | ✅ | Project detail / update / delete. |
| POST | `/api/v1/projects/{id}/environments/` | ✅ | Create an environment. |
| GET\|PATCH\|DELETE | `/api/v1/environments/{id}/` | ✅ | Environment detail / update / delete. |
| GET | `/api/v1/environments/{id}/credentials/` | ✅ | List the env's credentials. |
| GET\|PUT\|DELETE | `/api/v1/environments/{id}/credentials/{kind}/` | ✅ | Get / upsert / delete the env's credential of `kind`. |

**Environment object:** `{ id, name, slug, is_live, read_only, auto_approve, project_id, has_xmlrpc }`

---

## 6) Direct Odoo data (no agent) — read-only, fast, deterministic

Query the bound Odoo **without** an LLM turn. Scoped to the environment's XML-RPC credential. All read-only; **writes still go through the chat agent's approval flow.**

| Method | Path | Auth | Purpose |
|---|---|:--:|---|
| POST | `/api/v1/environments/{id}/odoo/search/` | ✅ | `search_read`. `{model, domain?, fields?, limit?, offset?, order?}` → `{rows, count}` |
| POST | `/api/v1/environments/{id}/odoo/count/` | ✅ | `{model, domain?}` → `{count}` |
| POST | `/api/v1/environments/{id}/odoo/read-group/` | ✅ | Aggregations. `{model, fields, groupby, domain?, limit?, lazy?}` → `{groups}` |
| POST | `/api/v1/environments/{id}/odoo/read/` | ✅ | `{model, ids:[…], fields?}` → `{rows}` |
| POST | `/api/v1/environments/{id}/odoo/fields/` | ✅ | Field metadata. `{model, attributes?}` → `{fields}` |
| POST | `/api/v1/environments/{id}/sql/` | ✅ | Read-only SQL (needs a `postgres` credential). `{query, limit?}` → `{result}` |

**Example** — `POST /environments/{id}/odoo/search/`
```json
{ "model": "res.partner", "domain": [["customer_rank", ">", 0]], "fields": ["name", "email"], "limit": 50 }
```
→
```json
{ "ok": true, "model": "res.partner", "count": 50, "rows": [ { "id": 14, "name": "Acme", "email": "acme@x.com" }, … ] }
```
> `limit` caps at 5000; page with `offset`. Many2one fields come back as `[id, "Display Name"]`.

---

## 7) Approvals (Inbox)

| Method | Path | Auth | Purpose |
|---|---|:--:|---|
| GET | `/api/v1/approvals/` | ✅ | Pending approvals (`?status=pending`), includes `pending_count`. |
| POST | `/api/v1/approvals/{id}/decision/` | ✅ | Approve/reject. `{decision: "approve"\|"reject"}` |

When the agent needs to run a write/destructive action it creates an approval; surface these in an inbox and post the decision. The agent resumes automatically.

---

## 8) Artifacts (generated files)

| Method | Path | Auth | Purpose |
|---|---|:--:|---|
| GET | `/api/v1/artifacts/` | ✅ | List generated files (`?limit=&offset=`). |
| GET | `/api/v1/artifacts/{id}/` | ✅ | One artifact's metadata + download `url`. |

**Artifact object:** `{ id, name, kind (xlsx\|pdf\|docx\|html\|md\|json\|zip), mime_type, metadata, url, conversation_id, created_at }`. Download the file from `url` (under `/media/…`).

---

## 9) Billing / usage / plans

| Method | Path | Auth | Purpose |
|---|---|:--:|---|
| GET | `/api/v1/plans/` | ⬜ | Plans list; with a token also returns `current_plan`. |
| GET | `/api/v1/usage/` | ✅ | Token usage + limits for day/week/month + current plan. |

**`GET /usage/`:**
```json
{ "ok": true, "plan": "free",
  "windows": { "day": {"used": 0, "cap": 625000, "remaining": 625000, "pct": 0},
               "week": {…}, "month": {…} } }
```

---

## 10) Misc

| Method | Path | Auth | Purpose |
|---|---|:--:|---|
| GET | `/api/v1/shares/{token}/` | ⬜ | Read a shared conversation transcript. |
| GET | `/api/v1/i18n/{lang}.json` | ⬜ | Remote translation bundle (`ar`, `en`). |
| POST | `/api/v1/transcribe/` | ✅ | Voice → text. multipart `audio` (≤25 MB / ≤120 s) via Whisper. |
| GET | `/api/v1/devices/` | ✅ | List registered push devices. |
| POST | `/api/v1/devices/` | ✅ | Register a push token. |
| DELETE | `/api/v1/devices/{id}/` | ✅ | Unregister a device. |
| GET | `/api/v1/health/` | ⬜ | Liveness/version probe → `{ ok, service, time, api }`. |

---

## Notes for the Flutter client
- **Token storage:** keep the bearer token in secure storage; on any `401`, clear it and route to login.
- **Polling:** chat is async — drive the UI from the `GET /conversations/{id}/?since=` poll loop while `is_running`. Use the returned `cursor` as the next `since`.
- **Environment binding:** before chatting against Odoo, bind an environment via `PATCH /conversations/{id}/ {environment_ids:[…]}` (or `credentials/active/`).
- **Rate limits:** auth endpoints are IP-rate-limited (~10/min); message sends are user-rate-limited — handle `429`/`409` gracefully.
- **Quota:** if a run is blocked, `conversation.plan.exceeded` is `day|week|month`; show an upgrade prompt.
- **Direct data vs agent:** use the §6 data endpoints for deterministic reads (lists, counts, charts data) — they're instant and free of LLM cost. Use the chat agent (§3) for natural-language tasks, writes (with approval), and report generation.
