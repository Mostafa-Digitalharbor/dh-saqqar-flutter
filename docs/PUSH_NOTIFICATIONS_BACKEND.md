# Push Notifications — Backend Integration Contract

> **This document is a CONTRACT.** The backend implements it exactly; the
> Saqqar mobile client is built to match it byte-for-byte. If anything here
> needs to change, change it here first and tell the mobile owner — the two
> sides decode the same `data` keys, so a silent rename breaks tap-routing.

- **Transport:** Firebase Cloud Messaging (FCM), **HTTP v1 API** (the modern
  one — legacy server keys are deprecated). Backend sends via a Firebase
  **service account**.
- **Why push at all:** the Saqqar agent runs **asynchronously** — the user
  POSTs a message / approval and may close the app while a long run, report,
  or write-with-approval is in flight. Push is how we pull them back at the
  right moment (an approval that *blocks the agent*, a finished run, a ready
  report).

---

## 0) Who does what (read this first)

| Step | Owner |
|---|---|
| Create ONE Firebase project; add Android + iOS apps | **Project owner** |
| Hand the **client config files** to mobile (`google-services.json`, `GoogleService-Info.plist`) | **Project owner → mobile** |
| Hand the **service-account JSON** (FCM send credentials) to backend | **Project owner → backend** |
| Request OS permission, obtain the **FCM device token**, register it via `/devices/`, refresh it, delete on logout | **Mobile (already coded against `DevicesApi`)** |
| **Store** device tokens bound to the user (`/devices/` endpoints) | **Backend** |
| **SEND** the FCM message (this exact payload) when an event fires | **Backend** — *the core of this doc* |
| Receive, display, and route the tap to the right chat/approval | **Mobile** |

> The client **cannot** send itself a server-side notification. Steps "store"
> and "send" are the backend's; everything else is mobile's.

---

## 1) Device-token registration — `/api/v1/devices/`

The client already calls these (see `lib/features/push/data/devices_api.dart`).
Backend must implement/confirm them and **bind every token to the
authenticated user** (so a send targets the right person, and account-switch
on one device re-binds the token).

### `POST /api/v1/devices/`  ✅ auth required
Upsert by token. Called after the OS permission grant, and again on every
app launch + on token refresh.

Request:
```json
{ "platform": "android",            // "android" | "ios"
  "token": "<FCM registration token>",
  "app_version": "1.0.22" }
```
Response (`201` new / `200` refresh):
```json
{ "ok": true,
  "created": true,
  "device": {
    "id": "<uuid>",
    "platform": "android",
    "token_preview": "fz8aQ1bD3kP…",   // NEVER return the full token
    "app_version": "1.0.22",
    "last_seen_at": "2026-06-30T10:00:00Z",
    "created_at": "2026-06-30T10:00:00Z"
  } }
```
Rules:
- **Upsert by `token`.** Re-POST of the same token updates `last_seen_at` and
  re-binds it to the calling user. One user may have many devices.
- A token is unique to (app install + device). If the same token arrives for
  a different user, move it to the new user (account switch).

### `GET /api/v1/devices/`  ✅ → `{ "ok": true, "devices": [ <device>… ] }`

### `DELETE /api/v1/devices/<id>/`  ✅
Idempotent (second call may 404 — fine). The client calls this on **logout**
so a signed-out device stops receiving that user's pushes.

> **Invalid-token cleanup (backend):** when FCM returns `UNREGISTERED` /
> `INVALID_ARGUMENT` for a token on send, delete that device row. Stale
> tokens otherwise pile up and every send wastes calls.

---

## 2) THE FCM MESSAGE CONTRACT (the important part)

Send an FCM **HTTP v1** message per target device token. It MUST contain
**both** `notification` (so the OS shows it when the app is backgrounded or
killed) **and** `data` (so the app can route the tap). 

> **FCM rule:** every value inside `data` MUST be a **string**. Numbers/bools
> too — send `"1"`, `"true"`, etc.

