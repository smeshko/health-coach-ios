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
    .library(name: "CoachCore", targets: ["CoachCore"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.17.0"),
    // `Dependencies` is NOT a product of swift-composable-architecture (TCA exposes only the
    // `ComposableArchitecture` product), so CoachCore must depend on swift-dependencies DIRECTLY to
    // reach `@Dependency(\.calendar)` / `(\.date)`. `from: "1.4.0"` matches TCA's own lower bound, so
    // SPM unifies on the highest version satisfying both with no conflict (validation round-1 #1/#2,
    // round-2 #B, verified). Depending on ComposableArchitecture here would pull all of TCA into the
    // bottom-of-graph CoachCore target.
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.4.0"),
    // swift-tagged is pre-1.0; `from: "0.10.0"` is the floor.
    .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
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
        // "strict-concurrency build settings" wording.
        .swiftLanguageMode(.v6),
      ]
    ),
    .target(
      name: "CoachCore",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Tagged", package: "swift-tagged"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    .testTarget(
      name: "CoachCoreTests",
      dependencies: [
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
  ]
)
