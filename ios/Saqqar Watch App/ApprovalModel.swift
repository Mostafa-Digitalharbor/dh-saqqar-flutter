import Foundation

/// Mirrors `Approval` from `lib/features/inbox/data/approval_models.dart`,
/// trimmed to what the watch actually renders. Built from the raw
/// `[String: Any]` dictionary WatchConnectivity hands us — no Codable
/// round-trip needed since `WCSession.applicationContext` already gives
/// us plist-native types.
struct WatchApproval: Identifiable, Equatable {
  let id: String
  let prompt: String
  let actionType: String
  let conversationTitle: String
  let createdAt: Date?
  let recordCount: Int?

  init?(dict: [String: Any]) {
    guard let id = dict["id"] as? String,
          let prompt = dict["prompt"] as? String
    else { return nil }
    self.id = id
    self.prompt = prompt
    self.actionType = dict["actionType"] as? String ?? ""
    self.conversationTitle = dict["conversationTitle"] as? String ?? ""
    if let ms = dict["createdAtMs"] as? NSNumber {
      self.createdAt = Date(timeIntervalSince1970: ms.doubleValue / 1000)
    } else {
      self.createdAt = nil
    }
    self.recordCount = (dict["recordCount"] as? NSNumber)?.intValue
  }

  /// Human label for the five `action_type` wire values the backend
  /// emits (SAQQAR_MOBILE_API.md §3/§8). Unrecognized values fall back to
  /// the raw string so a new server-side type still renders instead of
  /// disappearing.
  var actionTypeLabel: String {
    switch actionType {
    case "credential_storage": return "Store Credential"
    case "credential_usage": return "Use Credential"
    case "server_command": return "Server Command"
    case "odoo_write": return "Odoo Write"
    case "report_export": return "Report Export"
    default: return actionType.isEmpty ? "Action" : actionType
    }
  }

  /// SF Symbol paired with `actionTypeLabel` so rows read at a glance.
  var actionTypeIcon: String {
    switch actionType {
    case "credential_storage": return "key.fill"
    case "credential_usage": return "key.viewfinder"
    case "server_command": return "terminal.fill"
    case "odoo_write": return "pencil.and.list.clipboard"
    case "report_export": return "square.and.arrow.up.fill"
    default: return "bolt.fill"
    }
  }
}

/// Parses the `syncApprovals` payload the phone hands to
/// `WCSession.updateApplicationContext` — see `WatchSessionManager.swift`
/// (phone side) for the sender and `watch_bridge.dart` for the schema.
enum WatchApprovalsPayload {
  static func parse(_ context: [String: Any]) -> (approvals: [WatchApproval], pendingCount: Int) {
    let pendingCount = (context["pendingCount"] as? NSNumber)?.intValue ?? 0
    let raw = context["approvals"] as? [[String: Any]] ?? []
    let approvals = raw.compactMap(WatchApproval.init(dict:))
    return (approvals, pendingCount)
  }
}
