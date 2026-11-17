/// Where subscriptions are sold, and therefore what the app may show.
///
/// **Paymob is live on saqqaar.com. Nothing is charged inside the app.** The
/// app shows the plan catalogue and hands off to the website to pay; a user
/// who subscribes there sees their new plan here on the next poll.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Whether the app may show subscription prices and a tappable path to the
/// web checkout on saqqaar.com.
///
/// **This is the one switch that decides whether the app steers toward a
/// purchase**, and it is a store-policy decision, not a design one. Read
/// `docs/STORE_PAYMENTS_COMPLIANCE.md` before changing it.
///
/// The short version:
///
///   * An app that is **free and sells nothing** is fine on both stores. That
///     is true either way here — no payment is ever taken in the app.
///   * Showing prices and linking out to buy is what both stores restrict
///     ("anti-steering": App Store 3.1.1, Google Play Payments). Exceptions
///     exist — Apple's External Purchase Link entitlement, the US storefront
///     after the 2025 Epic injunction, the EU under the DMA — but they are
///     per-jurisdiction and have to be applied for.
///
/// Built as a `dart-define` so retreating is a build flag rather than a code
/// change: ship the same commit with `--dart-define=SAQQAR_WEB_SUBSCRIBE=false`
/// and every price, CTA and route below disappears. That is the whole reason
/// sales live on one surface — changing them shouldn't need a code review.
///
/// **Three states, and the third is the important one:**
///
///   * `=true`  → shown, whatever the platform.
///   * `=false` → hidden, whatever the platform.
///   * **omitted → [_platformDefault]**, which is off on iOS and on for
///     Android.
///
/// The default is per-platform rather than a flat `true` because the flat
/// version is a footgun: `flutter build ipa --release` with no defines would
/// ship prices and an external purchase link straight into App Review, and the
/// person running that command is exactly the person who won't remember. The
/// safe value has to be the one you get by typing nothing.
const String _kWebSubscribeRaw = String.fromEnvironment(
  'SAQQAR_WEB_SUBSCRIBE',
  defaultValue: '',
);

/// iOS off, everything else on. See `docs/STORE_PAYMENTS_COMPLIANCE.md` §3–4:
/// Apple enforces the anti-steering rule in 3.1.1 strictly and the exceptions
/// need an entitlement we haven't applied for; Google is materially more
/// permissive, and Android is where the hand-off is worth having.
bool get _platformDefault => !Platform.isIOS;

bool get kShowWebSubscribe => switch (_kWebSubscribeRaw) {
  'true' => true,
  'false' => false,
  _ => _platformDefault,
};

/// Gates prices, the "Subscribe on the web" CTAs, the pricing catalogue, and
/// the upgrade nudge on the over-quota banner.
///
/// The current plan name and usage bars are NOT gated: they are informational
/// (what you already have), and no store objects to an app telling a user
/// what their own account is.
bool get showPaidUpsell => _testOverride ?? kShowWebSubscribe;

bool? _testOverride;

/// Lets tests exercise **both** sides of [kShowWebSubscribe] in one run.
///
/// A `dart-define` is fixed at compile time, so without this a test suite can
/// only ever see the branch it was built with — and the branch nobody tests is
/// the one shipped in a hurry when App Review objects. An untested retreat
/// path is not a retreat path. Pass null to restore the build's own value.
@visibleForTesting
set debugShowPaidUpsell(bool? value) => _testOverride = value;

/// Read-only billing records — history and receipts for payments already made
/// on the web.
///
/// Deliberately **not** behind [showPaidUpsell]. Showing a customer what they
/// have already been charged is account information, not a purchase surface,
/// and it is the one billing screen that is more useful in an app that cannot
/// sell than in one that can — it is the only place the money shows up.
bool get showBillingRecords => true;
