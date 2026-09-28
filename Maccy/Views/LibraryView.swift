import Defaults
import SwiftUI

// What the main window's sidebar can show.
enum LibraryScope: Hashable {
  case all
  case pinned
  case kind(ContentFilter)
  // Source app bundle id (iCloud items use "iCloud"); the sidebar shows its display name.
  case app(String)
  case collection(String)

  func matches(_ item: HistoryItemDecorator) -> Bool {
    switch self {
    case .all: return true
    case .pinned: return item.isPinned
    case .kind(let filter): return filter.matches(item)
    case .app(let bundle): return LibraryView.sourceKey(item) == bundle
    case .collection(let name): return item.item.collection == name
    }
  }
}

// The main window: every history item in an adaptive grid, filtered by the sidebar and search.
// Clicking a card copies it.
struct LibraryView: View {
  static let cardMinimumWidth: CGFloat = 240
  static let copiedBadgeSeconds = 1.5

  @Environment(AppState.self) private var appState
  @Default(.collections) private var collections

  @State private var scope: LibraryScope? = .all
  @State private var query = ""
  @State private var copiedItemID: UUID?

  // One entry per source app: (key, display name), sorted by name.
  private var sourceApps: [(key: String, name: String)] {
    var names: [String: String] = [:]
    for item in appState.history.all {
      if let key = Self.sourceKey(item), names[key] == nil {
        names[key] = item.application ?? key
      }
    }
    return names.map { (key: $0.key, name: $0.value) }.sorted { $0.name < $1.name }
  }

  static func sourceKey(_ item: HistoryItemDecorator) -> String? {
    item.item.universalClipboard ? "iCloud" : item.item.application
  }

  private let search = Search()

  private var visibleItems: [HistoryItemDecorator] {
    // totalCount is observed; reading it refreshes the grid when items are added or removed.
    _ = appState.history.totalCount
    let scope = scope ?? .all
    let inScope = appState.history.all.filter(scope.matches)
    // Same search as the panel, so the search mode setting (exact, fuzzy, regex) applies here too.
    return search.search(string: query, within: inScope).map(\.object)
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
        if !sourceApps.isEmpty {
          Section("library_apps") {
            ForEach(sourceApps, id: \.key) { app in
              Text(verbatim: app.name).tag(LibraryScope.app(app.key))
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
        Clipboard.shared.copy(item.item, removeFormatting: Defaults[.removeFormattingByDefault])
        copiedItemID = item.id
        Task {
          try? await Task.sleep(for: .seconds(Self.copiedBadgeSeconds))
          if copiedItemID == item.id { copiedItemID = nil }
        }
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
