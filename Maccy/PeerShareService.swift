import AppKit
import Defaults
import Network
import OSLog

// Sends history items to Copper on other Macs on the same network and receives theirs.
// Off until enabled in Settings with a pairing code; nothing listens or advertises before that.
@MainActor
@Observable
final class PeerShareService {
  struct Peer: Hashable, Identifiable {
    let name: String
    let endpoint: NWEndpoint
    // Two Macs can share a name; the endpoint is unique.
    var id: String { endpoint.debugDescription }
  }

  enum SendResult: Equatable {
    case sent
    case secret
    case notPaired
    case unsupported
  }

  static let shared = PeerShareService()

  // Limits that keep a paired (or misbehaving) Mac from flooding this one.
  static let handshakeTimeout: TimeInterval = 10
  static let maxOpenConnections = 4
  static let maxItemsPerMinute = 20
  static let maxImageSide: CGFloat = 8_000

  private(set) var peers: [Peer] = []

  // Where received items go. Tests replace it.
  @ObservationIgnored var onReceive: (PeerFrame) -> Void = { PeerShareService.addToHistory($0) }

  @ObservationIgnored private let advertise: Bool
  @ObservationIgnored private var listener: NWListener?
  @ObservationIgnored private var browser: NWBrowser?
  @ObservationIgnored private var openConnections: [ObjectIdentifier: NWConnection] = [:]
  // The name Bonjour actually registered (it may add " (2)" on a clash), used to hide this Mac.
  @ObservationIgnored private var advertisedName: String?
  @ObservationIgnored private var recentReceipts: [Date] = []
  @ObservationIgnored private let queue = DispatchQueue(label: "com.abiodunosagie.Copper.peer-share")
  @ObservationIgnored private let logger = Logger(subsystem: "com.abiodunosagie.Copper", category: "PeerShare")

  // `advertise: false` is for tests on this Mac: no Bonjour advertising or browsing.
  init(advertise: Bool = true) {
    self.advertise = advertise
  }

  // The name other Macs see. Defaults to "Copper" plus a random tag, so the Mac's real
  // (often personal) name is never broadcast unless the owner types one.
  static var deviceName: String {
    let name = Defaults[.peerShareName].trimmingCharacters(in: .whitespaces)
    if !name.isEmpty { return name }
    if Defaults[.peerShareTag].isEmpty {
      Defaults[.peerShareTag] = String(UUID().uuidString.prefix(4))
    }
    return "Copper " + Defaults[.peerShareTag]
  }

  // Starts or stops to match the settings.
  func update() {
    stop()
    guard Defaults[.peerShareEnabled], let code = PeerPairing.code, PeerPairing.isValid(code) else { return }
    start(code: code)
  }

  func start(code: String, port: NWEndpoint.Port = .any, onReady: ((NWEndpoint.Port) -> Void)? = nil) {
    let parameters = PeerPairing.parameters(code: code)
    guard let listener = try? NWListener(using: parameters, on: port) else {
      logger.error("Could not start the peer share listener")
      return
    }
    if advertise {
      listener.service = NWListener.Service(name: Self.deviceName, type: PeerPairing.serviceType)
    }
    listener.stateUpdateHandler = { [weak self] state in
      if case .ready = state, let port = listener.port {
        Task { @MainActor in onReady?(port) }
      } else if case .failed(let error) = state {
        Task { @MainActor in self?.logger.error("Listener failed: \(error.localizedDescription)") }
      }
    }
    listener.serviceRegistrationUpdateHandler = { [weak self] change in
      if case .add(let endpoint) = change, case .service(let name, _, _, _) = endpoint {
        Task { @MainActor in self?.advertisedName = name }
      }
    }
    listener.newConnectionHandler = { [weak self] connection in
      Task { @MainActor in self?.accept(connection) }
    }
    listener.start(queue: queue)
    self.listener = listener

    guard advertise else { return }
    let browser = NWBrowser(for: .bonjour(type: PeerPairing.serviceType, domain: nil), using: parameters)
    browser.browseResultsChangedHandler = { [weak self] results, _ in
      Task { @MainActor in self?.updatePeers(results) }
    }
    browser.start(queue: queue)
    self.browser = browser
  }

  func stop() {
    openConnections.values.forEach { $0.cancel() }
    openConnections = [:]
    advertisedName = nil
    listener?.cancel()
    browser?.cancel()
    listener = nil
    browser = nil
    peers = []
  }

