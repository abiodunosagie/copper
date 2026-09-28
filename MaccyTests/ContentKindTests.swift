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

  @MainActor
  func testLinkThumbnailsAreDownscaled() throws {
    let big = NSImage(size: NSSize(width: 2_000, height: 1_000))
    big.lockFocus()
    NSColor.orange.setFill()
    NSRect(x: 0, y: 0, width: 2_000, height: 1_000).fill()
    big.unlockFocus()

    let data = try XCTUnwrap(LinkPreviewLoader.thumbnailData(big))
    let thumbnail = try XCTUnwrap(NSBitmapImageRep(data: data))
    XCTAssertLessThanOrEqual(CGFloat(thumbnail.pixelsWide), LinkPreviewLoader.maxThumbnailWidth * 2)
    XCTAssertNil(LinkPreviewLoader.thumbnailData(NSImage(size: .zero)))
  }

  @MainActor
  func testQuickLookWritesTextToATemporaryFile() throws {
    let url = try XCTUnwrap(QuickLookController.shared.previewFile(for: item("quick look me")))
    XCTAssertEqual(url.pathExtension, "txt")
    XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "quick look me")

    QuickLookController.shared.cleanUp()
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    XCTAssertNil(QuickLookController.shared.previewFile(for: item("")))
  }

  @MainActor
  func testOnlyPlainPublicPagesAreFetched() {
    let safe = ["https://communitee.co/", "https://www.apple.com/macbook-air/", "http://example.org/blog/post-1"]
    for link in safe {
      XCTAssertTrue(LinkPreviewLoader.isSafeToFetch(URL(string: link)!), link)
    }

    let unsafe = [
      "https://user:pass@example.com/",
      "https://example.com/reset-password?id=42",
      "https://app.example.com/auth/magic?id=1",
      "https://example.com/verify/abc",
      "https://example.com/page?token=abc",
      "https://example.com/unsubscribe/123",
      "https://192.168.1.10/admin",
      "https://127.0.0.1:8080/",
      "https://[::1]/",
      "https://printer.local/",
      "https://wiki.corp/",
      "ftp://example.com/file",
      "https://example.com/?q=" + ["gh", "p_", String(repeating: "a", count: 36)].joined()
    ]
    for link in unsafe {
      XCTAssertFalse(LinkPreviewLoader.isSafeToFetch(URL(string: link)!), link)
    }
  }

  func testSecretsStaySecretWithoutAnExpiry() {
    // Pinned secrets and secrets kept by the "Keep" setting have no expiry but are still secrets.
    let secretURL = item("https://api.example.com/hook?k=" + ["AI", "za", String(repeating: "b", count: 35)].joined())
    XCTAssertNil(secretURL.expiresAt)
    XCTAssertEqual(ContentKind.of(secretURL), .secret)
  }

  @MainActor
  func testMergeJoinsInOrderAndKeepsTheEarliestExpiry() {
    let first = item("one")
    let second = item("two")
    let secret = item("three")
    let soon = Date.now.addingTimeInterval(60)
    secret.expiresAt = soon

    XCTAssertEqual(ItemActions.merged([first, second], separator: .newLine).text, "one\ntwo")
    XCTAssertEqual(ItemActions.merged([first, second], separator: .comma).text, "one, two")
    let withSecret = ItemActions.merged([first, secret], separator: .space)
    XCTAssertEqual(withSecret.text, "one three")
    XCTAssertEqual(withSecret.expiresAt, soon)
    XCTAssertEqual(ItemActions.merged([item("")], separator: .space).text, "")
  }

  func testRicherKinds() {
    XCTAssertEqual(ContentKind.of(item("😀")), .emoji)
    XCTAssertEqual(ContentKind.of(item(" 👍🏽🎉 ")), .emoji)
    XCTAssertEqual(ContentKind.of(item("ok 👍")), .text)
    XCTAssertEqual(ContentKind.of(item("1")), .text, "digits are emoji-capable but not emoji")

    let rich = HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: Data("Bold words".utf8)),
      HistoryItemContent(type: NSPasteboard.PasteboardType.html.rawValue, value: Data("<b>Bold</b> words".utf8))
    ])
    XCTAssertEqual(ContentKind.of(rich), .richText)
    XCTAssertTrue(ContentFilter.text.matches(HistoryItemDecorator(rich)))

    func files(_ paths: [String]) -> HistoryItem {
      HistoryItem(contents: paths.map {
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.fileURL.rawValue, value: URL(filePath: $0).dataRepresentation
        )
      })
    }
    XCTAssertEqual(ContentKind.of(files(["/tmp/a.txt"])), .file)
    XCTAssertEqual(ContentKind.of(files(["/tmp/report.PDF"])), .pdf)
    XCTAssertEqual(ContentKind.of(files(["/tmp/a.txt", "/tmp/b.png", "/tmp/c.zip"])), .files(3))
    XCTAssertTrue(ContentFilter.files.matches(HistoryItemDecorator(files(["/tmp/a.txt", "/tmp/b.txt"]))))
  }

  func testRichTextDropsColorsButKeepsText() throws {
    let source = NSAttributedString(string: "Hello", attributes: [
      .foregroundColor: NSColor.black, .font: NSFont.boldSystemFont(ofSize: 40)
    ])
    let readable = try XCTUnwrap(CardPreviews.readableRichText(source))
    XCTAssertEqual(String(readable.characters), "Hello")
    let converted = NSAttributedString(readable)
    XCTAssertNil(converted.attribute(.foregroundColor, at: 0, effectiveRange: nil))
    let font = try XCTUnwrap(converted.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
    XCTAssertEqual(font.pointSize, CardPreviews.richTextFontRange.upperBound)
  }
}
