import AppKit
import SwiftHEXColors

// What a history item holds, used for card layout and the docked panel's filters.
enum ContentKind: Equatable {
  case text
  case richText
  case emoji
  case code
  case link(URL)
  case color(NSColor)
  case image
  case gif
  case pdf
  case file
  case files(Int)
  case secret

  static let hexColorLength = 7        // #RRGGBB
  static let shortHexColorLength = 4   // #RGB

  static func of(_ item: HistoryItem) -> ContentKind {
    // A secret stays a secret after it is pinned or when secrets are kept, so it is never
    // shown in full or fetched as a link.
    if item.expiresAt != nil { return .secret }
    let types = Set(item.contents.map(\.type))
    if item.imageData != nil {
      // For images the title holds the text recognized in them; a key in a screenshot is still a key.
      if SecretDetector.detect(in: item.title) != nil { return .secret }
      return types.contains(NSPasteboard.PasteboardType.gif.rawValue) ? .gif : .image
    }
    let files = item.fileURLs
    if types.contains(NSPasteboard.PasteboardType.pdf.rawValue)
        || (files.count == 1 && files[0].pathExtension.lowercased() == "pdf") {
      return .pdf
    }
    if files.count > 1 { return .files(files.count) }
    if files.count == 1 { return .file }

    let text = item.previewableText
    if SecretDetector.detect(in: text) != nil { return .secret }
    if let url = linkURL(in: text) { return .link(url) }
    if let color = color(in: text) { return .color(color) }
    if isEmoji(text) { return .emoji }
    if looksLikeCode(text) { return .code }
    let richTypes = [NSPasteboard.PasteboardType.rtf.rawValue, NSPasteboard.PasteboardType.html.rawValue]
    if richTypes.contains(where: types.contains) {
      return .richText
    }
    return .text
  }

  var title: String {
    switch self {
    case .text, .emoji: return NSLocalizedString("kind_text", comment: "")
    case .richText: return NSLocalizedString("kind_rich_text", comment: "")
    case .gif: return NSLocalizedString("kind_gif", comment: "")
    case .pdf: return NSLocalizedString("kind_pdf", comment: "")
    case .files(let count): return String(format: NSLocalizedString("kind_files", comment: ""), count)
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

  static let maxEmojiCount = 3

  // One to three emoji and nothing else, shown large like PastePal does.
  static func isEmoji(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= maxEmojiCount else { return false }
    return trimmed.allSatisfy { character in
      guard let scalar = character.unicodeScalars.first else { return false }
      return scalar.properties.isEmojiPresentation || (scalar.properties.isEmoji && character.unicodeScalars.count > 1)
    }
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
    case .text: return [.text, .richText, .emoji].contains(item.contentKind)
    case .code: return item.contentKind == .code
    case .images: return [.image, .gif].contains(item.contentKind)
    case .files:
      switch item.contentKind {
      case .file, .pdf, .files: return true
      default: return false
      }
    case .links:
      if case .link = item.contentKind { return true }
      return false
    case .colors:
      if case .color = item.contentKind { return true }
      return false
    }
  }
}
