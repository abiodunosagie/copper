import Defaults
import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var appState = AppState.shared
  @State private var modifierFlags = ModifierFlags()
  @State private var scenePhase: ScenePhase = .background

  @FocusState private var searchFocused: Bool
  @Default(.popupPosition) private var popupPosition
  @Environment(\.colorScheme) private var systemColorScheme

  var body: some View {
    ZStack {
      if popupPosition.isDocked {
        if #available(macOS 26.0, *) {
          GlassEffectView(style: .regular, tintColor: DockTheme.glassTint)
        } else {
          VisualEffectView(material: .hudWindow)
          DockTheme.background
        }
      } else if #available(macOS 26.0, *) {
        GlassEffectView()
      } else {
        VisualEffectView()
      }

      KeyHandlingView(searchQuery: $appState.history.searchQuery, searchFocused: $searchFocused) {
        VStack(spacing: 0) {
          SlideoutView(controller: appState.preview) {
            if popupPosition.isDocked {
              DockHeaderView(searchFocused: $searchFocused, isRow: popupPosition.isHorizontalDock)
            } else {
              HeaderView(
                controller: appState.preview,
                searchFocused: $searchFocused
              )
            }

            VStack(alignment: .leading, spacing: 0) {
              if popupPosition.isHorizontalDock {
                HorizontalHistoryListView(searchFocused: $searchFocused)
              } else {
                HistoryListView(
                  searchQuery: $appState.history.searchQuery,
                  searchFocused: $searchFocused
                )
              }

              if popupPosition.isDocked {
                DockFooterView(footer: appState.footer)
              } else {
                FooterView(footer: appState.footer)
              }
            }
            .animation(.default.speed(3), value: appState.history.items)
            .animation(
              .default.speed(3),
              value: appState.history.pasteStack?.id
            )
            .padding(.horizontal, popupPosition.isDocked ? 0 : Popup.horizontalPadding)
            .onAppear {
              searchFocused = true
            }
            .onMouseMove {
              appState.navigator.isKeyboardNavigating = false
            }
          } slideout: {
            SlideoutContentView()
          }
          .frame(minHeight: 0)
          .layoutPriority(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .task {
        try? await appState.history.load()
      }
    }
    .animation(.easeInOut(duration: 0.2), value: appState.searchVisible)
    // The docked panel is always the dark Copper design; the classic popup follows the system.
    .environment(\.colorScheme, popupPosition.isDocked ? .dark : systemColorScheme)
    .environment(appState)
    .environment(modifierFlags)
    .environment(\.scenePhase, scenePhase)
    // FloatingPanel is not a scene, so let's implement custom scenePhase..
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
      if let window = $0.object as? NSWindow,
         let bundleIdentifier = Bundle.main.bundleIdentifier,
         window.identifier == NSUserInterfaceItemIdentifier(bundleIdentifier) {
        scenePhase = .active
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) {
      if let window = $0.object as? NSWindow,
         let bundleIdentifier = Bundle.main.bundleIdentifier,
         window.identifier == NSUserInterfaceItemIdentifier(bundleIdentifier) {
        scenePhase = .background
      }
    }
  }
}

#Preview {
  ContentView()
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}
