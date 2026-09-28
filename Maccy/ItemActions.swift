import AppKit
import Defaults

// Editing an item before pasting it, and merging several items into one.
@MainActor
enum ItemActions {
  enum Separator: String, CaseIterable, Identifiable {
    case newLine = "\n"
    case comma = ", "
    case space = " "

    var id: Self { self }

    var title: String {
      switch self {
      case .newLine: return NSLocalizedString("merge_new_lines", comment: "")
      case .comma: return NSLocalizedString("merge_commas", comment: "")
      case .space: return NSLocalizedString("merge_spaces", comment: "")
      }
    }
  }

  static let editorSize = NSSize(width: 460, height: 240)

  // Shows the item's text in an editor; the edited text is copied as a new item.
  // The original item is left as it was.
  static func edit(_ item: HistoryItem) {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("edit_title", comment: "")
    alert.addButton(withTitle: NSLocalizedString("edit_copy", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("collection_new_cancel", comment: ""))

    let scrollView = NSTextView.scrollableTextView()
    scrollView.frame = NSRect(origin: .zero, size: editorSize)
    scrollView.borderType = .bezelBorder
    guard let textView = scrollView.documentView as? NSTextView else { return }
    textView.string = item.previewableText
    textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    textView.isRichText = false
    textView.allowsUndo = true
    alert.accessoryView = scrollView
    alert.window.initialFirstResponder = textView

    guard alert.runModal() == .alertFirstButtonReturn, !textView.string.isEmpty else { return }
    Clipboard.shared.copyInMaccy(textView.string, expiresAt: item.expiresAt)
  }

  // Joins the items' text in selection order. The result expires as soon as the first secret in it.
  static func merged(_ items: [HistoryItem], separator: Separator) -> (text: String, expiresAt: Date?) {
    let text = items.map(\.previewableText).filter { !$0.isEmpty }.joined(separator: separator.rawValue)
    let expiresAt = items.compactMap(\.expiresAt).min()
    return (text, expiresAt)
  }

  static func merge(_ items: [HistoryItem], separator: Separator) {
    let result = merged(items, separator: separator)
    guard !result.text.isEmpty else {
      NSSound.beep()
      return
    }
    Clipboard.shared.copyInMaccy(result.text, expiresAt: result.expiresAt)
  }
}
