import AppKit
import CryptoKit

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

    var id: Self { self }
  }

  let id: String
  let name: String
  let category: Category
  let apply: (String) -> String?

  static func transforms(in category: Category) -> [TextTransform] {
    all.filter { $0.category == category }
  }

  static func named(_ id: String) -> TextTransform? {
    all.first { $0.id == id }
  }

  static let all: [TextTransform] =
    caseTransforms + whitespaceTransforms + lineTransforms + encodingTransforms +
    jsonTransforms + hashTransforms + textTransforms + developerTransforms
}

// MARK: - Case

extension TextTransform {
  // Splits "helloWorld", "hello_world", "Hello-World" and "hello world" into ["hello", "world"].
  static func words(_ text: String) -> [String] {
    let spaced = text
      .replacingOccurrences(of: "([a-z0-9])([A-Z])", with: "$1 $2", options: .regularExpression)
      .replacingOccurrences(of: "([A-Z]+)([A-Z][a-z])", with: "$1 $2", options: .regularExpression)
    return spaced
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
      .map { $0.lowercased() }
  }

  private static func capitalizedWord(_ word: String) -> String {
    word.prefix(1).uppercased() + word.dropFirst()
  }

  static let caseTransforms: [TextTransform] = [
    TextTransform(id: "uppercase", name: "UPPERCASE", category: .textCase) { $0.uppercased() },
    TextTransform(id: "lowercase", name: "lowercase", category: .textCase) { $0.lowercased() },
    TextTransform(id: "titleCase", name: "Title Case", category: .textCase) { $0.capitalized },
    TextTransform(id: "sentenceCase", name: "Sentence case", category: .textCase) { text in
      var result = ""
      var capitalizeNext = true
      for character in text.lowercased() {
        if capitalizeNext, character.isLetter {
          result += character.uppercased()
          capitalizeNext = false
        } else {
          result.append(character)
        }
        if ".!?\n".contains(character) { capitalizeNext = true }
      }
      return result
    },
    TextTransform(id: "camelCase", name: "camelCase", category: .textCase) { text in
      let parts = words(text)
      guard let first = parts.first else { return "" }
      return first + parts.dropFirst().map(capitalizedWord).joined()
    },
    TextTransform(id: "pascalCase", name: "PascalCase", category: .textCase) { words($0).map(capitalizedWord).joined() },
    TextTransform(id: "snakeCase", name: "snake_case", category: .textCase) { words($0).joined(separator: "_") },
    TextTransform(id: "screamingSnakeCase", name: "SCREAMING_SNAKE_CASE", category: .textCase) {
      words($0).joined(separator: "_").uppercased()
    },
    TextTransform(id: "kebabCase", name: "kebab-case", category: .textCase) { words($0).joined(separator: "-") },
    TextTransform(id: "trainCase", name: "Train-Case", category: .textCase) {
      words($0).map(capitalizedWord).joined(separator: "-")
    },
    TextTransform(id: "dotCase", name: "dot.case", category: .textCase) { words($0).joined(separator: ".") },
    TextTransform(id: "swapCase", name: "sWAP cASE", category: .textCase) { text in
      String(text.map { $0.isUppercase ? Character($0.lowercased()) : Character($0.uppercased()) })
    }
  ]
}

// MARK: - Whitespace

extension TextTransform {
  static func lines(_ text: String) -> [String] {
    text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
  }

  static let whitespaceTransforms: [TextTransform] = [
    TextTransform(id: "trim", name: "Trim", category: .whitespace) {
      $0.trimmingCharacters(in: .whitespacesAndNewlines)
    },
    TextTransform(id: "trimLines", name: "Trim each line", category: .whitespace) {
      lines($0).map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
    },
    TextTransform(id: "collapseSpaces", name: "Collapse repeated spaces", category: .whitespace) {
      $0.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
    },
    TextTransform(id: "removeWhitespace", name: "Remove all whitespace", category: .whitespace) {
      $0.components(separatedBy: .whitespacesAndNewlines).joined()
    },
    TextTransform(id: "joinLines", name: "Join lines with spaces", category: .whitespace) {
      lines($0).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
    },
    TextTransform(id: "removeEmptyLines", name: "Remove empty lines", category: .whitespace) {
      lines($0).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: "\n")
    },
    TextTransform(id: "tabsToSpaces", name: "Tabs to spaces", category: .whitespace) {
      $0.replacingOccurrences(of: "\t", with: "    ")
    },
    TextTransform(id: "spacesToTabs", name: "Spaces to tabs", category: .whitespace) {
      $0.replacingOccurrences(of: "    ", with: "\t")
    },
    TextTransform(id: "normalizeLineEndings", name: "Normalize line endings", category: .whitespace) {
      $0.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    },
    TextTransform(id: "dedent", name: "Remove common indentation", category: .whitespace) { text in
      let all = lines(text)
      let indents = all
        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        .map { $0.prefix { $0 == " " || $0 == "\t" }.count }
      let common = indents.min() ?? 0
      return all.map { String($0.dropFirst(min(common, $0.count))) }.joined(separator: "\n")
    }
  ]
}

