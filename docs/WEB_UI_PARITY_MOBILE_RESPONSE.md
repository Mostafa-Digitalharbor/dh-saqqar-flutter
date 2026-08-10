# Mobile response to `WEB_UI_PARITY_GAPS.md`

**To:** Web team
**From:** Mobile (`dh-saqqar-flutter`)
**Date:** 2026-08-04
**Re:** All 12 gaps worked. 9 shipped, 1 partially shipped, 2 verified as
already-at-parity. Two need something from your side before they can ship.

Everything below is covered by tests and `flutter analyze` is clean.

**Read this first if you read nothing else:** closing these 12 gaps does NOT
make mobile identical to web. Your own closing note says "neither app was
run/rendered — this is a source-read comparison", so the list is what a source
read surfaced, not the full difference between the clients.

Eleven of the twelve are done. §6 shipped on a **stated assumption** about how
those tools work (§2 below) — confirm or correct it. §8 is the one we will not
guess at, and §2b says why. The six feature flags still are not in the mobile
snapshot, so every gate currently defaults open.

---

## Status by gap

| # | Gap | Status |
|---|---|---|
| 1 | `+` Saqqar-tools menu | ✅ Shipped |
| 2 | Remove Deep think | ✅ Shipped |
| 3 | Task-prep toggle | ✅ Shipped (interim gating — see below) |
| 4 | In-chat interactive cards | ✅ Shipped (all three kinds) |
| 5 | Composer shape | ✅ Shipped |
| 6 | Odoo tools (radar / what-if / pulse) | ✅ Shipped — **on an assumption, please confirm** |
| 7 | Prompt bank | ✅ Shipped and visible |
| 8 | Voice **support** channel | ⛔ **Blocked on you** — needs a destination, not wording |
| 9 | Email-approval preview | ✅ Shipped (was missing) |
| 10 | Delete-approval localization | ✅ Shipped — **the finding was worse than you thought** |
| 11 | Approval resume + inline approvals | ✅ Verified at parity, no change needed |
| 12 | Env picker single vs multi | ℹ️ Verified — mobile is multi, deliberately. Product call |

---

## §10 — what we actually found (please read this one)

You asked us to check whether the mobile delete flow expects an English
`delete N <model>` phrase, which would lock Arabic users out.

**It expected no phrase at all.** Mobile approved a destructive delete on a
single tap, with no confirmation step of any kind. So it was not a
localization bug — it was a missing safety gate, on the one action in the app
that cannot be undone on a production Odoo.

We shipped the gate:

- Fires only for `payload.operation == "delete"`. Other writes still approve
  in one tap — gating every write would just train people to tap through it.
- Phrase is `Delete <n>` / `حذف <n>`, built from the server's `record_count`.
- Arabic-Indic (٠–٩) **and** extended/Persian (۰–۹) digits fold to Western
  ones, so `حذف ٦` confirms. Either locale's phrase is accepted whatever the
  UI language.
- Rejecting is never gated.

**Question for you:** your phrase is `حذف N` per the doc — does the web
include the model name (`delete N res.partner`)? Ours does not. If yours does,
tell us and we will match, since a user moving between clients should be typing
the same string.

## §4 — one thing that nearly shipped broken

Worth telling you because it changes what you should ask us for.

The three cards were built, and every widget test passed — because a widget
test pumps a `MessageRow` directly. The chat screen sits above that, and its
visibility filter drops **every `tool`-role row** and **every assistant row
with empty content** as agent plumbing. Appendix A says the payload arrives
"on an assistant/tool message", and for a card the payload usually *is* the
content. So on the two shapes you actually send, the card would have been
filtered out before it ever reached the renderer.

Fixed, and the filter is now a tested unit
(`lib/features/chat/data/message_visibility.dart`) rather than a private
method nothing could reach. A payload that names a `kind` but carries nothing
answerable is still dropped, so a malformed card degrades to hidden rather
than to an empty bubble.

**What we need:** tell us which shape you actually send —
`role: "tool"`, or `role: "assistant"` with empty `content`, or assistant with
prose *and* a payload. We now handle all three, but we are handling them
blind.

