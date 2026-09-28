import Defaults
import SwiftUI

// Top of the docked panel: wordmark and actions, search, filter chips and the item count.
struct DockHeaderView: View {
  @FocusState.Binding var searchFocused: Bool

  @Environment(AppState.self) private var appState
  @Default(.popupPosition) private var popupPosition
  @Default(.unlimitedHistory) private var unlimitedHistory
  @Default(.size) private var size

  var body: some View {
    @Bindable var history = appState.history

    VStack(alignment: .leading, spacing: 10) {
      titleBar

      SearchFieldView(placeholder: "dock_search_placeholder", query: $history.searchQuery)
        .focused($searchFocused)
        .foregroundStyle(DockTheme.text)

      filterRow

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