### Canonical message
```jsonc
{
  "message": {
    "token": "<the device's FCM token>",

    "notification": {
      "title": "Saqqar needs your approval",      // ALREADY localized — see §4
      "body":  "A write to res.partner is waiting for your approval."
    },

    "data": {
      "type": "approval_required",                 // enum — see §3 (REQUIRED)
      "conversation_id": "<conversation uuid>",     // REQUIRED on every push
      "approval_id": "<id>",                        // only for approval_required
      "artifact_id": "<id>",                        // only for artifact_ready
      "deep_link": "saqqar://chats/<conversation uuid>"  // optional convenience
    },

    "android": {
      "priority": "high",
      "notification": {
        "channel_id": "saqqar_approvals",           // see §3 for which channel
        "sound": "default"
      }
    },

    "apns": {
      "headers": { "apns-priority": "10" },
      "payload": {
        "aps": {
          "sound": "default",
          "badge": 1,
          "content-available": 1
        }
      }
    }
  }
}
```

### Required `data` keys (always present)
| key | type | meaning |
|---|---|---|
| `type` | string enum | which event — drives the icon/channel + routing (§3) |
| `conversation_id` | string (uuid) | the chat the push belongs to — the client opens it on tap |

Per-type extra keys are listed in §3. **Unknown future keys are ignored by the
client — safe to add.**

---

## 3) Notification types + when the backend sends each

The client routes the tap by `type`. Android `channel_id` is given per type so
approvals can be a higher-importance channel (the client creates both channels:
`saqqar_approvals` = high importance + sound, `saqqar_updates` = default).

| `type` | Fires when… | Extra `data` | Android `channel_id` | Tap opens |
|---|---|---|---|---|
| `approval_required` | The agent created an approval and is **blocked** waiting for the user's decision. ⭐ highest value | `approval_id` | `saqqar_approvals` | the chat (approvals render inline) |
| `run_complete` | The agent finished a run for a conversation (turned `is_running` false) **and the app is not foreground** | — | `saqqar_updates` | the chat |
| `artifact_ready` | A generated file (xlsx/pdf/docx…) finished and is downloadable | `artifact_id` | `saqqar_updates` | the chat (artifact visible there) |
| `quota_warning` *(optional)* | The user crossed a usage threshold (e.g. 90% of a window) | `window` = `day`\|`week`\|`month` | `saqqar_updates` | the plan/usage screen |

> **Don't over-notify.** Suppress `run_complete` when the user is actively
> viewing that conversation (the app polls live). `approval_required` should
> always fire (it blocks the agent). De-dupe: don't send the same
> `approval_id` / `artifact_id` twice.

### Example payloads (copy-paste shapes)

**approval_required** (English user):
```jsonc
{ "message": { "token": "…",
  "notification": { "title": "Saqqar needs your approval",
                    "body": "A write to res.partner is waiting for approval." },
  "data": { "type": "approval_required", "conversation_id": "c-123",
            "approval_id": "a-789", "deep_link": "saqqar://chats/c-123" },
  "android": { "priority": "high",
               "notification": { "channel_id": "saqqar_approvals", "sound": "default" } },
  "apns": { "headers": { "apns-priority": "10" },
            "payload": { "aps": { "sound": "default", "badge": 1 } } } } }
```

**run_complete** (Arabic user):
```jsonc
{ "message": { "token": "…",
  "notification": { "title": "صقّار خلّص المهمة",
                    "body": "ردّ صقّار في محادثتك «تقرير المبيعات»." },
  "data": { "type": "run_complete", "conversation_id": "c-123",
            "deep_link": "saqqar://chats/c-123" },
  "android": { "priority": "high",
               "notification": { "channel_id": "saqqar_updates", "sound": "default" } },
  "apns": { "payload": { "aps": { "sound": "default" } } } } }
```

**artifact_ready** (English user):
```jsonc
{ "message": { "token": "…",
  "notification": { "title": "Your report is ready",
                    "body": "sales_report.xlsx has finished generating." },
  "data": { "type": "artifact_ready", "conversation_id": "c-123",
            "artifact_id": "art-555", "deep_link": "saqqar://chats/c-123" },
  "android": { "priority": "high",
               "notification": { "channel_id": "saqqar_updates" } },
  "apns": { "payload": { "aps": { "sound": "default" } } } } }
```

---

## 4) Localization (backend MUST localize the title/body)

