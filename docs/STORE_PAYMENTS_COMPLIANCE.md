# Shipping the paid plans: what Apple and Google need

**Date:** 2026-08-03
**Context:** Saqqar is live and free on both stores. Paymob is live on
saqqaar.com. We are turning on paid plans — **sold on the web only, never in
the app** — and need both stores to accept the update.

> I am not a lawyer and store policies move. Everything below marked
> **CONFIRM** is something to check against the current policy text or ask
> review directly before you rely on it. Everything else is either what the
> code does or a rule both stores have held to for years.

---

## 1. The one distinction everything turns on

Store payment rules separate three things that are easy to blur together:

| | Allowed? |
|---|---|
| **Selling** digital content inside the app with a third-party processor | **No.** Needs IAP (Apple) / Play Billing (Google). |
| Being a **free app** whose users happen to have a subscription bought elsewhere | **Yes, everywhere.** This is Netflix, Spotify, Kindle. |
| Showing prices and **linking out** to buy | **Restricted** — "anti-steering". This is the grey zone, and it is the only thing in this update that carries risk. |

**Saqqar never does the first one.** No card, no order, no payment reference
ever touches the app — `test/no_in_app_purchase_test.dart` holds that. The app
opens the browser at `saqqaar.com/pricing/?plan=<slug>` and forgets about it;
when the subscription lands, the next `/usage/` poll brings the new plan back.

So the entire question for review is row three.

---

## 2. What the app does now

Everything below is behind a single build flag, `kShowWebSubscribe`, in
`lib/features/billing/data/billing_visibility.dart`.

**With the flag ON (the default, and what is built today):**

- Account → Billing → **Plans & pricing** opens the catalogue.
- The catalogue reads `GET /api/v1/plans/` — the same five tiers, prices,
  caps and features as saqqaar.com/pricing, with the same Monthly/Annual
  switch and the same VAT note.
- Each paid tier a user is not already on shows **"Subscribe on the web"**
  with an external-link icon, opening the system browser.
- The over-quota banner regains its "See plans" CTA.
- A line under the catalogue says payment completes on saqqaar.com in the
  browser and the plan updates in the app afterwards.

**With the flag OFF (iOS by default):**

- No prices, no cycle switch, no VAT line, no Subscribe button, no CTA on the
  quota banner.
- The **Plans & pricing** entry on Account stays, and `/pricing` renders as a
  **feature comparison** — caps, limits, which tools each plan unlocks. That is
  informational, not a purchase path.
- The footer line becomes the plain, non-tappable *"Plans are managed on
  saqqaar.com."*
- Billing history stays either way.

### 2.1 Build commands — the default is already the safe one

**You do not need to remember a flag.** With `SAQQAR_WEB_SUBSCRIBE` unset the
app picks per platform: **off on iOS, on for Android.** So the ordinary release
commands produce the recommended shape of §5:

```bash
flutter build appbundle --release     # Android → prices + Subscribe shown
flutter build ipa       --release     # iOS     → prices + Subscribe hidden
```

That default is deliberate. A flat "on" would mean `flutter build ipa` with no
arguments ships an external purchase link into App Review, and the person
running that command is exactly the person who won't remember the flag. The
safe value has to be the one you get by typing nothing.

Override explicitly when you want to:

```bash
# Android retreat — if Play policy pushes back, same commit, no code change
flutter build appbundle --release --dart-define=SAQQAR_WEB_SUBSCRIBE=false

# iOS turn-on — only after the external-purchase-link entitlement is granted
flutter build ipa --release --dart-define=SAQQAR_WEB_SUBSCRIBE=true
```

### 2.2 What the flag does NOT hide

Both platforms, always, regardless of the flag:

- Current plan name and usage bars.
- The **plan comparison** — every tier's caps, limits and which tools it
  unlocks. On a build with prices off, `/pricing` is exactly this and nothing
  more.
- Billing history (receipts for payments already taken).
- A plain-text line, never a link or a button: *"Plans are managed on
  saqqaar.com."* This mirrors the sign-up screen's *"Registration is available
  on saqqaar.com"*, which is already shipped and already through App Review.

That combination is why the iOS build is not a dead end. A user who hits their
limit can still see what a bigger plan would give them and where to get it —
they just aren't sold to inside the app.

---

## 3. Apple

### 3.1 What changes in your filing, and this one is not optional

Build 107 was held under **2.1(b)** for business-model information, and the
answer given at the time was that nothing was sold anywhere. **Once Paymob
goes live on the website that answer is no longer true**, and Apple will
notice the mismatch the first time they look at saqqaar.com.

Update the App Review notes on the next submission to say, in substance:

> Saqqar is a paid SaaS for Odoo, sold on saqqaar.com. The iOS app is a free
> client for existing accounts. No digital content is sold in the app and the
> app contains no In-App Purchase or third-party payment SDK.

Attach a demo account on a paid plan so the reviewer can see the app working
without needing to buy anything.

### 3.2 Guideline 3.1.1 — the anti-steering rule

The rule Apple has held for years: apps may not include buttons, external
links or other calls to action pointing at purchase mechanisms other than IAP.
Under a strict reading, **"Subscribe on the web" is exactly that.**

The exceptions that exist — **CONFIRM each against the current policy for your
storefronts**:

- **External Purchase Link Entitlement** (`com.apple.developer.storekit.
  external-purchase-link`) — applied for through Apple, availability and
  commission vary by storefront.
- **US storefront**, following the April 2025 Epic injunction — external
  purchase links permitted without commission or an interstitial.
- **EU**, under the DMA — link-outs permitted with the relevant entitlement.
- **Reader apps** (3.1.3(a)) — magazines, books, audio, video, music. **Not
  us.**
- **Enterprise services** (3.1.3) — B2B sales to organisations. **Not us
  either**, and this is worth being clear about internally: the pricing page
  sells "Solo — for individuals" at $5/month. A consumer tier on the public
  price list is what takes the enterprise exemption off the table.

### 3.3 What I would actually do for iOS

**Ship the first update with the flag OFF.** Reasons, in order:

1. It cannot be rejected on 3.1.1 — there is nothing to reject.
2. It keeps the 2.1(b) story consistent while you correct the business-model
   answer, which is its own conversation.
3. The app keeps the useful half: current plan, usage bars, feature
   comparison, billing history.

Then, if you want the link on iOS, apply for the external-purchase-link
entitlement for the storefronts you sell in and turn the flag on in a later
build. That is a one-argument change to the same commit.

---

## 4. Google Play

### 4.1 Declarations to update in Play Console

- **In-app purchases: NO.** There are none. Do not tick it — an app that
  declares IAP and ships none gets flagged, and one that ships IAP undeclared
  gets removed.
- **App content → Financial features:** Saqqar is not a financial product.
  Nothing to declare — **CONFIRM** against the current questionnaire.
- **Data safety:** unchanged. No payment data is collected by the app; it
  never sees any.
- **Store listing:** you may describe the paid plans. Keep the wording
  factual — "plans are managed on saqqaar.com" — rather than promotional.

### 4.2 The Payments policy

Same shape as Apple: digital content unlocked in the app is meant to go
through Google Play Billing, and steering users to an outside payment method
is restricted. Google has been the more permissive of the two since the Epic
v. Google injunction, and it runs **alternative billing** and **external
offers** programmes in various markets — **CONFIRM** which apply to Saudi
Arabia and your other storefronts before relying on any of them.

### 4.3 What I would actually do for Android

**Ship with the flag ON**, and know the retreat path.

Android is where the argument for the hand-off is strongest — the same
subscription is used on the web, the app is a client rather than the product,
and Google's enforcement here is complaint- and review-driven rather than
automatic. If policy pushes back, you rebuild with the flag off and resubmit
the same commit. That is the whole reason it is a flag.

Being straight about it: this is a calculated risk, not a clean pass. If you
want zero risk on both platforms, ship both with the flag off and let users
find the pricing page themselves — that is what Netflix does, and it costs
conversions rather than compliance.

---

## 5. Recommended shape of the next release

| | iOS | Android |
|---|---|---|
| `SAQQAR_WEB_SUBSCRIBE` | **false** | **true** |
| Prices + Subscribe button | hidden | shown |
| Feature comparison, current plan, usage, billing history | shown | shown |
| IAP / Play Billing SDK | none | none |
| Review-notes change needed | **yes** — §3.1 | store listing only |

Both from the same commit, both covered by the same tests.

---

## 6. What is NOT needed

Worth stating so nobody builds it:

- **No `POST /api/v1/billing/iap/verify/`.** Withdrawn; that endpoint does not
  exist and does not need to.
- **No store products** in App Store Connect or Play Console.
- **No server-to-server notifications** (Apple ASSN v2, Google RTDN).
- **No `in_app_purchase` package.** A test fails if one is added.
- **No in-app Paymob checkout.** `/billing/checkout` redirects to the
  catalogue; the screen behind it is kept only so the redirect has somewhere
  to have come from.

---

## 7. Open items with the backend

See `docs/MOBILE_BACKEND_OPEN_ITEMS.md` §3. The one that matters for this
release is the plan-catalogue mismatch: `GET /api/v1/billing/plans/` returns a
two-entry SAR catalogue that does not match what the website sells, while
`GET /api/v1/plans/` matches it exactly. The app now reads the second one; the
first should be retired or fixed so nobody wires it up again.
