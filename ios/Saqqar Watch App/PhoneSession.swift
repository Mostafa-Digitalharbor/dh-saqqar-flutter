import Foundation
import UserNotifications
import WatchConnectivity
import WidgetKit

/// The watch app's only connection to the outside world. Everything here
/// is companion-mode: no network layer, no auth — data arrives from the
/// paired iPhone's `WatchSessionManager` via `WCSession`, and approve/deny
/// decisions are relayed back to it for the actual
/// `POST /approvals/<id>/decision/` call.
///
/// Also the source of truth for the complication widget: every fresh
/// context is mirrored into the shared App Group so
/// `SaqqarComplication` can read it without its own WatchConnectivity
/// session (widget extensions don't get delegate callbacks).
final class PhoneSession: NSObject, ObservableObject {
  static let shared = PhoneSession()

  @Published private(set) var approvals: [WatchApproval] = []
  @Published private(set) var pendingCount: Int = 0
  @Published private(set) var isReachable: Bool = false
  @Published var lastError: String?

  /// An assistant reply that arrived after a voice command's own
  /// interactive `sendMessage` already returned (a tool-using turn easily
  /// outlives that window) — delivered separately via `transferUserInfo`.
  /// `VoiceCommandView` observes this to update in place if it's still
  /// showing that conversation, and it backs the "Saqqar replied" local
  /// notification for whenever it isn't.
  @Published var lateVoiceReply: LateVoiceReply?

  static let appGroup = "group.sa.com.digitalharbor.saqqar"
  private static let pendingCountKey = "saqqar.pendingCount"
  private static let approvalsKey = "saqqar.approvals"

  private var session: WCSession?

  private override init() {
    super.init()
    loadPersisted()
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
    self.session = session
  }

  // MARK: - Shared storage (read by the complication widget)

  private func loadPersisted() {
    guard let defaults = UserDefaults(suiteName: Self.appGroup) else { return }
    pendingCount = defaults.integer(forKey: Self.pendingCountKey)
    if let raw = defaults.array(forKey: Self.approvalsKey) as? [[String: Any]] {
      approvals = raw.compactMap(WatchApproval.init(dict:))
    }
  }

  private func persist(rawApprovals: [[String: Any]], pendingCount: Int) {
    guard let defaults = UserDefaults(suiteName: Self.appGroup) else { return }
    defaults.set(pendingCount, forKey: Self.pendingCountKey)
    defaults.set(rawApprovals, forKey: Self.approvalsKey)
  }

  /// Applies a fresh `applicationContext` payload. Always invoked on the
  /// main thread by the delegate callbacks below.
  private func apply(context: [String: Any]) {
    let parsed = WatchApprovalsPayload.parse(context)
    let previousCount = pendingCount
    approvals = parsed.approvals
    pendingCount = parsed.pendingCount
    persist(
      rawApprovals: context["approvals"] as? [[String: Any]] ?? [],
      pendingCount: parsed.pendingCount
    )
    WidgetCenter.shared.reloadAllTimelines()
    if parsed.pendingCount > previousCount {
      notifyNewApproval(delta: parsed.pendingCount - previousCount)
    }
  }

  // MARK: - Local notifications
  //
  // Real remote push (FCM/APNs) is Phase-1-deferred on the backend — see
  // README.md "Phase 1 deferred". Until that ships, a rising pending
  // count on a context we just received is the only signal we have, so
  // we surface it as a local notification instead of a push one.

  private func notifyNewApproval(delta: Int) {
    let content = UNMutableNotificationContent()
    content.title = delta == 1 ? "New approval pending" : "\(delta) new approvals pending"
    content.body = approvals.first?.prompt ?? "Open Saqqar to review."
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
  }

  /// Call once a view has read [lateVoiceReply] so the same value doesn't
  /// re-trigger its `onChange` handler on the next appearance.
  func clearLateVoiceReply() {
    lateVoiceReply = nil
  }

  private func notifyVoiceReply(_ reply: String) {
    let content = UNMutableNotificationContent()
    content.title = "Saqqar replied"
    content.body = reply
    content.sound = .default
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }

  // MARK: - Approve / deny

  /// Relayed to the phone — the only side that talks to `saqqaar.com`.
  /// Requires the phone app reachable; optimistically drops the row for
  /// an instant-feeling watch UI, and rolls back on failure.
  func decide(_ approval: WatchApproval, approved: Bool, completion: @escaping (Bool) -> Void) {
    guard let session = session, session.isReachable else {
      DispatchQueue.main.async {
        self.lastError = "Open Saqqar on your iPhone to sync."
        completion(false)
      }
      return
    }
    let previousApprovals = approvals
    DispatchQueue.main.async {
      self.approvals.removeAll { $0.id == approval.id }
      self.pendingCount = max(0, self.pendingCount - 1)
    }
    session.sendMessage(
      ["type": "decideApproval", "id": approval.id, "approved": approved],
      replyHandler: { [weak self] reply in
        DispatchQueue.main.async {
          guard let self else { completion(false); return }
          if let err = reply["error"] as? String {
            self.approvals = previousApprovals
            self.pendingCount += 1
            self.lastError = err
            completion(false)
          } else {
            completion(true)
          }
        }
      },
      errorHandler: { [weak self] error in
        DispatchQueue.main.async {
          guard let self else { completion(false); return }
          self.approvals = previousApprovals
          self.pendingCount += 1
          self.lastError = error.localizedDescription
          completion(false)
        }
      }
    )
  }
}