// MARK: - Lines

extension TextTransform {
  private static func mapLines(_ text: String, _ transform: ([String]) -> [String]) -> String {
    transform(lines(text)).joined(separator: "\n")
  }

  private static func uniqueInOrder(_ items: [String]) -> [String] {
    var seen = Set<String>()
    return items.filter { seen.insert($0).inserted }
  }

  static let lineTransforms: [TextTransform] = [
    TextTransform(id: "sortAscending", name: "Sort A to Z", category: .lines) { mapLines($0) { $0.sorted() } },
    TextTransform(id: "sortDescending", name: "Sort Z to A", category: .lines) {
      mapLines($0) { $0.sorted(by: >) }
    },
    TextTransform(id: "sortCaseInsensitive", name: "Sort ignoring case", category: .lines) {
      mapLines($0) { $0.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending } }
    },
    TextTransform(id: "sortNumeric", name: "Sort numerically", category: .lines) {
      mapLines($0) { $0.sorted { $0.localizedStandardCompare($1) == .orderedAscending } }
    },
    TextTransform(id: "sortByLength", name: "Sort by length", category: .lines) {
      mapLines($0) { $0.enumerated().sorted { ($0.element.count, $0.offset) < ($1.element.count, $1.offset) }.map(\.element) }
    },
    TextTransform(id: "reverseLines", name: "Reverse line order", category: .lines) {
      mapLines($0) { $0.reversed() }
    },
    TextTransform(id: "shuffleLines", name: "Shuffle lines", category: .lines) { mapLines($0) { $0.shuffled() } },
    TextTransform(id: "uniqueLines", name: "Remove duplicate lines", category: .lines) {
      mapLines($0, uniqueInOrder)
    },
    TextTransform(id: "numberLines", name: "Number lines", category: .lines) {
      mapLines($0) { $0.enumerated().map { "\($0.offset + 1). \($0.element)" } }
    },
    TextTransform(id: "bulletLines", name: "Bullet lines", category: .lines) {
      mapLines($0) { $0.map { $0.isEmpty ? $0 : "- \($0)" } }
    },
    TextTransform(id: "linesToCommaList", name: "Lines to comma list", category: .lines) {
      lines($0).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: ", ")
    },
    TextTransform(id: "commaListToLines", name: "Comma list to lines", category: .lines) {
      $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }.joined(separator: "\n")
    }
  ]
}

// MARK: - Encoding

