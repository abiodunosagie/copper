import Foundation

// Flutter helpers: a Dart model class from JSON, and hex colors to and from Flutter's Color.
extension TextTransform {
  static let flutterTransforms: [TextTransform] = [
    TextTransform(id: "dartModel", name: "Dart model from JSON", category: .flutter) {
      DartModelGenerator.generate($0)
    },
    TextTransform(id: "hexToFlutterColor", name: "Hex to Flutter Color", category: .flutter) { text in
      var hex = text.trimmingCharacters(in: .whitespacesAndNewlines)
      if hex.hasPrefix("#") { hex.removeFirst() }
      if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
      if hex.count == 6 { hex = "FF" + hex }
      guard hex.count == 8, UInt32(hex, radix: 16) != nil else { return nil }
      return "Color(0x\(hex.uppercased()))"
    },
    TextTransform(id: "flutterColorToHex", name: "Flutter Color to hex", category: .flutter) { text in
      guard let match = text.range(of: #"0x([0-9A-Fa-f]{8})"#, options: .regularExpression) else { return nil }
      let argb = text[match].dropFirst(2).uppercased()
      let alpha = argb.prefix(2)
      let rgb = argb.dropFirst(2)
      return alpha == "FF" ? "#" + rgb : "#" + rgb + alpha
    }
  ]
}

// Builds Dart classes with typed final fields, a const constructor, fromJson and toJson.
// Nested objects become their own classes; lists of objects use a class named after the key.
enum DartModelGenerator {
  static let rootName = "Model"

  static func generate(_ json: String) -> String? {
    guard let data = json.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) else { return nil }

    let root: [String: Any]
    if let dictionary = object as? [String: Any] {
      root = dictionary
    } else if let array = object as? [Any], let first = array.first as? [String: Any] {
      root = first
    } else {
      return nil
    }

    var classes: [String] = []
    var usedNames: Set<String> = []
    buildClass(named: rootName, from: root, into: &classes, usedNames: &usedNames)
    return classes.joined(separator: "\n\n")
  }

  private static func buildClass(
    named name: String,
    from object: [String: Any],
    into classes: inout [String],
    usedNames: inout Set<String>
  ) {
    let className = uniqueName(name, usedNames: &usedNames)
    var fields: [(key: String, name: String, type: String, fromJson: String, toJson: String)] = []

    for key in object.keys.sorted() {
      let field = camelCase(key)
      let value = object[key] as Any
      let typeName = pascalCase(key)
      switch value {
      case let nested as [String: Any]:
        buildClass(named: typeName, from: nested, into: &classes, usedNames: &usedNames)
        let nestedName = classes.last.flatMap(declaredName) ?? typeName
        fields.append((key, field, "\(nestedName)?",
                       "json['\(key)'] == null ? null : \(nestedName).fromJson(json['\(key)'] as Map<String, dynamic>)",
                       "\(field)?.toJson()"))
      case let array as [Any]:
        if let first = array.first as? [String: Any] {
          buildClass(named: singular(typeName), from: first, into: &classes, usedNames: &usedNames)
          let itemName = classes.last.flatMap(declaredName) ?? singular(typeName)
          let fromJson = "(json['\(key)'] as List<dynamic>?)"
            + "?.map((e) => \(itemName).fromJson(e as Map<String, dynamic>)).toList()"
          fields.append((key, field, "List<\(itemName)>?", fromJson, "\(field)?.map((e) => e.toJson()).toList()"))
        } else {
          let itemType = array.first.map(scalarType) ?? "dynamic"
          fields.append((key, field, "List<\(itemType)>?",
                         "(json['\(key)'] as List<dynamic>?)?.cast<\(itemType)>()", field))
        }
      default:
        let type = scalarType(value)
        let cast = type == "double" ? "(json['\(key)'] as num?)?.toDouble()" : "json['\(key)'] as \(type)?"
        fields.append((key, field, type == "dynamic" ? "dynamic" : "\(type)?", cast, field))
      }
    }

    var lines = ["class \(className) {"]
    lines += fields.map { "  final \($0.type) \($0.name);" }
    lines.append("")
    lines.append(fields.isEmpty ? "  const \(className)();" : "  const \(className)({")
    if !fields.isEmpty {
      lines += fields.map { "    this.\($0.name)," }
      lines.append("  });")
    }
    lines.append("")
    lines.append("  factory \(className).fromJson(Map<String, dynamic> json) => \(className)(")
    lines += fields.map { "        \($0.name): \($0.fromJson)," }
    lines.append("      );")
    lines.append("")
    lines.append("  Map<String, dynamic> toJson() => {")
    lines += fields.map { "        '\($0.key)': \($0.toJson)," }
    lines.append("      };")
    lines.append("}")
    classes.append(lines.joined(separator: "\n"))
  }

  static func scalarType(_ value: Any) -> String {
    switch value {
    case let number as NSNumber:
      if CFGetTypeID(number) == CFBooleanGetTypeID() { return "bool" }
      return CFNumberIsFloatType(number) ? "double" : "int"
    case is String: return "String"
    default: return "dynamic"
    }
  }

  static func camelCase(_ key: String) -> String {
    let words = TextTransform.words(key)
    guard let first = words.first else { return "value" }
    let name = first + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    return name.first?.isNumber == true ? "field" + name : name
  }

  static func pascalCase(_ key: String) -> String {
    let name = camelCase(key)
    return name.prefix(1).uppercased() + name.dropFirst()
  }

  static func singular(_ name: String) -> String {
    if name.hasSuffix("ies") { return String(name.dropLast(3)) + "y" }
    if name.hasSuffix("s") && !name.hasSuffix("ss") { return String(name.dropLast()) }
    return name + "Item"
  }

  private static func uniqueName(_ name: String, usedNames: inout Set<String>) -> String {
    var candidate = name
    var index = 2
    while usedNames.contains(candidate) {
      candidate = "\(name)\(index)"
      index += 1
    }
    usedNames.insert(candidate)
    return candidate
  }

  private static func declaredName(_ declaration: String) -> String? {
    declaration.split(separator: "\n").first?
      .replacingOccurrences(of: "class ", with: "")
      .replacingOccurrences(of: " {", with: "")
  }
}
