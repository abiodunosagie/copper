import Network
import XCTest
@testable import Maccy

// Sends frames between two connections on this Mac over TLS with the pairing-code key.
// This proves the protocol; sending between two real Macs is a manual check.
@MainActor
class PeerShareTests: XCTestCase {
  let service = PeerShareService.shared

  override func tearDown() {
    service.stop()
    service.onReceive = { PeerShareService.addToHistory($0) }
    super.tearDown()
  }

  private func startListener(code: String) -> NWEndpoint.Port {
    let ready = expectation(description: "listener ready")
    var readyPort: NWEndpoint.Port?
    service.start(code: code, advertise: false) { port in
      readyPort = port
      ready.fulfill()
    }
    wait(for: [ready], timeout: 5)
    return readyPort!
  }

  func testFrameRoundTrip() throws {
    let frame = PeerFrame(kind: .text, from: "Studio", text: "hello from the other Mac")
    let data = try frame.encoded()
    let length = try PeerFrame.bodyLength(fromHeader: data.prefix(PeerFrame.headerLength))
    XCTAssertEqual(length, data.count - PeerFrame.headerLength)
    XCTAssertEqual(try PeerFrame.decode(body: data.dropFirst(PeerFrame.headerLength)), frame)
  }

  func testOversizedAndMalformedFramesAreRefused() {
    var huge = UInt32(PeerFrame.maxBodyLength + 1).bigEndian
    XCTAssertThrowsError(try PeerFrame.bodyLength(fromHeader: Data(bytes: &huge, count: 4)))
    XCTAssertThrowsError(try PeerFrame.bodyLength(fromHeader: Data([0, 0, 0, 0])))
    XCTAssertThrowsError(try PeerFrame.bodyLength(fromHeader: Data([1, 2])))
    XCTAssertThrowsError(try PeerFrame.decode(body: Data("{\"kind\":\"text\",\"from\":\"x\"}".utf8)))
    XCTAssertThrowsError(try PeerFrame.decode(body: Data("not json".utf8)))
  }

  func testMatchingCodeDeliversTheItem() {
    let port = startListener(code: "correct horse battery")
    let received = expectation(description: "frame received")
    service.onReceive = { frame in
      XCTAssertEqual(frame.text, "sent over TLS")
      XCTAssertEqual(frame.from, "Tester")
      received.fulfill()
    }

    service.send(
      PeerFrame(kind: .text, from: "Tester", text: "sent over TLS"),
      to: .hostPort(host: "127.0.0.1", port: port),
      code: "correct horse battery"
    )
    wait(for: [received], timeout: 5)
  }

  func testDifferentCodeCannotDeliver() {
    let port = startListener(code: "correct horse battery")
    let received = expectation(description: "frame must not arrive")
    received.isInverted = true
    service.onReceive = { _ in received.fulfill() }

    service.send(
      PeerFrame(kind: .text, from: "Intruder", text: "let me in"),
      to: .hostPort(host: "127.0.0.1", port: port),
      code: "wrong code entirely"
    )
    wait(for: [received], timeout: 3)
  }

  func testSecretsAreNeverSent() {
    let item = HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: Data((["gh", "p_"].joined() + String(repeating: "a", count: 36)).utf8)
      )
    ])
    let peer = PeerShareService.Peer(name: "Nowhere", endpoint: .hostPort(host: "127.0.0.1", port: 9))
    XCTAssertFalse(service.send(item, to: peer))
  }
}
