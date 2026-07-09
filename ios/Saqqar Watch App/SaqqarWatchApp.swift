import SwiftUI

@main
struct SaqqarWatchApp: App {
  @StateObject private var session = PhoneSession.shared

  var body: some Scene {
    WindowGroup {
      TabView {
        ContentView()
        VoiceCommandView()
      }
      .environmentObject(session)
      .onAppear { session.requestNotificationPermission() }
    }
  }
}
