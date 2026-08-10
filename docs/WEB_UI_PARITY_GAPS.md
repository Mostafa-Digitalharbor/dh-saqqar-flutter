# Saqqar mobile ⟶ web UI parity: gaps & how to close them

**To:** Mobile developer (hand this whole file to a fresh Claude Code session
rooted in this repo, `dh-saqqar-flutter`).
**From:** Web team.
**Date:** 2026-08-04.
**Re:** Over the last ~6 weeks the **web** app moved ahead of mobile in two
places: (1) the **composer** (a new `+` Saqqar-tools menu, a Task-prep toggle,
Deep-think removed, a reshaped button bar) and (2) the **chat stream itself** —
Saqqar now posts **interactive cards** where the user *chooses from options
inside the conversation* (clarifying questions, report builder, prompt
suggestion). Mobile renders none of those interactive cards yet.

Every gap below was verified against the current web source. Web is the source
of truth; each item cites `web: <file>:<line>` so your session (and the web team)
can trace it. **Note:** you have this Flutter repo but *not* the web repo, so the
exact web behavior is quoted inline, and Appendix A gives the JSON payload shapes
you need to build the cards.

---

> **⚠️ You do NOT need the web repo.** The mobile dev / Claude session cannot
> open the `web: <file>:<line>` citations — those are **provenance for the web
> team only**. Every fact you need to implement is written **inline** in this
> file: UI behavior in prose, exact EN/AR strings in tables, and the JSON payload
> + API contracts in **Appendix A**. If any task seems to require reading web
> code, treat that as a gap in this doc and ask the web team — don't go looking
> for the web source. The one backend endpoint you'll call
> (`/api/v1/report-entities/`) is fully specified in Appendix A.2.

## 0. How to use this document

- **You are the mobile dev.** Open a fresh Claude session **in this repo**. Each
  numbered gap is self-contained — you can start on any one alone.
- **Same backend.** Mobile and web hit the **same Django server**
  (`https://saqqaar.com`, `/api/v1/…`). Anything the server already accepts
  (e.g. the `task_prep` send-body key, or a `tool_payload` with `kind`) works
  from mobile today — the gap is the mobile UI, unless a task calls out a backend
  touch-point.
- **Priorities:** **P0** = named by the product owner + the interactive-card
  break. **P1** = shipped on web, no mobile counterpart. **P2** = verify the
  mobile side first (likely gap, not fully confirmed here).
- **Bilingual + RTL is mandatory** for every item. Exact EN/AR strings are given
  where you'd otherwise have to guess.

### Priority overview

| # | Gap | Priority | Type |
|---|---|---|---|
| 1 | No `+` Saqqar-tools menu | P0 | Composer |
| 2 | Deep-think still present (web removed it) | P0 | Composer + wiring |
| 3 | Task-prep toggle missing | P0 | Composer + send body |
| 4 | **In-chat interactive cards not rendered** (clarify / report / suggestion) | P0 | **Chat stream** |
| 5 | Composer shape/button set diverged | P0 | Composer |
| 6 | Odoo tools (radar / what-if / pulse) | P1 | Tools menu |
| 7 | Prompt bank | P1 | Tools menu |
| 8 | Voice **support** channel (≠ mic) | P1 | Tools menu |
| 9 | Email-approval preview card | P2 | Chat stream |
| 10 | Delete-approval Arabic localization | P2 | Chat stream (possible bug) |
| 11 | Approval resume + inline approvals | P2 | Chat stream |
| 12 | Env picker: single vs multi-select | P2 | Chat header |

### Source-of-truth file map

| Concern | Web (truth) | Mobile (to change) |
|---|---|---|
| Composer markup | `web: odoo_agent/templates/odoo_agent/index.html:214-273` | `lib/features/chat/widgets/chat_composer.dart` |
| Tools `+` menu | `web: odoo_agent/static/odoo_agent/app.js:7935` (`renderShadowMenu`) | *(none yet)* |
| Chat message render + `kind` dispatch | `web: app.js:5098-5210` (`renderMessages`) | `lib/features/chat/widgets/message_row.dart`, `message_bubble.dart` |
| Interactive cards | `web: app.js:4737 / 8595 / 8639` | *(none yet)* |
| Message model (already carries `tool_payload`) | — | `lib/features/conversations/data/conversation_models.dart:40-68` |
| Feature flags | `web: views.py:327-339` (`chat_app`) | `conversation_models.dart:447+` (feature snapshot) |

