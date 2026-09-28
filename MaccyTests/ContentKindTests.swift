import XCTest
@testable import Maccy

class ContentKindTests: XCTestCase {
  private func item(_ text: String) -> HistoryItem {
    let item = HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: Data(text.utf8))
    ])
    item.title = text
    return item
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

  func testClassificationPrecedence() {
    XCTAssertEqual(ContentKind.of(item("hello there")), .text)
    XCTAssertEqual(ContentKind.of(item("func a() {\n  return 1\n}")), .code)
    if case .link = ContentKind.of(item("https://example.com")) {} else { XCTFail("expected a link") }
    if case .color = ContentKind.of(item("#5B4DC7")) {} else { XCTFail("expected a color") }

    // A secret wins over every other kind, even when it looks like a link.
    let secret = item("https://example.com")
    secret.expiresAt = .now
    XCTAssertEqual(ContentKind.of(secret), .secret)
  }

  func testFiltersMatchTheirKinds() {
    let text = HistoryItemDecorator(item("hello"))
    let link = HistoryItemDecorator(item("https://example.com"))
    let color = HistoryItemDecorator(item("#fa0"))

    XCTAssertTrue(ContentFilter.all.matches(text))
    XCTAssertTrue(ContentFilter.text.matches(text))
    XCTAssertFalse(ContentFilter.text.matches(link))
    XCTAssertTrue(ContentFilter.links.matches(link))
    XCTAssertTrue(ContentFilter.colors.matches(color))
    XCTAssertFalse(ContentFilter.pinned.matches(text))
    XCTAssertFalse(ContentFilter.images.matches(text))
  }

  func testEveryFooterItemHasADockIcon() {
    for item in Footer().items {
      XCTAssertNotNil(DockFooterView.icons[item.title], "no dock icon for \(item.title)")
    }
  }

  func testDragProvidesTextForTextItems() {
    let provider = item("drag me").dragItemProvider
    XCTAssertTrue(provider.canLoadObject(ofClass: NSString.self))
    XCTAssertFalse(provider.canLoadObject(ofClass: NSImage.self))
  }
}
