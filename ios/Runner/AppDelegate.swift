import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
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
  }
}