---

# P0

## 1. ⛔ No "Saqqar tools" (`+`) menu on mobile

**Web.** The composer's left-most control is a `+` button (`#shadowMenuButton`,
`web: index.html:227-234`) opening the **Saqqar tools** menu
(`renderShadowMenu`, `web: app.js:7935`). Contents:

- **Upload file** — top-level (`data-attach-open`) → file picker.
- **Modes** (collapsible): Prompt bank, **Task prep** toggle, **Auto-approve**
  toggle. (`web: app.js:7977-7986`)
- **Odoo tools** (collapsible): Health radar, What-if, Business pulse.
  (`web: app.js:7990-7993`)
- **Connections** (collapsible): My database, Apps, Voice support, Credential
  vault. (`web: app.js:7994-7998`)
- Footer: "Tools do not change Odoo without your approval."

Each row is feature-flag gated; an off flag omits the row (or the whole section).

**Mobile.** No tools menu. The composer scatters attach/slash/mic as loose icon
buttons (`chat_composer.dart:284-312`). Radar / what-if / pulse / prompt-bank /
voice-support don't exist anywhere in `lib/` (verified: zero matches).

**Build.**
- Add a `+` trigger to the composer action row.
- Open a **bottom sheet** — use this repo's `chat_sheet.dart` / `*_sheet.dart`
  pattern. Do **not** port the web's `positionShadowMenu()` popover math; a
  bottom sheet is the right mobile idiom.
- Populate with the rows above **that make sense on mobile**. Several targets are
  already full mobile screens — link to them, don't rebuild (see §"parity").

**Strings (exact, from `web: app.js`):**

| key | EN | AR |
|---|---|---|
| `toolsTitle` | Saqqar tools | أدوات صقار |
| `toolsUploadFile` | Upload file | رفع ملف |
| `toolsModesSection` | Modes | أوضاع التشغيل |
| `toolsOdooSection` | Odoo tools | أدوات Odoo |
| `toolsConnectSection` | Connections | الربط والتكاملات |
| `radarReadonly` | Tools do not change Odoo without your approval. | الأدوات لا تغيّر أي شيء في Odoo بدون موافقتك. |

**Acceptance:** `+` opens a bottom sheet listing Upload file, Task prep,
Auto-approve, and any live Odoo tools; each row routes correctly; off/absent
features omitted; LTR **and** RTL.

---

## 2. ⛔ Remove the "Deep think" toggle (web already removed it)

**Web.** Deep-think is **gone** from the web UI — `app.js` has **0**
`deepThink`/`deep_think` references and the composer has no toggle. The backend
still silently routes hard tasks (artifact/code authoring) to the stronger
model, so nothing user-visible was lost — only the manual toggle.

**Mobile.** Still fully present — **104 references across 11 files**:

```
25  lib/features/chat/view/chat_screen.dart
14  lib/features/chat/view_model/chat_cubit.dart
13  lib/features/conversations/data/conversation_models.dart
13  lib/core/i18n/app_strings.dart
10  lib/features/chat/widgets/chat_composer.dart
 8  lib/features/chat/widgets/chat_header_controls.dart
 6  lib/features/chat/view_model/deep_think_cubit.dart
 6  lib/features/conversations/data/conversations_api.dart
 6  lib/features/conversations/data/conversations_repository.dart
 2  lib/main.dart
 1  lib/core/constants/ui_strings.dart
```

**Remove (mirror the web team's approach: strip UI + wiring, keep the model
tolerant):**
- Composer toggle: `deepThink` param + its `_ComposerToggle` + the `_ActiveModeBadge`
  deep-think branch (`chat_composer.dart:35-37, 89-92, 314-321, 367-373`).
- Delete `deep_think_cubit.dart` and its `main.dart` registration.
- Remove the deep-think control in `chat_header_controls.dart`.
- Stop sending `deep_think` in send/PATCH bodies (`conversations_api.dart`,
  `conversations_repository.dart`, `chat_cubit.dart`).
