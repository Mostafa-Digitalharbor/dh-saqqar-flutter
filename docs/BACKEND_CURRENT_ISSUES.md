# Open items — backend action required

**From:** Mobile (`dh-saqqar-flutter`)
**To:** Web / Backend (`saqqar_ui`)
**Date:** 2026-08-12 · supersedes every earlier version of this file

## What this file is

**Only what is still open.** Rewritten from empty after `BACKEND_FIXES_RESPONSE_2.md`.
Everything that now works was deleted rather than left in with a "done" tick —
a hand-off list that carries closed items stops being read.

**Four of the five items in the previous version are gone.** Our own
confirmation of each, with the code paths, is in
`BACKEND_FIXES_MOBILE_CONFIRMATION_2.md`.

| Previously | Closed on 2026-08-12 |
|---|---|
| 1 · Task-prep did not sync | **You shipped the field; we then broke it on our side and reported it fixed.** Our client refused to PATCH until `task_prep` was non-null — and you reset every row to `null`, so it never was. Caught on a real handset against production; fixed, and pinned by a test verified to fail against the old code. See the correction in `BACKEND_FIXES_MOBILE_CONFIRMATION_2.md` §1 |
| 2 · `voice-support/ticket/` field names unverified | **You published the contract**, and it exposed a worse bug on our side: we were sending 2 of the 9 fields, so a filed ticket would have carried a subject and an empty body. Fixed; success is now `ok && ticket_id`, and the `project.task` fallback is reported as a task |
| 3 · Four card `kind`s undocumented | **Closed with no work**, on your recommendation. They carry no structured data; the report is the message body, which we already render |
| 5 · `/plans/` Arabic | **You shipped `Accept-Language`.** We now send it on **every** request, from the live language preference — so your failure-envelope `error` strings can be localized too |

One item remains, and it is ours to unblock.

| # | Item | Endpoint | Severity | Blocked on |
|---|---|---|---|---|
| 1 | The **web** Task-prep toggle is not wired to the stored field | `PATCH /conversations/{id}/` | **P1 — the user's original report** | You — see `WEB_TASK_PREP_NOT_SYNCING.md` |
| 2 | Reviewer account needs the staff flag | — | P2 — blocks store review | **You**, now that we have sent the email |

---

## 1. The web's Task-prep toggle is not wired to the stored field

**Severity: P1** · *This is the other half of the sync the user reported*

> **Measured on 2026-08-12, not inferred.** With the server holding
> `task_prep: true` on a conversation, the website rendered the switch **off**,
> and turning it off left the server value unchanged. `auto_approve` — same
> page, same conversation, same endpoint — read and wrote correctly in the same
> sitting. Full evidence and the fix: **`WEB_TASK_PREP_NOT_SYNCING.md`**.
>
> The rest of this section is the background that led there, kept because it
> explains why the field behaves the way it does.

We fixed our half and proved it (see `BACKEND_FIXES_MOBILE_CONFIRMATION_2.md`
§1): mobile now PATCHes `task_prep`, the server stores it, and every later poll
reads it back. **The API contract works.**

What we cannot see from here is whether the **website** participates.

### Why we think it may not

`WEB_UI_PARITY_GAPS.md` §3, written by your team on 2026-08-04, describes the
web toggle as a **per-message** flag:

> "Server reads it from the send body (`web: views.py:578` →
> `payload.get("task_prep", True)`)"

That is a flag held in the web's own client state and attached to each send —
architecturally identical to what mobile had before, and it never touches the
stored conversation field. The stored field only came into existence eight days
later, on 2026-08-12, in your response #2.

Your own note says the server honours both:

> "the per-message `task_prep` still wins for a single turn; when omitted, the
> run uses the stored conversation value"

So if the web still only sends the per-message key and keeps its toggle in JS
state, then **nothing the two clients do can ever agree** — mobile writes a
field the web never reads, and the web sends a key that leaves no trace.

### The evidence that points that way

Both conversations we tested on a real account came back `"task_prep": null`
before mobile touched them — on an account whose owner uses the website daily.
If the web had ever PATCHed the field on either, it would not have been null.

Circumstantial, not proof: the user may simply never have flipped it on the web
*for those two conversations*.

### What we need — one answer

**Does the web's `#taskPrepToggle` issue a `PATCH /api/v1/conversations/{id}/`
carrying `task_prep`?**

- **Yes** → nothing further; the two clients are already in sync and we will
  confirm on a device.
- **No** → the web needs the same one-line change we just made: PATCH the
  conversation on flip, and render the toggle from
  `snapshot.conversation.task_prep` when it is non-null. `auto_approve` on the
  web already does exactly this — it is the same edit, on the switch beside it.

Note this is **per-conversation** by the product owner's decision, so a flip in
one chat is not expected to move another. Worth confirming the web treats it
that way too rather than as one global preference — if the web's toggle is
global and mobile's is per-chat, they will disagree even when both write the
field.

---

## 2. The store-review account needs the staff flag

**Severity: P2 — blocks store review**

We owed you the email address and it was the only thing holding this. It is:

> **`ai-tools@digital-harbor.net`**

Please set `is_staff` on that account. You estimated a one-minute change.

**Why it matters:** Apple and Google reviewers sign in with a supplied
account. On a non-staff login, Health Radar, What-If, Business Pulse and Voice
Support are correctly hidden — so a reviewer sees an app that does not contain
the features the store listing describes, and that is a rejection reason on
both stores.

---

## Parked — nothing needed from either side

- **`voice-support/ticket/` has still never been executed against
  production.** Not a request. It is a write into a customer's live Odoo, and
  now that the field names are documented rather than guessed we will exercise
  it against a database we own before it runs against anyone else's.
- **The English→Arabic plan table is still in the app**, deliberately, as a
  pure fallback behind `Accept-Language`. It keys on your English text, so
  once you answer in Arabic it never matches and never fires. Say the word if
  you would rather we delete it outright.

---

## How the closed items were verified

So the list can be trusted rather than re-argued:

- **Task-prep**: read back against the shipped code path, not assumed — the
  nullable parse, the conditional PATCH key, and the server-wins branch are
  each pinned by a test, including the one that matters most (*absent must
  stay `null`, never `false`*).
- **The ticket contract**: the request body is pinned field-by-field against
  Appendix B, including the negative cases — empty draft fields are omitted
  rather than sent blank, and a 200 with no `ticket_id` must NOT be reported
  as a filed ticket.
- **`Accept-Language`**: pinned by a test that the header follows a runtime
  language switch rather than being captured at boot, and that only the
  primary tag is sent.
