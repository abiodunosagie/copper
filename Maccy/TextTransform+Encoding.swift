import Foundation

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

  // Reverses htmlEncode plus numeric entities such as &#39; and &#x27;.
  static func decodeHTMLEntities(_ text: String) -> String {
    var result = text
    if let regex = try? NSRegularExpression(pattern: "&#(x?)([0-9A-Fa-f]+);") {
      for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
        guard let whole = Range(match.range, in: result),
              let marker = Range(match.range(at: 1), in: text),
              let digits = Range(match.range(at: 2), in: text),
              let value = UInt32(text[digits], radix: text[marker].isEmpty ? 10 : 16),
              let scalar = UnicodeScalar(value) else { continue }
        result.replaceSubrange(whole, with: String(Character(scalar)))
      }
    }
    // "&amp;" last, so "&amp;lt;" decodes to "&lt;" and not "<".
    for (character, entity) in htmlEntities.reversed() {
      result = result.replacingOccurrences(of: entity, with: character)
    }
    return result
  }

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
    TextTransform(id: "htmlDecode", name: "HTML entities decode", category: .encoding) { decodeHTMLEntities($0) },
    TextTransform(id: "hexEncode", name: "Hex encode", category: .encoding) {
      hex($0.utf8)
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
      // Braced escapes take 1 to 6 hex digits; bare escapes take exactly 4, so "\\u0041ab" is "A" + "ab".
      let pattern = #"\\u\{([0-9A-Fa-f]{1,6})\}|\\u([0-9A-Fa-f]{4})"#
      guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
      var result = text
      for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
        let hexGroup = match.range(at: 1).location != NSNotFound ? 1 : 2
        guard let whole = Range(match.range, in: result),
              let hexRange = Range(match.range(at: hexGroup), in: text),
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
