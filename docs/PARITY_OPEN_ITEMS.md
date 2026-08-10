# Parity — what is still needed, and from whom

**Date:** 2026-08-06
**Status:** all 12 gaps implemented on mobile · analyzer clean · **1122 tests
passing** · release AAB built and signed (`1.2.0+110`, before the conversations
and app-lock fixes — needs a rebuild)

> **The one thing to take from this file:** implementing every backend item
> below does **not** by itself make the two clients identical. Section **D2**
> lists what stays different afterwards, and the table near the end says, per
> item, whether it activates on its own or waits for a mobile release. Four
> items need one either way.

This file exists so nobody has to reconstruct the open questions from three
rounds of correspondence. It lists **only** what is genuinely outstanding, who
owns it, and what breaks if it stays open.

---

## A. Blocking — the app ships with these features DARK

### A1. Deploy `saqqar_features` — **backend**

**Owner:** web/backend · **Blocks:** §6 (all three Odoo tools) and §8 (voice
support) are invisible to every user

Your response doc says `saqqar_features` is "deploying next web release". It is
not on `GET /api/v1/usage/` yet. Mobile gates §6 and §8 **strictly** — absent
or `false` ⇒ the row is hidden — which is what you asked for and is the right
behaviour, but it means:

> The shipped app contains Health Radar, Business Pulse, What-If and the
> support workspace, and **none of them will appear** until this deploys.

The endpoints themselves are live — we probed all five and they return `401`,
not `404`. So this is purely the flag payload.

**When you deploy, mobile needs no release.** The flags are read live.

**Also:** your sample shows `health_radar`, `what_if`, `business_pulse` and
`voice_support` as `false` for a normal non-staff account (staff-only during
rollout). So even after the deploy, these stay hidden for ordinary users until
you clear the staff-only condition. If you want them visible for a demo or for
App Store / Play review, either flip the flags for the reviewer account or tell
us and we will expose them another way.

---

## B. Needed to finish work that is already written

### B1. Which message shape carries an interactive card — **backend**

**Owner:** web/backend · **Asked:** twice (2026-08-05, 2026-08-06) · **Not yet
answered**

Appendix A says the payload arrives "on an assistant/tool message". We need to
know which of these you actually send:

1. `role: "tool"`
2. `role: "assistant"` with empty `content`
3. `role: "assistant"` with prose **and** `tool_payload`

**Why it matters:** our visibility filter used to drop shapes 1 and 2 as agent
plumbing, which meant every `prompt_clarify` / `report_builder` /
`prompt_suggestion` card was filtered out before it reached the renderer —
while every widget test passed, because those pump the row directly. It is
fixed and all three shapes now render, but we are handling shapes you may
never send and possibly missing one you do.

**One line in a reply closes this.** A sample payload is even better.

### B2. Does `report_builder` gate the §4 report card? — **backend**

**Owner:** web/backend

Your §0 sample introduced four flags we had not seen: `collection_note`,
`version_awareness`, `module_management`, `report_builder`. We store all of
them (the raw map keeps every key) but gate on none.

`report_builder` is the one that matters: if it is meant to gate the §4 report
card, we will wire it in one line. If it gates a **web page** of that name,
we leave it alone. Right now the card renders whenever a payload arrives,
which is wrong if the feature is off for that account.

Same question, lower stakes, for the other three — do any of them correspond
to something mobile should show?

### B3. Confirm the batch-scope restriction — **backend**

**Owner:** web/backend · **Mobile is deliberately conservative pending an
answer**

Your §11 answer excludes only deletes from `scope: "batch"`. Taken literally
that permits batch-approving a `server_command` or a `credential_storage`
approval — one tap that silently pre-approves **future shell commands of the
same shape**.

We restricted the offer to `action_type == "odoo_write"`, because your own
wording is "future same-shape **writes** auto-approve silently", and because a
shell command is the approval most worth reading one at a time.

**If the server really does intend to batch every action type**, say so and we
will widen it. If not, consider rejecting `scope: "batch"` server-side for
non-write types too, so a future client cannot re-open this.

