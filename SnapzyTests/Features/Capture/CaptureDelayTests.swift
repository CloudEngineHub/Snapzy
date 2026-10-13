//
//  CaptureDelayTests.swift
//  SnapzyTests
//
//  Delayed Capture countdown setting resolution and the whole-second
//  countdown state machine behind the countdown HUD.
//

import XCTest
@testable import Snapzy

final class CaptureDelayTests: XCTestCase {
  private var defaults: UserDefaults!
  private var suiteName: String!

  override func setUp() {
    super.setUp()
    suiteName = "CaptureDelayTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    defaults = nil
    suiteName = nil
    super.tearDown()
  }

  // MARK: - CaptureDelayOption

  func testOptionsAreThreeFiveTenSeconds() {
    XCTAssertEqual(CaptureDelayOption.allCases.map(\.seconds), [3, 5, 10])
  }

  func testCurrentDefaultsToThreeSecondsWhenUnset() {
    XCTAssertEqual(CaptureDelayOption.current(defaults: defaults), .threeSeconds)
  }

  func testCurrentReadsStoredSeconds() {
    defaults.set(10, forKey: PreferencesKeys.screenshotDelayedCaptureSeconds)
    XCTAssertEqual(CaptureDelayOption.current(defaults: defaults), .tenSeconds)
  }

  func testUnknownStoredValueFallsBackToDefault() {
    defaults.set(7, forKey: PreferencesKeys.screenshotDelayedCaptureSeconds)
    XCTAssertEqual(CaptureDelayOption.current(defaults: defaults), .threeSeconds)
    XCTAssertEqual(CaptureDelayOption.resolve(0), .threeSeconds)
  }

  // MARK: - CaptureDelayCountdown

  func testCountdownFinishesExactlyOnceAfterAllSeconds() {
    var countdown = CaptureDelayCountdown(seconds: 3)
    XCTAssertFalse(countdown.tick())
    XCTAssertEqual(countdown.remainingSeconds, 2)
    XCTAssertFalse(countdown.tick())
    XCTAssertEqual(countdown.remainingSeconds, 1)
    XCTAssertTrue(countdown.tick())
    XCTAssertTrue(countdown.isFinished)
    XCTAssertFalse(countdown.tick(), "A finished countdown must not fire again")
    XCTAssertEqual(countdown.remainingSeconds, 0)
  }

  func testNegativeSecondsClampToFinished() {
    var countdown = CaptureDelayCountdown(seconds: -2)
    XCTAssertTrue(countdown.isFinished)
    XCTAssertFalse(countdown.tick())
  }

  // MARK: - CaptureDelayTarget

  func testAreaTargetKeepsTheOriginalCountdownLayout() {
    XCTAssertEqual(CaptureDelayTarget.area.logName, "delayedArea")
    XCTAssertNil(CaptureDelayTarget.area.hudDetail)
  }

  func testFullscreenTargetNamesTheCaptureAndLabelsTheHUD() {
    XCTAssertEqual(CaptureDelayTarget.fullscreen.logName, "delayedFullscreen")
    XCTAssertEqual(
      CaptureDelayTarget.fullscreen.hudDetail,
      L10n.ScreenCapture.captureDelayFullscreenHint
    )
    XCTAssertFalse(CaptureDelayTarget.fullscreen.hudDetail?.isEmpty ?? true)
  }

  func testDelayedFullscreenShortcutShipsUnbound() {
    XCTAssertEqual(GlobalShortcutKind.delayedFullscreen.configKey, "delayed_fullscreen")
    XCTAssertFalse(GlobalShortcutKind.delayedFullscreen.isSystemConflictRelevant)
    XCTAssertFalse(GlobalShortcutKind.delayedFullscreen.displayName.isEmpty)
  }
}