extension TextTransform {
  private static func base64URL(_ base64: String) -> String {
    base64.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  private static func decodeBase64(_ text: String, urlSafe: Bool) -> String? {
    var base64 = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if urlSafe {
      base64 = base64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    }
    base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
    guard let data = Data(base64Encoded: base64) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static let htmlEntities: [(String, String)] = [
    ("&", "&amp;"), ("<", "&lt;"), (">", "&gt;"), ("\"", "&quot;"), ("'", "&#39;")
  ]

  private static func rot13(_ text: String) -> String {
    String(text.unicodeScalars.map { scalar -> Character in
      switch scalar.value {
      case 65...90: return Character(UnicodeScalar((scalar.value - 65 + 13) % 26 + 65)!)
      case 97...122: return Character(UnicodeScalar((scalar.value - 97 + 13) % 26 + 97)!)
      default: return Character(scalar)
      }
    })
  }

  static let encodingTransforms: [TextTransform] = [
    TextTransform(id: "base64Encode", name: "Base64 encode", category: .encoding) {
      Data($0.utf8).base64EncodedString()
    },
    TextTransform(id: "base64Decode", name: "Base64 decode", category: .encoding) {
      decodeBase64($0, urlSafe: false)
    },
    TextTransform(id: "base64URLEncode", name: "Base64 URL encode", category: .encoding) {
      base64URL(Data($0.utf8).base64EncodedString())
    },
    TextTransform(id: "base64URLDecode", name: "Base64 URL decode", category: .encoding) {
      decodeBase64($0, urlSafe: true)
    },
    TextTransform(id: "urlEncode", name: "URL encode", category: .encoding) {
      var allowed = CharacterSet.alphanumerics
      allowed.insert(charactersIn: "-._~")
      return $0.addingPercentEncoding(withAllowedCharacters: allowed)
    },
    TextTransform(id: "urlDecode", name: "URL decode", category: .encoding) {
      $0.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
    },
    TextTransform(id: "htmlEncode", name: "HTML entities encode", category: .encoding) { text in
      htmlEntities.reduce(text) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
    },
    TextTransform(id: "htmlDecode", name: "HTML entities decode", category: .encoding) { text in
      guard let data = text.data(using: .utf8),
            let decoded = try? NSAttributedString(
              data: data,
              options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
              documentAttributes: nil
            ) else { return nil }
      return decoded.string
    },
    TextTransform(id: "hexEncode", name: "Hex encode", category: .encoding) {
      $0.utf8.map { String(format: "%02x", $0) }.joined()
    },
    TextTransform(id: "hexDecode", name: "Hex decode", category: .encoding) { text in
      let hex = text.filter { !$0.isWhitespace }
      guard hex.count.isMultiple(of: 2) else { return nil }
      var bytes = [UInt8]()
      var index = hex.startIndex
      while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
        bytes.append(byte)
        index = next
      }
      return String(bytes: bytes, encoding: .utf8)
    },
    TextTransform(id: "unicodeEscape", name: "Unicode escape", category: .encoding) { text in
      text.unicodeScalars.map { $0.isASCII ? String($0) : String(format: "\\u{%04X}", $0.value) }.joined()
    },
    TextTransform(id: "unicodeUnescape", name: "Unicode unescape", category: .encoding) { text in
      let pattern = #"\\u\{?([0-9A-Fa-f]{4,6})\}?"#
      guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
      var result = text
      for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
        guard let whole = Range(match.range, in: result),
              let hexRange = Range(match.range(at: 1), in: text),
              let value = UInt32(text[hexRange], radix: 16),
              let scalar = UnicodeScalar(value) else { continue }
        result.replaceSubrange(whole, with: String(Character(scalar)))
      }
      return result
    },
    TextTransform(id: "rot13", name: "ROT13", category: .encoding) { rot13($0) },
    TextTransform(id: "jsonStringEscape", name: "JSON string escape", category: .encoding) { text in
      guard let data = try? JSONSerialization.data(withJSONObject: [text], options: [.withoutEscapingSlashes]),
            let encoded = String(data: data, encoding: .utf8) else { return nil }
      return String(encoded.dropFirst(2).dropLast(2))
    },
    TextTransform(id: "jsonStringUnescape", name: "JSON string unescape", category: .encoding) { text in
      let quoted = text.hasPrefix("\"") ? text : "\"\(text)\""
      guard let data = "[\(quoted)]".data(using: .utf8),
            let array = try? JSONSerialization.jsonObject(with: data) as? [String] else { return nil }
      return array.first
    }
  ]
}

// MARK: - JSON

extension TextTransform {
  private static func reformatJSON(_ text: String, _ options: JSONSerialization.WritingOptions) -> String? {
    guard let data = text.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
          let output = try? JSONSerialization.data(withJSONObject: object, options: options.union(.fragmentsAllowed)) else {
      return nil
    }
    return String(data: output, encoding: .utf8)
  }

  static let jsonTransforms: [TextTransform] = [
    TextTransform(id: "jsonPretty", name: "Pretty print", category: .json) {
      reformatJSON($0, [.prettyPrinted, .withoutEscapingSlashes])
    },
    TextTransform(id: "jsonMinify", name: "Minify", category: .json) {
      reformatJSON($0, [.withoutEscapingSlashes])
    },
    TextTransform(id: "jsonSortKeys", name: "Pretty print with sorted keys", category: .json) {
      reformatJSON($0, [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }
  ]
}

// MARK: - Hash

extension TextTransform {
  private static func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
    digest.map { String(format: "%02x", $0) }.joined()
  }

  static let hashTransforms: [TextTransform] = [
    TextTransform(id: "md5", name: "MD5", category: .hashing) { hex(Insecure.MD5.hash(data: Data($0.utf8))) },
    TextTransform(id: "sha1", name: "SHA-1", category: .hashing) { hex(Insecure.SHA1.hash(data: Data($0.utf8))) },
    TextTransform(id: "sha256", name: "SHA-256", category: .hashing) { hex(SHA256.hash(data: Data($0.utf8))) },
    TextTransform(id: "sha384", name: "SHA-384", category: .hashing) { hex(SHA384.hash(data: Data($0.utf8))) },
    TextTransform(id: "sha512", name: "SHA-512", category: .hashing) { hex(SHA512.hash(data: Data($0.utf8))) }
  ]
}

// MARK: - Text

extension TextTransform {
  private static func matches(_ pattern: String, in text: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
      .compactMap { Range($0.range, in: text).map { String(text[$0]) } }
  }