### B4. Task prep does not sync between app and web — **backend**

**Owner:** web/backend · **Reported by the user 2026-08-06** · **Cannot be
fixed client-side**

Turning **Task prep** on in the mobile app does not turn it on in the web UI,
and vice versa. That is not a mobile bug — it is a missing contract:

- `task_prep` is a **send-body key only** (`payload.get("task_prep", True)`).
  The server reads it per message and gates it, then forgets it.
- There is **no persisted field anywhere**: it is not on the conversation
  serializer, and `PATCH /api/v1/conversations/<id>/` does not accept it.
  Compare `auto_approve`, which IS a real conversation field and therefore
  DOES sync between the two clients today.

So each client necessarily keeps its own copy — mobile in
`SharedPreferences`, web in its own session state — and neither can see the
other's. Any mobile-side "fix" would mean inventing a storage location and
guessing that web reads the same one.

**What would fix it, in your order of preference:**

1. **A conversation field** — serialize `task_prep` on the conversation and
   accept it in `PATCH`, exactly like `auto_approve`. Mobile then mirrors it
   the same way and the two clients agree per chat. This is the smallest
   change and matches the pattern already in place.
2. **A user-level preference** — if the intent is "one setting for the whole
   account rather than per conversation", any endpoint that persists and
   returns it works; tell us the shape.

Note the two behave differently on purpose today: auto-approve is
per-conversation, task prep is a global client preference. **Which one it
should be is a product decision** — tell us the target and mobile matches it
in an afternoon.

### B5. Saqqar Apps are English-only — **backend** (mobile has a stopgap)

**Owner:** web/backend

`GET /api/v1/apps/` serves one language: `name`, `tagline` and `category`
come back in English whatever the caller's locale. On an Arabic phone the
Saqqar Apps grid was five English cards inside an otherwise Arabic app.

**Mobile stopgap shipped:** each field now resolves a client string keyed by
the app's stable `slug` (`app_name_<slug>`, `app_tagline_<slug>`,
`app_category_<slug>`) and falls back to the server value. So a translated
package renders in the user's language, and a package you add tomorrow still
renders — in English — with no mobile release.

**The durable fix is yours**, because you own the list and add to it: either
`name_ar` / `tagline_ar` / `category_ar` alongside the existing fields, or
honour `Accept-Language` on the endpoint. Either is purely additive; when it
lands, mobile deletes its override keys and reads the server value directly.

**Until then, every new package is English on Arabic phones** unless someone
remembers to add three mobile strings for it.

### B6. `/api/v1/apps/` returns a package the web gallery doesn't show

**Owner:** web/backend · **Mobile has a stopgap that will rot**

The catalogue endpoint returns **five** packages. The web Apps gallery shows
**four**: ZATCA e-invoicing, WhatsApp integration, Chart of Accounts builder,
Bank reconciliation. So mobile was offering a fifth package that no other
surface supports.

**Mobile stopgap:** `SaqqarApp.shipped()` filters the list to an allowlist of
those four (matching on slug or normalized name), falling back to the full
list if nothing matches so a mass rename can never produce an empty gallery.

**This is maintenance debt and it is worth naming:** the allowlist means **a
genuinely new package you add will not appear on mobile** until someone adds
its key to `SaqqarApp.visibleKeys` and ships a release. That is the opposite
of how the rest of this screen works — the translations were built precisely
so new packages still render.

**What we need:** either serve mobile the same list you serve web, or tell us
the fifth package's slug so we can hide that one by name instead of
allowlisting the four. The second is a one-line change on our side and
restores "new packages just appear".

### B7. `/api/v1/conversations/` truncates without a way to page — **backend**

**Owner:** web/backend · **Found 2026-08-06 by the user** · **Mobile ships a
forward-compatible fix**

An account with ~140 conversations shows **140 on web and 100 in the app**.

- The client requests `limit=200`; the response carries **100** rows and
  `"total": 140`. So the server caps the page well below the requested limit
  and tells us, correctly, that more exist.
