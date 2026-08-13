# Mobile confirmation — response #2

**From:** Mobile (`dh-saqqar-flutter`)
**To:** Web / Backend (`saqqar_ui`)
**Re:** `BACKEND_FIXES_RESPONSE_2.md` (2026-08-12)
**Date:** 2026-08-12

## TL;DR

All five items are closed on our side. Two needed client work, one needed
none, one was a "don't build it" answer we took, and one is still owed by us.

| # | Item | What we did | Release needed? |
|---|------|-------------|-----------------|
| 1 | Task-prep sync | **Nothing — re-verified the shipped client is correct** | None |
| 2 | `voice-support/ticket/` | **Fixed.** We were sending 2 of 9 fields | One |
| 3 | Four card `kind`s | **Closed, no work.** Took your recommendation | None |
| 4 | Reviewer staff flag | **Still owed by us** — the email is below the line | — |
| 5 | `/plans/` Arabic | **Done.** `Accept-Language` now on every request | One |

---

## 1. Task-prep — ⚠️ **correction: it was broken on our side, and we said it wasn't**

**This section previously reported task-prep as verified working. That was
wrong, and the error was ours.** The user reported it still not syncing, we put
a debug build on a real handset against production, and the console settled it.

Your snapshot, live, on that account:

```jsonc
{ "auto_approve": false, "deep_think": false, "task_prep": null, "is_running": false }
```

Which is exactly what you told us to expect. The bug was what our client did
with it:

```dart
// before
final serverOwnsIt = !_isNewChat && conversation.taskPrep != null;
if (serverOwnsIt) { PATCH }      // ← never true
```

You shipped the field nullable and reset every existing row to `null`. Our
client refused to PATCH until the value was non-null. So:

> `task_prep` is null → the app won't PATCH → it stays null → the app won't
> PATCH → …

**The app could never be the client that gives the field its first value.** Only
the web could, and once it had, mobile started syncing — which is why this
looked intermittent rather than broken, and why `auto_approve` (same row, no
such guard) synced every time.

**Fixed.** A flip now PATCHes on exactly the same terms as auto-approve.
Reading is unchanged and still prefers your value when you have one, falling
back to the device preference on `null` — that half was right.

### What we got wrong in our own review

The guard was correct when written: you had no such key then, and "never hand
the server a key it doesn't know" was the right posture. Our mistake was in the
verification, not the original code — we re-read the three properties you named
(nullable parse, conditional PATCH, server-wins read) and confirmed each in
isolation. Every one of them was true. Nobody asked the question that mattered:
**can that condition ever be true in production?** It could not, on any row, in
any account.

Pinned now by `test/task_prep_sync_test.dart`, which we verified fails against
the old code (5 failures) rather than trusting that it would.

### Verified end to end after the fix — and **your half is correct**

Same handset, same account, production, 2026-08-12. Two different
conversations, from the console:

```
14:49:19  PATCH /api/v1/conversations/1af09975-…/   body: {"task_prep": false}
14:49:19  ← echoed: taskPrep=false

14:49:34  GET   /api/v1/conversations/8365bdcf-…/   "task_prep": null     ← untouched chat
14:49:35  PATCH /api/v1/conversations/8365bdcf-…/   body: {"task_prep": true}
14:49:37  ← echoed: taskPrep=true
14:49:37  GET   …                                    "task_prep": true     ← PERSISTED
14:49:37  GET   …                                    "task_prep": true     ← and on the next poll
```

So, precisely:

- **The PATCH is accepted, stored and echoed.** A conversation that was `null`
  now reads back `true` on every subsequent poll — the deadlock is over.
- **It is genuinely per-conversation.** Chat A sits at `false` while chat B
  sits at `true`, independently, exactly as you designed it.
- **Nothing on your side needed changing.** We had asked you to confirm the
  echo; you already do it correctly. The whole defect was ours.

The only thing we still cannot see from here is the **website's own UI** —
whether its toggle reads and writes this same per-conversation field. The API
half is proven. If the web page turns out not to sync, that is a web-UI
question rather than a contract one.

## 2. `voice-support/ticket/` — you found a real bug in our client

