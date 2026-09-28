import Defaults
import SwiftUI

struct FooterView: View {
  @Bindable var footer: Footer

  @Environment(AppState.self) private var appState
  @Environment(ModifierFlags.self) private var modifierFlags
  @Default(.showFooter) private var showFooter
  @State private var showClear = true
  @State private var showClearAll = false


  var body: some View {
    VStack(spacing: 0) {
      Divider()
        .padding(.horizontal, Popup.horizontalSeparatorPadding)
        .padding(.bottom, Popup.verticalSeparatorPadding)

      ZStack {
        FooterItemView(item: footer.items[0])
          .invisible(!showClear)
        FooterItemView(item: footer.items[1])
          .invisible(!showClearAll)
      }
      .onChange(of: modifierFlags.flags) {
        let clearAll = footer.isClearAllChord(modifierFlags.flags)
        showClear = !clearAll
        showClearAll = clearAll
        footer.showClearAll(clearAll)
      }
      .onAppear {
        // The footer is shared with the docked panel; start from a known state.
        showClear = true
        showClearAll = false
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
