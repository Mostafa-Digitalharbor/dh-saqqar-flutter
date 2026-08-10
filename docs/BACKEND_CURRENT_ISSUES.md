# Open items — backend action required

**From:** Mobile (`dh-saqqar-flutter`)
**To:** Web / Backend (`saqqar_ui`)
**Date:** 2026-08-10 · supersedes every earlier version of this file

## What this file is

**Only what is still open.** This file was rewritten from empty after a full
re-test against production on a real device and a real account. Everything that
now works was deleted rather than left in with a "done" tick — a hand-off list
that carries closed items stops being read.

**Five of the six items in the previous version are gone.** Four of them you
shipped, and we confirmed each one working end to end rather than taking the
release note's word for it:

| Previously | Verified on 2026-08-10 |
|---|---|
| `saqqar_features` missing | **Live.** Nine flags on `/usage/`; the tools sheet shows Health Radar, What-If, Business Pulse and Voice Support exactly as gated |
| Chats list showed 100 of ~140 | **Live.** `limit=200` returns all 149 with `total`, in a single request |
| `/apps/` served a 5th package | **Live.** Returns exactly the four the web gallery shows; our client-side allowlist is deleted |
| `/plans/` carried no copy | **Live.** `tagline`, `most_popular`, `features_intro`, `features_text`, `price_note` and `vat` all present and rendering, English and Arabic |

Five items remain. Each states how it was verified; nothing below is inference.

| # | Item | Endpoint | Severity | Blocked on |
|---|---|---|---|---|
| 1 | Task-prep toggle does not sync app ↔ web | `PATCH /conversations/{id}/` | **P1 — user-visible** | **You only** — decided, and mobile already ships the client half |
| 2 | `voice-support/ticket/` field names unverified | `POST /voice-support/ticket/` | **P1 — silent data loss risk** | You (one reply) |
| 3 | Four card `kind`s have no field shapes | chat `tool_payload` | P2 | You |
| 4 | Reviewer account needs the staff flag | — | P2 — blocks store review | **Us**, then you |
| 5 | `/plans/` Arabic — works today, decays silently | `GET /plans/` | P3 | You (already offered) |

---

## 1. Task-prep toggle does not sync between app and web

**Severity: P1** · *Reported by the user, twice*

### Symptom

Turning **Task prep** on in the app does not turn it on in the web, and turning
it on in the web does not reach the app.

### Root cause — there is nowhere to store it

This is not a client bug on either side. **The server holds no value for it.**
`task_prep` is a send-body key only (`payload.get("task_prep", True)`): read per
message, applied, and forgotten.

So each client necessarily keeps a private copy — mobile in device
preferences, web in its own state — and two private copies have no way to agree.

### Evidence, captured 2026-08-10

A live conversation snapshot returns exactly these conversation keys:

```
auto_approve · deep_think · is_running · stop_requested · run_progress
run_error · active_credential · environment · environments · project
needs_environment · plan
```

- **No `task_prep`.** Note `deep_think` *is* there — a per-conversation boolean
  of precisely this shape already exists, so this is a missing field rather than
  a missing capability.
- **No user-preference route exists.** `/preferences/`, `/settings/`,
  `/user/preferences/`, `/me/preferences/`, `/account/settings/` and `/profile/`
  all return **404**, while `/usage/` returns **401** — so the probe separates
  "route absent" from "route exists, needs auth".
- The only `task_prep` on the wire is inside `saqqar_features` on `/usage/`,
  which is a **capability** flag ("may this account use it"). Reading that as
  the setting would pin every user to "on" forever.

### Why the user keeps noticing

**Auto-approve sits directly beside it in the same row and does sync**, because
that one is a real conversation field. Two adjacent switches behaving
differently is what makes this look broken rather than unimplemented.

### The decision is made: **per-conversation**

The product owner settled it on 2026-08-10. Task prep becomes a
**per-conversation field, mirroring `auto_approve` exactly**. No account-level
preference, no new endpoint.

### What we need from you — two lines of serializer

1. **Serialize `task_prep` on the conversation**, as a boolean, everywhere
   `auto_approve` already appears (the snapshot and the `PATCH` response).
2. **Accept `task_prep` in `PATCH /api/v1/conversations/{id}/`.**

That is the whole contract. We are not asking for anything `auto_approve` does
not already do.

### Mobile is already done — and needs **no release** after your change

This is the useful part: **the client shipped support ahead of you.** It is in
the build going to the stores now.

- `Conversation.task_prep` is parsed as a **nullable** boolean.
  - **`null`** (every deployment today) → the app falls back to its local
    preference, which is byte-for-byte the behaviour that shipped. Nothing
    changes, nothing regresses.
  - **`true`/`false`** → the server is the source of truth, the switch renders
    from it, and flipping it PATCHes — optimistic, with rollback and a message
    if you refuse it.
- `PATCH` sends `task_prep` **only when the user actually flips it**, so a
  server that does not know the key is never handed one. Renaming a chat still
  sends only `title`.

**So the day you deploy the field, the toggle starts syncing on phones already
in users' hands.** No app update, no store review, no waiting.

Pinned by tests, including the one that matters most: *absent must stay
`null`, never `false`* — collapsing it would have silently turned Task prep
**off for every user of every build already shipped**.

### One request

Please send `task_prep` in the snapshot **and** echo it in the `PATCH`
response, the way `auto_approve` does. The client re-polls after a PATCH and
takes the server's value as canonical, so an echo that omits the field reads as
"the server has no opinion" and drops that conversation back to the local
preference.

---

## 2. `voice-support/ticket/` — we cannot confirm the field names, and it writes to a live Odoo

**Severity: P1** · *Found by mobile on 2026-08-09*

