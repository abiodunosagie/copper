import SwiftUI

// Colors and metrics of the docked panel, taken from the approved Copper design.
enum DockTheme {
  static let background = Color(hex: 0x1B1917)
  static let card = Color(hex: 0x221F1C)
  static let cardSelected = Color(hex: 0x2A2622)
  static let control = Color(hex: 0x262320)
  static let border = Color(hex: 0x34302B)
  static let controlBorder = Color(hex: 0x3A352F)
  static let text = Color(hex: 0xEFE9E3)
  static let secondaryText = Color(hex: 0xD6CFC7)
  static let mutedText = Color(hex: 0xA79E94)
  static let codeBackground = Color(hex: 0x161412)
  static let codeText = Color(hex: 0xD9E6C8)
  static let accent = Color(hex: 0xD08A55)
  static let onAccent = Color(hex: 0x1B1917)

  static let panelCornerRadius: CGFloat = 18
  static let cardCornerRadius: CGFloat = 14
  static let chipHeight: CGFloat = 26
  static let controlHeight: CGFloat = 30
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255
    )
  }
}
