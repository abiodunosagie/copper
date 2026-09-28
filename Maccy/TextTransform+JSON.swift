import Foundation

extension TextTransform {
  private static func reformatJSON(_ text: String, _ options: JSONSerialization.WritingOptions) -> String? {
    guard let data = text.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
          let output = try? JSONSerialization.data(
            withJSONObject: object, options: options.union(.fragmentsAllowed)
          ) else {
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
