import AppKit
import SwiftUI

// Naming prompt and colors for collections.
@MainActor
enum CollectionActions {
  // Dot colors for collection chips, assigned by position.
  static let dotColors: [Color] = [0x7FB0D6, 0x8FC39A, 0xC9A36A, 0xD58FB0, 0xA99BE0, 0xE0A06A].map(Color.init(hex:))

  static func dotColor(for name: String, in collections: [String]) -> Color {
    let index = collections.firstIndex(of: name) ?? 0
    return dotColors[index % dotColors.count]
  }

  // Asks for a new collection name and creates it. Returns the name, or nil when cancelled or invalid.
  @discardableResult
  static func createCollection() -> String? {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("collection_new_title", comment: "")
    alert.informativeText = NSLocalizedString("collection_new_info", comment: "")
    alert.addButton(withTitle: NSLocalizedString("collection_new_create", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("collection_new_cancel", comment: ""))

    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
    field.placeholderString = NSLocalizedString("collection_new_placeholder", comment: "")
    alert.accessoryView = field
    alert.window.initialFirstResponder = field

    while alert.runModal() == .alertFirstButtonReturn {
      let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      if AppState.shared.history.createCollection(named: name) {
        return name
      }
      NSSound.beep()
    }
    return nil
  }
}
