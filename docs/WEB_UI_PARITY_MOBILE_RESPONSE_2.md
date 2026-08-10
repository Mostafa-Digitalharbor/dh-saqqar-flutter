# Mobile reply to `WEB_UI_PARITY_WEB_RESPONSE.md`

**To:** Web (`saqqar_ui`)
**From:** Mobile (`dh-saqqar-flutter`)
**Date:** 2026-08-06
**Re:** Everything in your answer is implemented. Three things below need you.

Thank you — the endpoint paths and exact key names were what we actually
needed, and every one of them landed the same day. **All 12 gaps are now
closed on mobile**, including the two we told you were blocked.

Analyzer clean, **1049 tests passing**.

---

## Your §0 broke an assumption we had told you was safe — worth reading

We wrote in our last doc that the six flags would activate "with no client
release", because `PlanFeatures` keeps every boolean the server sends. **That
was wrong, and it would have failed silently.**

Two reasons:

1. `saqqar_features` is a **new top-level object**, not new keys inside
   `windows.features`. Our generic bag was pointed at the wrong bag.
2. The task flag is **`task_prep`**, not `task_prep_available` — we were
   reading the HTML-context name.

Reading the wrong object makes every flag come back **absent**, and our
gating at the time treated absent as *show it*. So on the account you
described — a normal non-staff user with `health_radar`, `what_if`,
`business_pulse` and `voice_support` all `false` — we would have rendered
three Odoo tool rows that the agent then refuses. Exactly the dead rows the
gating exists to prevent, arrived at by being optimistic in the wrong place.

Fixed, and pinned by a test that asserts a same-named key under
`plan.features` does **not** enable a row.

**We also took your gating advice as written**: everything except `task_prep`
and `prompt_bank` is now strict — absent OR `false` ⇒ hidden.

### One structural note, in case it's useful on your side

We could not put these on our plan model. `PlanCubit` is replaced wholesale
by every conversation snapshot on the 1.5 s poll, and the snapshot's `plan`
object carries no `saqqar_features` — so the flags would light up when the
user visited Account and blink out one poll after they opened a chat. They
now live in their own holder with its own lifetime
(`SaqqarFeaturesCubit`), fetched once per session and fed by whichever screen
calls `/usage/` first.

### Your open question: **don't mirror `features` / `exempt`**

That mismatch was **already fixed on our side on 2026-08-04** —
`UsageApi.fetch()` reads `windows['exempt']` and `windows['features']`, with a
comment describing the same bug you found. Your heads-up was accurate but
about a version two days stale. Keep the wire as it is; a purely additive
mirror would just give us two places to disagree with each other later.

---

## §6 — we swapped the prompts for your endpoints

We had three locally-authored prompt strings, written after a probe found no
route. The probe was sound; our guessed names weren't (`health-radar` vs
`radar/run`). The strings are **deleted**, not left unused, and a test fails
if they come back.

| Row | Calls |
|---|---|
| Health radar | `POST /api/v1/radar/run/` |
| Business pulse | `POST /api/v1/pulse/run/` |
| What-if | `POST /api/v1/whatif/intro/` |

**We deliberately do not call `/whatif/run/`.** It needs a `scenario` from
your four-value enum plus a `percent`, which on mobile means a form asking the
user to classify their own question before they've phrased it. `intro` posts
the primer and they describe it in words — your `simulate_what_if` path. If
you'd rather we build the form, say so; the plumbing is there.

Two behaviours worth knowing:

- These rows now **skip the live-database warning** our composer applies. That
  prompt exists for writes; these three cannot write, and putting a "this is
  production" confirmation in front of a read-only report trains people to
  dismiss the one warning that matters.
- While a scan is in flight we show the **existing** "Saqqar is working"
  indicator rather than inventing a second one, and the report appears
  through the ordinary poll.

---

## §8 — built

Your answer was the missing piece: it needed a **destination**, and "a Saudi
support workspace that files a real `helpdesk.ticket`" is one. Text box →
`/draft/` → diagnosis card (reply / steps / open questions, plus module,
category and priority as chips) → optional "Save as a ticket" → `/ticket/`.

**We did not build TTS.** It needs the billing `voice` entitlement, 403s on
Free, and returns audio this app has no player for. A button most accounts
can't use and the rest hear nothing from is worse than no button. The written
reply is the substance and everyone gets it. Say the word if you want it.

**On the ticket call being consent:** we took "the user's explicit tap is the
consent" seriously precisely *because* there's no approval card. It is the
only write in the feature and it lands in a live database, so it sits behind
its own confirmation dialog naming what happens, and it cannot fire twice for
one draft — two taps on a slow connection is how one problem becomes two
tickets in someone's queue.

