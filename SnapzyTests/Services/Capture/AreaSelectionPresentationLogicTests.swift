//
//  AreaSelectionPresentationLogicTests.swift
//  SnapzyTests
//
//  Unit tests for the area-selection presentation watchdog's pure evaluator.
//  The watchdog exists because `isVisible` alone cannot detect a window that
//  composites nothing (off-screen frame, wrong space, occlusion, dragged
//  alpha) — the live-passthrough failure mode where selection keeps working
//  but no crosshair/selection visuals ever paint.
//

import CoreGraphics
@testable import Snapzy
import XCTest

final class AreaSelectionPresentationLogicTests: XCTestCase {
  private let frame = CGRect(x: 0, y: 0, width: 1800, height: 1169)

  private func cleanState() -> AreaSelectionPresentationState {
    AreaSelectionPresentationState(
      isVisible: true,
      isOnActiveSpace: true,
      occlusionVisible: true,
      alphaValue: 1,
      windowFrame: frame,
      screenFrame: frame
    )
  }

  func testCleanState_reportsNoIssues() {
    XCTAssertTrue(AreaSelectionPresentationLogic.issues(for: cleanState()).isEmpty)
  }

  func testInvisibleWindow_flagged() {
    var state = cleanState()
    state.isVisible = false
    XCTAssertEqual(AreaSelectionPresentationLogic.issues(for: state), [.notVisible])
  }

  func testOffActiveSpace_flagged() {
    var state = cleanState()
    state.isOnActiveSpace = false
    XCTAssertEqual(AreaSelectionPresentationLogic.issues(for: state), [.offActiveSpace])
  }

  func testFrameMismatch_sameSizeDifferentOrigin_flagged() {
    var state = cleanState()
    state.windowFrame = CGRect(x: 1800, y: 0, width: frame.width, height: frame.height)
    XCTAssertEqual(AreaSelectionPresentationLogic.issues(for: state), [.frameMismatch])
  }

  func testFrameMismatch_differentSize_flagged() {
    var state = cleanState()
    state.screenFrame = CGRect(x: 0, y: 0, width: 2560, height: 1440)
    XCTAssertEqual(AreaSelectionPresentationLogic.issues(for: state), [.frameMismatch])
  }

  func testNonOpaqueAlpha_flagged() {
    var state = cleanState()
    state.alphaValue = 0
    XCTAssertEqual(AreaSelectionPresentationLogic.issues(for: state), [.unexpectedAlpha])
  }

  func testOccludedWindow_flagged() {
    var state = cleanState()
    state.occlusionVisible = false
    XCTAssertEqual(AreaSelectionPresentationLogic.issues(for: state), [.occluded])
  }

  /// The field failure this watchdog targets: `isVisible == true` while the window paints
  /// nothing. Each non-visible presentation defect must surface even when `isVisible` holds.
  func testInvisibleButFunctionalStates_flaggedDespiteIsVisible() {
    for mutate in [
      { (s: inout AreaSelectionPresentationState) in s.windowFrame.origin.x += 5000 },
      { (s: inout AreaSelectionPresentationState) in s.occlusionVisible = false },
      { (s: inout AreaSelectionPresentationState) in s.isOnActiveSpace = false },
    ] {
      var state = cleanState()
      mutate(&state)
      XCTAssertTrue(state.isVisible)
      XCTAssertFalse(
        AreaSelectionPresentationLogic.issues(for: state).isEmpty,
        "a compositing defect must be detected even when isVisible == true"
      )
    }
  }

  func testCombinedIssues_allReported() {
    var state = cleanState()
    state.isVisible = false
    state.isOnActiveSpace = false
    state.alphaValue = 0.5
    state.occlusionVisible = false
    state.windowFrame.origin.y = 999
    XCTAssertEqual(
      Set(AreaSelectionPresentationLogic.issues(for: state)),
      Set(AreaSelectionPresentationIssue.allCases)
    )
  }
}