  // Sends one item. Detected secrets never leave this Mac.
  @discardableResult
  func send(_ item: HistoryItem, to peer: Peer) -> SendResult {
    let result: SendResult
    if ContentKind.of(item) == .secret {
      result = .secret
    } else if let code = PeerPairing.code {
      if let frame = Self.frame(for: item) {
        send(frame, to: peer.endpoint, code: code)
        result = .sent
      } else {
        result = .unsupported
      }
    } else {
      result = .notPaired
    }

    if result != .sent {
      logger.info("Not sent: \(String(describing: result), privacy: .public)")
      NSSound.beep()
    }
    return result
  }

  func send(_ frame: PeerFrame, to endpoint: NWEndpoint, code: String) {
    guard let data = try? frame.encoded() else {
      NSSound.beep()
      return
    }
    let connection = NWConnection(to: endpoint, using: PeerPairing.parameters(code: code))
    connection.stateUpdateHandler = { [weak self] state in
      if case .failed(let error) = state {
        Task { @MainActor in self?.logger.error("Connection failed: \(error.localizedDescription)") }
        connection.cancel()
      }
    }
    connection.start(queue: queue)
    connection.send(content: data, completion: .contentProcessed { [weak self] error in
      if let error {
        Task { @MainActor in self?.logger.error("Send failed: \(error.localizedDescription)") }
      }
      connection.cancel()
    })
  }

  static func frame(for item: HistoryItem) -> PeerFrame? {
    if let png = item.image?.pngData {
      return PeerFrame(from: deviceName, content: .image(png))
    }
    let text = item.previewableText
    guard !text.isEmpty, item.fileURLs.isEmpty else { return nil }
    return PeerFrame(from: deviceName, content: .text(text))
  }

  private func updatePeers(_ results: Set<NWBrowser.Result>) {
    peers = results.compactMap { result in
      guard case .service(let name, _, _, _) = result.endpoint, name != (advertisedName ?? Self.deviceName) else {
        return nil
      }
      return Peer(name: name, endpoint: result.endpoint)
    }
    .sorted { $0.name < $1.name }
  }

  // Accepts at most a few connections at once and drops any that do not finish in time,
  // so connections that never complete the handshake cannot pile up.
  private func accept(_ connection: NWConnection) {
    guard openConnections.count < Self.maxOpenConnections else {
      connection.cancel()
      return
    }
    let key = ObjectIdentifier(connection)
    openConnections[key] = connection
    let finish: @MainActor () -> Void = { [weak self] in
      guard self?.openConnections.removeValue(forKey: key) != nil else { return }
      connection.cancel()
    }
    queue.asyncAfter(deadline: .now() + Self.handshakeTimeout) {
      Task { @MainActor in finish() }
    }
    connection.stateUpdateHandler = { state in
      switch state {
      case .failed, .cancelled:
        Task { @MainActor in finish() }
      default:
        break
      }
    }
    connection.start(queue: queue)
    receive(on: connection, finish: finish)
  }

  // Reads one frame: the header first, so an oversized length is refused before the body arrives.
  private func receive(on connection: NWConnection, finish: @escaping @MainActor () -> Void) {
    connection.receive(minimumIncompleteLength: PeerFrame.headerLength, maximumLength: PeerFrame.headerLength) {
      [weak self] header, _, _, error in
      guard error == nil, let header, let length = try? PeerFrame.bodyLength(fromHeader: header) else {
        Task { @MainActor in finish() }
        return
      }
      connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] body, _, _, _ in
        let frame = body.flatMap { try? PeerFrame.decode(body: $0) }
        Task { @MainActor in
          finish()
          if let frame, self?.admit(frame) == true {
            self?.onReceive(frame)
          }
        }
      }
    }
  }

  // Rate limit, and images must declare a sane size before anything decodes them.
  func admit(_ frame: PeerFrame) -> Bool {
    let now = Date.now
    recentReceipts = recentReceipts.filter { now.timeIntervalSince($0) < 60 }
    guard recentReceipts.count < Self.maxItemsPerMinute else { return false }
    if case .image(let png) = frame.content {
      guard let size = NSImage.pixelSize(of: png),
            size.width <= Self.maxImageSide, size.height <= Self.maxImageSide else { return false }
    }
    recentReceipts.append(now)
    return true
  }

  // Received items join history like a fresh copy (secret rules included); the clipboard is untouched.
  static func addToHistory(_ frame: PeerFrame) {
    let text: String?
    let content: HistoryItemContent
    switch frame.content {
    case .text(let value):
      text = value
      content = HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: Data(value.utf8))
    case .image(let png):
      text = nil
      content = HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: png)
    }
    guard let item = HistoryItem.forHistory(contents: [content], scannedText: text) else { return }
    // Links from another Mac are never fetched for a preview.
    item.receivedFromPeerAt = .now
    History.shared.add(item, notify: false)
    // The sender's name comes from the other side and is not verified, so it is not shown.
    Notifier.notify(body: NSLocalizedString("peer_received", comment: ""), sound: .write)
  }
}
