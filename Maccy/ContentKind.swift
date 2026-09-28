import AppKit
import SwiftHEXColors

// What a history item holds, used for card layout and the docked panel's filters.
enum ContentKind: Equatable {
  case text
  case code
  case link(URL)
  case color(NSColor)
  case image
  case file
  case secret

  static let hexColorLength = 7        // #RRGGBB
  static let shortHexColorLength = 4   // #RGB

  static func of(_ item: HistoryItem) -> ContentKind {
    if item.expiresAt != nil { return .secret }
    if item.imageData != nil { return .image }
    if !item.fileURLs.isEmpty { return .file }

    let text = item.previewableText
    if let url = linkURL(in: text) { return .link(url) }
    if let color = color(in: text) { return .color(color) }
    if looksLikeCode(text) { return .code }
    return .text
  }

  var title: String {
    switch self {
    case .text: return NSLocalizedString("kind_text", comment: "")
    case .code: return NSLocalizedString("kind_code", comment: "")
    case .link: return NSLocalizedString("kind_link", comment: "")
    case .color: return NSLocalizedString("kind_color", comment: "")
    case .image: return NSLocalizedString("kind_image", comment: "")
    case .file: return NSLocalizedString("kind_file", comment: "")
    case .secret: return NSLocalizedString("kind_secret", comment: "")
    }
  }

  // A single web address, with or without "https://" ("www.example.com" counts too).
  static func linkURL(in text: String) -> URL? {
    var candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidate.isEmpty, !candidate.contains(where: \.isWhitespace) else { return nil }
    if candidate.lowercased().hasPrefix("www.") {
      candidate = "https://" + candidate
    }
    guard let url = URL(string: candidate), let scheme = url.scheme?.lowercased(),
          ["http", "https"].contains(scheme), let host = url.host, host.contains(".") else { return nil }
    return url
  }

  static func color(in text: String) -> NSColor? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("#"), [hexColorLength, shortHexColorLength].contains(trimmed.count) else { return nil }
    return NSColor(hexString: trimmed)
  }

  // Conservative: several lines and at least two code signals. Only a display hint, never a guarantee.
  static func looksLikeCode(_ text: String) -> Bool {
    let lines = text.split(separator: "\n")
    guard lines.count >= 2 else { return false }

    let signals = [
      text.contains("{") && text.contains("}"),
      text.contains(";\n") || text.hasSuffix(";"),
      text.range(of: #"(?m)^\s*(func|let|var|const|final|class|struct|import|def|return|if|for|public|private)\b"#,
                 options: .regularExpression) != nil,
      text.range(of: #"(=>|->|==|!=|\)\s*\{|\w+\(.*\))"#, options: .regularExpression) != nil,
      lines.filter { $0.hasPrefix("  ") || $0.hasPrefix("\t") }.count >= 1
    ]
    return signals.filter { $0 }.count >= 2
  }
}

// The filter chips in the docked panel.
enum ContentFilter: String, CaseIterable, Identifiable {
  case all
  case pinned
  case text
  case links
  case images
  case colors
  case files
  case code

  var id: Self { self }

  var title: String { NSLocalizedString("filter_\(rawValue)", comment: "") }

  func matches(_ item: HistoryItemDecorator) -> Bool {
    switch self {
    case .all: return true
    case .pinned: return item.isPinned
    case .text: return ContentKind.of(item.item) == .text
    case .code: return ContentKind.of(item.item) == .code
    case .images: return ContentKind.of(item.item) == .image
    case .files: return ContentKind.of(item.item) == .file
    case .links:
      if case .link = ContentKind.of(item.item) { return true }
      return false
    case .colors:
      if case .color = ContentKind.of(item.item) { return true }
      return false
    }
  }
}
