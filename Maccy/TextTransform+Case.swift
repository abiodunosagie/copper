import Foundation

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
    TextTransform(id: "pascalCase", name: "PascalCase", category: .textCase) {
      words($0).map(capitalizedWord).joined()
    },
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
