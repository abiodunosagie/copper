import XCTest
@testable import Maccy

class PopupPositionTests: XCTestCase {
  // A 1440 x 875 visible frame, like a laptop screen below the menu bar and above the Dock.
  let visibleFrame = NSRect(x: 0, y: 70, width: 1440, height: 800)
  let margin = PopupPosition.dockMargin

  func testDockedRightHugsTheRightEdgeAtFullHeight() {
    let frame = PopupPosition.dockedRight.dockedFrame(width: 340, in: visibleFrame)
    XCTAssertEqual(frame.maxX, visibleFrame.maxX - margin)
    XCTAssertEqual(frame.width, 340)
    XCTAssertEqual(frame.minY, visibleFrame.minY + margin)
    XCTAssertEqual(frame.height, visibleFrame.height - 2 * margin)
  }

  func testDockedLeftHugsTheLeftEdge() {
    let frame = PopupPosition.dockedLeft.dockedFrame(width: 340, in: visibleFrame)
    XCTAssertEqual(frame.minX, visibleFrame.minX + margin)
    XCTAssertEqual(frame.height, visibleFrame.height - 2 * margin)
  }

  func testDockedFrameFollowsSecondaryScreenOrigin() {
    let secondScreen = NSRect(x: -1920, y: 200, width: 1920, height: 1050)
    let frame = PopupPosition.dockedRight.dockedFrame(width: 340, in: secondScreen)
    XCTAssertEqual(frame.maxX, secondScreen.maxX - margin)
    XCTAssertTrue(secondScreen.contains(frame))
  }

  func testDockedWidthNeverExceedsTheScreen() {
    let narrow = NSRect(x: 0, y: 0, width: 300, height: 600)
    let frame = PopupPosition.dockedRight.dockedFrame(width: 640, in: narrow)
    XCTAssertEqual(frame.width, narrow.width - 2 * margin)
    XCTAssertTrue(narrow.contains(frame))
  }

  func testOnlyEdgePositionsAreDocked() {
    XCTAssertEqual(PopupPosition.allCases.filter(\.isDocked), [.dockedRight, .dockedLeft])
  }
}
