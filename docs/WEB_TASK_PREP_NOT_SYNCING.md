# Task prep does not sync — the remaining half is the web

**From:** Mobile (`dh-saqqar-flutter`)
**To:** Web (`saqqar_ui`)
**Date:** 2026-08-12
**Severity:** P1 — user-reported, twice, and still visible after our fix
**Scope:** This file is only about `task_prep`. Nothing else is in question.

---

## TL;DR

`task_prep` became a real per-conversation field on 2026-08-12, and the API
works. **We had two bugs on mobile, both fixed and both verified on a real
device against production.** One symptom survived, and we have now measured it
from inside the website:

> **The website's Task-prep toggle neither reads nor writes the stored
> conversation field.** On one conversation, with the server holding
> `task_prep: true`, the page rendered the switch **off**, and turning it off
> left the server value untouched. **`auto_approve`, the switch beside it, did
> both correctly in the same sitting** — same page, same conversation, same
> endpoint.
>
> It looks like Task prep is still the pre-2026-08-12 per-message flag, kept in
> browser-local state.

We cannot open the web source, so we are not naming the line — but the
behaviour is measured, with a positive control, and §5 says what to change.

---

## 1. What the user actually sees

Three separate reports from the same person, on one account:

1. Flipping Task prep in the app did not appear on the website. *(Ours — fixed,
   §2.)*
2. Flipping Task prep in one chat turned it on in **every** chat. *(Ours —
   fixed, §3.)*
3. **Flipping Task prep on the website does not appear in the app.** *(Open —
   §4.)*

Auto-approve, the switch directly beside it, has always synced correctly in
both directions. That contrast is what made this look broken rather than
unimplemented.

---

## 2. Our first bug — we never PATCHed (fixed)

Our client refused to PATCH until `conversation.task_prep` was already
non-null:

```dart
// before
final serverOwnsIt = !_isNewChat && conversation.taskPrep != null;
if (serverOwnsIt) { PATCH }      // ← never true
```

You ship the column nullable and reset every existing row to `null`, so that
was false everywhere. A deadlock: the app could never give the field its first
value.

The guard was right when written — you had no such key then. It stopped being
right the day the field shipped, and our review missed it because we checked
each property in isolation and never asked whether the condition could ever be
true in production.

**Fixed**, and confirmed on a handset against production:

```
14:49:34  GET   /api/v1/conversations/8365bdcf-…/   "task_prep": null
14:49:35  PATCH /api/v1/conversations/8365bdcf-…/   body: {"task_prep": true}
14:49:37  ← echoed taskPrep=true
14:49:37  GET   …                                    "task_prep": true   ← stored
14:49:37  GET   …                                    "task_prep": true   ← and on the next poll
```

**Your half is correct.** The PATCH is accepted, persisted and echoed, and the
field is genuinely per-conversation. Nothing here is a backend request.

---

## 3. Our second bug — the flip leaked into other chats (fixed)

The app renders the toggle as:

```dart
conversation.taskPrep ?? deviceDefault
```

…and our flip handler wrote **both** the PATCH *and* the device-wide default.
Since your column defaults to `null`, every conversation nobody had flipped
inherited that default — so one flip re-rendered all of them.

**Fixed.** An existing chat now writes only its own conversation. The device
default is written solely for a chat that does not exist server-side yet, where
there is nothing to PATCH and it is what the first send carries.

Worth stating plainly because it shapes the question in §5: **the `null`
default is doing real work for us.** We are not asking you to backfill it.

---

## 4. What is left — **measured on the website, not inferred**

After both fixes, mobile→server is proven. The user still reports
**web→mobile** not working, and we have now measured it from inside the
website itself rather than reasoning about it.

### 4.0 The controlled comparison — one request, two booleans

On 2026-08-12, in a signed-in browser on
`https://saqqaar.com/c/8365bdcf-6a1a-4995-a4bf-c7c62c60b135/`, we fetched the
page's own API:

```
GET https://saqqaar.com/api/v1/conversations/8365bdcf-6a1a-4995-a4bf-c7c62c60b135/?limit=1
```

The server answered, on the `conversation` object:

```jsonc
"auto_approve": true,
"deep_think":   false,
"task_prep":    true,
"updated_at":   "2026-08-12T12:15:56.609784+00:00"
```

At that same moment, on the page rendering that same conversation:

| field | server says | the web UI shows | |
|---|---|---|---|
| `auto_approve` | `true` | **on** | agrees |
| `task_prep` | `true` | **off** | **contradicts** |

**Same request, same object, two adjacent booleans — one is honoured and the
other is ignored.** There is no transport, auth, caching or timing explanation
available: they arrived together, in one response, and the page acted on one of
them.

> **The web does not read `task_prep` from the conversation.** This is measured,
> not deduced.