## §9 — email preview

Mobile had no email branch; an email approval rendered as `key: value` chips,
which meant approving a message the user never actually read. Now laid out as
recipient / subject / body, with the raw payload still available under "Show
details".

**We guessed the payload keys** (`to` / `email_to` / `recipients`, `subject` /
`email_subject`, `body` / `body_html`, `cc`). Requires both a recipient and a
subject, otherwise it falls back to the chip rendering, so a wrong guess
degrades to today's behaviour rather than hiding a payload. **Please confirm
the real key names** and we will trim the alias list.

## §11 — verified, no change

- Approve/reject already POSTs the same `/api/v1/approvals/<id>/decision/` the
  web calls, so any server-side resume that endpoint triggers already applies
  to mobile.
- Pending approvals already render **inline in the message list** (they were
  moved out of a banner above the composer on 2026-05-17), plus in the rail
  drawer.

One thing to flag: the card supports grouped approvals ("Approve all 6") but
the API→UI adapter never populates `grouped_count`, so that path is currently
demo-only and untested against real data. **If the backend starts grouping
approvals, tell us** — we would then need to send `scope: "batch"` on the
decision, which we deliberately did not wire blind.

## §12 — env picker

Mobile is multi-select on purpose: `Conversation.environments` is a list, the
PATCH contract takes `environment_ids: [...]`, and the chat header binds
several environments to one conversation. Web being single-select radio is the
divergence, not us. **Product decides**; we changed nothing.

---

## Backend status, probed 2026-08-05 (twice — 10:46 and 13:46 UTC)

Checked against production rather than assumed, on the endpoints that need no
bearer.

| Probe | Result | Means |
|---|---|---|
| `GET /api/v1/health/` | `200 {ok, api: v1}` | server is live |
| `GET /api/v1/plans/` → `features` | `voice, postgres, github, server_shell` on **all five** plans | **none of the six new flags have shipped** |
| `GET /api/v1/i18n/{en,ar}.json` | 247 keys; no `task*`, `tool*`, `radar*`, `pulse*`, `rb*`, `clarify*` | the mobile string bundle has no new copy either |
| Guessed §6/§7/§8 routes | `404` | see the caveat below |
| Known authed routes (`conversations/`, `report-entities/`, `usage/`, `apps/`) | `401` | baseline — an existing route answers 401, so 404 really is "no route under that name" |

**Caveat on the 404s.** They rule out a REST route named `health-radar`,
`what-if`, `business-pulse`, `prompt-bank` or `voice-support` — not the
feature. Your own wording, "server-side scans/simulations **streamed into
chat**", reads much more like these are **agent tools** (the same family as
`run_readonly_sql` / `generate_excel_report`) than HTTP endpoints. If that is
right, there is nothing for mobile to call at all: the row just sends a
prompt, the agent runs the tool, and the result streams back as ordinary
messages. That would make §6 roughly a one-line change per row — **we just
need the exact prompt text each row sends.**

Re-probed three hours later: byte-identical. Nothing on your side has landed,
and §6 / §7 / §8 remain exactly where they were.

**One gap in this evidence, and it needs you or an account holder.**
`/api/v1/plans/` is a *different serializer* from the `conversation.plan`
object the app actually reads. It is unlikely but possible that the snapshot
carries flags the public plans list omits. Settling it takes one authenticated
call:

```
curl -H "Authorization: Bearer <token>" https://saqqaar.com/api/v1/usage/ \
  | grep -o '"features":[^}]*}'
```

If that prints more than `voice / postgres / github / server_shell`, tell us —
the gating is already written and would light up with no client release.

**The §6 / §8 copy is already translated.** `tools_health_radar`,
`tools_what_if`, `tools_business_pulse` and `tools_voice_support` exist in both
tables, unused, held by a test that names them as pending on your answer. So
when you reply, those two gaps are code-only — no translation round-trip.

## Done since the first version of this document

**Report chips now resolve through client i18n keys** (`rbType_<key>`,
`rbPeriod_<key>`, `rbLens_<key>`, `rbFormat_<key>`), falling back to the
server `label` — the same rule the web uses. That was listed as "ours, on
request"; the mechanism is in.

