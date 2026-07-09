import Flutter
import WatchConnectivity

/// Bridges the paired Apple Watch app to the Flutter side via
/// `WCSession`, exposed to Dart through the
/// `sa.com.digitalharbor.saqqarapp/watch` method channel (see
/// `lib/features/watch/data/watch_bridge.dart`).
///
/// Two directions:
///   * Dart → watch: `syncApprovals` is forwarded via
///     `updateApplicationContext` (best-effort, latest-state-wins, works
///     even while the watch app isn't foregrounded); `pushVoiceReply` is
///     forwarded via `transferUserInfo` (queued, guaranteed delivery —
///     used for an assistant reply that lands after the watch's
///     interactive request already timed out).
///   * Watch → Dart: an approve/deny tap or a voice command arrives here
///     as a `WCSession` interactive message and is relayed to Dart,
///     whose result becomes the reply sent back to the watch.
final class WatchSessionManager: NSObject {
  static let shared = WatchSessionManager()

  private var channel: FlutterMethodChannel?
  private var session: WCSession?

  /// Call once, from `AppDelegate.didInitializeImplicitFlutterEngine`.
  func start(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "sa.com.digitalharbor.saqqarapp/watch",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "syncApprovals":
        self?.handleSyncApprovals(call.arguments, result: result)
      case "pushVoiceReply":
        self?.handlePushVoiceReply(call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel

    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
    self.session = session
  }

  private func handleSyncApprovals(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let dict = arguments as? [String: Any] else {
      result(FlutterError(code: "bad_args", message: "syncApprovals expects a map", details: nil))
      return
    }
    guard let session = session else {
      result(nil) // WatchConnectivity unsupported on this device — no-op.
      return
    }
    // Best-effort: an unpaired watch, an inactive session, or a stale
    // context all fail silently here — the phone UI must never notice.
    // The next successful refresh will simply overwrite this attempt.
    do {
      try session.updateApplicationContext(dict)
    } catch {
      // Swallowed intentionally — see comment above.
    }
    result(nil)
  }

  /// A voice-triggered assistant reply that arrived after the watch's
  /// interactive `sendMessage` already returned. `transferUserInfo`
  /// (rather than another `sendMessage`) queues it for delivery instead
  /// of failing outright if the watch isn't reachable right this moment.
  private func handlePushVoiceReply(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let dict = arguments as? [String: Any],
          dict["conversationId"] is String,
          dict["reply"] is String
    else {
      result(FlutterError(code: "bad_args", message: "pushVoiceReply expects conversationId/reply", details: nil))
      return
    }
    guard let session = session else {
      result(nil)
      return
    }
    var payload = dict
    payload["type"] = "voiceReply"
    session.transferUserInfo(payload)
    result(nil)
  }
}

extension WatchSessionManager: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    // Re-activate for a fresh session when the user switches paired
    // watches, per Apple's WCSessionDelegate guidance.
    session.activate()
  }

  /// Interactive message from the watch — either an approve/deny action or
  /// a recorded voice command. Both are relayed to Dart, which is the only
  /// side that actually talks to `saqqaar.com`.
  ///
  /// `WCSessionDelegate` callbacks arrive on a background queue, but
  /// `FlutterMethodChannel.invokeMethod` must be called on the platform
  /// (main) thread — hopping here, once, keeps every call site below
  /// (including `relay`) simple.
  func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    DispatchQueue.main.async { [weak self] in
      switch message["type"] as? String {
      case "decideApproval":
        guard let id = message["id"] as? String,
              let approved = message["approved"] as? Bool
        else {
          replyHandler(["error": "bad_request"])
          return
        }
        self?.relay("decideApproval", arguments: ["id": id, "approved": approved], replyHandler: replyHandler)
      case "voiceCommand":
        guard let audio = message["audio"] as? Data else {
          replyHandler(["error": "bad_request"])
          return
        }
        self?.handleVoiceCommand(
          audio: audio,
          conversationId: message["conversationId"] as? String,
          environmentId: message["environmentId"] as? String,
          replyHandler: replyHandler
        )
      case "listProjects":
        self?.relay("listProjects", arguments: [:], replyHandler: replyHandler)
      case "useDefaultProject":
        self?.relay("useDefaultProject", arguments: [:], replyHandler: replyHandler)
      default:
        replyHandler(["error": "bad_request"])
      }
    }
  }

  /// Writes the watch's recorded clip to a temp file — passing a path over
  /// the method channel avoids a second binary copy through the Flutter
  /// codec — and hands it to Dart, which deletes the file once it's read
  /// it (see `WatchBridge._handleVoiceCommand`).
  private func handleVoiceCommand(
    audio: Data,
    conversationId: String?,
    environmentId: String?,
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    let tmpURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("saqqar-voice-\(UUID().uuidString).m4a")
    do {
      try audio.write(to: tmpURL)
    } catch {
      replyHandler(["error": "Couldn't stage the recording."])
      return
    }
    var arguments: [String: Any] = ["path": tmpURL.path]
    if let conversationId {
      arguments["conversationId"] = conversationId
    }
    if let environmentId {
      arguments["environmentId"] = environmentId
    }
    relay("voiceCommand", arguments: arguments, replyHandler: replyHandler)
  }

  /// Shared invoke-and-translate-the-result plumbing for every watch
  /// message that needs a Dart round-trip.
  private func relay(
    _ method: String,
    arguments: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    guard let channel = channel else {
      replyHandler(["error": "phone_app_not_ready"])
      return
    }
    channel.invokeMethod(method, arguments: arguments) { response in
      if let dict = response as? [String: Any] {
        replyHandler(dict)
      } else if let flutterError = response as? FlutterError {
        replyHandler(["error": flutterError.message ?? "\(method)_failed"])
      } else {
        replyHandler(["error": "\(method)_failed"])
      }
    }
  }
}