- **Keep `conversation_models.dart`'s `deepThink` field parse-and-ignore** — the
  server still serializes the key; a stricter model would break decoding.
- Remove i18n keys last, then re-run `test/i18n_parity_test.dart` (dropping a key
  from only one of EN/AR turns it red).

**Acceptance:** no Deep-think UI anywhere; send body no longer sets a user
`deep_think`; conversation decoding still succeeds if the server returns the key;
normal send still works; `i18n_parity_test.dart` passes.

---

## 3. ⛔ "Task prep" toggle missing on mobile

**Web.** A **Task prep** toggle in the composer bar (`web: index.html:243-249`,
`#taskPrepToggle`) **and** as a Modes row in the tools menu
(`web: app.js:7981-7982`). On → Saqqar asks quick clarifying questions before
building (which arrive as the **prompt_clarify card**, §4). Server reads it from
the send body (`web: views.py:578` → `payload.get("task_prep", True)`) and gates
it server-side (`views.py:581-582`, coerced to `False` if the plan lacks it). Web
shows the toggle only when `task_prep_available` (`views.py:338`).

**Mobile.** Absent (zero `task_prep` matches).

**Build.**
- Add a Task-prep toggle to the composer (mirror the existing `_ComposerToggle`
  in `chat_composer.dart`) and, once §1 lands, a tools-sheet row.
- Send `task_prep: <bool>` in the send-message body from `chat_cubit.dart` /
  `conversations_api.dart`. **The server already honors this key today** — no
  backend change for the toggle to function.
- **Gating (backend touch-point):** `task_prep_available` is returned **only in
  the web HTML context** (`views.py:327-339`), **not** in any mobile JSON
  endpoint. Options: (1) show unconditionally and rely on the server's own
  gating (safe, but ineligible users see a dead toggle); (2) ask backend to add
  `task_prep_available` (and `voice_support_available`) to the mobile **feature
  snapshot** (`conversation_models.dart:447` already carries plan/quota/features
  — the natural home) and gate on it. **Recommend (2)**; (1) is an acceptable
  interim.

**Strings (exact, from `web: app.js`):**

| key | EN | AR |
|---|---|---|
| `taskPrep` | Task prep | تجهيز المهمة |
| `taskPrepTitle` | Saqqar asks quick questions to refine a vague task before building | صقّار يطرح أسئلة توضيحية مختصرة قبل تنفيذ أي مهمة غير واضحة |
| `taskPrepOn` | Task prep on. Saqqar will ask a couple of questions to refine vague tasks. | تجهيز المهمة مفعّل. صقّار سيطرح أسئلة قصيرة لتوضيح المهام غير المكتملة. |
| `taskPrepOff` | Task prep off. Saqqar builds directly from what you write. | تجهيز المهمة متوقف. صقّار سيبدأ من النص المكتوب مباشرة. |

**Acceptance:** toggle present; state sent & honored; hidden/disabled per chosen
gating; RTL labels read fully; `i18n_parity_test.dart` passes. **Note:** the
toggle is only half the feature — without §4 the clarifying questions it triggers
can't be answered on mobile.

---

## 4. ⛔ In-chat interactive cards are not rendered (the "choose from a card" flow)

**This is the biggest chat-side gap.** On web, Saqqar can reply with an
**interactive card inside the conversation** — the user taps options / edits text
right in the chat and that composes the next message. The web message renderer
dispatches on `message.tool_payload.kind` (`web: app.js:5198-5207`):

```js
if (result.tool_payload.kind === "report_builder")      buildReportBuilderCard(result);
else if (result.tool_payload.kind === "prompt_clarify")  buildPromptClarifyCard(result);
else if (result.tool_payload.kind === "prompt_suggestion") buildPromptSuggestionCard(result);
else                                                     buildAgentMessageCard(result);
```

