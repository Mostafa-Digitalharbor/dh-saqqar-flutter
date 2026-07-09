import SwiftUI

/// Compact brand mark used at the top of every screen in place of a
/// plain text title — the real logo mark (see `SaqqarLogoMark`), paired
/// with a tracked-out monospaced wordmark, in the same dark/cyan identity
/// as saqqaar.com (see `SaqqarColor`).
struct SaqqarBrandHeader: View {
  var body: some View {
    HStack(spacing: 6) {
      SaqqarLogoMark(size: 20)
      Text("SAQQAR")
        .font(.system(size: 13, weight: .heavy, design: .monospaced))
        .tracking(1.5)
        .foregroundStyle(SaqqarColor.cyan)
    }
  }
}