---

## §11 — "Approve all 6" is gone, and it should never have existed

Your answer here was the most useful correction in the doc. Our card read a
`grouped_count` and promised a number **before** the request. Since the count
only comes back in the response, that number could never have been anything
but invented.

Now:

- The primary button is always the singular **Approve**.
- A separate, quieter **"Approve all similar requests"** action sends
  `scope: "batch"` — no count in the label — and the toast afterwards reports
  `batch.resolved_count`, the real number.
- **Hidden entirely for deletes.** You return 400; we'd be offering a button
  that can only fail, and a batch delete is the one mistake with no undo.
- **Hidden when `payload.batch_scope == true`** — offering to batch something
  a scope already cleared is offering a no-op.

`grouped_count` survives on the demo fixtures only, with a comment saying no
server-fed card may key a label off it.

---

## §9 / §10 — trimmed to what you sent

**§9.** Alias list cut from thirteen guesses to your six exact keys. `title`
is gone as a subject alias — it's shared by half our approval types, so it was
making every titled approval a candidate for the email layout. Added:

- **`bcc`**, rendered as prominently as `to`. It's the one field invisible in
  the sent mail, so the approval card is the only place a user can ever see
  it.
- **`in_reply_to`** as a small "Reply" badge. The Message-ID itself is noise
  on screen, but its presence changes what's being approved.

**§10.** We now read `confirm_phrase` off the approval as you suggested —
**in addition to**, never instead of, the two locale-built phrases. Your API
accepts `delete N`, `حذف N` and `احذف N` interchangeably, so honouring only
the canonical spelling would make our client stricter than your server and
hand an Arabic user an English string to copy. A blank or wrong-typed
`confirm_phrase` reads as absent rather than as an empty required phrase,
which would gate the delete forever.

---

## Still open — three things

### 1. Which message shape carries an interactive card (our §4 ask)

**This one wasn't answered.** We asked which shape you send — `role: "tool"`,
`role: "assistant"` with empty `content`, or assistant with prose *and* a
payload. We handle all three, but blind.

It matters more than it sounds: our visibility filter used to drop tool-role
rows and empty-content assistant rows as plumbing, which meant every
`prompt_clarify` / `report_builder` / `prompt_suggestion` card was being
filtered out before reaching the renderer — while every widget test passed,
because those pump the row directly. One line in a reply saves us guarding a
shape you never send.

### 2. `report_builder` is a flag now — does it gate the card?

Your §0 sample carries four flags we hadn't heard of: `collection_note`,
`version_awareness`, `module_management` and **`report_builder`**. We read
them all (the raw map keeps every key), but nothing gates on them yet.

`report_builder` is the interesting one — if it's meant to gate the §4 report
card, we'll wire it. If it gates a *web page* of the same name, we'll leave
it alone. Right now the card renders whenever a payload arrives.

### 3. Prompt-bank contents

Unchanged from last time and not urgent: our prompt bank shows the app's own
four starter prompts, because there's no saved-prompt catalogue on the API. If
`prompt_bank` being a server flag implies server-side content, tell us where
it lives.

---

## Two we're closing as agreed

- **§4.2 report chip labels** — same trade-off on both sides, no action. Our
  client-key table stays deliberately empty; the server `label` wins.
- **§12 env picker** — product's call. Mobile stays multi-select, web stays
  single. Neither side changes unilaterally.

---

## Where the new code lives

| Gap | Files |
|---|---|
| §0 flags | `features/billing/data/saqqar_features.dart`, `view_model/saqqar_features_cubit.dart`, `data/usage_api.dart`, `features/chat/data/chat_features.dart` |
| §6 | `features/chat/data/saqqar_tools_api.dart` |
| §8 | `features/support/{data,view}/` |
| §9 | `features/chat/widgets/email_approval_preview.dart` |
| §10 | `features/inbox/data/approval_models.dart`, `features/chat/widgets/delete_approval_confirm_dialog.dart` |
| §11 | `features/chat/widgets/chat_approval_card.dart`, `features/chat/view/chat_screen.dart` |

New test files: `saqqar_features_test`, `saqqar_tools_api_test`,
`voice_support_test`, `approval_batch_test` — plus rewrites of
`chat_features_test`, `saqqar_tools_sheet_test`, `approval_parity_test` and
`parity_copy_test` to the corrected contract.

The rewrites are the point: those files previously encoded our assumptions as
if they were your contract, and passed. Tests that agree with a wrong belief
are how the `plan.features` mistake would have shipped.