**Mobile.** The message model **already carries** `tool_payload`
(`conversation_models.dart:53,68`), but the renderer has **no branch on
`kind`**: `message_row.dart:31-34` sends any tool-role message to the generic
`ToolActivityCard`, which shows "the monospace payload on a code plate"
(`tool_activity_card.dart:11`). Verified: **zero** matches in `lib/` for
`prompt_clarify | report_builder | prompt_suggestion | questions | pq-opt`. So
today a mobile user gets a **raw JSON blob with nothing to tap** where the web
user gets an interactive card. **With Task-prep (§3) on, this makes vague
requests unusable on mobile.**

**Build.** Add a `kind` dispatch in the mobile message renderer (parallel to
`web: app.js:5198`) and implement three card widgets. Payload shapes + exact
button behavior are in **Appendix A** — build to that. The three:

### 4a. `prompt_clarify` — clarifying-questions card *(build first; ties to §3)*
`web: buildPromptClarifyCard, app.js:8639`. Saqqar asks 1–3 short questions, each
with tappable option chips (single-select per question) plus a "Something else…"
free-text field. A smart **default** option may be pre-selected. Two actions:
**Build & send** and **Prepare & review**. On tap it composes
`"Answers to your questions:\n- <q> <a>\n…"` and sends it. See Appendix A.1.