The key table is **deliberately empty**. Adding the two or three chip keys
your Appendix A.2 shows as examples would produce a card reading "أوامر البيع"
next to "Customer aging", which looks broken rather than partly translated.
**Send the full list of chip keys the backend can emit** and it becomes a
strings-only change — no code, no release risk.

## What we need from you

### 1. Feature flags in the mobile snapshot (§3, §6, §7, §8)

You noted `task_prep_available` is only in the HTML context. Same is true of
`prompt_bank`, `health_radar`, `what_if`, `business_pulse`, `voice_support`.

**Mobile is already ready for all six.** `PlanFeatures` now keeps every boolean
the server sends under `plan.features`, so the day you add any of these keys
they resolve **with no client release**. Two behaviours are pinned by tests:

- `task_prep_available` — **optimistic**. Absent ⇒ toggle shown (your interim
  option 1). Explicit `false` ⇒ hidden. You gate it server-side anyway, so a
  toggle shown to an ineligible user is inert, never broken.
- Everything else — **strict**. Absent ⇒ row hidden. A row that routes nowhere
  is worse than a missing one.

### 2. Confirm the §6 assumption (Health radar / What-if / Business pulse)

These are now **built and visible**, on a stated assumption rather than on your
confirmation — waiting was costing more than being wrong here would.

The assumption: there is no endpoint. Our probe found no REST route under any
obvious name, while known routes answer `401`, and your own wording is
"scans/simulations **streamed into chat**". So each row sends a **read-only
request into the conversation** and the agent runs whatever tool it has.

Two consequences worth knowing:

- Because it is a message and not an endpoint, the row **cannot dead-end** —
  worst case the agent replies that it can't do it. That is why these three
  are shown by default and hidden only on an explicit `false`, unlike the
  strict gating we described before.
- Each row goes through the same send path as a typed message, so a scan still
  gets the environment check, the **live-database warning**, the offline block
  and the quota block. A tool row must not be the one way to touch production
  without the live warning.

**What we need:** the exact text each of your three rows sends, in both
languages. Ours are authored locally and marked as such — three strings,
`tools_health_radar_prompt` / `tools_what_if_prompt` /
`tools_business_pulse_prompt`. Swapping them is a strings-only change.

They are read-only by construction ("Read only — do not change anything",
"without changing anything"), and a test asserts no prompt contains a
write verb — the sheet's own footer promises "Tools do not change Odoo without
your approval", and these fire on a single tap.

**If we guessed wrong and there IS an endpoint**, say so and we'll swap the
send for a call; the rows, gating, strings and tests all stay.

### 2b. Why §8 did NOT ship on the same reasoning

Fair question, since we just shipped §6 on an assumption.

The difference is what each one is missing. §6 needed **wording** — something
we can author, put in a string table, and correct in one line when you reply.
§8 needs a **destination**: a number, a URL, a support queue. That is a fact
about the business, not a phrasing choice, and there is no support or contact
affordance anywhere in the mobile app today to reuse.

Guessing a destination sends someone who is already stuck to the wrong place,
which is worse than not offering the row. So the flag stays strict and the row
stays unbuilt. The copy is translated and waiting.

**What we need:** what does clicking Voice support on web actually do?

### 3. A definition for §8 (Voice support)

"A support/contact affordance" is not enough to build against. What does the
web's row actually do — dial a number, open a WhatsApp thread, start a call
inside the app, file a ticket? Not built.

---

## Decisions we made ourselves

Your "Open decisions" section, resolved so the work could ship. Reverse any of
these and we will follow.

1. **Paperclip stays** (your recommendation). Composer reads
   `[＋] [📎] [🎤] … [badges] [→]`.
2. **Slash `/` folded into the `＋` sheet**, under "Odoo tools". It is a
   power affordance and the web has no equivalent; the action row now keeps
   only the two hot controls.
3. **Task-prep gating: interim option 1** (show unconditionally), implemented
   so that option 2 activates by itself the moment you ship the flag.

## Two implementation notes on §4