// MARK: - Voice command

/// A completed round-trip: the phone's Whisper transcript of what was
/// recorded, the conversation it landed in (new or continued), and the
/// assistant's reply text if one arrived before the bounded wait on the
/// phone side timed out. `reply == nil` doesn't mean failure — Saqqar may
/// still be working; any resulting approval surfaces through the normal
/// `applicationContext` sync like every other approval.
struct VoiceCommandResult {
  let transcript: String
  let conversationId: String
  let reply: String?
}

struct VoiceCommandError: Error {
  let message: String
}

struct WatchDefaultProjectResult {
  let environmentId: String
  let environmentName: String
}

struct LateVoiceReply: Equatable {
  let conversationId: String
  let reply: String
}

extension PhoneSession {
  /// Sends a recorded voice note to the phone for transcription + a
  /// Saqqar turn, bound to [environmentId] if this is the first turn of a
  /// new conversation (nil when continuing one already bound). Mirrors
  /// `decide(_:approved:completion:)` — same reachability guard, same
  /// `WCSession.sendMessage` interactive round-trip — but nothing here is
  /// optimistic since there's no local state to update ahead of the reply.
  func sendVoiceCommand(
    fileURL: URL,
    conversationId: String?,
    environmentId: String?,
    completion: @escaping (Result<VoiceCommandResult, VoiceCommandError>) -> Void
  ) {
    guard let data = try? Data(contentsOf: fileURL) else {
      completion(.failure(VoiceCommandError(message: "Couldn't read the recording.")))
      return
    }
    var payload: [String: Any] = ["type": "voiceCommand", "audio": data]
    if let conversationId {
      payload["conversationId"] = conversationId
    }
    if let environmentId {
      payload["environmentId"] = environmentId
    }
    sendInteractive(payload) { result in
      switch result {
      case .success(let reply):
        guard let transcript = reply["transcript"] as? String,
              let conversationId = reply["conversationId"] as? String
        else {
          completion(.failure(VoiceCommandError(message: "Unexpected response.")))
          return
        }
        completion(.success(VoiceCommandResult(
          transcript: transcript,
          conversationId: conversationId,
          reply: reply["reply"] as? String
        )))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  /// Every project (with nested environments) the user has, for the
  /// picker shown before the first voice turn of a conversation.
  func fetchProjects(completion: @escaping (Result<[WatchProject], VoiceCommandError>) -> Void) {
    sendInteractive(["type": "listProjects"]) { result in
      switch result {
      case .success(let reply):
        let raw = reply["projects"] as? [[String: Any]] ?? []
        completion(.success(raw.compactMap(WatchProject.init(dict:))))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  /// Idempotently provisions (or fetches) a default project + environment
  /// — the watch-side equivalent of the phone's "Use My Database" button,
  /// for accounts with no projects set up yet.
  func useDefaultProject(completion: @escaping (Result<WatchDefaultProjectResult, VoiceCommandError>) -> Void) {
    sendInteractive(["type": "useDefaultProject"]) { result in
      switch result {
      case .success(let reply):
        guard let environmentId = reply["environmentId"] as? String else {
          completion(.failure(VoiceCommandError(message: "Unexpected response.")))
          return
        }
        completion(.success(WatchDefaultProjectResult(
          environmentId: environmentId,
          environmentName: reply["environmentName"] as? String ?? "Default"
        )))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  /// Shared reachability guard + `WCSession.sendMessage` + error-key
  /// translation for every interactive watch → phone round-trip above.
  private func sendInteractive(
    _ payload: [String: Any],
    completion: @escaping (Result<[String: Any], VoiceCommandError>) -> Void
  ) {
    guard let session = session, session.isReachable else {
      completion(.failure(VoiceCommandError(message: "Open Saqqar on your iPhone to sync.")))
      return
    }
    session.sendMessage(
      payload,
      replyHandler: { reply in
        DispatchQueue.main.async {
          if let err = reply["error"] as? String {
            completion(.failure(VoiceCommandError(message: err)))
          } else {
            completion(.success(reply))
          }
        }
      },
      errorHandler: { error in
        DispatchQueue.main.async {
          completion(.failure(VoiceCommandError(message: error.localizedDescription)))
        }
      }
    )
  }
}

extension PhoneSession: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    DispatchQueue.main.async { self.isReachable = session.isReachable }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    DispatchQueue.main.async { self.isReachable = session.isReachable }
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    DispatchQueue.main.async { self.apply(context: applicationContext) }
  }

  /// A late voice-command reply, queued by the phone via
  /// `transferUserInfo` once the assistant actually answered (see
  /// `WatchSessionManager.handlePushVoiceReply`). Always fires a
  /// notification — `VoiceCommandView` additionally updates in place via
  /// `lateVoiceReply` if it's still showing that conversation.
  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    guard userInfo["type"] as? String == "voiceReply",
          let conversationId = userInfo["conversationId"] as? String,
          let reply = userInfo["reply"] as? String
    else { return }
    DispatchQueue.main.async {
      self.lateVoiceReply = LateVoiceReply(conversationId: conversationId, reply: reply)
      self.notifyVoiceReply(reply)
    }
  }
}
