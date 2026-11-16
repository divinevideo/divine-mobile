// ABOUTME: Divine's colors for the Apple Watch app.
// ABOUTME: Values match the `VineTheme` constants of the same name.

import SwiftUI

/// Divine's colors, as `VineTheme` defines them in the Flutter app.
enum DivinePalette {
  static let primary = Color(red: 0x27 / 255.0, green: 0xC5 / 255.0, blue: 0x8B / 255.0)
  static let primaryContainer = Color(red: 0xD0 / 255.0, green: 0xFB / 255.0, blue: 0xCB / 255.0)
  static let error = Color(red: 0xF4 / 255.0, green: 0x43 / 255.0, blue: 0x36 / 255.0)
  static let onSurfaceDisabled = Color.white.opacity(0.25)
}