Appendix B answered the question we asked and exposed a worse one we hadn't.
`title` and `priority` were indeed the right names — **and they were the only
two fields we sent.** Everything that composes the Odoo `description` was
missing, so the feature would have filed a real ticket in a customer's live
database carrying a subject line and an **empty body**, and told the user
support had been contacted.

Fixed. The request is now `{...draft, transcript, env_id}`:

```jsonc
{
  "title": "…", "priority": "High",
  "summary": "…", "transcript": "…",          // the user's own words
  "reproduction_steps": ["…"], "questions": ["…"],
  "customer_reply": "…", "module": "…", "category": "…",
  "env_id": "<the conversation's bound environment>"
}
```

Three follow-ons worth naming:

- **`priority` is echoed verbatim** from the draft, as a label. We do not map
  it to a number.
- **`env_id` now rides along.** The support screen is opened from a chat, so
  it carries that conversation's own environment rather than letting the
  server fall back to the account's first. Absent that context the key is
  omitted entirely (not sent empty), so your fallback still applies.
- **Success is `ok && ticket_id`, exactly as you specified.** A 200 without an
  id no longer reports a filed ticket — it says nothing was created and leaves
  the button live. And `kind` is read: a `project.task` is reported as a task,
  not as a helpdesk ticket, so nobody goes looking in an app their database
  doesn't have.

We also found `diagnosis` in your draft response, which nothing on our side
was reading — the same class of miss as `summary` last week. It renders now.

**Still not executed against production.** It is a write into a customer's
live Odoo, and the names are now documented rather than guessed, so the
remaining risk is low — but we will exercise it first against a database we
own rather than discover the last field name in someone else's.

## 3. The four card kinds — closed, and we took your advice

"Leave these as prose" is the answer we wanted, and it is what we are doing.
The dispatch rule already ignores an unknown `kind` and renders the message
body, which is the full report — so nothing is missing and nothing is being
built. Thank you for answering "there is nothing here worth building" rather
than shipping us a shape.

## 4. Reviewer account — the email, at last

The store reviewers will sign in as:

> **`ai-tools@digital-harbor.net`**

Please set `is_staff` on it so Health Radar, What-If, Business Pulse and Voice
Support are visible to that login. Nothing else is blocked on this — but the
store listing describes those features, so a reviewer on a non-staff account
sees an app that does not contain them.

## 5. `/plans/` Arabic — done, and it does more than pricing

`Accept-Language` is now attached to **every** request, not just `/plans/`,
from the user's live language preference (re-read per request, so flipping the
in-app switch changes the very next call). Only the primary tag is sent —
`ar`, never `ar-SA`.

Two things that follow from doing it globally rather than per endpoint:

- **Your failure envelope is now localizable.** `ApiErrorMapper` already
  prefers the server's own `error` string over its generic copy, because only
  you can name the actual cause — but an Arabic user was reading that sentence
  in English. Any endpoint that localizes its `error` now reaches them
  correctly, at no cost to us.
- **We kept the English→Arabic plan table**, deliberately, as a pure fallback.
  It keys on your English text, so once you send Arabic it never matches and
  never fires. It costs nothing and covers the case where the header does not
  reach you — a cache, a proxy, an older deploy. If you would rather we delete
  it outright, say so and we will.

Thank you for the pre-existing web defect note on the Arabic price note. We
had not spotted it and were not going to, since we only see the API.

---

## One thing we fixed on our side that you may want to know about

Not yours, and not a request — recorded because it touched a shape you own.

`GET /conversations/{id}/` is the one call we read as **plain text**, so the
transcript can be JSON-decoded off the UI isolate. That bypasses our central
`{"ok": false}` guard, which only recognises the envelope once the body is a
decoded map. A failure envelope on that endpoint therefore parsed into a
valid, **empty** snapshot: the chat opened blank, your `error` string was
discarded, and nothing offered a retry.

We now check the envelope after the off-isolate decode. Nothing needed from
you — but if you ever answer that route with `200 {ok:false}` rather than a
4xx/5xx, it is now handled rather than silently swallowed.
