import XCTest
@testable import Maccy

class CardItemViewTests: XCTestCase {
  func testAge() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    XCTAssertEqual(CardItemView.age(of: now.addingTimeInterval(-30), until: now), "now")
    XCTAssertEqual(CardItemView.age(of: now.addingTimeInterval(-5 * 60), until: now), "5m")
    XCTAssertEqual(CardItemView.age(of: now.addingTimeInterval(-3 * 3_600), until: now), "3h")
    XCTAssertEqual(CardItemView.age(of: now.addingTimeInterval(-2 * 86_400), until: now), "2d")
    XCTAssertEqual(CardItemView.age(of: now.addingTimeInterval(60), until: now), "now", "future dates read as now")
  }

  func testRemainingNeverShowsZero() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    XCTAssertEqual(CardItemView.remaining(until: now.addingTimeInterval(10), now: now), "1m")
    XCTAssertEqual(CardItemView.remaining(until: now.addingTimeInterval(-10), now: now), "1m")
    XCTAssertEqual(CardItemView.remaining(until: now.addingTimeInterval(45 * 60), now: now), "45m")
    XCTAssertEqual(CardItemView.remaining(until: now.addingTimeInterval(2 * 3_600), now: now), "2h")
  }

  func testMaskedShowsOnlyThePrefix() {
    XCTAssertEqual(CardItemView.masked("abcdefghijklmnop"), "abcdefgh••••••••")
    XCTAssertEqual(CardItemView.masked("short"), "short")
    let longSecret = String(repeating: "x", count: 100)
    XCTAssertEqual(CardItemView.masked(longSecret).count, CardItemView.secretPreviewLength + CardItemView.maxMaskedDots)
  }

  func testLinkDetection() {
    XCTAssertEqual(ContentKind.linkURL(in: "https://example.com/a")?.host, "example.com")
    XCTAssertEqual(ContentKind.linkURL(in: " www.parishandcompany.com ")?.host, "www.parishandcompany.com")
    XCTAssertNil(ContentKind.linkURL(in: "see https://example.com"))
    XCTAssertNil(ContentKind.linkURL(in: "ftp://example.com"))
    XCTAssertNil(ContentKind.linkURL(in: "localhost"))
    XCTAssertNil(ContentKind.linkURL(in: ""))
  }

  func testCodeDetectionIsConservative() {
    XCTAssertTrue(ContentKind.looksLikeCode("final user = ref.watch(\n  authProvider,\n);"))
    XCTAssertTrue(ContentKind.looksLikeCode("func a() {\n  return 1\n}"))
    XCTAssertFalse(ContentKind.looksLikeCode("Can we move the call to Wednesday?\nI will send the link."))
    XCTAssertFalse(ContentKind.looksLikeCode("single line { }"))
  }

  func testColorDetection() {
    XCTAssertNotNil(ContentKind.color(in: " #5B4DC7 "))
    XCTAssertNotNil(ContentKind.color(in: "#fa0"))
    XCTAssertNil(ContentKind.color(in: "#5B4DC"))
    XCTAssertNil(ContentKind.color(in: "5B4DC7"))
  }
}
