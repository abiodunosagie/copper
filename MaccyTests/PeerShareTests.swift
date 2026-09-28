import Network
import XCTest
@testable import Maccy

// Sends frames between two connections on this Mac over TLS with the pairing-code key.
// This proves the protocol; sending between two real Macs is a manual check.
@MainActor
class PeerShareTests: XCTestCase {
  // A private instance: no Bonjour, no shared state with the app's own service.
  let service = PeerShareService(advertise: false)
  let code = PeerPairing.generateCode()

  override func tearDown() {
    service.stop()
    super.tearDown()
  }

  private func startListener() throws -> NWEndpoint.Port {
    let ready = expectation(description: "listener ready")
    var readyPort: NWEndpoint.Port?
    service.start(code: code) { port in
      readyPort = port
      ready.fulfill()
    }
    wait(for: [ready], timeout: 5)
    return try XCTUnwrap(readyPort)
  }

  func testGeneratedCodesAreLongAndValid() {
    let generated = PeerPairing.generateCode()
    let expectedLength = PeerPairing.codeGroups * PeerPairing.groupLength + PeerPairing.codeGroups - 1
    XCTAssertEqual(generated.count, expectedLength)
    XCTAssertTrue(PeerPairing.isValid(generated))
    XCTAssertTrue(PeerPairing.isValid(generated.lowercased().replacingOccurrences(of: "-", with: " ")))
    XCTAssertNotEqual(generated, PeerPairing.generateCode())
    XCTAssertFalse(PeerPairing.isValid("password"), "short typed codes are refused")
    XCTAssertFalse(PeerPairing.isValid(String(repeating: "1", count: 30)), "outside the code alphabet")
  }

  func testFrameRoundTrip() throws {
    let frame = PeerFrame(from: "Studio", content: .text("hello from the other Mac"))
    let data = try frame.encoded()
    let length = try PeerFrame.bodyLength(fromHeader: data.prefix(PeerFrame.headerLength))
    XCTAssertEqual(length, data.count - PeerFrame.headerLength)
    XCTAssertEqual(try PeerFrame.decode(body: data.dropFirst(PeerFrame.headerLength)), frame)
  }

  func testOversizedAndMalformedFramesAreRefused() throws {
    var huge = UInt32(PeerFrame.maxBodyLength + 1).bigEndian
    XCTAssertThrowsError(try PeerFrame.bodyLength(fromHeader: Data(bytes: &huge, count: 4)))
    XCTAssertThrowsError(try PeerFrame.bodyLength(fromHeader: Data([0, 0, 0, 0])))
    XCTAssertThrowsError(try PeerFrame.bodyLength(fromHeader: Data([1, 2])))
    XCTAssertThrowsError(try PeerFrame.decode(body: Data("not json".utf8)))
    let empty = try JSONEncoder().encode(PeerFrame(from: "x", content: .text("")))
    XCTAssertThrowsError(try PeerFrame.decode(body: empty))
  }

  func testMatchingCodeDeliversTheItem() throws {
    let port = try startListener()
    let received = expectation(description: "frame received")
    service.onReceive = { frame in
      XCTAssertEqual(frame.content, .text("sent over TLS"))
      received.fulfill()
    }

    let endpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: port)
    service.send(PeerFrame(from: "Tester", content: .text("sent over TLS")), to: endpoint, code: code)
    wait(for: [received], timeout: 5)
  }

  func testDifferentCodeCannotDeliver() throws {
    let port = try startListener()
    let received = expectation(description: "frame must not arrive")
    received.isInverted = true
    service.onReceive = { _ in received.fulfill() }

    service.send(
      PeerFrame(from: "Intruder", content: .text("let me in")),
      to: .hostPort(host: "127.0.0.1", port: port),
      code: PeerPairing.generateCode()
    )
    wait(for: [received], timeout: 3)
  }

  func testRateLimitStopsFloods() {
    let frame = PeerFrame(from: "Flood", content: .text("item"))
    let admitted = (0..<(PeerShareService.maxItemsPerMinute + 5)).filter { _ in service.admit(frame) }
    XCTAssertEqual(admitted.count, PeerShareService.maxItemsPerMinute)
  }

  func testHugeImagesAreRefusedBeforeDecoding() throws {
    let tiny = NSImage(size: NSSize(width: 2, height: 2))
    tiny.lockFocus()
    NSColor.blue.setFill()
    NSRect(x: 0, y: 0, width: 2, height: 2).fill()
    tiny.unlockFocus()
    XCTAssertTrue(service.admit(PeerFrame(from: "x", content: .image(try XCTUnwrap(tiny.pngData)))))
    XCTAssertFalse(service.admit(PeerFrame(from: "x", content: .image(Data("not an image".utf8)))))
  }

  func testSecretsAreNeverSent() {
    let item = HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: Data((["gh", "p_"].joined() + String(repeating: "a", count: 36)).utf8)
      )
    ])
    let peer = PeerShareService.Peer(name: "Nowhere", endpoint: .hostPort(host: "127.0.0.1", port: 9))
    XCTAssertEqual(service.send(item, to: peer), .secret)
  }

  func testImageSizeIsReadWithoutDecoding() throws {
    let image = NSImage(size: NSSize(width: 40, height: 20))
    image.lockFocus()
    NSColor.red.setFill()
    NSRect(x: 0, y: 0, width: 40, height: 20).fill()
    image.unlockFocus()
    let size = try XCTUnwrap(NSImage.pixelSize(of: try XCTUnwrap(image.pngData)))
    XCTAssertGreaterThan(size.width, size.height)
    XCTAssertNil(NSImage.pixelSize(of: Data("not an image".utf8)))
  }
}
