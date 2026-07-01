# Saqqar Mobile — Push Notifications (Backend Endpoints)

Handoff for the Flutter developer. Covers device registration and the push
payload contract the backend sends via **Firebase Cloud Messaging HTTP v1**.

> File location note: this lives alongside the other `API_MOBILE_*.md` docs.
> (Originally requested as `docs/push_notifications_backend_endpoints.md`.)

---

## 1. Overview

The backend stores each device's FCM registration token bound to the
authenticated user, and pushes notifications for four events:
`approval_required`, `run_complete`, `artifact_ready`, `quota_warning`.

Every push carries **both** a `notification` block (so the OS renders it when
the app is backgrounded/killed) and a string-only `data` block (so the app can
route the tap). Titles/bodies are **localized server-side** (en/ar) because the
app isn't running to translate when backgrounded.

## 2. Auth requirement

All `/devices/` endpoints require authentication — send the bearer token:

```
Authorization: Bearer <token>
```

(Same token issued by the existing mobile auth flow. Session auth also works.)
Endpoints are under the versioned prefix `/api/v1/` (and legacy `/api/`).

## 3. Device endpoints

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/v1/devices/` | Register or refresh this device's FCM token |
| GET | `/api/v1/devices/` | List the current user's devices |
| DELETE | `/api/v1/devices/<id>/` | Unregister a device (on logout) |

A token is unique to one app install. One user may have many devices. If the
same token arrives from a different user (same physical device, new login), the
backend **re-binds** it to the new user.

## 4. Request / response examples

### POST `/api/v1/devices/`

Request:

```json
{
  "platform": "android",
  "token": "<FCM registration token>",
  "app_version": "1.0.22"
}
```

Optional: `"locale": "ar"` — the app's current UI language (`en`/`ar`). The
backend uses it to localize the notification title/body the OS renders. If
omitted, the user's most recent device locale is used, defaulting to English.

Response (`201` when newly created, `200` when refreshed):

```json
{
  "ok": true,
  "created": true,
  "device": {
    "id": "<uuid>",
    "platform": "android",
    "token_preview": "fz8aQ1bD3kP…",
    "app_version": "1.0.22",
    "last_seen_at": "2026-06-30T10:00:00Z",
    "created_at": "2026-06-30T10:00:00Z"
  }
}
```

### GET `/api/v1/devices/`

```json
{
  "ok": true,
  "devices": [
    {
      "id": "<uuid>",
      "platform": "android",
      "token_preview": "fz8aQ1bD3kP…",
      "app_version": "1.0.22",
      "last_seen_at": "2026-06-30T10:00:00Z",
      "created_at": "2026-06-30T10:00:00Z"
    }
  ]
}
```

### DELETE `/api/v1/devices/<id>/`

```json
{ "ok": true }
```

Returns `404` for a device that doesn't exist or isn't yours.

## 5. Validation rules

| Field | Rule |
|---|---|
| `platform` | Required. Must be `android` or `ios`. |
| `token` | Required, non-empty, ≤ 512 chars. |
| `app_version` | Optional string. |
| `locale` | Optional. `en` or `ar` (others ignored → English). |

The full token is **never** returned — only `token_preview` (first ~12 chars + `…`).

## 6. Notification data contract

All `data` values are **strings**. Required keys on every notification:

```
type
conversation_id
```

Convenience key on every notification:

```
deep_link = saqqar://chats/<conversation_id>
```

## 7. Supported notification types

| type | Extra `data` keys | When |
|---|---|---|
| `approval_required` | `approval_id` | Agent created an approval and is blocked waiting for the user |
| `run_complete` | — | Agent finished a run (app not foreground) |
| `artifact_ready` | `artifact_id` | A generated file (xlsx/pdf/docx/md/zip) is ready |
| `quota_warning` | `window` (`day`/`week`/`month`) | User approaching a usage limit |

Example `data` (approval):

```json
{
  "type": "approval_required",
  "conversation_id": "<conversation uuid>",
  "approval_id": "<approval id>",
  "deep_link": "saqqar://chats/<conversation uuid>"
}
```

## 8. Android channel IDs

Register these channels in the app:

| type | channel_id |
|---|---|
| `approval_required` | `saqqar_approvals` |
| `run_complete` / `artifact_ready` / `quota_warning` | `saqqar_updates` |

Android pushes are sent `priority: high`; iOS `apns-priority: 10`. Each push
also sets `collapse_key` / `apns-collapse-id` = `"<conversation_id>:<type>"`.

## 9. Localization note

`notification.title` / `notification.body` arrive **already localized** (en/ar)
based on the device `locale` you send at registration (default English). The
app should NOT re-translate the OS-rendered notification. Use `data` for
routing only.

## 10. Deep link format

```
saqqar://chats/<conversation_id>
```

Route the tap to the conversation screen. `type` tells you the context
(open the approval sheet for `approval_required`, scroll to the artifact for
`artifact_ready`, etc.).

## 11. Logout behavior

On logout, call `DELETE /api/v1/devices/<id>/` for this device so it stops
receiving pushes. (The backend also auto-prunes tokens FCM reports as
`UNREGISTERED`.)

## 12. Real-device testing checklist

- [ ] Grant notification permission, then `POST /api/v1/devices/` with the FCM token (+ `locale`).
- [ ] Confirm `created: true` (201) on first call, `created: false` (200) on a repeat.
- [ ] Background the app; trigger an approval from another session → OS shows the `saqqar_approvals` notification.
- [ ] Kill the app; trigger again → still delivered (notification block renders without the app running).
- [ ] Tap the notification → app opens to `saqqar://chats/<conversation_id>`.
- [ ] Switch app language to Arabic, re-register with `locale: "ar"` → next notification title/body is Arabic.
- [ ] `GET /api/v1/devices/` lists your device(s); no full token is present.
- [ ] Log out → `DELETE /api/v1/devices/<id>/` → you stop receiving pushes.
- [ ] Reinstall the app (new token) → old token is auto-pruned on the next send.
