import XCTest
@testable import Maccy

class FooterTests: XCTestCase {
  func testClearAllNeedsItsFullChord() {
    let footer = Footer()
    XCTAssertFalse(footer.items[1].isVisible, "Clear shows first, not Clear all")

    XCTAssertTrue(footer.isClearAllChord([.command, .option, .shift]))
    XCTAssertFalse(footer.isClearAllChord([.shift]), "typing a capital letter must not arm Clear all")
    XCTAssertFalse(footer.isClearAllChord([.command, .shift]))
    XCTAssertFalse(footer.isClearAllChord([.option, .shift]))
    XCTAssertFalse(footer.isClearAllChord([.command, .option]))
    XCTAssertFalse(footer.isClearAllChord([]))
  }}
