import AppKit
import Defaults

// Saved text the owner reuses (a signature, bank details), with placeholders filled in on use.
struct Snippet: Codable, Hashable, Identifiable, Defaults.Serializable {
  var id = UUID()
  var name: String
  var body: String

  static let placeholders = ["{date}", "{time}", "{datetime}", "{clipboard}", "{uuid}"]

  // Fills the placeholders. `clipboard` is the current clipboard text.
  static func expand(_ body: String, now: Date = .now, clipboard: String?, uuid: UUID = UUID()) -> String {
    let date = now.formatted(.iso8601.year().month().day())
    let time = now.formatted(date: .omitted, time: .shortened)
    return body
      .replacingOccurrences(of: "{datetime}", with: "\(date) \(time)")
      .replacingOccurrences(of: "{date}", with: date)
      .replacingOccurrences(of: "{time}", with: time)
      .replacingOccurrences(of: "{clipboard}", with: clipboard ?? "")
      .replacingOccurrences(of: "{uuid}", with: uuid.uuidString)
  }

  // Copies the filled-in snippet and pastes it into the app in front.
  @MainActor
  func insert() {
    let text = Self.expand(body, clipboard: NSPasteboard.general.string(forType: .string))
    AppState.shared.popup.close()
    Clipboard.shared.copyInMaccy(text)
    Clipboard.shared.paste()
  }
}
