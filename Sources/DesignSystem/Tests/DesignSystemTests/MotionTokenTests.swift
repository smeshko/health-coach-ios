import Foundation
import SwiftUI
import Testing

@testable import DesignSystem

/// Pins the `CoachMotion` resolution table (DECISIONS D1). `Animation` is `Equatable`, so the per-class
/// spring-vs-Reduce-Motion table is assertable in plain unit tests — that's why `reduceMotion` is a plain
/// `Bool` parameter (no UI automation needed).
@MainActor
struct MotionTokenTests {
  // MARK: Full motion (reduceMotion: false) → each token's spring

  @Test func test_selection_fullMotion_isSpring() {
    #expect(CoachMotion.animation(.selection, reduceMotion: false) == .spring(duration: 0.3, bounce: 0.2))
  }

  @Test func test_disclosure_fullMotion_isSpring() {
    #expect(CoachMotion.animation(.disclosure, reduceMotion: false) == .spring(duration: 0.35, bounce: 0))
  }

  @Test func test_screenChange_fullMotion_isSpring() {
    #expect(CoachMotion.animation(.screenChange, reduceMotion: false) == .spring(duration: 0.4, bounce: 0))
  }

  @Test func test_pressed_fullMotion_isSpring() {
    #expect(CoachMotion.animation(.pressed, reduceMotion: false) == .spring(duration: 0.2, bounce: 0))
  }

  // MARK: Reduce Motion (reduceMotion: true) → the pinned fallback table

  /// Positional class → `nil` (instant snap): a crossfade would still animate the slide.
  @Test func test_selection_reduceMotion_isNil_positional() {
    #expect(CoachMotion.animation(.selection, reduceMotion: true) == nil)
  }

  /// Positional class → `nil` (instant expand/collapse): a crossfade would still animate height/rotation.
  @Test func test_disclosure_reduceMotion_isNil_positional() {
    #expect(CoachMotion.animation(.disclosure, reduceMotion: true) == nil)
  }

  /// Opacity class → `easeInOut` crossfade (honest under Reduce Motion).
  @Test func test_screenChange_reduceMotion_isCrossfade() {
    #expect(CoachMotion.animation(.screenChange, reduceMotion: true) == .easeInOut(duration: 0.2))
  }

  /// Opacity + scale → still animates (the style drops the scale leg; the opacity dim animates).
  @Test func test_pressed_reduceMotion_isCrossfade() {
    #expect(CoachMotion.animation(.pressed, reduceMotion: true) == .easeInOut(duration: 0.2))
  }

  /// Every token resolves (no missing case) in both branches.
  @Test func test_everyToken_resolvesInBothBranches() {
    for token in CoachMotion.Token.allCases {
      #expect(CoachMotion.animation(token, reduceMotion: false) != nil)
      _ = CoachMotion.animation(token, reduceMotion: true)
    }
  }
}
