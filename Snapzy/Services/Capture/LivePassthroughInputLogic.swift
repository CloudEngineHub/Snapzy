//
//  LivePassthroughInputLogic.swift
//  Snapzy
//
//  Pure decision logic for the live-capture passthrough input path, extracted
//  from AreaSelectionController so it can be unit-tested without a session.
//  See plans/260723-2112-live-capture-passthrough.
//

import CoreGraphics
import Foundation

enum LivePassthroughInputLogic {
  /// CGEvent locations arrive in global Quartz coordinates (top-left origin); the selection
  /// machinery works in AppKit global coordinates (bottom-left) — flip against the main
  /// display's height once at the boundary.
  static func appKitScreenPoint(
    fromQuartzGlobalPoint point: CGPoint,
    mainScreenHeight: CGFloat
  ) -> CGPoint {
    CGPoint(x: point.x, y: mainScreenHeight - point.y)
  }

  /// Coalesced hover gate: process at most the latest point per run-loop pass (handled by
  /// the caller's scheduling) and skip sub-pixel movement — but always process when the
  /// pointer crossed onto a different display, however small the move, so the crosshair
  /// never lingers on the wrong display.
  static func shouldProcessHover(
    newPoint: CGPoint,
    lastProcessedPoint: CGPoint?,
    containingDisplayChanged: Bool
  ) -> Bool {
    if containingDisplayChanged { return true }
    guard let lastProcessedPoint else { return true }
    return abs(newPoint.x - lastProcessedPoint.x) >= 1 || abs(newPoint.y - lastProcessedPoint.y) >= 1
  }

  /// Dim visibility in passthrough sessions, mirroring the legacy window-event appearance:
  /// window-selection mode always shows the dim (the hovered window gets a cutout via the
  /// existing mask); manual region keeps it hidden until the first drag reveals it.
  static func showsDim(
    interactionMode: AreaSelectionInteractionMode,
    hasRevealedDim: Bool,
    isDragging: Bool
  ) -> Bool {
    switch interactionMode {
    case .applicationWindow:
      true
    case .manualRegion:
      hasRevealedDim || isDragging
    }
  }
}

/// Tracks `CGDisplayHideCursor`/`CGDisplayShowCursor` balance per display. Hide and show
/// are per-display counters at the WindowServer level — hiding a display twice would
/// require showing it twice — so the set guards against double-hides (session start plus
/// mid-session display attach) and guarantees every hidden display gets exactly one show
/// on teardown. Effect closures are injectable for tests.
///
/// Known limitation: `CGDisplayHideCursor` only takes effect for the FOREGROUND
/// application, and Snapzy must never activate mid-capture (activating would itself
/// dismiss the hover UI this feature preserves) — so from this background agent the
/// hide does NOT reliably apply, and the system arrow remains visible next to the
/// drawn cursor proxy. Kept per user decision as the accepted baseline: it is
/// harmless where it does apply, and the show-balance bookkeeping must still run so
/// the cursor can never be left hidden where a hide did take effect.
struct LivePassthroughCursorHider {
  private(set) var hiddenDisplayIDs: Set<CGDirectDisplayID> = []

  var isHidden: Bool {
    !hiddenDisplayIDs.isEmpty
  }

  mutating func hide(
    displayIDs: Set<CGDirectDisplayID>,
    hider: (CGDirectDisplayID) -> Void = { CGDisplayHideCursor($0) }
  ) {
    for displayID in displayIDs where !hiddenDisplayIDs.contains(displayID) {
      hider(displayID)
      hiddenDisplayIDs.insert(displayID)
    }
  }

  mutating func showAll(shower: (CGDirectDisplayID) -> Void = { CGDisplayShowCursor($0) }) {
    for displayID in hiddenDisplayIDs {
      shower(displayID)
    }
    hiddenDisplayIDs.removeAll()
  }
}
