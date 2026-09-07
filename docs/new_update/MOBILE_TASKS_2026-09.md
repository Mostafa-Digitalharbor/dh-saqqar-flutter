# Mobile implementation brief — September 2026

**For:** the mobile developer. Open a **fresh Claude Code session rooted in this repo**
(`dh-saqqar-flutter`) and hand it this file.
**From:** the web team. **Date:** 2026-09-05.
**Mobile reviewed at:** `saqqar-mostafa` @ `99706de`.

---

## How to use this file

- **You do not have the web repo, and you do not need it.** Every contract, payload
  shape, endpoint and string you need is written out below. If a task seems to require
  reading web source, that is a bug in this document — ask the web team, don't go looking.
- **Same backend.** Mobile and web both talk to `https://saqqaar.com/api/v1/…`. Everything
  described here is **already live on the server right now**. No backend work is pending
  for any of these four tasks.
- **Each task is self-contained.** Start with any one alone.
- **Bilingual + RTL is mandatory.** Exact EN/AR strings are given wherever you'd otherwise
  have to guess. Where a string is *proposed* rather than copied from a live source, it
  says so.

| # | Task | Priority | Effort |
|---|---|---|---|
| 1 | Render the seven in-chat app cards | **P0** | Large |
| 2 | Resume button for a run that stopped silently | **P0** | Small |
| 3 | Arabic copy for six apps in the gallery | P1 | Small |
| 4 | Email preview before approving a send | P2 | Small |

**Do #2 first.** It is the smallest, it is P0, and it removes a dead end a user cannot
escape today. #1 is the big one.

---

# Task 2 — Resume button (do this first)

## The problem

A run can end **without finishing and without saying anything**: the last thing in the
chat is a tool result, nothing is waiting on the user, and the agent just stopped. The
web app shows a banner with a **Resume** button. Mobile shows nothing, so the user is
looking at a chat that died with no way forward except typing «كمل» and hoping.

The server already detects this state and already tells you about it. You are only
missing the UI.

## The contract (live now, nothing to build server-side)

**1. The signal.** The `conversation` object inside every snapshot and every poll response
carries a boolean:

```jsonc
{
  "conversation": {
    "id": "…",
    "is_running": false,
    "needs_resume": true,      // ← this
    …
  }
}
```

Show the banner when **`needs_resume == true` && `is_running == false`**.

Do not add conditions of your own. The server has already excluded every legitimate
pause — a pending approval, an open question, a credential request, a quota stop — so
`needs_resume` is only ever true for a genuine dead end. If you re-derive the rule you
will get it wrong in the direction that shows a Resume button under an approval card.

**2. The action.**

```
POST /api/v1/conversations/<conversation_id>/resume/
Authorization: Bearer <token>
Body: {} (empty)
```

The response is a **full conversation snapshot** — the same shape your cold-open
`getSnapshot` returns. Merge it exactly the way you merge a poll response (`_mergeSnapshot`),
then start run-polling: the run continues server-side and the answer arrives through the
normal message stream.

**3. Rate limiting is the server's job.** It counts attempts per conversation and flips
`needs_resume` to false once the cap is reached, so the banner disappears on its own.
**Do not add your own counter or cooldown** — you would only be able to make it stricter,
and the failure mode is a user who cannot resume a chat the server was willing to resume.

## Behaviour to copy from web

- Tapping the button **disables it immediately** and swaps the label to the "working"
  string.
- On failure, **re-enable it** and restore the original label. Don't toast an error — the
  user can just tap again.
