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

class IgnoredFolderTests: XCTestCase {
  private func fileContent(_ path: String) -> HistoryItemContent {
    HistoryItemContent(type: NSPasteboard.PasteboardType.fileURL.rawValue, value: URL(filePath: path).dataRepresentation)
  }

  func testFilesFromIgnoredFoldersAreDetected() {
    let folders = ["/Users/me/Private"]
    XCTAssertTrue(Clipboard.isFromIgnoredFolder([fileContent("/Users/me/Private/tax.pdf")], folders: folders))
    XCTAssertTrue(Clipboard.isFromIgnoredFolder([fileContent("/Users/me/Private/2026/a.png")], folders: folders))
    XCTAssertFalse(Clipboard.isFromIgnoredFolder([fileContent("/Users/me/PrivateNotes/a.txt")], folders: folders))
    XCTAssertFalse(Clipboard.isFromIgnoredFolder([fileContent("/Users/me/Public/a.txt")], folders: folders))
    XCTAssertFalse(Clipboard.isFromIgnoredFolder([fileContent("/Users/me/Private/tax.pdf")], folders: []))
  }
}
