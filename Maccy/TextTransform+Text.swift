import Foundation

extension TextTransform {
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
