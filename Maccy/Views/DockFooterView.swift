import Defaults
import SwiftUI

// Bottom bar of the docked panel: the classic footer actions as icons.
// Each icon keeps its FooterItem, so keyboard shortcuts and clear confirmations work as before.
struct DockFooterView: View {
  @Bindable var footer: Footer

  @Environment(AppState.self) private var appState
  @Environment(ModifierFlags.self) private var modifierFlags
  @Default(.showFooter) private var showFooter

  // Keyed by FooterItem.title; ContentKindTests checks every footer item has one.
  static let icons: [String: String] = [
    "clear": "eraser",
    "clear_all": "trash",
    "preferences": "gearshape",
    "about": "info.circle",
    "quit": "power"
  ]

  var body: some View {
    // Clear and Clear all share the first slot; Clear all only appears while its modifiers are held.
    let clearSlot = footer.items[1].isVisible ? footer.items[1] : footer.items[0]

    HStack(spacing: 6) {
      icon(for: clearSlot)
      Spacer(minLength: 0)
      ForEach(footer.items.suffix(from: 2)) { item in
        icon(for: item)
      }
    }
    .padding(.horizontal, DockTheme.barPadding)
    .padding(.vertical, 10)
    .overlay(alignment: .top) {
      Rectangle().fill(DockTheme.border).frame(height: 1)
    }
    .invisible(!showFooter)
    .frame(maxHeight: showFooter ? nil : 0)
    .readHeight(appState, into: \.popup.footerHeight)
    .onChange(of: modifierFlags.flags) {
      footer.showClearAll(footer.isClearAllChord(modifierFlags.flags))
    }
    .onAppear {
      footer.showClearAll(false)
    }
  }

  private func icon(for item: FooterItem) -> some View {
    ConfirmationView(item: item) {
      Image(systemName: Self.icons[item.title] ?? "circle")
        .font(.system(size: 13))
        .foregroundStyle(foreground(for: item))
        .dockControl(selected: item.isSelected)
    }
    .help(Text(item.help ?? LocalizedStringKey(item.title)))
    .accessibilityLabel(Text(LocalizedStringKey(item.title)))
  }

  private func foreground(for item: FooterItem) -> Color {
    switch item.title {
    case "clear_all": return DockTheme.destructive
    case "quit": return DockTheme.mutedText
    default: return DockTheme.text
    }
  }
}