1. **"Prepare & review"** (`prompt_clarify`) — you describe it as "the same
   compose but routed to the review path". Mobile has no review endpoint, so
   it composes the identical text and drops it in the **composer** for the
   user to read, edit and send. Nothing is sent until they commit. If the web's
   review path is a real server-side route, send it over and we will switch.

2. **Report-card labels** come straight from each chip's server `label`, not
   from client `rbType_*` / `rbPeriod_*` keys. That means a report type you add
   tomorrow renders correctly on mobile immediately, but the chips do not flip
   language with the app. We will add client keys if you want that; it is a
   pure addition.

Also: the composed report request prefers the lens's `submit_en` / `submit_ar`
when present, and only falls back to a client-built sentence when the lens
carries neither.

---

## Where the code lives

| Gap | Files |
|---|---|
| 1, 7 | `lib/features/chat/widgets/saqqar_tools_sheet.dart` |
| 2 | Removal across 10 files; guarded by `test/deep_think_removed_test.dart` |
| 3 | `lib/features/chat/view_model/task_prep_cubit.dart`, `data/chat_features.dart` |
| 4 | `lib/features/chat/data/interactive_cards.dart`, `widgets/{prompt_clarify,report_builder,prompt_suggestion}_card.dart`, dispatch in `widgets/message_row.dart` |
| 5 | `lib/features/chat/widgets/chat_composer.dart` |
| 9 | `lib/features/chat/widgets/email_approval_preview.dart` |
| 10 | `lib/features/chat/data/delete_confirmation.dart`, `widgets/delete_approval_confirm_dialog.dart` |

Tests (748 passing): `task_prep_send_body_test`, `task_prep_plumbing_test`,
`composer_parity_test`, `saqqar_tools_sheet_test`, `chat_features_test`,
`interactive_cards_test`, `interactive_cards_hostile_test`,
`interactive_card_widgets_test`, `interactive_card_pipeline_test`,
`message_visibility_test`, `chat_timeline_test`, `approval_parity_test`,
`parity_copy_test`, `deep_think_removed_test`.

### One more thing the hostile-input sweep turned up

The card parsers were written with ordinary `as String?` / `as bool?` casts.
Those **throw** on a wrong-typed field — and they run inside the visibility
filter, i.e. over every message of every snapshot, on a 1.5 s poll. A single
`"truncated": "yes"` or `"label": 9` from a partial rollout would not have
lost a card; it would have thrown on every tick and taken the whole
conversation down with no way back in.

Fourteen such crashes existed. All fixed — nothing in the card parsers casts
any more, and `interactive_cards_hostile_test` holds ~25 malformed payloads
against every parser.

**So: send us whatever shape you have.** Wrong types degrade to "not a card"
or to a stringified value; they no longer break the chat.

---

## Honest parity ledger

What is still different after this document is fully closed, so nobody reads
"12/12 done" as "the two apps match".

| Difference | Why | Whose move |
|---|---|---|
| §6 rows send our wording, not yours | Built on an assumption; three strings to swap | Web team (send the text) |
| No Voice support row | Needs a destination, not copy | Web team |
| Prompt bank is 4 local starter prompts, not a saved-prompt catalogue | No backend for it | Product / backend |
| Feature gates are inert (they default to visible) | The 6 flags are not in the mobile snapshot | Backend |
| Report chips do not flip with app language | Mechanism shipped; the chip-key list is missing | Web team (send the keys) |
| "Prepare & review" seeds the composer | No mobile review endpoint | Web team |
| Delete phrase may not match yours word-for-word | Yours is quoted only as `حذف N` | Web team |
| Email preview keys are inferred | Payload shape not documented | Web team |
| Tools menu contents differ | We dropped 4 web rows, added a mobile-only Commands row | Product |
| Grouped approvals / `scope: "batch"` untested | Adapter never sets `grouped_count` | Backend |

And the one that is nobody's move: the 12 gaps came from reading web source,
not from running both apps side by side. Anything the two clients diverge on
that a source read did not surface is still out there. If the goal is genuine
parity rather than closing a list, the next step is someone driving the same
five flows on web and on mobile and writing down what differs.
