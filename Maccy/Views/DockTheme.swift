import AppKit
import SwiftUI

// Colors and metrics of the docked panel, from the approved Copper design.
enum DockTheme {
  // The approved Copper palette (charcoal, warm cards, copper accent) laid over macOS's own
  // glass: the charcoal tints the glass, and the cards are slightly see-through.
  static let glassTint = NSColor(red: 0.106, green: 0.098, blue: 0.090, alpha: 0.72)
  static let background = Color(hex: 0x1B1917).opacity(0.86)
  static let card = Color(hex: 0x221F1C).opacity(0.78)
  static let cardSelected = Color(hex: 0x2A2622).opacity(0.9)
  static let control = Color(hex: 0x262320).opacity(0.85)
  static let border = Color(hex: 0x34302B)
  static let controlBorder = Color(hex: 0x3A352F)
  static let text = Color(hex: 0xEFE9E3)
  static let secondaryText = Color(hex: 0xD6CFC7)
  static let mutedText = Color(hex: 0xA79E94)
  static let codeBackground = Color(hex: 0x161412).opacity(0.9)
  static let codeText = Color(hex: 0xD9E6C8)
  static let accent = Color(hex: 0xD08A55)
  static let onAccent = Color(hex: 0x1B1917)
  static let destructive = Color(nsColor: .systemRed)

  static let panelCornerRadius: CGFloat = 18
  static let cardCornerRadius: CGFloat = 14
  static let contentCornerRadius: CGFloat = 10
  static let controlCornerRadius: CGFloat = 9
  static let cardPadding: CGFloat = 12
  static let barPadding: CGFloat = 14
  static let chipHeight: CGFloat = 26
  static let smallChipHeight: CGFloat = 22
  static let controlHeight: CGFloat = 30
}

extension View {
  // The square dark control used for icon buttons in the docked panel.
  func dockControl(selected: Bool = false) -> some View {
    let shape = RoundedRectangle(cornerRadius: DockTheme.controlCornerRadius)
    return self
      .frame(width: DockTheme.controlHeight, height: DockTheme.controlHeight)
      .background(DockTheme.control, in: shape)
      .overlay(
        shape.strokeBorder(selected ? DockTheme.accent : DockTheme.controlBorder, lineWidth: selected ? 2 : 1)
      )
      .contentShape(shape)
  }
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
