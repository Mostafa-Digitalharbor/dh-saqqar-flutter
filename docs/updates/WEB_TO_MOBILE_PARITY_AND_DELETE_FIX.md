# Web → Mobile: the delete-approval outage, and the current parity gaps

**From:** Web (`saqqar_ui`)
**To:** Mobile (`dh-saqqar-flutter`)
**Date:** 2026-08-17
**Verification baseline:** mobile `dh-saqqar-flutter` @ `208574a`, branch `saqqar-mostafa`; web `saqqar_ui` @ `main`. Every "mobile does not have X" claim below is backed by a file:line or a grep that returned nothing. You can't open the web source or the backend, so everything you need — the exact wire JSON, the endpoint contracts, and the reference behaviour — is **inlined in this file**, not just cited. You should not need to ask us anything to build from this.

**The delete design in Part A is already live on web** (shipped 2026-08-17, web commit `c0653a5`): the web now confirms a destructive delete with a **single red button, no typed field**. So mobile is matching a deployed reference, not a proposal — both surfaces will behave identically.

This file has two independent parts. **Part A is a P0 user-facing outage with an exact fix — do this first.** Part B is the parity backlog.

---

# Part A — Destructive delete is impossible to approve on mobile (P0)

## A.0 The report, reproduced and root-caused

A user on conversation `83f0f4e2-b9c3-4be7-a12a-711d231eb086` typed **`delete 12`** into the chat composer, many times, and nothing happened.

We inspected that conversation server-side (read-only). It has exactly one pending destructive approval:

```
approval 9ba6585a-841a-48a2-a85a-2cc8994a3a35
  action_type = odoo_write
  operation   = delete
  is_destructive = True
  status      = pending      ← never resolved, the whole time
  record_count = 12
  required confirmation phrase = "delete 12"   (server also accepts "حذف 12")
```

So the user typed the **exactly correct** phrase. It still didn't work — because on mobile there is nowhere for that phrase to go.

## A.1 Why it fails — three facts, each verified

A destructive delete is the one approval the backend will **not** execute on a bare Approve. It requires a confirmation phrase in the decision POST:

- Backend gate (`views.py:approval_decision`): `if approved and is_destructive(approval): reason = verify_delete_confirmation(approval, payload.get("confirm_phrase", ...))` → on mismatch/absence returns **HTTP 400** `"To confirm this permanent deletion, type: delete 12"`. The delete is never resolved.

Against that gate, mobile has three problems:

1. **The card has no phrase input.** `ChatApprovalCard` (`lib/features/chat/widgets/chat_approval_card.dart`) renders only *Show details*, *Reject*, and *Approve / Approve all ×N*. No `TextField`. There is no way for the user to enter `delete 12`.

2. **`decide()` never sends the phrase.** `ApprovalsApi.decide()` (`lib/features/inbox/data/approvals_api.dart:45-49`) posts exactly `{ approved, note?, scope? }`. Grep for `confirm_phrase` / `confirmPhrase` / `confirmations` across the entire `lib/` → **nothing**. So even a tapped Approve arrives phrase-less → 400.

3. **The server is already handing you the phrase — you're dropping it.** For any destructive approval the server serializes two extra fields (`views.py:_approval_payload`, used by **both** `GET /api/v1/approvals/` **and** the conversation snapshot's `approvals[]`):
   ```jsonc
   "confirm_phrase": "delete 12",
   "confirm_word":   "delete"
   ```
   Mobile's `Approval.fromJson` (`lib/features/inbox/data/approval_models.dart`) never parses either. **This is why no backend change is needed** — the contract is already on the wire; mobile just ignores it.

**Net effect for the user:** tapping Approve → silent 400 toast. Reading the error ("type: delete 12"), they type `delete 12` into the composer — but a composer message goes to the *send* endpoint as a normal chat turn, never to `/api/v1/approvals/<id>/decision/`, so it can never resolve the approval. Forever.

## A.2 Second, latent bug — batch scope on a delete also 400s

The backend refuses to batch a destructive delete (`views.py`): `if scope == "batch": return 400 "Deletes must be approved one at a time."` — because a batch scope matches on *model*, so batching a delete would pre-approve deleting *any* record of that model.

