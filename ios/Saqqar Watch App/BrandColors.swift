import SwiftUI

/// Mirrors `lib/core/theme/app_colors.dart` — the same dark, neon
/// cyan/purple palette saqqaar.com and the main Flutter app use — so the
/// watch app reads as the same product instead of a generic system-tinted
/// SwiftUI screen.
enum SaqqarColor {
  static let bg = Color(red: 0x03 / 255, green: 0x07 / 255, blue: 0x12 / 255)
  static let surface = Color(red: 0x11 / 255, green: 0x18 / 255, blue: 0x27 / 255)
  static let surface2 = Color(red: 0x1E / 255, green: 0x29 / 255, blue: 0x3B / 255)
  static let cyan = Color(red: 0x22 / 255, green: 0xD3 / 255, blue: 0xEE / 255)
  static let purple = Color(red: 0x8B / 255, green: 0x5C / 255, blue: 0xF6 / 255)
  static let muted = Color(red: 0x94 / 255, green: 0xA3 / 255, blue: 0xB8 / 255)
  static let danger = Color(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255)
}
