import AppKit.NSEvent
import Defaults
import Foundation

enum PopupPosition: String, CaseIterable, Identifiable, CustomStringConvertible, Defaults.Serializable {
  case dockedRight
  case dockedLeft
  case cursor
  case statusItem
  case window
  case center
  case lastPosition

  var id: Self { self }

  // Docked positions glue a full-height panel to a screen edge, like a sidebar.
  var isDocked: Bool { self == .dockedRight || self == .dockedLeft }

  static let dockMargin: CGFloat = 8
  static let dockWidthRange: ClosedRange<Double> = 260...640

  var description: String {
    switch self {
    case .dockedRight:
      return NSLocalizedString("PopupDockedRight", tableName: "AppearanceSettings", comment: "")
    case .dockedLeft:
      return NSLocalizedString("PopupDockedLeft", tableName: "AppearanceSettings", comment: "")
    case .cursor:
      return NSLocalizedString("PopupAtCursor", tableName: "AppearanceSettings", comment: "")
    case .statusItem:
      return NSLocalizedString("PopupAtMenuBarIcon", tableName: "AppearanceSettings", comment: "")
    case .window:
      return NSLocalizedString("PopupAtWindowCenter", tableName: "AppearanceSettings", comment: "")
    case .center:
      return NSLocalizedString("PopupAtScreenCenter", tableName: "AppearanceSettings", comment: "")
    case .lastPosition:
      return NSLocalizedString("PopupAtLastPosition", tableName: "AppearanceSettings", comment: "")
    }
  }

  func origin(size: NSSize, statusBarButton: NSStatusBarButton?) -> NSPoint {
    switch self {
    case .center:
      if let frame = NSScreen.forPopup?.visibleFrame {
        return NSRect.centered(ofSize: size, in: frame).origin
      }
    case .window:
      if let frame = NSWorkspace.shared.frontmostApplication?.windowFrame {
        return NSRect.centered(ofSize: size, in: frame).origin
      }
    case .statusItem:
      if let statusBarButton {
        let rectInWindow = statusBarButton.convert(statusBarButton.bounds, to: nil)
        if let screenRect = statusBarButton.window?.convertToScreen(rectInWindow) {
          let topLeftPoint = NSPoint(x: screenRect.minX, y: screenRect.minY - size.height)
          let screen = statusBarButton.window?.screen ?? NSScreen.main
          return constrained(topLeftPoint, ofSize: size, to: screen)
        }
      }
    case .lastPosition:
      if let frame = NSScreen.forPopup?.visibleFrame {
        let relativePos = Defaults[.windowPosition]
        let anchorX = frame.minX + frame.width * relativePos.x
        let anchorY = frame.minY + frame.height * relativePos.y
        // Anchor is top middle of frame
        return NSPoint(x: anchorX - size.width / 2, y: anchorY - size.height)
      }
    default:
      break
    }

    let mouseLocation = NSEvent.mouseLocation
    let point = NSPoint(x: mouseLocation.x, y: mouseLocation.y - size.height)
    let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    return constrained(point, ofSize: size, to: screen)
  }

  // Full-height frame glued to the left or right edge of `visibleFrame` (menu bar and Dock excluded).
  func dockedFrame(width: CGFloat, in visibleFrame: NSRect) -> NSRect {
    let margin = Self.dockMargin
    let clampedWidth = min(width, visibleFrame.width - 2 * margin)
    let originX = self == .dockedLeft ? visibleFrame.minX + margin : visibleFrame.maxX - clampedWidth - margin
    return NSRect(
      x: originX,
      y: visibleFrame.minY + margin,
      width: clampedWidth,
      height: visibleFrame.height - 2 * margin
    )
  }

  // The screen under the mouse, so the panel follows the user between displays.
  static var mouseScreen: NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
  }

  // Ensure that window doesn't spill over to an adjacent screen.
  private func constrained(_ origin: NSPoint, ofSize size: NSSize, to screen: NSScreen?) -> NSPoint {
    guard let frame = screen?.visibleFrame else {
      return origin
    }

    return NSPoint(
      x: min(max(origin.x, frame.minX), frame.maxX - size.width),
      y: min(max(origin.y, frame.minY), frame.maxY - size.height)
    )
  }
}