  static let textTransforms: [TextTransform] = [
    TextTransform(id: "reverseText", name: "Reverse text", category: .text) { String($0.reversed()) },
    TextTransform(id: "removeDiacritics", name: "Remove accents", category: .text) {
      $0.folding(options: .diacriticInsensitive, locale: .current)
    },
    TextTransform(id: "slugify", name: "Slugify", category: .text) { text in
      words(text.folding(options: .diacriticInsensitive, locale: .current)).joined(separator: "-")
    },
    TextTransform(id: "stripHTML", name: "Strip HTML tags", category: .text) {
      $0.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    },
    TextTransform(id: "removePunctuation", name: "Remove punctuation", category: .text) {
      $0.components(separatedBy: .punctuationCharacters).joined()
    },
    TextTransform(id: "removeDigits", name: "Remove digits", category: .text) {
      $0.components(separatedBy: .decimalDigits).joined()
    },
    TextTransform(id: "keepDigits", name: "Keep only digits", category: .text) {
      String($0.filter(\.isNumber))
    },
    TextTransform(id: "extractURLs", name: "Extract links", category: .text) {
      matches(#"https?://[^\s<>"')\]]+"#, in: $0).joined(separator: "\n")
    },
    TextTransform(id: "extractEmails", name: "Extract email addresses", category: .text) {
      matches(#"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, in: $0).joined(separator: "\n")
    },
    TextTransform(id: "extractNumbers", name: "Extract numbers", category: .text) {
      matches(#"-?\d+(?:[.,]\d+)?"#, in: $0).joined(separator: "\n")
    },
    TextTransform(id: "countStats", name: "Count words, characters and lines", category: .text) { text in
      let wordCount = text.split { $0.isWhitespace || $0.isNewline }.count
      return "\(wordCount) words, \(text.count) characters, \(lines(text).count) lines"
    },
    TextTransform(id: "straightQuotes", name: "Smart quotes to straight", category: .text) {
      $0.replacingOccurrences(of: "[\u{201C}\u{201D}\u{201E}]", with: "\"", options: .regularExpression)
        .replacingOccurrences(of: "[\u{2018}\u{2019}\u{201A}]", with: "'", options: .regularExpression)
    },
    TextTransform(id: "wrapQuotes", name: "Wrap in quotes", category: .text) { "\"\($0)\"" },
    TextTransform(id: "wrapCodeBlock", name: "Wrap in code block", category: .text) { "```\n\($0)\n```" },
    TextTransform(id: "markdownToPlain", name: "Markdown to plain text", category: .text) { text in
      text
        .replacingOccurrences(of: #"!?\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        .replacingOccurrences(of: #"(?m)^\s{0,3}#{1,6}\s*"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"(\*\*|__|\*|_|~~|`)"#, with: "", options: .regularExpression)
    }
  ]
}

// MARK: - Developer

extension TextTransform {
  private static let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  static let developerTransforms: [TextTransform] = [
    TextTransform(id: "timestampToDate", name: "Unix timestamp to date", category: .developer) { text in
      guard var seconds = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
      if seconds > 100_000_000_000 { seconds /= 1_000 } // milliseconds
      return isoFormatter.string(from: Date(timeIntervalSince1970: seconds))
    },
    TextTransform(id: "dateToTimestamp", name: "Date to Unix timestamp", category: .developer) { text in
      guard let date = isoFormatter.date(from: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
      return String(Int(date.timeIntervalSince1970))
    },
    TextTransform(id: "hexToRGB", name: "Hex color to RGB", category: .developer) { text in
      var hex = text.trimmingCharacters(in: .whitespacesAndNewlines)
      if hex.hasPrefix("#") { hex.removeFirst() }
      if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
      guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
      return "rgb(\(value >> 16 & 0xFF), \(value >> 8 & 0xFF), \(value & 0xFF))"
    },
    TextTransform(id: "rgbToHex", name: "RGB to hex color", category: .developer) { text in
      let numbers = matches(#"\d{1,3}"#, in: text).compactMap(Int.init)
      guard numbers.count >= 3, numbers.prefix(3).allSatisfy({ (0...255).contains($0) }) else { return nil }
      return "#" + numbers.prefix(3).map { String(format: "%02X", $0) }.joined()
    },
    TextTransform(id: "escapeRegex", name: "Escape for regular expression", category: .developer) {
      NSRegularExpression.escapedPattern(for: $0)
    },
    TextTransform(id: "escapeShell", name: "Escape for shell", category: .developer) {
      "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'"
    },
    TextTransform(id: "queryToJSON", name: "Query string to JSON", category: .developer) { text in
      let query = text.split(separator: "?", maxSplits: 1).last.map(String.init) ?? text
      guard let items = URLComponents(string: "?" + query)?.queryItems, !items.isEmpty else { return nil }
      var dictionary = [String: String]()
      items.forEach { dictionary[$0.name] = $0.value ?? "" }
      guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys]) else {
        return nil
      }
      return String(data: data, encoding: .utf8)
    }
  ]
}
