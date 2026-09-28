import Foundation

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
