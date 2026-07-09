import SwiftUI

/// The real Saqqar mark — hexagon + checkmark on navy, the same artwork
/// as the app icon (`assets/img/app-icon-foreground.png`) — used
/// wherever the brand identity should show through, instead of an SF
/// Symbol stand-in.
struct SaqqarLogoMark: View {
  var size: CGFloat = 28

  var body: some View {
    Image("SaqqarLogo")
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(width: size, height: size)
      .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
  }
}

/// A loading/waiting indicator built from the logo itself — a cyan ring
/// pulsing outward from the mark — instead of a generic system spinner,
/// so even the "thinking" states read as Saqqar rather than stock
/// SwiftUI chrome.
struct SaqqarLoadingMark: View {
  var size: CGFloat = 40
  @State private var pulse = false

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        .stroke(SaqqarColor.cyan.opacity(pulse ? 0 : 0.6), lineWidth: 2)
        .frame(width: size, height: size)
        .scaleEffect(pulse ? 1.6 : 1.0)
      SaqqarLogoMark(size: size)
    }
    .onAppear {
      withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
        pulse = true
      }
    }
  }
}