When the app is **backgrounded or killed**, the OS renders
`notification.title` / `notification.body` **directly** — the app isn't
running to translate. So the **backend must send the final, already-localized
strings** based on the user's saved locale (`ar` / `en`).

Reference copy (use these or close variants):

| type | EN title / body | AR title / body |
|---|---|---|
| approval_required | "Saqqar needs your approval" / "A write to {model} is waiting for your approval." | «صقّار محتاج موافقتك» / «فيه تعديل على {model} مستني موافقتك.» |
| run_complete | "Saqqar finished" / "Saqqar replied in {conversation}." | «صقّار خلّص المهمة» / «ردّ صقّار في محادثتك «{conversation}».» |
| artifact_ready | "Your report is ready" / "{filename} has finished generating." | «تقريرك جاهز» / «{filename} خلص تجهيز.» |
| quota_warning | "Approaching your limit" / "You've used {pct}% of your {window} quota." | «اقتربت من حدّك» / «استخدمت {pct}% من حصتك {window}.» |

> The `data` payload stays English/canonical (it's machine-read). Only
> `notification.title/body` are localized.

---

## 5) Delivery details

- **Priority:** `high` on Android + `apns-priority: 10` — these are
  user-relevant, time-sensitive (especially approvals).
- **Multiple devices:** a user can have N tokens (`GET /devices/`). Send to
  **all** of the user's active tokens.
- **Collapse / de-dupe:** use FCM `collapse_key` (Android) /
  `apns-collapse-id` (iOS) keyed by `conversation_id`+`type` if you want a
  newer notification to replace an unseen older one for the same chat.
- **TTL:** approvals are time-sensitive — a short TTL (e.g. a few hours) is
  fine; don't deliver a day-old "agent finished" push.
- **No silent-only sends** for these user-facing events — always include the
  `notification` block so the OS shows them when the app isn't running.

---

## 6) End-to-end sequence

```
App launch ──► request OS permission ──► get FCM token
           └─► POST /devices/ {platform, token, app_version}        (mobile)
                       └─► backend stores token ↔ user               (backend)

Agent creates an approval (run blocked)                              (backend)
           └─► backend looks up the user's device tokens
           └─► backend sends FCM message  type=approval_required     (backend)
                       └─► OS shows it; user taps
                                   └─► app opens /chats/<conversation_id>  (mobile)

Logout ──► DELETE /devices/<id>/                                     (mobile)
```

---

## 7) What the mobile client does (so the backend has the full picture)

Built by mobile once the Firebase config files land (no backend dependency
beyond §1–§4):
- `firebase_core` + `firebase_messaging` + `flutter_local_notifications`.
- Requests notification permission (iOS always; Android 13+ runtime).
- Gets the FCM token, registers via `DevicesApi.register`, re-registers on
  token refresh + each launch, `DevicesApi.revoke` on logout.
- Creates the two Android channels (`saqqar_approvals`, `saqqar_updates`).
- Foreground messages → shown via `flutter_local_notifications`.
  Background/killed → OS shows the `notification` block.
- Tap handler reads `data.type` + `data.conversation_id` and routes to
  `/chats/<conversation_id>` (deep-linking already exists in the app).

---

## 8) Acceptance checklist (both sides)

- [ ] One Firebase project; Android + iOS apps registered with bundle id
      `sa.com.digitalharbor.saqqar`.
- [ ] iOS: APNs **Auth Key (.p8)** uploaded to Firebase Cloud Messaging.
- [ ] Backend has the **service-account JSON**; mobile has the **config files**.
- [ ] `POST /devices/` stores + binds token to user; `DELETE` unregisters.
- [ ] Backend sends FCM **HTTP v1** messages with the exact `notification` +
      `data` shape in §2, `data` values all strings.
- [ ] `type` ∈ {approval_required, run_complete, artifact_ready,
      quota_warning}; per-type extra keys present.
- [ ] `notification.title/body` localized to the user's locale (§4).
- [ ] Invalid tokens deleted on FCM `UNREGISTERED`.
- [ ] Real-device test: approval push arrives within seconds, tapping it
      opens the right conversation.

---

## Contact / questions
Mobile owner: see the Saqqar mobile repo's README / CODEOWNERS. Coordinate the
single Firebase project + the exact `data` keys before implementing — both
sides decode them.
