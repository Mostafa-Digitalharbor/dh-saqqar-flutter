import Flutter
import UIKit
import receive_sharing_intent

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let shareChannelName = "saqqar/share_intake"
  private static let appGroupId = "group.sa.com.digitalharbor.saqqar"
  private static let shareKey = "ShareKey"
  private static let shareMessageKey = "ShareMessageKey"
  private var shareIntakeChannel: FlutterMethodChannel?

  /// Opaque overlay raised while the app is not active, so the iOS
  /// app-switcher thumbnail (and the resign-active transition) never captures
  /// live Odoo data / chat content. iOS has no `FLAG_SECURE` equivalent
  /// (Android sets that in MainActivity), so this is the parity mechanism.
  /// It runs UNCONDITIONALLY — independent of the optional in-app biometric
  /// lock — and is purely visual (no auth prompt), so it adds no friction.
  private var privacyCover: UIView?

  /// Set by either APNs registration callback. The launch-time watchdog reads
  /// it so "iOS answered with nothing at all" is reported instead of leaving a
  /// silent gap in the log.
  private var apnsCallbackFired = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Make this app delegate the notification-center delegate. Required by
    // flutter_local_notifications on iOS so foreground notifications actually
    // display and taps route through `onDidReceiveNotificationResponse`.
    // `FlutterAppDelegate` conforms to UNUserNotificationCenterDelegate and
    // forwards to the registered plugins (firebase_messaging included), so
    // setting it here is compatible with FCM's APNs↔FCM swizzling.
    //
    // Plugin registration is NOT done here on purpose — this project uses the
    // new implicit-engine embedding, which registers plugins in
    // `didInitializeImplicitFlutterEngine` below. Registering again here would
    // double-register every plugin.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    logPushDiagnostics(application)
    return result
  }

  // MARK: - Push diagnostics (launch-time)

  /// Dumps everything needed to explain an iOS push failure WITHOUT guessing,
  /// then explicitly asks APNs to register so the ✅/❌ callback below always
  /// fires. Grep the run for `SAQQAR-APNS`.
  ///
  /// The decisive line is `aps-environment` read from the *embedded
  /// provisioning profile the app was actually signed with*:
  ///   • `development` / `production` → the build really is push-entitled, so a
  ///     null APNs token is NOT a signing problem.
  ///   • `MISSING` → the profile grants no push. That is the whole bug: enable
  ///     Push Notifications on the App ID + add the capability in Xcode →
  ///     Signing & Capabilities, then let automatic signing regenerate it.
  ///
  /// Registering here (rather than waiting for the Dart layer) is safe and
  /// idempotent — iOS issues the device token regardless of alert permission,
  /// so this also removes the "token not ready yet" race that made
  /// `getAPNSToken()` return null.
  private func logPushDiagnostics(_ application: UIApplication) {
    #if targetEnvironment(simulator)
    NSLog("[SAQQAR-APNS] ⚠️ running on the SIMULATOR — APNs never issues a token here. Use a real device.")
    #endif
    let bundleId = Bundle.main.bundleIdentifier ?? "(unknown)"
    NSLog("[SAQQAR-APNS] ℹ️ bundleId=\(bundleId) · aps-environment=\(Self.apsEnvironmentFromProfile()) · alreadyRegistered=\(application.isRegisteredForRemoteNotifications)")
    NSLog("[SAQQAR-APNS] ▶ requesting APNs registration…")
    application.registerForRemoteNotifications()

    // Watchdog: iOS answers registerForRemoteNotifications with EITHER
    // didRegister or didFailToRegister. Silence past this point is itself the
    // finding (the request never reached APNs), so say so rather than leaving
    // the log ambiguous.
    DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
      guard let self = self, !self.apnsCallbackFired else { return }
      NSLog("[SAQQAR-APNS] ⏱ NO callback after 12s — iOS answered the registration request with neither success nor failure.")
      NSLog("[SAQQAR-APNS] 👉 CAUSE: almost always the build is signed with a profile that has no push entitlement (check the aps-environment line above), or there is no network path to APNs. It is NOT the backend and NOT the notification permission.")
    }
  }

  /// Reads `Entitlements → aps-environment` out of `embedded.mobileprovision`
  /// (the profile baked into this build). Returns `MISSING …` when the profile
  /// grants no push, which is the single most common cause of a null APNs
  /// token on a correctly-permissioned real device.
  private static func apsEnvironmentFromProfile() -> String {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          let raw = String(data: data, encoding: .isoLatin1)
    else {
      return "NO PROFILE FOUND (simulator, or App Store build)"
    }
    guard let start = raw.range(of: "<?xml"),
          let end = raw.range(of: "</plist>")
    else {
      return "PROFILE UNPARSEABLE"
    }
    let plistText = String(raw[start.lowerBound..<end.upperBound])
    guard let plistData = plistText.data(using: .isoLatin1),
          let plist = try? PropertyListSerialization.propertyList(
            from: plistData, options: [], format: nil
          ) as? [String: Any],
          let entitlements = plist["Entitlements"] as? [String: Any]
    else {
      return "PROFILE HAS NO ENTITLEMENTS"
    }
    if let aps = entitlements["aps-environment"] as? String {
      return aps
    }
    return "MISSING ❌ (this profile grants NO push — that is the bug)"
  }

  // MARK: - APNs registration diagnostics
  //
  // Purely additive logging so a failing iOS push setup names its OWN cause in
  // the console. Grep the run for `SAQQAR-APNS`:
  //   ✅ registered → APNs is fine; any non-delivery is backend/FCM side.
  //   ❌ FAILED     → the error string is the exact reason, e.g.
  //      "no valid 'aps-environment' entitlement string found" = the Push
  //      Notifications capability / provisioning profile is missing it.
  //
  // Firebase's method swizzling (FirebaseAppDelegateProxyEnabled, default on)
  // still runs: we call `super`, which chains to the swizzled implementation
  // that hands the device token to FCM. This only observes; it changes nothing.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    apnsCallbackFired = true
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    NSLog("[SAQQAR-APNS] ✅ registered — APNs device token = \(hex)")
    NSLog("[SAQQAR-APNS] 👉 APNs is WORKING on this device. If pushes still do not arrive, the client is fine — look at FCM/backend delivery (test the FCM token in Firebase Console → Send test message).")
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    apnsCallbackFired = true
    let ns = error as NSError
    NSLog(
      "[SAQQAR-APNS] ❌ APNs registration FAILED — "
        + "\(ns.domain) code=\(ns.code): \(ns.localizedDescription)"
    )
    // Translate the raw error into the action that actually fixes it, so the
    // console says what to DO rather than only what broke.
    let text = ns.localizedDescription.lowercased()
    if text.contains("aps-environment") || text.contains("entitlement") {
      NSLog("[SAQQAR-APNS] 👉 CAUSE: the signed build has no valid push entitlement. FIX: Apple Developer portal → App ID → enable Push Notifications, then Xcode → Runner → Signing & Capabilities → + Capability → Push Notifications, let automatic signing regenerate the profile, then flutter clean && rebuild.")
    } else if text.contains("network") || text.contains("connect") || text.contains("offline") {
      NSLog("[SAQQAR-APNS] 👉 CAUSE: the device could not reach APNs (network). FIX: retry on a normal Wi-Fi/cellular connection — corporate networks sometimes block APNs (port 5223).")
    } else {
      NSLog("[SAQQAR-APNS] 👉 Unrecognised APNs error — send the two lines above verbatim.")
    }
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    WatchSessionManager.shared.start(messenger: engineBridge.applicationRegistrar.messenger())
    registerShareIntakeChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }

  // MARK: - App-switcher privacy cover

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    // Raise the cover BEFORE the switcher snapshot is taken (which happens
    // around resign-active), not on didEnterBackground which is too late.
    showPrivacyCover()
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    hidePrivacyCover()
  }

  private func showPrivacyCover() {
    guard privacyCover == nil, let window = self.window else { return }
    let cover = UIView(frame: window.bounds)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    // Solid brand navy (#0B1A38) — matches the launch/splash background so
    // the switcher thumbnail reads as the app's launch state, not a blank.
    cover.backgroundColor = UIColor(
      red: 0x0B / 255.0,
      green: 0x1A / 255.0,
      blue: 0x38 / 255.0,
      alpha: 1.0
    )
    cover.isUserInteractionEnabled = false
    window.addSubview(cover)
    privacyCover = cover
  }

  private func hidePrivacyCover() {
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }

  override func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if SwiftReceiveSharingIntentPlugin.instance.hasMatchingSchemePrefix(url: url) {
      return SwiftReceiveSharingIntentPlugin.instance.application(
        application,
        open: url,
        options: options
      )
    }
    return super.application(application, open: url, options: options)
  }

  private func registerShareIntakeChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: Self.shareChannelName,
      binaryMessenger: messenger
    )
    shareIntakeChannel = channel

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "peekSharedMedia":
        result(Self.sharedMediaPayload())
      case "clearSharedMedia":
        Self.clearSharedMediaPayload()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func sharedMediaPayload() -> String? {
    guard let userDefaults = UserDefaults(suiteName: appGroupId),
          let data = userDefaults.object(forKey: shareKey) as? Data,
          let json = String(data: data, encoding: .utf8),
          !json.isEmpty,
          json != "[]"
    else {
      return nil
    }

    return json
  }

  private static func clearSharedMediaPayload() {
    guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
      return
    }

    userDefaults.removeObject(forKey: shareKey)
    userDefaults.removeObject(forKey: shareMessageKey)
    userDefaults.synchronize()
  }
}