### What already happened on the sibling endpoint

`POST /voice-support/draft/` was specified to us in prose — *"send the user's
problem text"* — with no field name. Mobile guessed `problem`. The guess was
wrong on **three** counts, and the feature therefore **never produced a single
draft** from the day it shipped:

| We sent | Server wanted |
|---|---|
| `problem` | **`transcript`** |
| read the reply from the response root | it is nested under **`draft`** |
| `steps` / `reply` | **`reproduction_steps`** / **`customer_reply`** |

The server also returns a **`summary`** field that nothing on our side was
reading, because we did not know it existed.

All four are fixed and Voice Support now works end to end — verified on a
device against production, rendering the diagnosis, the reply, the steps and
the follow-up questions in Arabic.

### Why it stayed invisible for so long

The 400 travels the error path correctly and the screen returns to its empty
state — which looks exactly like a feature nobody has tried yet. Only the
console said otherwise. Our own unit test asserted `problem`, so the test and
the code were wrong in the same way and the suite stayed green.

### The open risk

**`POST /voice-support/ticket/` has never been executed successfully by mobile.**
We currently send:

```jsonc
{ "title": "…", "priority": "…" }
```

Those names were guessed from the same prose that got `draft` wrong three times.
We have deliberately **not** tested it, because unlike `draft` it is a write:
it creates a real `helpdesk.ticket` in the customer's production Odoo, and
firing a probe ticket into a live database to discover a field name is not a
reasonable way to learn one.

If the names are wrong here the failure mode is worse than `draft`'s: the user
taps "file a ticket", the request 400s, and they believe support has been
contacted when nothing was created.

### What we need — one reply

The exact request body for `POST /api/v1/voice-support/ticket/`: field names,
which are required, and the accepted values for `priority` (the draft returns
`"High"` — is that the value to echo back, or is it a numeric code?).

Please also confirm the **response** shape, so we can tell a created ticket
from an accepted-but-dropped one.

### Ask

Publish the request/response shape for both voice-support endpoints the way
Appendix A.1 documented `prompt_clarify`. Two payload captures would have
prevented all of this.

---

## 3. Four interactive-card `kind`s have no documented field shape

**Severity: P2** · *Follows from your own Q12 answer*

Your reply listed seven card kinds:

```
prompt_clarify · report_builder · prompt_suggestion · odoo_health_radar
executive_brief · what_if_intro · what_if
```

**You documented the fields for one of them** (`prompt_clarify`, in Appendix
A.1). Mobile renders the three it has shapes for. The other four arrive as
ordinary prose — nothing breaks, nothing is blank, the agent's text still reads
correctly, but the interactive card the web shows is simply absent on mobile.

The dispatch rule you gave is implemented and tested, including the negative
case you flagged as critical: a `tool_payload` carrying `tool_calls` with no
`kind` renders as a plain bubble and the payload is ignored.

### What we need

For `odoo_health_radar`, `executive_brief`, `what_if_intro` and `what_if`:

1. The field shape of each payload.
2. **Which of them the mobile-reachable tools actually emit.** We run Health
   Radar, Business Pulse and What-If from the tools sheet; if those post plain
   prose with no `kind`, then there is nothing to build and we would rather
   know that than build against a kind that never arrives.

Until then this stays a missing card, not a broken screen — so it is not
blocking a release.

---

## 4. The store-review account needs the staff flag

**Severity: P2 — blocks store review** · *Owed by us first*

You offered two options for making the staff-gated features visible:

1. mark one specific account as staff, or
2. un-gate specific features globally.

**We chose option 1** — it keeps your rollout controlled. **The email address is
still owed by you-to-us, i.e. by us.** This item is listed here so it is not
forgotten, not because you are blocking it.

Once we send the address, the change is yours and takes a moment.

**Why it matters:** Apple and Google reviewers use a supplied account. On a
non-staff login, Health Radar, What-If, Business Pulse and Voice Support are
correctly hidden — so a reviewer sees an app that does not contain the features
the listing describes.

---

## 5. `/plans/` Arabic — correct today, decays silently

**Severity: P3** · *Not broken now; listed because the failure is silent*

This one is **working**. It is here only because its failure mode leaves no
trace, and because you already offered the fix.

`/plans/` is English-only by design — the web page translates in the browser
through a static English→Arabic map. Mobile now does the same thing, keyed by
the English text, and the result is correct: the Arabic pricing screen renders
all five tiers with **no English leaking anywhere**, verified on a device.

**The decay:** the lookup keys on your English string. If you *edit* the wording
of a bullet or tagline we have already translated, the key stops matching and
that line silently falls back to your new English on an Arabic phone. Nothing
errors. Nobody is notified. It is the current claim in the wrong language,
which is the better of the two possible failures — but it is still a failure,
and it exists only because the Arabic lives on our side.

### Ask

`Accept-Language: ar` on `/plans/`, which you offered as a fast follow. It is
additive, needs nothing from us beyond sending the header, and retires our
translation table entirely.

**Not blocking.** Ship it whenever it suits.

---

## How this was verified

So the list can be trusted rather than re-argued:

- **A real signed-in account on a device**, driven through the accessibility
  tree, with the Dio console captured throughout — not a staging fixture.
- **Live endpoint probes** for existence, using the 401-vs-404 distinction so
  "route missing" is never confused with "route needs auth".
- **A live `/plans/` fetch** diffed field by field against the pricing page.
- Health Radar **executed against a real Odoo**, returning a full scan.
- Voice Support **executed end to end** after the fix, returning a real draft.

One thing we checked and are **not** reporting, so you do not chase it: approval
payloads appear as `"payload": "***"` in our logs. That is our own logging
interceptor redacting credential-bearing fields, not something you send.
