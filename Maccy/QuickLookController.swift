import AppKit
import Quartz

// Opens the system Quick Look panel for a history item. Text and images are written to a
// temporary file first (Quick Look previews files); copied files are previewed in place.
@MainActor
final class QuickLookController: NSObject, QLPreviewPanelDataSource {
  static let shared = QuickLookController()

  private var previewURL: URL?
  private let folder = FileManager.default.temporaryDirectory.appending(path: "QuickLook", directoryHint: .isDirectory)

  var isVisible: Bool { QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible }

  func toggle(_ item: HistoryItem?) {
    if isVisible {
      QLPreviewPanel.shared().orderOut(nil)
      return
    }
    // Detected secrets are never written to disk for a preview.
    guard let item, item.expiresAt == nil, let url = previewFile(for: item) else {
      NSSound.beep()
      return
    }

    previewURL = url
    let panel = QLPreviewPanel.shared()!
    panel.dataSource = self
    // The docked panel sits at screen saver level; Quick Look must appear above it.
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
    panel.reloadData()
    panel.makeKeyAndOrderFront(nil)
  }

  // Removes temporary preview files, for example at launch.
  func cleanUp() {
    try? FileManager.default.removeItem(at: folder)
  }

  // A file Quick Look can open: the copied file itself, or a temporary PNG or text file.
  func previewFile(for item: HistoryItem) -> URL? {
    if let url = item.fileURLs.first {
      return url
    }

    try? FileManager.default.removeItem(at: folder)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    if let image = item.image, let tiff = image.tiffRepresentation,
       let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
      let url = folder.appending(path: "Copper image.png")
      return (try? png.write(to: url)) != nil ? url : nil
    }

    let text = item.previewableText
    guard !text.isEmpty else { return nil }
    let url = folder.appending(path: "Copper text.txt")
    return (try? Data(text.utf8).write(to: url)) != nil ? url : nil
  }

  nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
    MainActor.assumeIsolated { previewURL == nil ? 0 : 1 }
  }

  nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
    MainActor.assumeIsolated { previewURL as NSURL? }
  }
}