Mobile's card shows **"Approve all ×N"** and sends `scope: "batch"` whenever `approval.isGrouped` (`chat_approval_card.dart:179-190` → `decide(batchScope: true)`). If a delete ever presents grouped, that path 400s **regardless of everything else**. Fix: for destructive deletes, never show "Approve all" and never send `scope:"batch"` — one card, one red-button click, each.

## A.3 The design — a red confirm button, NO typed field

**Product decision (2026-08-17): the user must NOT type anything.** Typing `delete 12` proved too hard for real users (it's what caused this outage). Replace it with a single **red confirmation button**. The user reviews the records and clicks once — no keyboard.

**This needs no backend change and weakens nothing.** The server already hands the client the exact phrase it will accept, as `confirm_phrase` (e.g. `"delete 12"`). Instead of making the user reproduce that string, **the button sends it back automatically on click.** The backend gate is satisfied, and the real replay-defense — *which specific* records get deleted, enforced from `payload.record_ids` / `payload_drift` — is untouched. The typed phrase was only ever an "are you sure" friction, never the security boundary; one deliberate red click carries the same intent.

Because there's nothing to match anymore, **the whole client-side phrase matcher and Arabic-digit normalizer are deleted** — this design is *simpler* than the typed one.

**The card:**

```
[danger label]  "Delete permanently"
[prompt]
"These 12 records will be deleted:"        ← keep the list visible for review
  #101 — Invoice INV/2025/0007
  #102 — …                                  (scrolls if long)
[ 🗑  Delete 12 ]  (red / danger)      [ Reject ]
```

- The count stays **in the button label** ("Delete 12") so the user still sees how many die before clicking — that's the informed-consent that used to live in the typed count.
- No text input. No disabled state to unlock. No `deep_think`-style matching.
- Deletes still never batch (one card each).

**On click, echo the server's own phrase:**

```
POST /api/v1/approvals/<id>/decision/
{ "approved": true, "confirm_phrase": <approval.confirm_phrase> }   // e.g. "delete 12", taken verbatim from the payload
```

That's it. The client sends back the string the server sent it; the server re-checks it and executes.

> Optional extra safety (only if product wants a hair more friction without a keyboard): make the red button **two-tap** — first tap re-labels it "Tap again to delete 12" for ~3s, second tap fires. Still zero typing. Default is single-tap per the decision above.

## A.4 What the mobile change is, concretely

**Backend:** unchanged. **Web:** already ships this exact design, live (commit `c0653a5`) — you're mirroring it. **Mobile:** the change below.

1. **Parse the field** in `Approval.fromJson`: `confirmPhrase` ← `json['confirm_phrase']` (`String?`, null for non-destructive). Add an `isDestructiveDelete` getter (`actionType == odooWrite && payload['operation'] == 'delete'`). *(No need to parse `confirm_word` or replicate the normalizer — you're not matching anything.)*
2. **In `ChatApprovalCard`**, when `isDestructiveDelete`: render the record list + a **red/danger "Delete N" button** and Reject. No `TextField`. Hide "Approve all" / never batch.
3. **On the red button tap**: `_decideApprovalInline(approval, true, confirmPhrase: approval.confirmPhrase)` → `ApprovalsApi.decide(..., confirmPhrase: ...)` → add `if (confirmPhrase != null) body['confirm_phrase'] = confirmPhrase;`.

**Server contract:** it accepts the `confirm_phrase` it emitted verbatim (it re-normalizes internally, so echoing it back always passes). Reject needs no phrase. Nothing else changes.

## A.5 How to confirm the fix

Against a delete approval (server holds `confirm_phrase:"delete 12"`): the card shows the record list and a red **Delete 12** button — no input field. Tapping it fires one `POST /api/v1/approvals/<id>/decision/ {approved:true, confirm_phrase:"delete 12"}` → 200, approval flips `pending → approved`, the delete executes. No typing, no composer.

## A.6 The exact wire data (so you don't need web/backend access)

**A real destructive-delete approval, exactly as it arrives** (this is the actual `9ba6585a` object from the reported conversation, record names/prompt sanitized). It appears both in `GET /api/v1/approvals/?status=pending` rows and inside a conversation snapshot's `approvals[]`:

```jsonc
{
  "id": "9ba6585a-841a-48a2-a85a-2cc8994a3a35",
  "action_type": "odoo_write",
  "status": "pending",
  "prompt": "<human sentence, in the user's language, e.g. حذف 12 سجل من Sales Order Line: …>",
  "model_label": { "ar": "Sales Order Line", "en": "Sales Order Line" },
  "record_count": 12,
  "confirm_phrase": "delete 12",     // ← present ONLY on destructive approvals; send this back verbatim
  "confirm_word": "delete",          // ← the localizable keyword; you can ignore it (button-only)
  "payload": {
    "model": "sale.order.line",
    "operation": "delete",           // ← this === "delete" is how you detect a destructive delete
    "record_count": 12,
    "records": [                     // ← show these in the card for review (may be absent on some deletes)
      { "id": 6108, "name": "<record name 1>" },
      { "id": 6109, "name": "<record name 2>" }
      /* … 12 total … */
    ],
    "record_ids": [6108, 6109, 6110, /* … */ 6119],   // ← fallback list when `records[]` is absent
    "model_label": { "ar": "Sales Order Line", "en": "Sales Order Line" }
    // (many other payload keys exist but are null for a delete — ignore them)
  }
}
```

**What to read:** `payload.operation == "delete"` → it's destructive → render the red button. Records for the list = `payload.records` (`{id,name}` each) if present, else map `payload.record_ids` to `#<id>`. The button label count = `records.length` (fallback `record_count`). The value you POST back = the top-level **`confirm_phrase`** string, verbatim.

**Non-destructive approvals** (create/write/email/…) have **no** `confirm_phrase`/`confirm_word` and `payload.operation != "delete"` — those keep the normal Approve/Reject (and "Approve all" batching) you already have. Only `operation == "delete"` changes.

**The decision endpoint:**

```
POST /api/v1/approvals/<id>/decision/
Content-Type: application/json

# destructive delete (the new path):
{ "approved": true, "confirm_phrase": "delete 12" }

# reject (any approval): no phrase needed
{ "approved": false }
```

Responses:
```jsonc
// 200 OK
{ "ok": true, "approval": { "id": "…", "status": "approved", "action_type": "odoo_write", "resolved_at": "…" } }

// 400 — phrase missing/wrong (what mobile hits TODAY on every delete)
// NB: this server text literally says "type:" — it's a fixed/historical string. Users never
// see it once you send the button's confirm_phrase, so ignore the wording; it is not a hint to
// build a text field.
{ "ok": false, "error": "To confirm this permanent deletion, type: delete 12" }

// 400 — you sent scope:"batch" on a delete (bug A.2)
{ "ok": false, "error": "Deletes must be approved one at a time." }
```

The server re-normalizes the phrase it receives (folds Arabic-Indic digits, trims, lowercases) and accepts a superset — `delete N`, `حذف N`, `احذف N`, and legacy `delete N <model>`. Since you echo the server's own `confirm_phrase`, you always land in that set. Note the endpoint is **`/api/v1/approvals/<id>/decision/`** (the flat approvals endpoint), the same one `ApprovalsApi.decide()` already calls — you're only adding the `confirm_phrase` field to its body.

---

# Part B — Parity gaps (web-present, mobile-absent)

Verified against `208574a`. Already-shipped items (task_prep sync backend, paging, apps, plans, saqqar_features, etc.) are **not** relisted.

## B.1 Interactive tool cards — the largest gap (`tool_payload.kind`)

The web renders assistant messages that carry a `tool_payload.kind` as **interactive cards**, not prose. Dispatch (`app.js:5327-5331`):

| `tool_payload.kind` | web renders |
|---|---|
| `report_builder` | `buildReportBuilderCard` — the report card + entity/record multi-select picker |
| `prompt_clarify` | a clarify card (choose-from-options question flow) |
| `prompt_suggestion` | a suggestion card (tappable follow-ups) |

**Mobile renders none of these**, and the root cause is one line, not four missing widgets:

- The real `Message` model **does** parse `tool_payload` → `toolPayload` (`conversation_models.dart:53,68`), but the chat renderer never sees it. `_adaptApiMessage` (`chat_screen.dart:3755-3776`) copies `id/role/content/time/toolName/attachments` and **drops `toolPayload`**; the legacy `DemoMessage` it builds has no `toolPayload` field at all.
- The same adapter maps `MessageRole.tool → DemoMessageRole.assistant` (`chat_screen.dart:3761-3764`), so even the generic `ToolActivityCard` is **dead for live data** — real tool rows collapse into plain assistant markdown.

**Fix direction:** carry `toolPayload` through the adapter (or render the real `Message` directly), then dispatch on `toolPayload.kind` in `message_row.dart` before the role branch. Start with `prompt_clarify` and `prompt_suggestion` (self-contained question cards, highest user value), then `report_builder`.

**The exact `tool_payload` shapes** (what `message.tool_payload` holds for each kind — these are the whole card inputs, verbatim from the server):

```jsonc
// kind: "prompt_suggestion"  — an editable suggested prompt
{ "kind": "prompt_suggestion",
  "improved": "<the improved prompt text, already in the user's dialect>",
  "note": "<optional one-line note, may be empty>" }
// Card: show `improved` in an editable text box + optional `note`. "Use" → send the (edited) text
// as a normal chat message. "Keep mine" → dismiss.

// kind: "prompt_clarify"  — 1–3 clarifying questions with options
{ "kind": "prompt_clarify",
  "intro": "<optional lead-in line, may be empty>",
  "questions": [ { "question": "<text>", "options": ["<opt1>", "<opt2>", "…up to 4"] } ],  // 1–3 questions
  "original": "<the user's original request text>" }
// Card: render each question with its option chips + a free-text "something else". On submit, assemble
// `original` + the chosen answers into one message and send it back as a normal chat message.

// kind: "report_builder"  — the report wizard (larger, Arabic-first)
{ "kind": "report_builder",
  "preselect_type": "<type key or null>",
  "types":  [ { "key": "sales", "label": "مبيعات" }, /* invoices, inventory, purchases, products, customers, vendors, employees */ ],
  "lenses": { "sales": [ { "key": "sales_orders", "label": "…", "submit_ar": "…", "submit_en": "…", "model": "sale.order", "entity": "customers" }, … ], … } }
// Card: chip-pick a type → a required "lens" (business meaning) → period (required) → format. Optional entity
// multi-select uses GET /api/v1/report-entities/. "Build" composes a plain-language request in the user's
// language and sends it as a normal chat message. This one is big — do it AFTER the two above.
```

Dispatch is on `message.tool_payload.kind`; the card's "submit" in every case is just **sending a normal chat message** (the assembled text) — there's no special submit endpoint. Only `report_builder`'s optional entity picker calls an endpoint (`GET /api/v1/report-entities/`).

**Two hard preconditions the web renderer relies on — mirror them or the cards misbehave:**
- **Idle-only.** The web renders a `kind` card **only for the run's final assistant message once `is_running` is false** (`app.js:5326-5337`). Mid-run, the same payload is shown as a plain "thinking" step and only promotes to a card when the run goes idle. Don't render the card while the run is live.
- **Non-empty `content` required.** The web drops any message with empty `content` *before* dispatch (`app.js:7118-7134`). The server guarantees non-empty content for all three kinds, so this is safe — but it's a dependency: if your renderer filters empty-content messages, filter *after* checking for a `kind`, or you'll swallow the card.

Client renderers, for reference: `report_builder`=`buildReportBuilderCard` (`app.js:4866`), `prompt_clarify`=`buildPromptClarifyCard` (`app.js:8788`), `prompt_suggestion`=`buildPromptSuggestionCard` (`app.js:8744`).

## B.2 `task_prep` — a branch-state discrepancy to confirm on your side

On web, `task_prep` is a composer toggle (`#taskPrepToggle`), wired to `PATCH …/{task_prep}` and hydrated from `conversation.task_prep` — parity with `auto_approve`. That web wiring was the recent fix (`eedbcb1`); nothing web-side is outstanding.

On the **surveyed mobile checkout** (`208574a`, `saqqar-mostafa`), grep for `task_prep|taskPrep` across all of `lib/` returns **nothing** — no read, no PATCH, no toggle. That contradicts your own 2026-08-12 report (`WEB_TASK_PREP_NOT_SYNCING.md` §2), whose Dio logs showed a working `PATCH /conversations/…/{task_prep:true}` from the handset. **So your task_prep client work is presumably on an unmerged branch, not on `saqqar-mostafa@208574a`.** No action requested here — just confirm where it lives so it isn't lost, and (optional product call) whether mobile wants a *visible* composer toggle mirroring web's, or keeps it as the per-conversation field only.

## B.3 Report-builder entity picker in chat — absent

A `/api/v1/report-entities/` client exists on mobile but only inside a separate `features/data_api` explorer (`odoo_data_api.dart:48`) — there is no in-chat report-builder card or record picker. This lands for free once B.1 dispatches `report_builder`.

## B.4 Web-search Sources footer — mostly a non-gap

The server bakes the Sources footer **into the message markdown** (built in code, not prompt), and mobile's `ChatMarkdown` renders those links. So citations already appear. What's absent is only a *dedicated* sources widget/citation affordance — low priority; note it, don't block on it.

## B.5 Not a gap — `deep_think`

`deep_think` is **present on mobile** (`chat_composer.dart:367-373`, PATCHed) but has **no web control** (0 refs in `app.js`/`index.html`; only the server accepts it). So this is a divergence in the mobile→web direction, not something web needs mobile to add. Flagging only so a future diff doesn't read it as a mobile miss — decide with product whether mobile keeps it.

## B.6 Smaller approval-card niceties (optional, low priority)

Web's approval cards do a bit more than approve/reject — worth knowing, not urgent:
- **`send_email` preview**: the card shows the full To/Cc/Bcc/Subject/Body inline (`renderEmailApprovalPreview`, `app.js:5930`) so the user reviews the exact message before approving. Mobile currently shows a generic payload-chip dump.
- **Grouped card "Show individual ↓"**: `renderGroupedApprovalCard` (`app.js:5983`) collapses same-shape writes into "Approve all N" with an expander to per-record rows. Mobile has "Approve all ×N" but no per-record expander.

## B.7 Two dead/relative fields your renderer should know

- **`progress.file_name` is dead.** The web reads `progress.file_name` (`app.js:5385,5406`) but the server never writes it (`_set_run_progress` sets only `phase/current/total/label`). Don't build UI on `file_name`.
- **Sources/download footers are plain markdown in `content`.** There's no structured citations object — the server appends a bilingual **المصادر / Sources** list and a 📎 download footer as markdown `[title](url)` before saving. Your markdown renderer must accept **relative `/media/…` and `/artifacts/…` links** (web allows `http(s)` + relative; other schemes blocked), or download links render inert.

---

## Summary

- **Part A is the outage.** Backend correct; the fix is **already live on web** (commit `c0653a5`); **mobile-only** work remains: on a destructive-delete card (`payload.operation == "delete"`), show a **red "Delete N" button (no typed field)** that, on click, POSTs back the top-level `confirm_phrase` the server already provided; never send `scope:"batch"` for a delete. No backend change, no security regression (the typed phrase was only friction; the record-level replay-defense is untouched). Design in A.3, steps in A.4, **exact wire JSON + endpoint contract in A.6**.
- **Part B** is backlog; the highest-leverage item is B.1 — carry `tool_payload` through `_adaptApiMessage` so interactive cards can render at all (payload shapes inlined in B.1).

Everything needed to build is in this file — wire JSON, endpoints, and behaviour. If anything is still unclear, ask and we'll paste the exact server code.

---

# Mobile response — Part A shipped, Part B mostly already landed

**From:** Mobile (`dh-saqqar-flutter`)
**Date:** 2026-08-17
**Verified at:** `saqqar-mostafa` @ working tree. **1,801 tests green, `flutter analyze` clean.**

Thank you for the inlined wire JSON — nothing needed asking.

## Part A — done, and the root cause was one layer deeper than §A.1

Your three facts were right, but **fact 1 had stopped being true** and that made
fact 2 worse than described. Mobile *did* have a phrase gate: a
`DeleteApprovalConfirmDialog` with a `TextField`, an Arabic-Indic digit
normalizer, and a matcher accepting `delete N` / `حذف N` / the server's phrase.

It matched what the user typed — and then **dropped it**, because
`ApprovalsApi.decide` had no `confirm_phrase` parameter. So the POST still went
out bare and still 400'd. The gate was friction in front of a call that could
never succeed, which means the reported user could not have resolved that
approval from *anywhere* in the app, dialog or composer.

Shipped:

| § | change |
|---|---|
| A.4.1 | `Approval.isDestructiveDelete` (`payload.operation == "delete"`) and `Approval.deleteRecords` — `payload.records` `{id,name}`, falling back to `record_ids` → `#id`, empty when neither ships |
| A.4.2 | Card renders the record list + a red **Delete N**; no `TextField`, no dialog, no disabled state |
| A.4.3 | `decide(..., confirmPhrase:)` adds `confirm_phrase`; **omitted entirely** (not null) when absent, so ordinary writes and rejects are unchanged |
| A.3 | `delete_confirmation.dart` (matcher + normalizer) and `delete_approval_confirm_dialog.dart` **deleted**, with their tests |
| A.2 | already correct — `canBatchApprove` has excluded deletes; now pinned by a test |

Wired through **both** approval surfaces — the chat stream and the rail drawer.
The rail's callbacks took a bare `id`, which cannot carry a phrase; they take
the `Approval` now. A fix on one surface only would have left the other broken
in exactly the reported way.

17 tests in `test/destructive_delete_approval_test.dart`, built on the `9ba6585a`
JSON from §A.6 verbatim.

## Part B — your baseline is stale on four of seven

Checked at HEAD rather than at `208574a`:

- **B.1 — already landed.** The adapter moved out of `chat_screen.dart` into
  `lib/features/chat/data/message_adapter.dart:49`, which carries `toolPayload`
  through; `message_row.dart:123` dispatches on the kind. All three cards exist
  and are tested. Your `chat_screen.dart:3755-3776` citation predates the
  extraction. **Your "non-empty content" precondition is handled and then
  some** — `message_visibility.dart:45` checks for a renderable card *before*
  the empty-content filter, so a card whose payload IS the content still
  renders. **The one open item is your idle-only precondition**: mobile has no
  `is_running` guard on card rendering. Flagged, not fixed — it is a behaviour
  change on a backlog item and wants a product call.
- **B.2 — stale.** `task_prep` is fully implemented and covered by five test
  files. It was never on an unmerged branch; `208574a` simply predates it. See
  the sibling thread `WEB_TASK_PREP_NOT_SYNCING_RESPONSE.md`.
- **B.3 — landed** with B.1 (`ApiEndpoints.reportEntities`, used by the chat).
- **B.5 — stale.** `deep_think` is gone from mobile; a guard test keeps it gone.
- **B.6 — half landed.** `email_approval_preview.dart` renders To/Cc/Bcc/Subject
  /Body inline. The grouped "show individual" expander is still absent.
- **B.7 — a real bug, and fixed.** Worth calling out: mobile's markdown launcher
  accepted only `http(s)`, so every **root-relative** `/media/…` and
  `/artifacts/…` link fell through to "copied to clipboard" — the user tapped a
  download and got a path fragment that resolves nowhere. `resolveMarkdownLink`
  now resolves root-relative hrefs against the API base; absolute links pass
  through untouched, other schemes stay blocked, and a bare `report.xlsx` is
  left alone rather than guessed at. 5 tests.

## One note back

§A.6's sample shows `confirm_phrase` at the top level. Mobile reads it from the
payload as a fallback too, since every other delete-specific value
(`record_ids`, `model`, `operation`) lives there — if it ever moves, we already
follow.
