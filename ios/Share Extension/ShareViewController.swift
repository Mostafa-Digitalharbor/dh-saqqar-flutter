import receive_sharing_intent

/// Share Extension entry point for Saqqar (iOS).
///
/// Subclasses the `receive_sharing_intent` plugin's `RSIShareViewController`,
/// which does all the heavy lifting: it reads the shared items the system
/// hands the extension, writes them into the shared App Group container
/// (`group.sa.com.digitalharbor.saqqar`), then opens the host app via the
/// `ShareMedia-sa.com.digitalharbor.saqqar` URL scheme so Flutter's
/// `ReceiveSharingIntent` stream delivers them to `ShareIntakeService`.
///
/// We keep auto-redirect ON: the moment the user picks Saqqar from the iOS
/// share sheet, jump straight into the app (no intermediate compose UI in
/// the extension) — matching the Android ACTION_SEND hand-off, where the
/// chat's destination sheet is where the user actually picks the target.
class ShareViewController: RSIShareViewController {
    override func shouldAutoRedirect() -> Bool {
        return true
    }
}
