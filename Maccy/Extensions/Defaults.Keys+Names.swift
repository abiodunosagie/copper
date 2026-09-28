import AppKit
import Defaults

struct StorageType {
  static let files = StorageType(types: [.fileURL])
  static let images = StorageType(types: [.png, .tiff, .jpeg, .heic, .gif])
  static let text = StorageType(types: [.html, .rtf, .string])
  static let all = StorageType(types: files.types + images.types + text.types)

  var types: [NSPasteboard.PasteboardType]
}

extension Defaults.Keys {
#if DEBUG
  // UI Tests bundle preferences
  static let testingSuiteName = "\(Bundle.main.bundleIdentifier ?? "com.abiodunosagie.Copper").uitests"

  // When UI tests run with the `enable-testing` argument, window and pin
  // preferences are stored in a separate xcuitest bundle
  private static let preferencesSuite: UserDefaults = AppDelegate.isTesting
    ? (UserDefaults(suiteName: testingSuiteName) ?? .standard)
    : .standard
#else
  private static let preferencesSuite: UserDefaults = .standard
#endif

  static let clearOnQuit = Key<Bool>("clearOnQuit", default: false, suite: preferencesSuite)
  static let clearSystemClipboard = Key<Bool>("clearSystemClipboard", default: false, suite: preferencesSuite)
  static let clipboardCheckInterval = Key<Double>("clipboardCheckInterval", default: 0.5, suite: preferencesSuite)
  static let enabledPasteboardTypes = Key<Set<NSPasteboard.PasteboardType>>(
    "enabledPasteboardTypes", default: Set(StorageType.all.types), suite: preferencesSuite
  )
  static let highlightMatch = Key<HighlightMatch>("highlightMatch", default: .bold, suite: preferencesSuite)
  static let ignoreAllAppsExceptListed = Key<Bool>("ignoreAllAppsExceptListed", default: false, suite: preferencesSuite)
  static let ignoreEvents = Key<Bool>("ignoreEvents", default: false, suite: preferencesSuite)
  static let ignoreOnlyNextEvent = Key<Bool>("ignoreOnlyNextEvent", default: false, suite: preferencesSuite)
  static let ignoreRegexp = Key<[String]>("ignoreRegexp", default: [], suite: preferencesSuite)
  static let secretHandling = Key<SecretHandling>("secretHandling", default: .expire, suite: preferencesSuite)
  // 0 keeps secrets on the system clipboard; otherwise they are wiped after this many seconds.
  static let clearSecretFromClipboardSeconds = Key<Int>(
    "clearSecretFromClipboardSeconds", default: 60, suite: preferencesSuite
  )
  // Bundle ids of apps that always receive plain text when Copper pastes into them.
  static let snippets = Key<[Snippet]>("snippets", default: [], suite: preferencesSuite)
  static let plainTextApps = Key<[String]>("plainTextApps", default: [], suite: preferencesSuite)
  static let pauseInSensitiveApps = Key<Bool>("pauseInSensitiveApps", default: true, suite: preferencesSuite)
  static let secretExpiryMinutes = Key<Int>("secretExpiryMinutes", default: 60, suite: preferencesSuite)
  static let ignoredFolders = Key<[String]>("ignoredFolders", default: [], suite: preferencesSuite)
  static let ignoredApps = Key<[String]>("ignoredApps", default: [], suite: preferencesSuite)
  static let ignoredPasteboardTypes = Key<Set<String>>(
    "ignoredPasteboardTypes",
    default: Set([
      "Pasteboard generator type",
      "com.agilebits.onepassword",
      "com.typeit4me.clipping",
      "de.petermaurer.TransientPasteboardType",
      "net.antelle.keeweb"
    ]),
    suite: preferencesSuite
  )
  static let imageMaxHeight = Key<Int>("imageMaxHeight", default: 40, suite: preferencesSuite)
  static let menuIcon = Key<MenuIcon>("menuIcon", default: .maccy, suite: preferencesSuite)
  static let migrations = Key<[String: Bool]>("migrations", default: [:], suite: preferencesSuite)
  static let pasteByDefault = Key<Bool>("pasteByDefault", default: false, suite: preferencesSuite)
  static let pinTo = Key<PinsPosition>("pinTo", default: .top, suite: preferencesSuite)
  static let popupPosition = Key<PopupPosition>("popupPosition", default: .dockedRight, suite: preferencesSuite)
  static let popupScreen = Key<Int>("popupScreen", default: 0, suite: preferencesSuite)
  static let openPreviewAutomatically = Key<Bool>("openPreviewAutomatically", default: true, suite: preferencesSuite)
  static let previewDelay = Key<Int>("previewDelay", default: 1500, suite: preferencesSuite)
  static let removeFormattingByDefault = Key<Bool>("removeFormattingByDefault", default: false, suite: preferencesSuite)
  static let searchMode = Key<Search.Mode>("searchMode", default: .exact, suite: preferencesSuite)
  static let showFooter = Key<Bool>("showFooter", default: true, suite: preferencesSuite)
  static let showInStatusBar = Key<Bool>("showInStatusBar", default: true, suite: preferencesSuite)
  static let showRecentCopyInMenuBar = Key<Bool>("showRecentCopyInMenuBar", default: false, suite: preferencesSuite)
  static let showSearch = Key<Bool>("showSearch", default: true, suite: preferencesSuite)
  static let searchVisibility = Key<SearchVisibility>("searchVisibility", default: .always, suite: preferencesSuite)
  static let showSpecialSymbols = Key<Bool>("showSpecialSymbols", default: true, suite: preferencesSuite)
  static let showTitle = Key<Bool>("showTitle", default: true, suite: preferencesSuite)
  static let size = Key<Int>("historySize", default: 200, suite: preferencesSuite)
  // Collection names in the order the owner created them.
  static let collections = Key<[String]>("collections", default: [], suite: preferencesSuite)
  // Sending items to Copper on other Macs; the pairing code lives in the Keychain (PeerPairing).
  static let peerShareEnabled = Key<Bool>("peerShareEnabled", default: false, suite: preferencesSuite)
  static let peerShareName = Key<String>("peerShareName", default: "", suite: preferencesSuite)
  // Random tag for the default broadcast name ("Copper 4F2A"), created on first use.
  static let peerShareTag = Key<String>("peerShareTag", default: "", suite: preferencesSuite)
  static let loadLinkPreviews = Key<Bool>("loadLinkPreviews", default: true, suite: preferencesSuite)
  static let unlimitedHistory = Key<Bool>("unlimitedHistory", default: false, suite: preferencesSuite)
  // 0 keeps items forever; otherwise unpinned items not copied for this many days are deleted.
  static let historyRetentionDays = Key<Int>("historyRetentionDays", default: 0, suite: preferencesSuite)
  static let sortBy = Key<Sorter.By>("sortBy", default: .lastCopiedAt, suite: preferencesSuite)
  static let suppressClearAlert = Key<Bool>("suppressClearAlert", default: false, suite: preferencesSuite)
  static let windowSize = Key<NSSize>("windowSize", default: NSSize(width: 450, height: 800), suite: preferencesSuite)
  // Only Appearance settings write this. ("dockWidth" was overwritten by resize code and is retired.)
  static let dockWidth = Key<Double>("dockPanelWidth", default: 300, suite: preferencesSuite)
  static let dockHeight = Key<Double>("dockPanelHeight", default: 300, suite: preferencesSuite)
  static let windowPosition = Key<NSPoint>("windowPosition", default: NSPoint(x: 0.5, y: 0.8), suite: preferencesSuite)
  static let showApplicationIcons = Key<Bool>("showApplicationIcons", default: false, suite: preferencesSuite)
  static let showHexColorSwatch = Key<Bool>("showHexColorSwatch", default: true, suite: preferencesSuite)
  static let previewWidth = Key<CGFloat>("previewWidth", default: 400, suite: preferencesSuite)
}
