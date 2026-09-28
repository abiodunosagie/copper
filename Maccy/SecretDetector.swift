import Defaults
import Foundation

enum SecretHandling: String, CaseIterable, Identifiable, CustomStringConvertible, Defaults.Serializable {
  case keep
  case skip
  case expire

  var id: Self { self }

  var description: String {
    switch self {
    case .keep:
      return NSLocalizedString("SecretHandlingKeep", tableName: "IgnoreSettings", comment: "")
    case .skip:
      return NSLocalizedString("SecretHandlingSkip", tableName: "IgnoreSettings", comment: "")
    case .expire:
      return NSLocalizedString("SecretHandlingExpire", tableName: "IgnoreSettings", comment: "")
    }
  }
}

// Recognizes high-confidence credentials (API keys, tokens, private keys) in copied text.
// Patterns are anchored on vendor prefixes to keep false positives rare.
enum SecretDetector {
  struct Pattern {
    let name: String
    let regex: NSRegularExpression
  }

  // Scanning is capped so a huge copy never stalls the clipboard check.
  static let maxScannedLength = 20_000

  static let patterns: [Pattern] = [
    ("Private key", #"-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY(?: BLOCK)?-----"#),
    ("AWS access key", #"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"#),
    ("GitHub token", #"\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{60,})\b"#),
    ("GitLab token", #"\bglpat-[A-Za-z0-9_-]{20,}\b"#),
    ("Anthropic key", #"\bsk-ant-[A-Za-z0-9_-]{32,}"#),
    ("OpenAI key", #"\bsk-(?:proj-|svcacct-|admin-)?[A-Za-z0-9_-]{32,}"#),
    ("Stripe or Paystack key", #"\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{20,}\b"#),
    ("Google API key", #"\bAIza[0-9A-Za-z_-]{35}\b"#),
    ("Slack token", #"\bxox[abposr]-[A-Za-z0-9-]{10,}\b"#),
    ("SendGrid key", #"\bSG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}\b"#),
    ("npm token", #"\bnpm_[A-Za-z0-9]{36}\b"#),
    ("Hugging Face token", #"\bhf_[A-Za-z0-9]{34,}\b"#),
    ("JSON Web Token", #"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"#)
  ].map { name, pattern in
    // Patterns are constants; a failure here is a programming error caught by the tests.
    // swiftlint:disable:next force_try
    Pattern(name: name, regex: try! NSRegularExpression(pattern: pattern))
  }

  // Returns the kind of the first secret found, or nil when the text looks safe.
  static func detect(in text: String) -> String? {
    let scanned = text.count > maxScannedLength ? String(text.prefix(maxScannedLength)) : text
    let range = NSRange(scanned.startIndex..., in: scanned)

    return patterns.first { $0.regex.firstMatch(in: scanned, range: range) != nil }?.name
  }
}
