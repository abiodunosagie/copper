import Foundation

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
      // Stable: lines of equal length keep their order.
      mapLines($0) { lines in
        lines.enumerated()
          .sorted { ($0.element.count, $0.offset) < ($1.element.count, $1.offset) }
          .map(\.element)
      }
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
