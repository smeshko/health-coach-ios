// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "CoachKit",
  // .iOS(.v26) is the product baseline. .macOS is REQUIRED so the package compiles for the macOS
  // host under `swift build` / `swift test` — TCA's products require macOS 13+, so an iOS-only
  // platforms line makes the host build fail to compile (validation round-2 #12, verified). The
  // .macOS line governs only host build/test; the shipped app target stays iOS-only (xcodeproj).
  platforms: [.iOS(.v26), .macOS(.v14)],
  products: [
    .library(name: "AppFeature", targets: ["AppFeature"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.17.0"),
  ],
  targets: [
    .target(
      name: "AppFeature",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ],
      swiftSettings: [
        // Explicit Swift 6 language mode = complete strict concurrency. Already the default from
        // `swift-tools-version: 6.3`; stated here to self-document and to satisfy the epic's
        // "strict-concurrency build settings" wording. NOT the Swift-5-mode
        // `-strict-concurrency=complete` flag / `StrictConcurrency` upcoming-feature.
        .swiftLanguageMode(.v6),
      ]
    ),
  ]
)
