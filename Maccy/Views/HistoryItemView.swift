import Defaults
import SwiftUI

struct HistoryItemView: View {
  @Bindable var item: HistoryItemDecorator
  var previous: HistoryItemDecorator?
  var next: HistoryItemDecorator?
  var index: Int

  private var selectionAppearance: SelectionAppearance {
    let previousSelected = previous?.isSelected ?? false
    let nextSelected = next?.isSelected ?? false
    switch (previousSelected, nextSelected) {
    case (true, false):
      return .topConnection
    case (false, true):
      return .bottomConnection
    case (true, true):
      return .topBottomConnection
    default:
      return .none
    }
  }

  @Default(.showHexColorSwatch) private var showHexColorSwatch
  @Default(.popupPosition) private var popupPosition
  @Default(.collections) private var collections
  @Environment(AppState.self) private var appState

  private var colorSwatchImage: NSImage? {
    guard showHexColorSwatch else { return nil }
    return ColorImage.from(item.title)
  }

  private func performSelect() {
    if NSEvent.modifierFlags.contains(.command) && appState.multiSelectionEnabled {
      appState.navigator.addToSelection(item: item)
    } else {
      let flags = NSEvent.ModifierFlags.currentModifierFlags
      Task {
        appState.history.select(item, flags: flags)
      }
    }
  }

  var body: some View {
    Group {
      if popupPosition.isDocked {
        card
      } else {
        row
      }
    }
    .accessibilityIdentifier("copy-history-item")
    .buttonAction(performSelect)
    .onAppear {
      item.ensureThumbnailImage()
    }
    .contextMenu {
      contextMenuItems
    }
    .accessibilityAction(named: Text(item.isPinned ? "history_item_unpin_action" : "history_item_pin_action")) {
      appState.history.togglePin(item)
    }
    .accessibilityAction(named: Text("history_item_delete_action")) {
      appState.history.delete(item)
    }
  }

  private var card: some View {
    CardItemView(item: item, isSelected: item.isSelected, selectionIndex: item.multiSelectionIndex)
      .padding(.vertical, CardItemView.spacing / 2)
      .padding(.horizontal, DockTheme.cardPadding)
      .id(item.id)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(item.accessibilityLabel))
      .accessibilityAddTraits(item.isSelected ? .isSelected : [])
      .hoverSelectionId(item.id)
  }

  private var row: some View {
    ListItemView(
      id: item.id,
      selectionId: item.id,
      appIcon: item.applicationImage,
      image: item.thumbnailImage,
      accessoryImage: item.thumbnailImage != nil ? nil : colorSwatchImage,
      attributedTitle: item.attributedTitle,
      shortcuts: item.shortcuts,
      isSelected: item.isSelected,
      selectionIndex: item.multiSelectionIndex,
      selectionAppearance: selectionAppearance,
      accessibilityLabel: item.accessibilityLabel
    ) {
      Text(verbatim: item.title)
    }
  }

  @ViewBuilder
  private var contextMenuItems: some View {
    Button(LocalizedStringKey(item.isPinned ? "history_item_unpin_action" : "history_item_pin_action")) {
      appState.history.togglePin(item)
    }
    if item.item.image != nil && !item.title.isEmpty {
      Button("history_item_copy_image_text") {
        Clipboard.shared.copyInMaccy(item.title, expiresAt: item.item.expiresAt)
      }
    }
    Menu("history_item_collection_menu") {
      ForEach(collections, id: \.self) { name in
        Toggle(name, isOn: Binding(
          get: { item.item.collection == name },
          set: { appState.history.setCollection($0 ? name : nil, for: item) }
        ))
      }
      if !collections.isEmpty {
        Divider()
      }
      Button("history_item_collection_new") {
        if let name = CollectionActions.createCollection() {
          appState.history.setCollection(name, for: item)
        }
      }
      if item.item.collection != nil {
        Button("history_item_collection_remove") {
          appState.history.setCollection(nil, for: item)
        }
      }
    }
    Menu("history_item_transform_menu") {
      ForEach(TextTransform.Category.allCases) { category in
        Menu(category.title) {
          ForEach(TextTransform.transforms(in: category)) { transform in
            Button(transform.title) {
              appState.history.apply(transform, to: item)
            }
          }
        }
      }
    }
    Divider()
    Button("history_item_delete_action", role: .destructive) {
      appState.history.delete(item)
    }
  }
}
