import SwiftUI
import WidgetKit

/// Watch face complication showing the pending-approvals count. A widget
/// extension runs in its own process with no `WCSession` delegate
/// callbacks of its own, so it reads the same App Group storage
/// `PhoneSession` (the watch app target) writes to on every
/// `applicationContext` update, rather than talking to WatchConnectivity
/// directly.
struct ApprovalsEntry: TimelineEntry {
  let date: Date
  let pendingCount: Int
}

struct ApprovalsTimelineProvider: TimelineProvider {
  private static let appGroup = "group.sa.com.digitalharbor.saqqar.watch"
  private static let pendingCountKey = "saqqar.pendingCount"

  private func currentPendingCount() -> Int {
    UserDefaults(suiteName: Self.appGroup)?.integer(forKey: Self.pendingCountKey) ?? 0
  }

  func placeholder(in context: Context) -> ApprovalsEntry {
    ApprovalsEntry(date: Date(), pendingCount: 2)
  }

  func getSnapshot(in context: Context, completion: @escaping (ApprovalsEntry) -> Void) {
    completion(ApprovalsEntry(date: Date(), pendingCount: currentPendingCount()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ApprovalsEntry>) -> Void) {
    let entry = ApprovalsEntry(date: Date(), pendingCount: currentPendingCount())
    // `PhoneSession` calls `WidgetCenter.shared.reloadAllTimelines()`
    // every time a fresh context lands, so there's no need for this
    // widget to poll on its own — a single entry with `.never` is
    // correct here.
    completion(Timeline(entries: [entry], policy: .never))
  }
}

struct SaqqarComplicationCircularView: View {
  let entry: ApprovalsEntry

  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      VStack(spacing: 0) {
        Image(systemName: "checkmark.shield")
          .font(.caption2)
          .widgetAccentable()
        Text("\(entry.pendingCount)")
          .font(.headline)
      }
    }
    .widgetLabel { Text("Saqqar") }
  }
}

struct SaqqarComplicationRectangularView: View {
  let entry: ApprovalsEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("Saqqar")
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(entry.pendingCount == 0 ? "All caught up" : "\(entry.pendingCount) to approve")
        .font(.headline)
    }
  }
}

@main
struct SaqqarComplication: Widget {
  let kind: String = "SaqqarApprovalsComplication"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ApprovalsTimelineProvider()) { entry in
      switch entry.pendingCount {
      case _:
        ComplicationContent(entry: entry)
      }
    }
    .configurationDisplayName("Saqqar Approvals")
    .description("Shows the number of approvals waiting for your decision.")
    .supportedFamilies([.accessoryCircular, .accessoryRectangular])
  }
}

/// Picks the right layout for the active complication family — WidgetKit
/// injects `\.widgetFamily` into the environment per-render.
private struct ComplicationContent: View {
  @Environment(\.widgetFamily) private var family
  let entry: ApprovalsEntry

  var body: some View {
    switch family {
    case .accessoryRectangular:
      SaqqarComplicationRectangularView(entry: entry)
    default:
      SaqqarComplicationCircularView(entry: entry)
    }
  }
}

#Preview(as: .accessoryCircular) {
  SaqqarComplication()
} timeline: {
  ApprovalsEntry(date: .now, pendingCount: 3)
}