- `/api/v1/conversations/` documents only `?limit=&include_archived=` —
  **no `offset`**, unlike `/api/v1/approvals/` and `/api/v1/artifacts/`,
  which both have it. So there is no documented way to ask for rows 101-140.

**Mobile fix shipped:** the list now pages — it sends `offset` and keeps
requesting until `total` is reached. It is safe against a server that
ignores `offset`: a page that returns no new ids ends the loop, so today it
costs exactly one extra request and then stops, showing the same 100.

**What we need from you — one of:**

1. **Support `offset` on this endpoint** (matching `/approvals/`). Mobile
   already sends it, so this needs **no mobile release** — the full list
   appears the moment you deploy.
2. **Raise or remove the page cap**, if 140-ish is the realistic ceiling.
3. **Tell us the real paging parameter** if it is something else (a cursor,
   `page=`), and we will switch.

Option 1 is strictly best: it is the only one that also fixes the account
with 900 conversations.

### B8. Prompt-bank contents — **backend** (low priority)

`prompt_bank` is a server flag, but there is no saved-prompt endpoint. Mobile
shows the app's own four starter prompts. If the flag implies server-side
content, tell us where it lives; otherwise we will leave it as is.

### B9. Serve the plan copy on `/api/v1/plans/` — **backend**

**Owner:** web/backend · **Mobile has shipped a stopgap; it is a maintenance
liability, not a fix**

`GET /api/v1/plans/` returns the commercial facts and nothing a customer would
call a plan description:

```
slug  name  sort  price_monthly_cents  price_annual_cents
daily_tokens  daily_burst_tokens  weekly_tokens  monthly_tokens
max_projects  max_envs_per_project
features{ voice, postgres, github, server_shell }
```

Everything saqqaar.com/pricing actually shows a buyer is missing:

| On the website | On `/plans/` |
|---|---|
| Tagline — "For power users" / "للمستخدمين المتقدمين" | ✗ |
| Feature bullets — "Create and edit Odoo records (with approval)" … | ✗ |
| The "Everything in Solo, plus:" ladder | ✗ |
| The "Most popular" badge | ✗ |
| Arabic tier name — "الاحترافي", "الأعمال" | ✗ (`name` is English-only) |
| "Free for everyone" note on the free tier | ✗ |

**What mobile shipped, and why it is a problem.** So the two surfaces stop
describing two different products, the app now carries that copy itself in
`lib/features/billing/data/plan_copy.dart`, keyed by wire slug (`free`,
`starter`, `max-5x`, `pro`, `max-20x`), with the strings in the app's i18n
tables. Prices still come from you and are untouched.

That means **every wording change on the website — a new bullet, a renamed
tier, a reordered list — now needs an app release and a store review to reach
mobile.** Store review is days, not minutes. The two will drift, and the
surface they drift on is the one where people spend money.

Before this, the screen filled the gap with what the API did have: two token
caps quoted in "ST" and the four `features` booleans drawn as a green-tick /
grey-cross matrix. Neither appears anywhere on the website, so a buyer
comparing the app to the site saw two different products. That is why the
stopgap exists at all.

**What we are asking for.** Add the descriptive fields to each plan row, ideally
honouring `Accept-Language` the way B5 asks for `/apps/`:

```json
{
  "slug": "pro",
  "name": "Professional",
  "tagline": "For power users",
  "most_popular": true,
  "inherits_from": "max-5x",
  "features_text": [
    "Build and edit Odoo addons, download as .zip",
    "Trigger server actions and install modules",
    "Higher usage limits",
    "Priority support"
  ],
  "price_note": null
}
```

`inherits_from` is enough for us to render "Everything in Solo, plus:"
ourselves — we do not need the sentence, just the slug. `price_note` carries
the free tier's "Free for everyone"; null elsewhere.

**Whichever shape you pick, one rule matters more than the shape: it must be
the same source the website's own pricing page renders from.** A second copy on
your side solves nothing — it just moves the drift.

