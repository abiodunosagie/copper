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
    XCTAssertEqual(PopupPosition.allCases.filter(\.isDocked), PopupPosition.dockEdges)
    XCTAssertEqual(PopupPosition.allCases.filter(\.isHorizontalDock), [.dockedBottom, .dockedTop])
  }

  func testBottomAndTopDocksSpanTheWidth() {
    let bottom = PopupPosition.dockedBottom.dockedFrame(width: 300, in: visibleFrame)
    XCTAssertEqual(bottom.minY, visibleFrame.minY + margin)
    XCTAssertEqual(bottom.height, 300)
    XCTAssertEqual(bottom.width, visibleFrame.width - 2 * margin)

    let top = PopupPosition.dockedTop.dockedFrame(width: 300, in: visibleFrame)
    XCTAssertEqual(top.maxY, visibleFrame.maxY - margin)
    XCTAssertEqual(top.minX, visibleFrame.minX + margin)

    let short = NSRect(x: 0, y: 0, width: 1_000, height: 200)
    XCTAssertEqual(PopupPosition.dockedBottom.dockedFrame(width: 480, in: short).height, short.height - 2 * margin)
  }
}