### 4b. `report_builder` — report configurator card
`web: buildReportBuilderCard, app.js:4737`. Chips for **type**, **period**,
**lens**, **format (PDF/…)**, plus a secondary **entity multi-select** ("which
customers / vendors / employees?") loaded from `GET /api/v1/report-entities/`.
The picks compose a precise report request that's sent. Labels are localized
**on the client** from keys the server sends. See Appendix A.2.

### 4c. `prompt_suggestion` — cleaner-prompt card
`web: buildPromptSuggestionCard, app.js:8595`. Shows an **editable textarea**
with a tidier version of the user's request + optional note. **Approve & use**
sends the (possibly edited) text; **Keep mine** dismisses the card. See Appendix
A.3. *(Mobile has a suggestion **strip** — `chat_suggestion_strip.dart` — but
that's the empty-state starter prompts, a different thing; confirm it doesn't
already cover this.)*

**Acceptance:** a message with each `kind` renders its interactive card (not raw
JSON); selecting/typing then confirming composes and sends the correct follow-up;
smart-default pre-selection works for `prompt_clarify`; the report card's entity
multi-select calls `/api/v1/report-entities/`; all three are bilingual + RTL and
theme-aware.

---

## 5. ⛔ Composer shape / button set has diverged

**Web (the "new shape").** Left → right (`web: index.html:227-270`):

`[ + Saqqar-tools ] · divider · [Task prep] [Auto-approve] —spacer— [🎤 mic] [→ send]`

No paperclip (upload moved into the `+` menu + drag-drop), no deep-think, no
slash button.

**Mobile.** Two-row pill (`chat_composer.dart`): textarea, then
`[📎][/][🎤] —spacer— [badges][→]`, then a **third** toggles row
`[Deep think][Auto-approve]`.

**Reconcile.** After §1–§3, the mobile bar should read roughly
`[ + tools ] [📎?] … [Task prep] [Auto-approve] —spacer— [🎤] [→]`, deep-think
gone. Whether the paperclip and slash survive is an **open decision** (below) —
web deleted both, but that's touch-specific.

**Acceptance:** matches the agreed mobile layout; no deep-think; task-prep
present; tools reachable via `+`; RTL mirrored.

---

# P1 — shipped on web, absent on mobile

## 6. Odoo tools: Health radar · What-if · Business pulse
`web: app.js:7990-7993`, each behind a flag (`health_radar`, `what_if`,
`business_pulse`). Server-side scans/simulations streamed into chat. Mobile: none
(zero matches). Add as tools-sheet rows (§1), gated on those flags (same
snapshot-plumbing note as §3). Confirm the server endpoints with the web team
before wiring.

## 7. Prompt bank
`web: app.js:7978-7979` (gated `prompt_bank`) — a saved-prompt / task-wording
entry. Mobile: absent. Add as a tools-sheet row if product wants it.

## 8. Voice **support** (contact channel) — NOT the mic
`web: app.js:7997` (gated `voice_support`), a support/contact affordance. Mobile
already has voice **input** (mic + `/transcribe/`, `voice_input_button.dart`) —
**do not conflate.** Voice *support* is absent; add only if product wants it.

---

# P2 — verify the mobile side before building

## 9. Email-approval preview card
**Web:** `renderEmailApprovalPreview` (`web: app.js:5798`) shows a preview before
Saqqar sends an email. **Mobile:** zero `emailApproval` matches — likely renders
as a plain approval or raw payload. Verify and add a preview if missing.

## 10. Delete-approval localization (possible functional bug)
**Web:** destructive-delete confirmations were localized to Arabic (`حذف N`) with
Arabic-Indic digit folding (`renderDeleteApprovalCard`, `web: app.js:5756`;
commit `ed4460b`, verified in the web tree — 22 `حذف` refs in `app.js`). **Mobile:**
`chat_approval_card.dart` showed no localized type-to-confirm phrase on a grep.
**Verify:** if the mobile delete flow expects an English `delete N <model>`
phrase, **AR users can't confirm deletes — a bug, not polish.**

## 11. Approval resume + inline approvals
**Web:** clicking **Approve** restarts the stalled run server-side (commit
`6d04250`, verified — 7 `inlineApprovals`/resume refs); approvals also surface
**inline** in the composer area (`web: index.html:212`, `#inlineApprovals`), not
only the Inbox. **Mobile:** has `chat_approval_card.dart` + an `inbox` feature.
Verify the mobile Approve triggers the server-side resume (vs. waiting for the
user to type a continuation) and that pending approvals surface inline in chat.

## 12. Environment picker: single vs multi-select
**Web:** a **single-select radio** DB picker per chat (commit `0d80df5`,
verified). **Mobile:** `environment_multi_select_sheet.dart` is **multi**-select.
Possibly intentional (mobile may support multi-env) — confirm the intended model
with product.

---

## Already have parity — do NOT rebuild

The web surfaces some of these from its tools menu, but they're **first-class
screens/widgets** in this app. Link to them; don't reimplement.

| Feature | Mobile file(s) | Status |
|---|---|---|
| Credential vault | `lib/features/vault/` | Screen exists |
| Apps | `lib/features/apps/` | Screen exists |
| My database / env selection | `chat_header_controls.dart`, `environment_multi_select_sheet.dart`, `chat_env_hint_banner.dart` | Exists (see §12 for the select-mode question) |
| Voice **input** / transcribe | `voice_input_button.dart` | Exists (≠ §8) |
| Thinking / reasoning fold | `chat_thinking_pill.dart` | Exists |
| Tool-activity ("Reading files…") cards | `tool_activity_card.dart`, `data/tool_status.dart` | Exists (but see §4 — it must NOT swallow interactive kinds) |
| Plan banner | `chat_plan_banner.dart` | Exists |
| Artifacts (pills/tiles/inbox) | `chat_artifact_tile.dart`, `artifact_pill.dart` | Exists |
| Approval cards — single & grouped/batch | `chat_approval_card.dart` (has `isGrouped`) | Exists (delete-localization = §10) |
| Markdown rendering | `chat_markdown.dart` | Exists |
| Empty-state starter suggestions | `empty_chat_suggestions.dart`, `chat_suggestion_strip.dart` | Exists (≠ the §4c `prompt_suggestion` card) |

---

## Open decisions (need product sign-off before §1 / §5)

1. **Keep the paperclip?** Web removed it (upload → `+` menu + drag-drop). On
   touch, hiding the most common action behind a menu adds a tap — and the web
   team previously *reverted* a similar removal to preserve one-tap upload.
   **Recommend: mobile keeps the paperclip in the action row AND adds the `+`
   menu.**
2. **Keep the slash (`/`) button?** Mobile has one (`onSlash`, quick Odoo ops);
   web has none. Keep as a loose button, fold into the `+` sheet, or drop.
3. **Task-prep gating (§3):** add `task_prep_available` to the mobile feature
   snapshot (recommended) vs. show unconditionally and lean on server gating.

---

## Appendix A — interactive-card payload shapes (build to these)

The server sends these as `message.tool_payload` on an assistant/tool message.
Labels for the report card are **keys** localized on the client; the clarify /
suggestion cards carry human text directly. All three compose a follow-up and
send it via the normal send-message path.

### A.1 `prompt_clarify` (§4a) — `web: app.js:8639`
```jsonc
{
  "kind": "prompt_clarify",
  "original": "the user's vague request",
  "intro": "A couple of quick questions before I start 👇",   // optional
  "questions": [
    {
      "question": "Which period?",
      "options": ["This month", "This quarter", "This year"],  // tappable chips
      "default": 1                                             // optional pre-selected index; -1/absent = none
    }
    // 1–3 questions
  ]
}
```
Behavior: single-select chip per question; typing in the "Something else…" field
clears that question's chip (and vice-versa). **Build & send** composes
`"Answers to your questions:\n- <question> <answer>\n…"` (answers only — the
original is already a message above) and sends it; **Prepare & review** is the
same compose but routed to the review path. Require ≥1 answer (else toast "Pick at
least one answer" / "اختر إجابة واحدة على الأقل").

### A.2 `report_builder` (§4b) — `web: app.js:4737`
```jsonc
{
  "kind": "report_builder",
  "types":   [{ "key": "sales_orders", "label": "Sales orders" }],
  "periods": [{ "key": "this_month",   "label": "This month" }],
  "lenses":  { /* keyed groups; a lens carries entity + submit_ar/submit_en */ },
  "formats": [{ "key": "pdf", "label": "PDF" }]
}
```
Each chip carries a `key` and a `label`. The web localizes labels from client
i18n keys (`rbType_<key>`, `rbPeriod_<key>`, `rbLens_<key>`, `rbFormat_<key>`)
and falls back to the server-provided `label`. **Simplest for mobile: just render
the server `label`** and add client i18n keys later if you want the card to flip
with the app language. The chosen type + period + lens + format (+ entities)
compose a precise report request that is sent as a normal message.

Report types/lenses in the customers / vendors / employees families get a
secondary **entity multi-select**. Load it from this endpoint (read-only, live
Odoo query):

```
GET /api/v1/report-entities/?conversation_id=<id>&entity=<customers|vendors|employees>&q=<optional search text>

200 → { "ok": true,
        "items": [ { "id": 42, "name": "Acme Co" }, … ],   // capped at 1000, ordered by name
        "truncated": true|false }                           // true = more exist; use q to narrow

Errors (JSON body, non-200): 400 conversation_id missing/not yours · 400 unsupported entity ·
400 no Odoo env linked to the conversation · 502 could not fetch.
```

Behavior: show a checkbox list of `items`; the user ticks records; on `truncated`
show a "refine with search" hint and re-query with `q`. Send the ticked
`{id, name}` set as part of the composed report request.

### A.3 `prompt_suggestion` (§4c) — `web: app.js:8595`
```jsonc
{ "kind": "prompt_suggestion", "improved": "a clearer version of the task", "note": "optional note" }
```
Render `improved` in an **editable** multiline field. **Approve & use** / "اعتمد
الصياغة" sends the current (edited) text; **Keep mine** / "أبقِ صياغتي" hides the
card without sending.

---

## Verification notes

- Web deep-think removal: `grep -c deepThink app.js` → **0**. Mobile footprint:
  **104** refs / **11** files (§2).
- `task_prep` server acceptance: `web: views.py:578-582`; flag exposure limited
  to HTML context `web: views.py:327-339` (not in mobile JSON).
- Interactive-card dispatch: `web: app.js:5198-5207`; builders at 4737 / 8595 /
  8639. Mobile has **no** `kind` branch (`message_row.dart:31-34` → generic
  `ToolActivityCard`); zero `lib/` matches for the three kinds.
- P1 absences (odoo tools / prompt bank / voice-support) confirmed by zero `lib/`
  matches for their identifiers.
- P2 **web** side confirmed present in the deployed tree: SHAs `981f885`,
  `db17102`, `ed4460b`, `6d04250`, `0d80df5` all exist; features live in `app.js`
  (`report_builder` ×2, Arabic `حذف` ×22, `inlineApprovals`/resume ×7). P2 items
  are "verify" only because the **mobile** side wasn't fully confirmed here.
- Neither app was run/rendered — this is a **source-read** comparison.