And `updated_at` places the value: `12:15:56Z` is `15:15:56` Riyadh, which is
the minute the user was flipping the toggle **on the phone**. The `true` sitting
on the server is ours. The website has been rendering over it without seeing it.

### 4.1 The write half — measured too, with a positive control

Same page, same conversation, same API endpoint, in one sitting:

| # | action on the website | server afterwards |
|---|---|---|
| 1 | turn **Task prep** off (server held `true`) | `task_prep` **still `true`** — unchanged |
| 2 | flip **Auto-approve** | `auto_approve` went **`true` → `false`** |

Step 2 is the control, and it is what makes step 1 unarguable. The neighbouring
switch, on the same page, writing to the same conversation through the same
endpoint, **persists correctly**. So:

- the endpoint is reachable from the page,
- the session is authenticated,
- `PATCH /conversations/{id}/` works,
- the tester's method is sound.

…and `task_prep` still did not move.

> **The web neither reads nor writes `task_prep`.** Both halves measured, each
> against a working control on the switch beside it.

A Network-tab recording filtered to `conversations`, taken across a Task-prep
flip, likewise contained no `PATCH` — only the two page-load `GET`s.

### 4.2 The complete picture

| field | web reads it? | web writes it? |
|---|---|---|
| `auto_approve` | ✅ yes — UI matched the server | ✅ yes — `true` → `false` persisted |
| `task_prep` | ❌ no — UI showed *off* while server said `true` | ❌ no — flip left the server untouched |

Two adjacent booleans on one conversation. One is fully wired to the stored
field; the other is not wired to it at all.

### 4a. The web's toggle looks like a per-message flag

Your own hand-off, `WEB_UI_PARITY_GAPS.md` §3 (2026-08-04), describes it as:

> "A **Task prep** toggle in the composer bar (`web: index.html:243-249`,
> `#taskPrepToggle`) … Server reads it from the **send body**
> (`web: views.py:578` → `payload.get("task_prep", True)`)"

That is a value held in page state and attached to each send. It never touches
a conversation row. The stored field did not exist until eight days later.

Your response #2 confirms the server still honours both paths:

> "the per-message `task_prep` still wins for a single turn; when omitted, the
> run uses the stored conversation value"

So a web toggle that only sends the per-message key **works perfectly for the
web's own runs while leaving no trace anywhere mobile can read.** That is
exactly the symptom.

### 4b. The values on the wire agree with that

Every conversation on this account read `"task_prep": null` until mobile wrote
one — on an account whose owner uses the website daily. Had the web ever
PATCHed the field, those rows would not have been null.

Circumstantial on its own. Combined with 4a, less so.

### 4c. The reload test was inconclusive, and we said so

We asked the user to hard-reload the page. The toggle kept its state, and we
initially read that as "the server stores it". **That inference was wrong** —
`Ctrl+Shift+R` clears the HTTP cache but **not** `localStorage`, so a purely
client-side toggle survives it too. It distinguishes nothing. Correcting it
here so nobody repeats it.

---

## 5. What we are asking for

Both halves are measured (§4.0, §4.1), each against a working control on the
switch beside it. Nothing here is inference any more, and there is no open
question left for us to ask you — only work to do.

**The web's Task-prep toggle needs wiring to the stored field, the same way
`auto_approve` on that page already is:**

1. **On flip:** `PATCH /api/v1/conversations/{id}/` with
   `{ "task_prep": true|false }`.
2. **On render:** read `snapshot.conversation.task_prep`, and fall back to the
   page's own default only when it is `null`.
3. **Keep sending the per-message key** if you want — the server lets it win
   for that turn, and it costs nothing.

`auto_approve` on the web already does exactly this. It is the same edit, on
the switch immediately beside it — which is precisely why one syncs and the
other does not.

---

## 6. One thing to agree on regardless

**Is the web's Task prep per-conversation or global?**

Ours is per-conversation, by the product owner's decision on 2026-08-10
("mirroring `auto_approve` exactly"). If the web's toggle is a single global
preference, the two will still disagree even once both write the field — the
web would show one value across every chat while mobile shows a different value
per chat, and each side would look broken to the other.

If global is what the product wants, say so and we will change ours to match.
We would rather both be wrong in the same direction than right in two different
ones.

---

## How the mobile side was verified

So this can be trusted rather than re-argued:

- A **debug build on a real handset**, signed in to a real account, against
  production `saqqaar.com`, with the full Dio console captured — request line,
  headers, body, response body.
- Two different conversations, showing `null` → PATCH → stored → still stored
  on the following poll.
- Both fixes are pinned by tests that were **verified to fail against the old
  code** before being kept — the first with 5 failures, the second after a
  first attempt at the guard passed against a deliberately reintroduced bug and
  had to be rewritten.
