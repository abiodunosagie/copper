import AppKit
import SwiftUI

// The main window (PastePal's "main view"): a normal, resizable window with the library grid.
@MainActor
final class LibraryWindowController: NSWindowController {
  static let shared = LibraryWindowController()

  static let defaultSize = NSSize(width: 1_000, height: 680)
  static let minimumSize = NSSize(width: 640, height: 420)
  private static let frameName = "CopperLibrary"

  private init() {
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.defaultSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = NSLocalizedString("library_title", comment: "")
    window.titlebarAppearsTransparent = true
    window.minSize = Self.minimumSize
    window.isReleasedWhenClosed = false
    // Reopens where the owner left it; centred the very first time.
    if !window.setFrameUsingName(Self.frameName) {
      window.center()
    }
    window.setFrameAutosaveName(Self.frameName)
    window.contentView = NSHostingView(
      rootView: LibraryView()
        .environment(AppState.shared)
        .environment(ModifierFlags())
        .modelContainer(Storage.shared.container)
    )
    super.init(window: window)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not used")
  }

  func show() {
    // Copper is a menu bar app, so it has to bring itself forward for a normal window.
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }
}
