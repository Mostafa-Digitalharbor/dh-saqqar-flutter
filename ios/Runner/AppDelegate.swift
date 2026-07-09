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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
