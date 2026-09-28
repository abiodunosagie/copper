import XCTest
import Defaults
@testable import Maccy

// Fake secrets are assembled at runtime so no secret-shaped literal lives in the repository.
class SecretDetectorTests: XCTestCase {
  let clipboard = Clipboard.shared
  let pasteboard = NSPasteboard.general

  let savedSecretHandling = Defaults[.secretHandling]
  let savedSecretExpiryMinutes = Defaults[.secretExpiryMinutes]

  override func setUp() {
    super.setUp()
    Defaults[.ignoreEvents] = false
    Defaults[.ignoreAllAppsExceptListed] = false
  }

  override func tearDown() {
    super.tearDown()
    Defaults[.secretHandling] = savedSecretHandling
    Defaults[.secretExpiryMinutes] = savedSecretExpiryMinutes
    clipboard.clearHooks()
  }

  private func fake(_ parts: String...) -> String { parts.joined() }
  private func run(_ length: Int, _ character: Character = "a") -> String { String(repeating: character, count: length) }

  func testDetectsKnownSecretKinds() {
    let samples: [String: String] = [
      "Private key": fake("-----BEGIN ", "OPENSSH PRIVATE KEY-----\nabc"),
      "AWS access key": fake("AKIA", run(16, "Q")),
      "GitHub token": fake("gh", "p_", run(36)),
      "GitLab token": fake("glpat", "-", run(20)),
      "Anthropic key": fake("sk", "-ant-", run(40)),
      "OpenAI key": fake("sk", "-proj-", run(40)),
      "Stripe or Paystack key": fake("sk", "_live_", run(24)),
      "Google API key": fake("AI", "za", run(35)),
      "Slack token": fake("xo", "xb-", run(20, "1")),
      "SendGrid key": fake("SG", ".", run(22), ".", run(43)),
      "npm token": fake("np", "m_", run(36)),
      "Hugging Face token": fake("h", "f_", run(34)),
      "JSON Web Token": fake("ey", "J", run(12), ".ey", "J", run(12), ".", run(12))
    ]

    for (kind, sample) in samples {
      XCTAssertEqual(SecretDetector.detect(in: "token: \(sample) end"), kind, "failed for \(kind)")
    }
  }

  func testIgnoresOrdinaryText() {
    let texts = [
      "",
      "Meeting at 10am, bring the slides",
      "https://github.com/abiodunosagie",
      "sk-short",
      "AKIA123",
      "eyJhbGciOi only one part",
      "The quick brown fox jumps over the lazy dog"
    ]

    for text in texts {
      XCTAssertNil(SecretDetector.detect(in: text), "false positive for \(text)")
    }
  }

  func testOnlyScansTheCappedPrefix() {
    let padding = run(SecretDetector.maxScannedLength, " ")
    XCTAssertNil(SecretDetector.detect(in: padding + fake("gh", "p_", run(36))))
    XCTAssertNotNil(SecretDetector.detect(in: fake("gh", "p_", run(36)) + padding))
  }

  func testDecisionFollowsSettingsAndClampsExpiry() {
    let secret = fake("gh", "p_", run(36))
    let now = Date(timeIntervalSince1970: 1_000_000)

    Defaults[.secretHandling] = .keep
    XCTAssertEqual(SecretDetector.decision(for: secret, now: now), .save(expiresAt: nil))

    Defaults[.secretHandling] = .skip
    XCTAssertEqual(SecretDetector.decision(for: secret, now: now), .skip)
    XCTAssertEqual(SecretDetector.decision(for: "hello", now: now), .save(expiresAt: nil))
    XCTAssertEqual(SecretDetector.decision(for: nil, now: now), .save(expiresAt: nil))

    Defaults[.secretHandling] = .expire
    Defaults[.secretExpiryMinutes] = 60
    XCTAssertEqual(SecretDetector.decision(for: secret, now: now), .save(expiresAt: now.addingTimeInterval(3_600)))
    Defaults[.secretExpiryMinutes] = -5
    XCTAssertEqual(SecretDetector.decision(for: secret, now: now), .save(expiresAt: now.addingTimeInterval(60)))
    Defaults[.secretExpiryMinutes] = 99_999
    XCTAssertEqual(SecretDetector.decision(for: secret, now: now), .save(expiresAt: now.addingTimeInterval(86_400)))
  }

  func testDefaultKeepsSecretsForAnHour() {
    XCTAssertEqual(Defaults.Keys.secretHandling.defaultValue, .expire)
    XCTAssertEqual(Defaults.Keys.secretExpiryMinutes.defaultValue, 60)
  }

  func testLogDescriptionRedactsSecrets() {
    let item = HistoryItem()
    item.title = "plain title"
    XCTAssertEqual(item.logDescription, "plain title")
    item.expiresAt = .now
    XCTAssertFalse(item.logDescription.contains("plain title"))
  }

  func testSkipModeDoesNotSaveSecrets() {
    Defaults[.secretHandling] = .skip
    let hookExpectation = expectation(description: "Hook is not called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy { _ in hookExpectation.fulfill() }
    clipboard.start()

    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString(fake("gh", "p_", run(36)), forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testExpireModeSavesSecretsWithExpiry() {
    Defaults[.secretHandling] = .expire
    Defaults[.secretExpiryMinutes] = 3
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy { item in
      guard let expiresAt = item.expiresAt else {
        XCTFail("secret item has no expiry")
        return
      }
      XCTAssertEqual(expiresAt.timeIntervalSinceNow, 180, accuracy: 10)
      hookExpectation.fulfill()
    }
    clipboard.start()

    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString(fake("sk", "_test_", run(24)), forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testKeepModeSavesSecretsWithoutExpiry() {
    Defaults[.secretHandling] = .keep
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy { item in
      XCTAssertNil(item.expiresAt)
      hookExpectation.fulfill()
    }
    clipboard.start()

    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString(fake("gh", "p_", run(36)), forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testOrdinaryCopiesNeverExpire() {
    Defaults[.secretHandling] = .expire
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy { item in
      XCTAssertNil(item.expiresAt)
      hookExpectation.fulfill()
    }
    clipboard.start()

    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("hello copper", forType: .string)
    waitForExpectations(timeout: 2)
  }
}