- If the user switches conversations while the request is in flight, **discard the
  response** (web checks the conversation id hasn't changed before merging).

## Strings

Copied verbatim from the live web client — use these, don't retranslate:

| key | EN | AR |
|---|---|---|
| banner text | `This chat stopped before the task was finished.` | `توقفت المحادثة قبل إكمال المهمة.` |
| button | `Resume` | `استئناف` |
| button, working | `Resuming…` | `جارٍ الاستئناف…` |

## Acceptance

- A conversation with `needs_resume: true` and `is_running: false` shows the banner.
- One with a pending approval shows **no** banner (verify by leaving an approval card
  unanswered — `needs_resume` will be false).
- Tapping resumes and new messages arrive without a manual pull-to-refresh.
- The banner disappears by itself once the server stops offering it.

---

# Task 1 — The seven in-chat app cards (P0, the big one)

## The problem

Seven guided apps shipped on web between August and September. Each posts a **rich card
inside the conversation** — number tiles, risk chips, action rows — instead of a wall of
text. Your `InteractiveCardKind` enum knows three kinds. The other seven arrive as plain
text or get dropped by the visibility filter.

| `tool_payload.kind` | app slug | app name (EN) |
|---|---|---|
| `factory` | `factory` | Your factory |
| `inventory` | `smart-inventory` | Your inventory |
| `finance` | `finance-pulse` | Your money |
| `purchasing` | `purchase-pulse` | Your purchasing |
| `quality_guard` | `quality-guard` | Quality Guard |
| `accountant` | `accountant` | Your accounts manager |
| `hr` | `hr-assistant` | Recruitment Manager |

## How a card reaches you — no new endpoint

Identical to `prompt_clarify`, which you already render. The card rides on the
**`tool_payload` of the final assistant message** in the turn. So:

1. Extend `InteractiveCardKind` with the seven wire values above.
2. Add a `parse` for each, following the forgiving style already in
   `interactive_cards.dart` — a malformed card returns `null` and falls through to an
   ordinary message, never throws.
3. Add each to `hasRenderableInteractiveCard` so the visibility filter keeps the message.
4. Add a widget per kind and dispatch it in `message_row.dart`.

## ⚠️ Read this before you go looking for a card

**A card is only emitted inside its own app's chat.** The server checks that the
conversation was launched from that app (`context.package == "<slug>"`) and returns **no
card at all** in an ordinary chat — there the same numbers come back as prose, on purpose.

So a card will never appear in a chat you started from the composer. **To see one:**

```
POST /api/v1/apps/factory/launch/   { "environment_id": "<an env with Odoo data>" }
```

then open the returned conversation and ask it for the pulse («إيه أخبار المصنع؟» /
"how's the factory doing?").

## Getting the exact payload — do this rather than trusting a transcription

The shapes are large and they will drift. Rather than copy a spec that goes stale, **read
the real thing from the server you already talk to**:

```
GET /api/v1/conversations/<id>/messages/
```

and look at `tool_payload` on the last assistant message. That is the authoritative shape,
live, for whichever card you're building. Do that once per card before you write its widget.

Two shapes are written out below because they are the two to build first and because they
prove an important point: **they are not the same shape.** Plan for a family of widgets,
not one generic renderer.

### `factory` — flat scalar tiles + one ranked list

```jsonc
{
  "kind": "factory",
  "status": "ok",
  "as_of": "2026-09-05",
  "mo_running": 12,          // null when the `mrp` app isn't installed
  "mo_late": 3,              // null likewise
  "mo_done_today": 5,        // null likewise
  "po_late": 2,              // null when purchase isn't installed
  "orders_at_risk": 4,
  "top_risks": [             // at most 5
    { "order": "SO/0042", "order_id": 42, "customer": "…",
      "missing_lines": 3, "lead_days": 21, "worst_product": "…" }
  ],
  "notes": [ "…" ]           // ALREADY IN ARABIC from the server — render as-is
}
```

### `inventory` — six uniform buckets

```jsonc
{
  "kind": "inventory", "status": "ok", "as_of": "2026-09-05",
  "sales_days": 90,
  "product_count": 1840,
  "inventory_value": { "available": true, "total": 984000.0 },
  "low_stock":       { "available": true, "count": 12, "items": [ … ] },
  "demand_shortage": { "available": true, "count": 4,  "items": [ … ] },
  "stagnant_stock":  { "available": true, "count": 31, "items": [ … ], "total": 120400.0 },
  "overstock":       { "available": true, "count": 8,  "items": [ … ], "total": 65000.0 },
  "fast_reorder":    { "available": true, "count": 6,  "items": [ … ] },
  "missing_data":    { "available": true, "count": 22, "counts": {}, "items": [ … ] },
  "notes": [ … ],
  "priorities": [ … ]
}
```

### Top-level keys for the other five

Enough to plan the widget; read the live payload for the nested shapes.

| kind | top-level keys |
|---|---|
| `finance` | `cash`, `receivables`, `payables`, `collection_aging`, `payment_horizon`, `liquidity_7d`, `drafts`, `bank_reconciliation`, `notes`, `priorities` |
| `purchasing` | `open_rfqs`, `awaiting_approval`, `late_purchase_orders`, `late_incoming_receipts`, `to_bill`, `vendor_bills`, `vendor_delay_summary`, `notes` |
| `accountant` | `window_days`, `no_reference`, `manual_on_control`, `edited_after_post`, `self_cancelling`, `multi_company`, `notes` |
| `hr` | `window_days`, `recruitment`, `operations`, `payroll`, `time_off`, `counters` |
| `quality_guard` | `out_of_spec`, `failed_checks`, `pending_checks`, `quality_alerts`, `missing_numeric_specs`, `review_cases`, `deep_discounts`, `delivery_swaps`, `invoice_swaps`, `lower_cost_substitutes`, `documented_substitutes`, `undocumented_substitutes`, `high_risk_cases`, `cost_saving_total`, `discount_value_estimate`, `standard_odoo_only` |

## Four rules that come straight from the server's behaviour

1. **`available: false` means "this database can't answer", not "zero".** Render that
   bucket as unavailable — greyed, "غير متاح" — never as an empty result. Showing `0` for
   a customer whose Odoo simply lacks the module is a wrong answer, not a blank one.
2. **A scalar can be `null`** when the underlying Odoo app isn't installed. The server
   puts an explanatory Arabic line in `notes` when that happens — **show the notes.**
3. **`status` can be `"error"`**, with an `error` string and empty buckets. Render the
   error, not an empty card.
4. **`notes` and `priorities` arrive already written in Arabic.** Do not translate them,
   do not run them through your string table — print them.

## Suggested order

`factory` → `inventory` → `finance` → `purchasing` → `accountant` → `hr` →
`quality_guard`. The first two are the most demoed and have the most complete data;
`quality_guard` is the flattest and easiest, so it makes a fine warm-up if you'd rather
start small.

## Acceptance

- Launch each app, ask for its pulse, and the card renders instead of a text dump.
- The same question in an ordinary chat still renders as text with **no** empty card.
- A payload with a missing key, an empty `items`, a `null` total, or `status: "error"`
  renders something sensible and never throws.
- Cards read correctly in Arabic and in RTL.

---

# Task 3 — Arabic copy for six apps (P1)

`GET /api/v1/apps/` now returns **11** packages for a normal user; it returned 4 when the
catalogue was last discussed. Your `app_package_models.dart` already handles that
correctly — the four-slug allowlist is gone and the list renders whole — so nothing is
broken. But **six of the eleven have no Arabic copy on the mobile side** and show in
English on an Arabic phone:

| slug | server name (EN) | proposed AR name | proposed AR tagline |
|---|---|---|---|
| `finance-pulse` | Your money | فلوسك | حصّل وادفع وسوّي وقفل يومك من بيانات أودو المالية مباشرة. |
| `purchase-pulse` | Your purchasing | مشترياتك | طلبات الشراء والاستلامات المتأخرة وفواتير الموردين والمخاطر، من أودو. |
| `quality-guard` | Quality Guard | حارس الجودة | يراقب القياسات والفحوصات الراسبة وتبديل المنتجات والبدائل الأرخص. |
| `smart-inventory` | Your inventory | مخزونك | المخزون اللي محتاج تحرّك: نقص، وراكد، وزيادة، وبيانات ناقصة، وإشارات إعادة طلب. |
| `accountant` | Your accounts manager | مدير حساباتك | يراجع القيود وسلسلة الفواتير والبنك والضريبة وقفل الشهر — من أودو مباشرة. |
| `hr-assistant` | Recruitment Manager | مدير التوظيف | يفرز المتقدمين ويراجع الموظفين والعقود والرواتب والإجازات والحضور من أودو. |

> **These Arabic strings are proposed, not copied from a live source** — the server
> catalogue holds English only. «مدير حساباتك» and «مدير التوظيف» are the names the agent
> already uses for those two apps in its own prompts, so those two are settled. Get the
> other four signed off by the product owner before shipping.

**Watch the key format.** `normalizeKey` turns `finance-pulse` into `finance_pulse`, so
the keys are `app_name_finance_pulse` / `app_tagline_finance_pulse`. The raw hyphenated
slug matches nothing — that exact bug already cost two of the original four packages
their translations.

**The durable fix is server-side** (`name_ar`/`tagline_ar`, or honouring `Accept-Language`
on `/apps/` the way `/plans/` already does). Your own code comment says the same. Tell the
web team which you'd rather have; adding the twelve keys unblocks the Arabic build today
either way.

---

# Task 4 — Email preview before approving a send (P2)

An approval whose `action_type == "send_email"` currently renders on mobile as a generic
approval card, so the user approves an email **without seeing what it says**. Web renders
a preview of the actual message first.

Lower priority only because email approvals are far rarer than Odoo writes.

## The data

All of it is already on the approval's existing `payload` object — the same approval you
render today. No new call.

| field | notes |
|---|---|
| `to` | recipients; string or list — format both |
| `cc` | optional, hide the row when empty |
| `bcc` | optional, hide the row when empty |
| `in_reply_to` | optional, hide the row when empty |
| `subject` | may be empty → show the "(no subject)" placeholder |
| `body` | plain text, **preserve line breaks**; may be empty → placeholder |

Row order on web: **To, Cc, Bcc, In reply to, Subject, Message.** The card's label is
"Send email" rather than the raw `action_type`. Approve/Reject stay exactly as they are
today.

## Strings

Copied verbatim from the live web client:

| key | EN | AR |
|---|---|---|
| card label | `Send email` | `إرسال بريد إلكتروني` |
| to | `To` | `إلى` |
| cc | `Cc` | `نسخة` |
| bcc | `Bcc` | `نسخة مخفية` |
| in reply to | `In reply to` | `رداً على` |
| subject | `Subject` | `الموضوع` |
| body | `Message` | `الرسالة` |
| empty subject | `(no subject)` | `(بدون موضوع)` |
| empty body | `(empty message)` | `(رسالة فارغة)` |

Set `dir="auto"` on the values: an email body is very often the opposite direction from
the surrounding UI.

---

# Things that are NOT gaps — please don't re-raise

- **Payments** — `billing/checkout/`, `billing/plans/`, `billing/webhook/paymob` are web
  only, by store policy.
- **`meetings/demo`** and the apps that open an internal web route — the server already
  filters those out of your `/apps/` list.
- **`/api/v1/voice-support/tts/`** — called by neither client. A dead endpoint, not a gap.
- **Prompt Bank using local starter prompts** instead of `/api/v1/prompt-memory/` — your
  rationale is sound and the web team is happy with it. Say if you'd rather switch.
- **Auth endpoints** — `auth/signup/*`, `auth/password/reset/*`, `auth/login/email/*` look
  missing if you diff URL lists, but `auth_flow_screen.dart` implements all three OTP
  flows already.

# Already live on your phone — no work needed

These changed server/agent behaviour only. Same Django backend, so they reached your users
the moment each was deployed, with no app release:

- Auto-approve now tells the agent it granted the write — a chat with the shield **on**
  used to stop and ask the user to press an approval card that was never created
- An approval answered mid-run is honoured instead of dropped
- One language per message (no more stacked Arabic + English)
- The no-silent-stop invariant and the orphan-run sweeper *(the client half is Task 2)*
- OCR for scanned and image-only PDFs, plus a one-shot retry on a transient vision failure
- Split a PDF and attach page N to record N
- Create Odoo records from a PDF with dynamic field mapping
- The ~40-page ceiling lifted to whole files
- Build sale orders from price-list documents
- Recovery from empty model completions instead of hanging
- «كمل» no longer replays the same stall
- The Radar / What-If / Business Pulse reports now post **in the conversation's language**
  rather than the app's UI locale — an English-locale phone was dropping English text into
  Arabic chats. **Fixed server-side, so no mobile change is needed**, and you can stop
  worrying about which `lang` you send on those three calls.

# Backend request you filed — now done

`GET /api/v1/app/version/` returned 404 since your update gate shipped. **It is live.**

```
GET /api/v1/app/version/?platform=ios      (or android)
→ 200 { "min_supported_build": 0, "latest_build": 0,
        "latest_version": "", "store_url": "" }
```

Public, no auth — your `AppUpdateGate` mounts outside the auth and lock gates, so it is
called before there is a token. Unknown or absent `platform` falls back to iOS, matching
your `DevicePlatform.fromWire`. It never returns 404 or 400.

It currently answers with **zeros and an empty `store_url`, which your client reads as "no
opinion"** — so the gate stays inert and nothing changes for users until a human fills the
values in on the web admin. **Send the web team the real current build numbers** (min
supported, latest, semver, store URL, per platform) — `pubspec.yaml` reads `1.2.7+201`
while the tags run to `v1.2.20`, so nobody on the web side is willing to guess. Until then
the gate cannot tell anyone to update.

One safeguard worth knowing: if `min_supported_build` is ever configured **above**
`latest_build` — a typo that would demand a build no store has — the server reports the
floor as `0` rather than serving a value that would wall off every install.
