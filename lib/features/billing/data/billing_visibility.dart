import 'dart:io' show Platform;

/// Whether to surface paid-plan **upsell** UI — tier prices, the "Upgrade" /
/// "See plans" CTAs, and the pricing catalogue's price + contact CTA.
///
/// Hidden on iOS to comply with App Store Review **guideline 3.1.1**: the app
/// must not display prices for, or steer users toward purchasing, digital
/// features outside In-App Purchase. Android is unaffected.
///
/// The current plan name and usage bars stay visible on every platform — they
/// are informational (what you already have), not an upsell.
bool get showPaidUpsell => !Platform.isIOS;
