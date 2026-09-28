import SwiftUI

// Bottom bar of the docked panel: the classic footer actions as icons.
// Each icon keeps its FooterItem, so keyboard shortcuts and clear confirmations work as before.
struct DockFooterView: View {
  @Bindable var footer: Footer

  @Environment(AppState.self) private var appState

  // Keyed by FooterItem.title; DockFooterViewTests checks every footer item has one.
  static let icons: [String: String] = [
    "clear": "eraser",
    "clear_all": "trash",
    "preferences": "gearshape",
    "about": "info.circle",
    "quit": "power"
  ]

  var body: some View {
    HStack(spacing: 6) {
      ForEach(footer.items) { item in
        icon(for: item)
        if item.title == "clear_all" {
          Spacer(minLength: 0)
        }
      }
    }
    .padding(.horizontal, DockTheme.barPadding)
    .padding(.vertical, 10)
    .overlay(alignment: .top) {
      Rectangle().fill(DockTheme.border).frame(height: 1)
    }
    .readHeight(appState, into: \.popup.footerHeight)
  }

  private func icon(for item: FooterItem) -> some View {
    ConfirmationView(item: item) {
      Image(systemName: Self.icons[item.title] ?? "circle")
        .font(.system(size: 13))
        .foregroundStyle(item.title == "quit" ? DockTheme.mutedText : DockTheme.text)
        .dockControl(selected: item.isSelected)
    }
    .help(Text(item.help ?? LocalizedStringKey(item.title)))
    .accessibilityLabel(Text(LocalizedStringKey(item.title)))
  }
}
