import Defaults
import SwiftUI

@Observable
class Footer: ItemsContainer {
  var items: [FooterItem] = []

  var selectedItem: FooterItem? {
    willSet {
      selectedItem?.isSelected = false
      newValue?.isSelected = true
    }
  }

  var suppressClearAlert = Binding<Bool>(
    get: { Defaults[.suppressClearAlert] },
    set: { Defaults[.suppressClearAlert] = $0 }
  )

  private var showFooter: Bool {
    return Defaults[.showFooter]
  }
  var containerVisible: Bool {
    return showFooter
  }

  // "Clear" and the more destructive "Clear all" share one slot. "Clear all" only takes it
  // while its modifier keys are held, in the popup and the docked panel alike.
  func isClearAllChord(_ flags: NSEvent.ModifierFlags) -> Bool {
    let clearModifiers = items[0].shortcuts.first?.modifierFlags ?? []
    let clearAllModifiers = items[1].shortcuts.first?.modifierFlags ?? []
    // All of Clear all's modifiers held, and more than Clear's; Shift alone never qualifies.
    return clearAllModifiers.isSubset(of: flags) && !flags.isSubset(of: clearModifiers)
  }

  // Returns the item that now occupies the clear slot, so selection can follow it.
  @discardableResult
  func showClearAll(_ show: Bool) -> FooterItem {
    items[0].isVisible = !show
    items[1].isVisible = show
    let shown = show ? items[1] : items[0]
    let hidden = show ? items[0] : items[1]
    if selectedItem == hidden {
      AppState.shared.navigator.select(footerItem: shown)
    }
    return shown
  }

  init() { // swiftlint:disable:this function_body_length
    defer {
      // Clear shows until the Clear all chord is held.
      items[1].isVisible = false
    }
    items = [
      FooterItem(
        title: "clear",
        shortcuts: [KeyShortcut(key: .delete, modifierFlags: [.command, .option])],
        help: "clear_tooltip",
        confirmation: .init(
          message: "clear_alert_message",
          comment: "clear_alert_comment",
          confirm: "clear_alert_confirm",
          cancel: "clear_alert_cancel"
        ),
        suppressConfirmation: suppressClearAlert
      ) {
        Task { @MainActor in
          AppState.shared.history.clear()
        }
      },
      FooterItem(
        title: "clear_all",
        shortcuts: [KeyShortcut(key: .delete, modifierFlags: [.command, .option, .shift])],
        help: "clear_all_tooltip",
        confirmation: .init(
          message: "clear_alert_message",
          comment: "clear_alert_comment",
          confirm: "clear_alert_confirm",
          cancel: "clear_alert_cancel"
        ),
        suppressConfirmation: suppressClearAlert
      ) {
        Task { @MainActor in
          AppState.shared.history.clearAll()
        }
      },
      FooterItem(
        title: "preferences",
        shortcuts: [KeyShortcut(key: .comma)]
      ) {
        Task { @MainActor in
          AppState.shared.openPreferences()
        }
      },
      FooterItem(
        title: "about",
        help: "about_tooltip"
      ) {
        AppState.shared.openAbout()
      },
      FooterItem(
        title: "quit",
        shortcuts: [KeyShortcut(key: .q)],
        help: "quit_tooltip"
      ) {
        AppState.shared.quit()
      }
    ]
  }
}
