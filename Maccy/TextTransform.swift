import Foundation

// A named text-to-text conversion shown in the item context menu.
// `apply` returns nil when the input is not valid for the transform (for example bad Base64).
struct TextTransform: Identifiable {
  enum Category: String, CaseIterable, Identifiable {
    case textCase = "Case"
    case whitespace = "Whitespace"
    case lines = "Lines"
    case encoding = "Encode and decode"
    case json = "JSON"
    case hashing = "Hash"
    case text = "Text"
    case developer = "Developer"
    case flutter = "Flutter"

    var id: Self { self }

    var title: String {
      NSLocalizedString("Category.\(rawValue)", tableName: "Transforms", value: rawValue, comment: "")
    }
  }

  let id: String
  let name: String
  let category: Category
  let apply: (String) -> String?

  var title: String { NSLocalizedString(id, tableName: "Transforms", value: name, comment: "") }

  static func transforms(in category: Category) -> [TextTransform] {
    all.filter { $0.category == category }
  }

  static func named(_ id: String) -> TextTransform? {
    all.first { $0.id == id }
  }

  static let all: [TextTransform] =
    caseTransforms + whitespaceTransforms + lineTransforms + encodingTransforms +
    jsonTransforms + hashTransforms + textTransforms + developerTransforms + flutterTransforms
}

// MARK: - Shared helpers

extension TextTransform {
  static func matches(_ pattern: String, in text: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
      .compactMap { Range($0.range, in: text).map { String(text[$0]) } }
  }

  static func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
    digest.map { String(format: "%02x", $0) }.joined()
  }
}
