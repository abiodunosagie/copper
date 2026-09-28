import XCTest
import Defaults
@testable import Maccy

@MainActor
class BackupTests: XCTestCase {
  let history = History.shared
  let savedSize = Defaults[.size]

  override func setUp() {
    super.setUp()
    history.clearAll()
    Defaults[.size] = 50
  }

  override func tearDown() {
    super.tearDown()
    history.clearAll()
    Defaults[.size] = savedSize
  }

  private func item(_ value: String) -> HistoryItem {
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = [HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: Data(value.utf8))]
    item.title = item.generateTitle()
    return item
  }

  func testEncryptDecryptRoundTrip() throws {
    let archive = Backup.Archive(items: [
      Backup.Item(title: "hello", application: "com.apple.Notes", firstCopiedAt: .now, lastCopiedAt: .now,
                  numberOfCopies: 3, isPinned: true,
                  contents: [Backup.Content(type: "public.utf8-plain-text", value: Data("hello".utf8))])
    ])

    let data = try Backup.encrypt(archive, password: "correct horse")
    XCTAssertNil(data.range(of: Data("hello".utf8)), "plaintext leaked into the backup file")

    let decoded = try Backup.decrypt(data, password: "correct horse")
    XCTAssertEqual(decoded.items, archive.items)
  }

  func testEachExportUsesAFreshSalt() throws {
    let archive = Backup.Archive(items: [])
    XCTAssertNotEqual(try Backup.encrypt(archive, password: "p"), try Backup.encrypt(archive, password: "p"))
  }

  func testWrongPasswordIsRejected() throws {
    let data = try Backup.encrypt(Backup.Archive(items: []), password: "right")
    XCTAssertThrowsError(try Backup.decrypt(data, password: "wrong")) { error in
      XCTAssertEqual(error as? Backup.BackupError, .wrongPassword)
    }
  }

  func testRandomFilesAreRejected() {
    XCTAssertThrowsError(try Backup.decrypt(Data("not a backup at all, just text".utf8), password: "x")) { error in
      XCTAssertEqual(error as? Backup.BackupError, .notABackup)
    }
    XCTAssertThrowsError(try Backup.decrypt(Data(), password: "x"))
  }

  func testTamperedFilesAreRejected() throws {
    var data = try Backup.encrypt(Backup.Archive(items: []), password: "p")
    data[data.count - 1] ^= 0xFF
    XCTAssertThrowsError(try Backup.decrypt(data, password: "p"))
  }

  func testExpiringSecretsAreNotExported() {
    let plain = item("plain")
    let secret = item("secret")
    secret.expiresAt = .now.addingTimeInterval(60)

    let archive = Backup.archive(of: [plain, secret])
    XCTAssertEqual(archive.items.map(\.title), ["plain"])
  }

  func testRestoreAddsItemsAndKeepsPins() throws {
    history.add(item("existing"))
    let pinned = item("pinned")
    history.add(pinned)
    pinned.pin = "b"

    let data = try Backup.encrypt(Backup.archive(of: history.all.map(\.item)), password: "p")
    history.clearAll()
    XCTAssertTrue(history.all.isEmpty)

    let restored = history.restore(try Backup.decrypt(data, password: "p"))
    XCTAssertEqual(restored, 2)
    XCTAssertEqual(Set(history.all.map(\.title)), ["existing", "pinned"])
    XCTAssertEqual(history.all.first { $0.title == "pinned" }?.isPinned, true)
    XCTAssertEqual(history.all.first { $0.title == "existing" }?.isPinned, false)
  }

  func testRestoringTwiceMergesDuplicates() throws {
    history.add(item("once"))
    let archive = Backup.archive(of: history.all.map(\.item))

    history.restore(archive)
    XCTAssertEqual(history.all.count, 1)
  }
}