**Release impact:** mobile needs one release to read the new fields, and after
that your wording changes reach the app with no release at all. Until then the
app is correct but frozen: the copy currently in `plan_copy.dart` was taken
from the live site on 2026-08-06, English and Arabic, monthly and annual.

### B10. Billing history is in SAR, checkout is in USD — **backend**

**Owner:** web/backend · **User-visible today**

The two endpoints disagree about the currency of the same purchase:

| Endpoint | Field | Value |
|---|---|---|
| `GET /api/v1/plans/` | `price_monthly_cents` | **USD cents** — `API_MOBILE_SUBSCRIPTION.md` §2 calls these "the source of truth (what checkout charges)" |
| `GET /api/v1/billing/history/` | `currency` | **`"SAR"`** — §3 documents it as the default, and production returns it |

So a customer sees `$20` on the plans screen, pays in USD, and then finds the
same payment listed as `75.00 SAR` in their history. Nothing tells them these
are the same charge, and no conversion rate is given, so the two numbers cannot
be reconciled by the person looking at them. On a billing screen that is the
one thing that has to be beyond doubt.

The doc's own sample makes the point: it shows `"what": "Professional —
annual"` against `"amount": 75.0, "currency": "SAR"`, while Professional annual
is $120/yr.

**We are not asking which currency is right** — that is a commercial call, and
the VAT wording ("15% VAT is added at checkout") suggests SAR may be what
Paymob actually settles in. We are asking for **one** of these:

1. **Charge and report in the same currency.** Simplest, and what we would
   pick: if checkout takes USD, `history.currency` is `"USD"` and `amount` is
   the dollars charged.
2. **If the gateway genuinely settles in SAR**, then say so on both ends: add
   the settled amount *and* the quoted amount to each history row, e.g.
   `amount: 75.0, currency: "SAR", charged_amount: 20.0, charged_currency:
   "USD", fx_rate: 3.75`. Mobile will show the charged figure with the settled
   one beneath it.

What we cannot do is guess. The app renders `amount` and `currency` exactly as
sent — it invents no conversion and never will.

**Release impact:** option 1 needs **no mobile release** — the screen already
renders whatever `currency` says. Option 2 needs one release to show the second
line.

---

## C. Verified live — no action needed

Probed against production on 2026-08-06. Known authenticated routes answer
`401`, so `401` here means "route exists, needs auth" rather than "missing".

| Endpoint | Result |
|---|---|
| `POST /api/v1/radar/run/` | `401` — exists |
| `POST /api/v1/pulse/run/` | `401` — exists |
| `POST /api/v1/whatif/intro/` | `401` — exists |
| `POST /api/v1/voice-support/draft/` | `401` — exists |
| `POST /api/v1/voice-support/ticket/` | `401` — exists |

**Not yet exercised against a real response body**, because that needs an
authenticated account with a bound Odoo credential:

- the `/voice-support/draft/` payload shape (we built to your prose
  description: `title`, `module`, `category`, `priority`, `questions[]`,
  `steps[]`, `reply`)
- the `batch` object on a decision response (`resolved_count`, `scope_added`)
- a real `tool_payload` interactive card

All three parse defensively — a wrong-typed or missing field degrades to
"feature hidden", never to a crash — but "parses defensively" is not the same
as "confirmed correct". **One authenticated smoke test on staging closes all
three**, and we would rather do that than discover it in review.

---

## D. Owned by mobile — done, listed for completeness

Found and fixed during the 2026-08-06 deep pass. Each had shipped through a
green test suite, because each lived at a seam *between* two units that were
individually well tested.

