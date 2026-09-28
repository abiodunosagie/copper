import Foundation

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
      let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
      guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: options) else {
        return nil
      }
      return String(data: data, encoding: .utf8)
    }
  ]
}
