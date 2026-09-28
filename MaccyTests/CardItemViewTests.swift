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
    XCTAssertEqual(CardItemView.masked(String(repeating: "x", count: 100)).count, 20)
  }

  func testLinkDetection() {
    XCTAssertEqual(CardItemView.linkURL(in: "https://example.com/a")?.host, "example.com")
    XCTAssertEqual(CardItemView.linkURL(in: " www.parishandcompany.com ")?.host, "www.parishandcompany.com")
    XCTAssertNil(CardItemView.linkURL(in: "see https://example.com"))
    XCTAssertNil(CardItemView.linkURL(in: "ftp://example.com"))
    XCTAssertNil(CardItemView.linkURL(in: "localhost"))
    XCTAssertNil(CardItemView.linkURL(in: ""))
  }
}
