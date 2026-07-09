import Foundation

/// Mirrors `Project`/`Environment` from
/// `lib/features/vault/data/project_models.dart`, trimmed to what the
/// watch's pre-recording picker needs.
struct WatchEnvironment: Identifiable, Equatable, Hashable {
  let id: String
  let name: String
  let isLive: Bool

  init?(dict: [String: Any]) {
    guard let id = dict["id"] as? String else { return nil }
    self.id = id
    self.name = dict["name"] as? String ?? ""
    self.isLive = dict["isLive"] as? Bool ?? false
  }
}

struct WatchProject: Identifiable, Equatable, Hashable {
  let id: String
  let name: String
  let environments: [WatchEnvironment]

  init?(dict: [String: Any]) {
    guard let id = dict["id"] as? String else { return nil }
    self.id = id
    self.name = dict["name"] as? String ?? ""
    let rawEnvironments = dict["environments"] as? [[String: Any]] ?? []
    self.environments = rawEnvironments.compactMap(WatchEnvironment.init(dict:))
  }
}