| # | Defect | User-visible effect |
|---|---|---|
| 1 | Approval adapter stringified `null` | Every email approval rendered **"Cc: null"**, **"Bcc: null"**, and a **Reply badge** — on the shape you documented as normal |
| 2 | Batch offered on every action type | One tap could pre-approve future **shell commands** |
| 3 | Stop button shown during a §6 scan | A Stop button that cannot stop an in-flight HTTP POST; tapping it reported "generation stopped" falsely |
| 4 | Sign-out race in the flags cubit | Signing out mid-fetch leaked the **previous account's** staff-only rows into the next session |
| 5 | `context.go` to the support screen | Opening support from a chat destroyed that chat's route — no way back |
| 6 | No re-entry guard on tool rows | A second tap during a slow scan posted two reports |
| 7 | Chats list never paged | Showed **100 of ~140** conversations and looked complete — `total` was in the response and nothing read it (see B7) |
| 8 | App lock guarded only cold start | Anyone holding an unlocked phone could sign out or **delete the account** without proving identity; both now re-prompt when the lock is on |

Regression coverage in `test/parity_regression_test.dart`,
`test/conversations_paging_test.dart` and `test/app_lock_confirm_test.dart`.
Both the adapter fix and the sign-out fix were **mutation-tested** — reverted
deliberately to confirm the new tests fail without them. The paging loop is
tested against a server that *ignores* `offset`, because the wrong stop
condition there is an infinite loop rather than a wrong number.

---

## D2. Owned by mobile — parity gaps this file does NOT close

**Read this before assuming "backend implements the file → everything
matches".** These are real differences from the web that no item above will
fix, because none of them is the backend's to fix.

### D2.1 The Apps grid shows generic icons, not the server's

`GET /api/v1/apps/` sends `icon_svg` — inline 24×24 markup, one per package.
Mobile **parses it, stores it, and never renders it**: `flutter_svg` is not a
dependency, so each tile falls back to a Material icon chosen from the
package's `group`.

The visible result: on web, WhatsApp integration has the green WhatsApp mark,
Chart of Accounts a blue document, Bank reconciliation a purple bank. On
mobile all four Accounting/Finance packages share whichever icon their group
maps to. Two Accounting packages are visually identical.

Nothing is wrong with the API here — the field is correct and already
arriving. **Closing this is one mobile change** (add `flutter_svg`, render
`iconSvg` tinted with `accent`, keep the group icon as the fallback for a
malformed or empty SVG). It needs a release, and it is the largest remaining
visual difference on that screen.

### D2.2 Voice support has no spoken reply

`POST /api/v1/voice-support/tts/` exists and mobile does not call it. That was
deliberate: it needs the billing `voice` entitlement (403 on Free) and returns
audio the app has no player for, so the button would fail for most accounts
and play nothing for the rest. The written reply — which every account gets —
carries the substance.

Listed here so "we shipped §8" is not read as "§8 is complete". If spoken
replies matter commercially, say so and we will add an audio player.

---

## E. Owned by mobile — outside this parity work

Not parity items; listed so they are not forgotten before the store submission.

- **`SAQQAR_SENTRY_DSN` was not supplied** to the `1.2.0+110` build, so crash
  reporting is off in the current AAB. Needed for the Play resubmit.
- **iOS cannot be built on the current machine** (Windows, no Xcode). The IPA
  needs macOS: `flutter build ipa --release`, with no `--dart-define` so the
  paid-upsell surface stays off per Guideline 3.1.1.
- **App Review notes must be corrected.** The previous 2.1(b) answer said
  nothing is sold anywhere; that is no longer true now that Paymob is live on
  the website.
- **Reviewer credentials** on a paid plan, for both stores.
- Cosmetic: iOS `RunnerTests` bundle id is `sa.com.digitalharbor.saqqar.
  RunnerTests` while every other target nests under `…saqqarapp`. Not an
  upload blocker (test targets are not archived).

---

---

## Does each item light up on its own, or does mobile need another release?

Asked directly, and answered per item rather than in general — because the
answer is **not** the same for all of them, and assuming it is would mean
shipping a build that silently never picks half of this up.

