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
    registerShareIntakeChannel(messenger: engineBridge.applicationRegistrar.messenger())
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
