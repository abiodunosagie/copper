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
    var id: String { name }
  }

  static let shared = PeerShareService()

  private(set) var peers: [Peer] = []
  private(set) var isRunning = false

  // Where received items go. Tests replace it.
  @ObservationIgnored var onReceive: (PeerFrame) -> Void = { PeerShareService.addToHistory($0) }

  @ObservationIgnored private var listener: NWListener?
  @ObservationIgnored private var browser: NWBrowser?
  @ObservationIgnored private let queue = DispatchQueue(label: "com.abiodunosagie.Copper.peer-share")
  @ObservationIgnored private let logger = Logger(subsystem: "com.abiodunosagie.Copper", category: "PeerShare")

  static var deviceName: String {
    let name = Defaults[.peerShareName].trimmingCharacters(in: .whitespaces)
    return name.isEmpty ? (Host.current().localizedName ?? "Mac") : name
  }

  // Starts or stops to match the settings.
  func update() {
    guard Defaults[.peerShareEnabled], let code = PeerPairing.code, PeerPairing.isValid(code) else {
      stop()
      return
    }
    stop()
    start(code: code)
  }

  // `advertise: false` and a fixed port are for tests on this Mac only.
  func start(code: String, port: NWEndpoint.Port = .any, advertise: Bool = true, onReady: ((NWEndpoint.Port) -> Void)? = nil) {
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
    listener.newConnectionHandler = { [weak self] connection in
      Task { @MainActor in self?.receive(on: connection) }
    }
    listener.start(queue: queue)
    self.listener = listener
    isRunning = true

    guard advertise else { return }
    let browser = NWBrowser(for: .bonjour(type: PeerPairing.serviceType, domain: nil), using: parameters)
    browser.browseResultsChangedHandler = { [weak self] results, _ in
      Task { @MainActor in self?.updatePeers(results) }
    }
    browser.start(queue: queue)
    self.browser = browser
  }

  func stop() {
    listener?.cancel()
    browser?.cancel()
    listener = nil
    browser = nil
    peers = []
    isRunning = false
  }

  // Sends one item. Detected secrets never leave this Mac. Returns false when nothing was sent.
  @discardableResult
  func send(_ item: HistoryItem, to peer: Peer) -> Bool {
    guard ContentKind.of(item) != .secret, let code = PeerPairing.code, let frame = Self.frame(for: item) else {
      NSSound.beep()
      return false
    }
    send(frame, to: peer.endpoint, code: code)
    return true
  }

  func send(_ frame: PeerFrame, to endpoint: NWEndpoint, code: String) {
    guard let data = try? frame.encoded() else {
      NSSound.beep()
      return
    }
    let connection = NWConnection(to: endpoint, using: PeerPairing.parameters(code: code))
    connection.start(queue: queue)
    connection.send(content: data, completion: .contentProcessed { [weak self] error in
      if let error {
        Task { @MainActor in self?.logger.error("Send failed: \(error.localizedDescription)") }
      }
      connection.cancel()
    })
  }

  static func frame(for item: HistoryItem) -> PeerFrame? {
    if let image = item.image, let tiff = image.tiffRepresentation,
       let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
      return PeerFrame(kind: .image, from: deviceName, imagePNG: png)
    }
    let text = item.previewableText
    guard !text.isEmpty, item.fileURLs.isEmpty else { return nil }
    return PeerFrame(kind: .text, from: deviceName, text: text)
  }

  private func updatePeers(_ results: Set<NWBrowser.Result>) {
    peers = results.compactMap { result in
      guard case .service(let name, _, _, _) = result.endpoint, name != Self.deviceName else { return nil }
      return Peer(name: name, endpoint: result.endpoint)
    }
    .sorted { $0.name < $1.name }
  }

  // Reads one frame: the header first, so an oversized length is refused before the body arrives.
  private func receive(on connection: NWConnection) {
    connection.start(queue: queue)
    connection.receive(minimumIncompleteLength: PeerFrame.headerLength, maximumLength: PeerFrame.headerLength) {
      [weak self] header, _, _, error in
      guard error == nil, let header, let length = try? PeerFrame.bodyLength(fromHeader: header) else {
        connection.cancel()
        return
      }
      connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] body, _, _, _ in
        defer { connection.cancel() }
        guard let body, let frame = try? PeerFrame.decode(body: body) else { return }
        Task { @MainActor in self?.onReceive(frame) }
      }
    }
  }

  // Received items join history like a fresh copy (secret rules included); the clipboard is untouched.
  static func addToHistory(_ frame: PeerFrame) {
    var contents: [HistoryItemContent] = []
    if let text = frame.text {
      contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: Data(text.utf8)))
    }
    if let png = frame.imagePNG {
      contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: png))
    }
    guard case .save(let expiresAt) = SecretDetector.decision(for: frame.text) else { return }

    let item = HistoryItem(contents: contents)
    if #unavailable(macOS 15.0) {
      try? History.shared.insertIntoStorage(item)
    }
    item.expiresAt = expiresAt
    item.title = item.generateTitle()
    History.shared.add(item, notify: false)
    Notifier.notify(
      body: String(format: NSLocalizedString("peer_received", comment: ""), frame.from),
      sound: .write
    )
  }
}
