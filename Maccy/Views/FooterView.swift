import Defaults
import SwiftUI

struct FooterView: View {
  @Bindable var footer: Footer

  @Environment(AppState.self) private var appState
  @Environment(ModifierFlags.self) private var modifierFlags
  @Default(.showFooter) private var showFooter

  var body: some View {
    VStack(spacing: 0) {
      Divider()
        .padding(.horizontal, Popup.horizontalSeparatorPadding)
        .padding(.bottom, Popup.verticalSeparatorPadding)

      ZStack {
        FooterItemView(item: footer.items[0])
          .invisible(!footer.items[0].isVisible)
        FooterItemView(item: footer.items[1])
          .invisible(!footer.items[1].isVisible)
      }
      .onChange(of: modifierFlags.flags) {
        footer.showClearAll(footer.isClearAllChord(modifierFlags.flags))
      }
      .onAppear {
        // The footer is shared with the docked panel; start from a known state.
        footer.showClearAll(false)
      }

      ForEach(footer.items.suffix(from: 2)) { item in
        FooterItemView(item: item)
      }
    }
    .invisible(!showFooter)
    .frame(maxHeight: showFooter ? nil : 0)
    .padding(.bottom, showFooter ? Popup.verticalPadding : 0)
    .readHeight(appState, into: \.popup.footerHeight)
  }
}
