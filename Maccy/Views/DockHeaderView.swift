import Defaults
import SwiftUI

// Top of the docked panel: wordmark and actions, search, filter chips and the item count.
struct DockHeaderView: View {
  @FocusState.Binding var searchFocused: Bool

  @Environment(AppState.self) private var appState
  @Default(.popupPosition) private var popupPosition
  @Default(.unlimitedHistory) private var unlimitedHistory
  @Default(.size) private var size

  private var queueCount: Int { appState.history.pasteStack?.items.count ?? 0 }

  var body: some View {
    @Bindable var history = appState.history

    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "list.clipboard")
          .font(.system(size: 17, weight: .medium))
          .foregroundStyle(DockTheme.accent)
          .accessibilityHidden(true)
        Text(verbatim: "Copper")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(DockTheme.text)

        Spacer(minLength: 4)

        if queueCount > 0 {
          HStack(spacing: 5) {
            Image(systemName: "list.bullet")
            Text("dock_queue")
            Text("\(queueCount)")
              .font(.system(size: 11, weight: .semibold))
              .frame(minWidth: 18, minHeight: 18)
              .background(DockTheme.accent, in: Circle())
              .foregroundStyle(DockTheme.onAccent)
          }
          .font(.system(size: 12))
          .padding(.horizontal, 8)
          .frame(height: DockTheme.controlHeight)
          .background(DockTheme.control, in: RoundedRectangle(cornerRadius: 9))
          .accessibilityElement(children: .combine)
        }

        iconButton("rectangle.lefthalf.inset.filled", help: "dock_move_edge") {
          let newPosition: PopupPosition = popupPosition == .dockedRight ? .dockedLeft : .dockedRight
          popupPosition = newPosition
          appState.popup.open(height: appState.popup.height, at: newPosition)
        }
        .scaleEffect(x: popupPosition == .dockedRight ? -1 : 1)
      }

      SearchFieldView(placeholder: "dock_search_placeholder", query: $history.searchQuery)
        .focused($searchFocused)
        .foregroundStyle(DockTheme.text)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(ContentFilter.allCases) { filter in
            chip(filter)
          }
        }
      }

      Text(itemCountLine)
        .font(.system(size: 11))
        .foregroundStyle(DockTheme.mutedText)
    }
    .padding(.horizontal, 14)
    .padding(.top, 14)
    .padding(.bottom, 6)
    .readHeight(appState, into: \.popup.headerHeight)
  }

  private var itemCountLine: String {
    let count = String(format: NSLocalizedString("dock_item_count", comment: ""), appState.history.all.count)
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

  private func iconButton(_ systemName: String, help: LocalizedStringKey, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 13))
        .foregroundStyle(DockTheme.text)
        .frame(width: DockTheme.controlHeight, height: DockTheme.controlHeight)
        .background(DockTheme.control, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(DockTheme.controlBorder))
    }
    .buttonStyle(.plain)
    .help(help)
    .accessibilityLabel(Text(help))
  }
}
