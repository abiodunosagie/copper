import Defaults
import SwiftUI

// Right-click menu for a history item, shared by the panel and the main window.
struct HistoryItemContextMenu: View {
  var item: HistoryItemDecorator

  @Environment(AppState.self) private var appState
  @Default(.collections) private var collections

  var body: some View {
    Button(LocalizedStringKey(item.isPinned ? "history_item_unpin_action" : "history_item_pin_action")) {
      appState.history.togglePin(item)
    }
    if item.item.image != nil && !item.title.isEmpty {
      Button("history_item_copy_image_text") {
        Clipboard.shared.copyInMaccy(item.title, expiresAt: item.item.expiresAt)
      }
    }
    Button("history_item_quick_look") {
      QuickLookController.shared.toggle(item.item)
    }
    .keyboardShortcut(.space, modifiers: .option)
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
    if !PeerShareService.shared.peers.isEmpty {
      Menu("history_item_send_to") {
        ForEach(PeerShareService.shared.peers) { peer in
          Button(peer.name) {
            PeerShareService.shared.send(item.item, to: peer)
          }
        }
      }
      .disabled(item.contentKind == .secret)
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
