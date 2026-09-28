import AppKit
import Defaults
import LinkPresentation
import Network
import OSLog

// Fetches the page title and thumbnail for link cards, once per item, and stores them on the item.
@MainActor
enum LinkPreviewLoader {
  private static let logger = Logger(subsystem: "com.abiodunosagie.Copper", category: "LinkPreview")
  static let timeout: TimeInterval = 8
  static let maxThumbnailWidth: CGFloat = 600

  static let retryInterval: TimeInterval = 86_400

  static func loadIfNeeded(for item: HistoryItem, url: URL) async {
    guard Defaults[.loadLinkPreviews], item.linkTitle == nil, isSafeToFetch(url) else { return }
    // Secrets are never fetched, whatever the secret setting or pin state.
    guard ContentKind.of(item) != .secret else { return }
    // One attempt per item per day, so failures never turn into a burst of requests.
    if let lastAttempt = item.linkPreviewFetchedAt, Date.now.timeIntervalSince(lastAttempt) < retryInterval {
      return
    }
    item.linkPreviewFetchedAt = .now

    let provider = LPMetadataProvider()
    provider.timeout = timeout
    let metadata: LPLinkMetadata
    do {
      metadata = try await provider.startFetchingMetadata(for: url)
    } catch {
      logger.info("Link preview failed for \(url.host() ?? "", privacy: .public): \(error.localizedDescription)")
      return
    }

    item.linkTitle = metadata.title
    if let imageProvider = metadata.imageProvider ?? metadata.iconProvider,
       let image = await loadImage(from: imageProvider) {
      item.linkImageData = thumbnailData(image)
    }
    do {
      try Storage.shared.context.save()
    } catch {
      logger.error("Saving link preview failed: \(error.localizedDescription)")
    }
  }

  // Words in a path or query that mark links which may act on a single visit
  // (password resets, magic logins, confirmations) or carry credentials.
  static let sensitiveMarkers = [
    "token", "key", "secret", "password", "passwd", "pwd", "auth", "code", "otp", "sig", "signature",
    "session", "reset", "verify", "confirm", "magic", "login", "signin", "sign-in", "activate",
    "invite", "unsubscribe", "credential", "access", "jwt", "nonce", "ticket"
  ]
  static let privateHostSuffixes = [".local", ".internal", ".lan", ".home", ".corp", ".intranet", ".localhost"]

  // Only plain public web pages are fetched. Anything that could spend a one-time link,
  // send credentials or reach the local network is shown as a link without a preview.
  static func isSafeToFetch(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
          url.user == nil, url.password == nil,
          let host = url.host()?.lowercased(), host.contains("."),
          !privateHostSuffixes.contains(where: host.hasSuffix),
          !isIPAddress(host) else { return false }

    let pathAndQuery = (url.path() + "?" + (url.query() ?? "")).lowercased()
    guard !sensitiveMarkers.contains(where: pathAndQuery.contains) else { return false }
    return SecretDetector.detect(in: url.absoluteString) == nil
  }

  private static func isIPAddress(_ host: String) -> Bool {
    let trimmed = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    return IPv4Address(trimmed) != nil || IPv6Address(trimmed) != nil
  }

  private static func loadImage(from provider: NSItemProvider) async -> NSImage? {
    await withCheckedContinuation { continuation in
      _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
        continuation.resume(returning: object as? NSImage)
      }
    }
  }

  // A small PNG, so previews do not bloat the history database.
  static func thumbnailData(_ image: NSImage) -> Data? {
    let scale = min(1, maxThumbnailWidth / max(image.size.width, 1))
    let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    guard size.width >= 1, size.height >= 1 else { return nil }

    let thumbnail = NSImage(size: size)
    thumbnail.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: size))
    thumbnail.unlockFocus()

    guard let tiff = thumbnail.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
    return bitmap.representation(using: .png, properties: [:])
  }
}
