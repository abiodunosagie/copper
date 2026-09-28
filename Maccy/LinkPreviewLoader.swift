import AppKit
import Defaults
import LinkPresentation

// Fetches the page title and thumbnail for link cards, once per item, and stores them on the item.
@MainActor
enum LinkPreviewLoader {
  static let timeout: TimeInterval = 8
  static let maxThumbnailWidth: CGFloat = 600

  static func loadIfNeeded(for item: HistoryItem, url: URL) async {
    // Secrets are never fetched; a failed or finished fetch is never repeated.
    guard Defaults[.loadLinkPreviews], item.expiresAt == nil, item.linkPreviewFetchedAt == nil else { return }
    item.linkPreviewFetchedAt = .now

    let provider = LPMetadataProvider()
    provider.timeout = timeout
    guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return }

    item.linkTitle = metadata.title
    if let imageProvider = metadata.imageProvider ?? metadata.iconProvider,
       let image = await loadImage(from: imageProvider) {
      item.linkImageData = thumbnailData(image)
    }
    try? Storage.shared.context.save()
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
