# Reply to App Review — Guideline 2.1(b), build 107

## How to send it

1. App Store Connect → **Apps** → *Saqqar — Odoo Copilot* → **App Review** (the page showing
   "Unresolved Issues" and **Messages (4)**).
2. Scroll to the bottom → click **Reply to App Review**.
3. Paste everything between the two `====` markers below. **Nothing else** — not this section,
   not the fact table.
4. Send. Review resumes on the existing submission; no new build is needed or wanted.

The reply body below is deliberately **plain text** — App Store Connect's reply box does not
render Markdown, so `**bold**` would reach the reviewer as literal asterisks. Keep it that way
when editing.

## Facts it asserts, and where they come from

Verify each is still true before sending — this is a formal statement to Apple.

| Claim | Source |
| --- | --- |
| No IAP/billing SDK of any kind | `pubspec.yaml`, `pubspec.lock`, `ios/Podfile.lock` — no `in_app_purchase`, `purchases_flutter`, StoreKit |
| No purchase flow anywhere in the product | Confirmed by the team: no payment provider signed, no checkout on saqqaar.com |
| No prices shown on iOS | `billing_visibility.dart` → `showPaidUpsell => !Platform.isIOS`, applied at `pricing_screen.dart:172` |
| The `free` badge is a bug, now removed | `plan_badge.dart:7` documents "only render for non-free plans"; `plan_usage_card.dart` ignored `showBadge` and fell back to the raw slug. Fixed + pinned by `test/plan_badge_test.dart` |
| Target users are businesses + independent professionals running Odoo | Confirmed by the team |

**What App Review actually screenshotted** (verified against the images, not inferred):
the Account screen, and Usage → "Plan & usage" showing the `free` badge and the three token
windows. They never reached the pricing catalogue. The reply addresses only what they saw —
do not volunteer a tour of screens they cannot reach.

**Do not upload a new build until this reply is answered** — a new build cancels the in-flight
submission and restarts review. The reply is accurate for build 107 as-is: it describes the
`free` badge as a bug already fixed on our side and shipping in the next build.

========================= COPY FROM HERE =========================

Hello,

Thank you for the questions — happy to explain our business model in full.

The short answer is that Saqqar is currently a completely free application. Nothing in the app is sold, on any platform, through any channel. We have no payment processor, no checkout, and no billing of any kind in our product today. No user has ever paid us anything for access to the app.

Here are detailed answers to each of your questions.

1. Who are the users that will use the paid content, subscriptions, features, and services in the app?

There are none. Every user of the app is on our free tier and has access to the app's full functionality at no cost.

For context on what the app does: Saqqar is a companion client for Odoo, a business ERP system. The user signs in, connects their own Odoo database — which they own and operate themselves, either self-hosted or hosted by Odoo S.A. — and then asks questions about their own business data in natural language. That Odoo database is not something we sell, host, or bill for; it belongs to the user and exists independently of our app.

2. Where can users purchase the content, subscriptions, features, and services that can be accessed in the app?

Nowhere. We do not sell anything at this time — not inside the app, not on our website (saqqaar.com), and not through any other channel. No checkout flow exists anywhere in our product, and the app contains no link to any purchase page.

3. What specific types of previously purchased content, subscriptions, features, and services can a user access in the app?

None. No user has previously purchased anything from us, because no purchase mechanism has ever existed. The app has no "restore purchases", no paid entitlement, and no paid unlock of any kind.

4. What paid content, subscriptions, or features are unlocked within the app that do not use In-App Purchase?

None. Every feature is available to every signed-in user for free.

We have looked closely at the two screenshots attached to your message — our Account screen, and the Usage screen reached from it — and we believe we can point to exactly what raised this question.

The Usage screen shows the user how much of the AI service they have consumed against a free allowance (in the screenshot: 0 of 625K today, 0 of 3.5M this week, 0 of 15M this month). We provide the AI processing behind the app at our own cost and give it away for free, so we show users their own consumption for transparency. When a user reaches the allowance, it resets automatically once the time window passes — nothing is offered for sale at that moment, and no payment is ever requested.

Next to it, that screen displays a small badge reading "free". We believe this badge is what suggested a paid tier must exist. It is an internal system label that was never meant to be user-visible, and we agree it is misleading: it implies the user could obtain some other tier, when in fact no other tier is available to anyone, from anywhere, at any price. This is a bug on our side, and we have already removed that badge — it will not appear in our next build.

To restate the substance plainly: no feature in the app is unlocked by payment, because no payment for the app exists.

5. Are the enterprise services in your app sold to single users, consumers, or for family use?

Nothing in the app is sold to anyone today, so no service is sold to single users, consumers, or families.

On our intended audience: Saqqar is a business productivity tool for people who already operate an Odoo ERP system — small businesses, and independent professionals such as accountants and ERP consultants working with their own or their clients' Odoo databases. It has no consumer or family use case.

Finally, so our intent is on the record: if we introduce paid plans in the future, we will implement In-App Purchase in accordance with guideline 3.1.1 before unlocking any paid feature for iOS users, and we will submit that build for your review.

Please let us know if any further detail would help.

Best regards,
Mostafa Badr
Digital Harbor

========================== COPY TO HERE ==========================
