import Defaults
import SwiftUI

// What the main window's sidebar can show.
enum LibraryScope: Hashable {
  case all
  case pinned
  case kind(ContentFilter)
  case app(String)
  case collection(String)

  func matches(_ item: HistoryItemDecorator) -> Bool {
    switch self {
    case .all: return true
    case .pinned: return item.isPinned
    case .kind(let filter): return filter.matches(item)
    case .app(let name): return item.application == name
    case .collection(let name): return item.item.collection == name
    }
  }
}

// The main window: every history item in an adaptive grid, filtered by the sidebar and search.
// Clicking a card copies it.
struct LibraryView: View {
  static let cardMinimumWidth: CGFloat = 240

  @Environment(AppState.self) private var appState
  @Default(.collections) private var collections

  @State private var scope: LibraryScope? = .all
  @State private var query = ""
  @State private var copiedItemID: UUID?

  private var appNames: [String] {
    Set(appState.history.all.compactMap(\.application)).sorted()
  }

  private var visibleItems: [HistoryItemDecorator] {
    // totalCount is observed; reading it refreshes the grid when items are added or removed.
    _ = appState.history.totalCount
    let scope = scope ?? .all
    let needle = query.trimmingCharacters(in: .whitespaces)
    return appState.history.all.filter { item in
      scope.matches(item) && (needle.isEmpty || item.title.localizedCaseInsensitiveContains(needle)
        || item.item.previewableText.localizedCaseInsensitiveContains(needle))
    }
  }

  var body: some View {
    NavigationSplitView {
      List(selection: $scope) {
        Section {
          Label("library_all", systemImage: "tray.full").tag(LibraryScope.all)
          Label("filter_pinned", systemImage: "pin").tag(LibraryScope.pinned)
        }
        Section("library_types") {
          ForEach(ContentFilter.allCases.filter { $0 != .all && $0 != .pinned }) { filter in
            Text(filter.title).tag(LibraryScope.kind(filter))
          }
        }
        if !appNames.isEmpty {
          Section("library_apps") {
            ForEach(appNames, id: \.self) { name in
              Text(verbatim: name).tag(LibraryScope.app(name))
            }
          }
        }
        if !collections.isEmpty {
          Section("dock_collections") {
            ForEach(collections, id: \.self) { name in
              HStack(spacing: 6) {
                Circle().fill(CollectionActions.dotColor(for: name, in: collections)).frame(width: 8, height: 8)
                Text(verbatim: name)
              }
              .tag(LibraryScope.collection(name))
            }
          }
        }
      }
      .navigationSplitViewColumnWidth(min: 170, ideal: 200)
    } detail: {
      grid
        .searchable(text: $query, placement: .toolbar, prompt: Text("dock_search_placeholder"))
    }
    .environment(\.colorScheme, .dark)
    .task {
      // History normally loads when the panel first opens; the window may come first.
      if appState.history.all.isEmpty {
        try? await appState.history.load()
      }
    }
  }

  @ViewBuilder
  private var grid: some View {
    let items = visibleItems
    if items.isEmpty {
      ContentUnavailableView("library_empty", systemImage: "doc.on.clipboard")
    } else {
      ScrollView {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: Self.cardMinimumWidth), spacing: 12, alignment: .top)],
          alignment: .leading,
          spacing: 12
        ) {
          ForEach(items) { item in
            card(item)
          }
        }
        .padding(16)
      }
    }
  }

  private func card(_ item: HistoryItemDecorator) -> some View {
    CardItemView(item: item, isSelected: copiedItemID == item.id, showsShortcut: false)
      .overlay(alignment: .topTrailing) {
        if copiedItemID == item.id {
          Text("library_copied")
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(DockTheme.accent, in: Capsule())
            .foregroundStyle(DockTheme.onAccent)
            .padding(8)
        }
      }
      .onTapGesture {
        Clipboard.shared.copy(item.item)
        copiedItemID = item.id
      }
      .onDrag { item.item.dragItemProvider }
      .contextMenu {
        HistoryItemContextMenu(item: item)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(item.accessibilityLabel))
      .accessibilityAddTraits(.isButton)
  }
}
