import Defaults
import SwiftUI

// Top of the docked panel: wordmark and actions, search, filter chips and the item count.
struct DockHeaderView: View {
  @FocusState.Binding var searchFocused: Bool

  @Environment(AppState.self) private var appState
  @Environment(\.scenePhase) private var scenePhase
  @Default(.popupPosition) private var popupPosition
  @Default(.unlimitedHistory) private var unlimitedHistory
  @Default(.size) private var size
  @Default(.collections) private var collections

  var body: some View {
    @Bindable var history = appState.history

    VStack(alignment: .leading, spacing: 10) {
      titleBar

      SearchFieldView(placeholder: "dock_search_placeholder", query: $history.searchQuery)
        .focused($searchFocused)
        .foregroundStyle(DockTheme.text)
        // Every opening starts with an empty search, like the classic popup.
        .onChange(of: scenePhase) {
          if scenePhase == .background && !history.searchQuery.isEmpty {
            history.searchQuery = ""
          }
        }

      filterRow

      collectionRow

      Text(itemCountLine)
        .font(.system(size: 11))
        .foregroundStyle(DockTheme.mutedText)
    }
    .padding(.horizontal, DockTheme.barPadding)
    .padding(.top, DockTheme.barPadding)
    .padding(.bottom, 6)
    .readHeight(appState, into: \.popup.headerHeight)
  }

  private var titleBar: some View {
    HStack(spacing: 8) {
      Image(systemName: "list.clipboard")
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(DockTheme.accent)
        .accessibilityHidden(true)
      Text(verbatim: "Copper")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(DockTheme.text)

      Spacer(minLength: 4)

      queueBadge

      Button {
        appState.popup.toggleDockEdge()
      } label: {
        Image(systemName: "rectangle.lefthalf.inset.filled")
          .font(.system(size: 13))
          .foregroundStyle(DockTheme.text)
          .scaleEffect(x: popupPosition == .dockedRight ? -1 : 1)
          .dockControl()
      }
      .buttonStyle(.plain)
      .help(Text("dock_move_edge"))
      .accessibilityLabel(Text("dock_move_edge"))
    }
  }

  @ViewBuilder
  private var queueBadge: some View {
    let count = appState.history.pasteStack?.items.count ?? 0
    if count > 0 {
      HStack(spacing: 5) {
        Image(systemName: "list.bullet")
        Text("dock_queue")
        Text("\(count)")
          .font(.system(size: 11, weight: .semibold))
          .frame(minWidth: 18, minHeight: 18)
          .background(DockTheme.accent, in: Circle())
          .foregroundStyle(DockTheme.onAccent)
      }
      .font(.system(size: 12))
      .foregroundStyle(DockTheme.text)
      .padding(.horizontal, 8)
      .frame(height: DockTheme.controlHeight)
      .background(DockTheme.control, in: RoundedRectangle(cornerRadius: DockTheme.controlCornerRadius))
      .accessibilityElement(children: .combine)
    }
  }

  private var filterRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        ForEach(ContentFilter.allCases) { filter in
          chip(filter)
        }
      }
    }
  }

  private var collectionRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        Text("dock_collections")
          .font(.system(size: 11))
          .foregroundStyle(DockTheme.mutedText)
        ForEach(collections, id: \.self) { name in
          collectionChip(name)
        }
        Button {
          CollectionActions.createCollection()
        } label: {
          Text("dock_collection_new")
            .font(.system(size: 11))
            .padding(.horizontal, 9)
            .frame(height: DockTheme.smallChipHeight)
            .foregroundStyle(DockTheme.mutedText)
            .overlay(Capsule().strokeBorder(DockTheme.controlBorder, style: StrokeStyle(lineWidth: 1, dash: [3])))
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func collectionChip(_ name: String) -> some View {
    let active = appState.history.collectionFilter == name
    return Button {
      appState.history.collectionFilter = active ? nil : name
    } label: {
      HStack(spacing: 5) {
        Circle()
          .fill(CollectionActions.dotColor(for: name, in: collections))
          .frame(width: 7, height: 7)
        Text(verbatim: name)
          .font(.system(size: 11, weight: active ? .semibold : .regular))
      }
      .padding(.horizontal, 9)
      .frame(height: DockTheme.smallChipHeight)
      .foregroundStyle(DockTheme.text)
      .background(active ? DockTheme.cardSelected : Color.clear, in: Capsule())
      .overlay(Capsule().strokeBorder(active ? DockTheme.text : DockTheme.controlBorder))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(active ? .isSelected : [])
    .contextMenu {
      Button("dock_collection_delete", role: .destructive) {
        if CollectionActions.confirmDelete(name) {
          appState.history.deleteCollection(name)
        }
      }
    }
  }

  private var itemCountLine: String {
    let count = String(format: NSLocalizedString("dock_item_count", comment: ""), appState.history.totalCount)
    let limit = unlimitedHistory
      ? NSLocalizedString("dock_unlimited", comment: "")
      : String(format: NSLocalizedString("dock_limit", comment: ""), size)
    return count + " · " + limit
  }

  private func chip(_ filter: ContentFilter) -> some View {
    let active = appState.history.contentFilter == filter
    return Button {
      appState.history.contentFilter = filter
    } label: {
      Text(filter.title)
        .font(.system(size: 12, weight: active ? .semibold : .regular))
        .padding(.horizontal, 11)
        .frame(height: DockTheme.chipHeight)
        .foregroundStyle(active ? DockTheme.onAccent : DockTheme.text)
        .background(active ? DockTheme.accent : DockTheme.control, in: Capsule())
        .overlay(Capsule().strokeBorder(active ? DockTheme.accent : DockTheme.controlBorder))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(active ? .isSelected : [])
  }
}