| Item | Backend deploys → does it just work? |
|---|---|
| **A1** `saqqar_features` | ✅ **Yes, no release, no restart.** The flags read as "unknown" until the field exists, so the app keeps asking on every chat open; the first response carrying it lights up §6 and §8 immediately. |
| **B1** card message shape | ✅ **Yes, if** it is one of the three shapes already handled (`role:"tool"`, empty-content assistant, assistant with prose + payload). A fourth shape needs a release. |
| **B2** `report_builder` gating | ⚠️ **Works, but wrong.** The report card renders today regardless of the flag. Making it *hide* when the flag is off is a one-line change that **needs a release**. |
| **B3** batch scope for non-writes | ⚠️ **Needs a release** if you widen batching past `odoo_write`. Nothing breaks meanwhile — mobile is simply conservative. |
| **B4** persist `task_prep` | ❌ **Needs a release.** Nothing in the client reads a `task_prep` field, because none exists to read. Adding it server-side changes nothing on mobile until we wire it. |
| **B5** localize `/apps/` | ⚠️ **Depends how.** If you honour `Accept-Language` and return a localized `name`, mobile renders it with no release — but our own override for the four known packages would still win, so **send us word and we will drop them in the same release**. If you add `name_ar`/`tagline_ar` fields instead, that needs a release to read them. |
| **B6** the 5th app package | ❌ **Needs a release** for any NEW package, because mobile allowlists the four. Give us the fifth package's slug and we flip it to a denylist — after that, new packages appear on their own. |
| **B7** conversations paging | ✅ **Yes, no release.** Mobile already sends `offset` and pages until the list is complete; it stops safely today because the server ignores it. |
| **B8** prompt-bank contents | ⚠️ **Needs a release** if there is server-side content to fetch. Nothing breaks meanwhile. |
| **D2.1** app icons | ❌ **Not yours to fix.** `icon_svg` already arrives correctly; mobile has no SVG renderer. Needs a mobile release. |
| **B9** plan copy on `/plans/` | ❌ **Needs a release** to read the new fields — but that is the release that ends the problem: after it, your wording changes reach the app with none. Today every one of them needs a store review. |
| **B10** billing currency | ✅ **Yes, no release** if you make `history.currency` match what checkout charges — the screen prints whatever you send. ❌ A release only if you add a second `charged_*` line. |

**So: two hard blockers on a future release (B4, B6), two "works but not
correctly" (B2, B3), one conditional (B5), and one — B9 — where a single
release buys permanent independence.** Everything else is genuinely
self-activating.

None of these block shipping the current build. They decide what a *second*
build has to contain.

---

## Summary

| Item | Owner | Blocks |
|---|---|---|
| A1 · deploy `saqqar_features` | backend | §6 + §8 invisible |
| B1 · card message shape | backend | §4 handled blind |
| B2 · `report_builder` gating | backend | §4 card may show when off |
| B3 · confirm batch restriction | backend | mobile stays conservative |
| B4 · persist `task_prep` | backend | the toggle never syncs app ↔ web |
| B5 · localize `/api/v1/apps/` | backend | new packages stay English in Arabic |
| B6 · `/apps/` serves 5, web shows 4 | backend | new packages won't reach mobile |
| B7 · `/conversations/` has no `offset` | backend | the app shows 100 of ~140 chats |
| B8 · prompt-bank contents | backend | nothing (cosmetic) |
| B9 · plan copy on `/plans/` | backend | every pricing-copy change needs a store review |
| B10 · history in SAR, checkout in USD | backend | a buyer cannot reconcile `$20` paid with `75.00 SAR` billed |
| C · one authed smoke test | either | 3 response shapes unconfirmed |
| D2.1 · app `icon_svg` not rendered | **mobile** | generic icons; two Accounting tiles look identical |
| D2.2 · voice-support TTS not built | **mobile** | §8 has no spoken reply |
| E · Sentry DSN, iOS build, review notes | mobile | store submission |

Nothing on this list blocks shipping the Android build. A1 determines whether
the new features are *visible* once it ships. **B9 and B10 are both live in the
shipping build** — B9 as copy mirrored from the website on 2026-08-06 (correct,
but frozen until you serve it), B10 as a currency mismatch the app is faithfully
passing through.
