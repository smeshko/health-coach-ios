// The shared snapshot convention (ARCHITECTURE D16): snapshot a SwiftUI view in **light + dark** on
// a **single reference device**; no accessibility-variant matrix in v1.
//
// All of this is UIKit-only (SwiftUI image snapshots use `ViewImageConfig` / `.device`), so the whole
// file is wrapped in `#if canImport(UIKit)`. On the macOS host this target compiles to an empty
// module, which keeps `swift build` / `swift test` green even though every target is compiled for the
// host (validation round-2 #A). The snapshot tests themselves run on an iOS 26 simulator via
// `xcodebuild test`.

#if canImport(UIKit)
  import SnapshotTesting
  import SwiftUI
  import UIKit
  import XCTest

  /// The single reference device for all view snapshots (D16). Centralised here so every test target
  /// renders against the same geometry.
  public let coachReferenceDevice: ViewImageConfig = .iPhone13

  /// Assert light + dark snapshots of a SwiftUI view on the single reference device (D16).
  ///
  /// Records two images per call — `<name>-light` and `<name>-dark`. To (re)record references, pass
  /// `record: .all` (or wrap the call in `withSnapshotTesting(record: .all) { … }`), run once on the
  /// iOS 26 simulator, then revert and commit the images. `nil` (the default) uses the ambient
  /// recording configuration (verify mode unless overridden).
  public func assertCoachSnapshot(
    of view: @autoclosure () -> some View,
    named name: String? = nil,
    record recording: SnapshotTestingConfiguration.Record? = nil,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
  ) {
    for style in [UIUserInterfaceStyle.light, .dark] {
      let suffix = style == .light ? "light" : "dark"
      assertSnapshot(
        of: view(),
        as: .image(
          layout: .device(config: coachReferenceDevice),
          traits: UITraitCollection(userInterfaceStyle: style)
        ),
        named: name.map { "\($0)-\(suffix)" } ?? suffix,
        record: recording,
        file: file,
        testName: testName,
        line: line
      )
    }
  }
#endif
