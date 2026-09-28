import SwiftUI

// The card row used when the panel is docked to the top or bottom edge: pinned items first,
// then history, scrolling sideways. Keyboard navigation and selection work as in the column.
struct HorizontalHistoryListView: View {
  static let cardWidth: CGFloat = 240

  @FocusState.Binding var searchFocused: Bool

  @Environment(AppState.self) private var appState
  @Environment(ModifierFlags.self) private var modifierFlags
  @Environment(\.scenePhase) private var scenePhase

  private var items: [HistoryItemDecorator] {
    appState.history.pinnedItems.filter(\.isVisible) + appState.history.unpinnedItems.filter(\.isVisible)
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 0) {
          ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            HistoryItemView(item: item, previous: nil, next: nil, index: index)
              .frame(width: Self.cardWidth)
          }
        }
        .padding(.horizontal, 6)
      }
      .task(id: appState.navigator.scrollTarget) {
        guard let target = appState.navigator.scrollTarget else { return }
        try? await Task.sleep(for: .milliseconds(10))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.15)) {
          proxy.scrollTo(target, anchor: .center)
        }
        appState.navigator.scrollTarget = nil
      }
      .onChange(of: scenePhase) {
        if scenePhase == .active {
          searchFocused = true
          appState.navigator.isKeyboardNavigating = true
          appState.navigator.select(item: appState.history.unpinnedItems.first ?? appState.history.pinnedItems.first)
        } else {
          modifierFlags.flags = []
          appState.navigator.isKeyboardNavigating = true
        }
      }
    }
  }
}
