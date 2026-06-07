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
    .library(name: "WireModels", targets: ["WireModels"]),
    .library(name: "DomainModels", targets: ["DomainModels"]),
    .library(name: "WireDomainMapping", targets: ["WireDomainMapping"]),
    .library(name: "SampleData", targets: ["SampleData"]),
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
    // Test-only: SwiftUI image snapshots. Used only by CoachTestSupport + the snapshot test target.
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
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
    // Wire-contract DTOs (Codable mirror of openapi.yaml). Bottom-of-graph: depends only on
    // CoachCore (+ Foundation). Must NOT import TCA / GRDB / DomainModels (ARCHITECTURE §4.1).
    .target(
      name: "WireModels",
      dependencies: [
        "CoachCore",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Shared test helper (light+dark / single reference device snapshot convention). Links XCTest via
    // SnapshotTesting, so it must be depended on ONLY by test targets — never by the app or a shipping
    // library, or the app build breaks. All UIKit-only code is wrapped in `#if canImport(UIKit)` so
    // this target compiles to an empty module on the macOS host (validation round-2 #A).
    .target(
      name: "CoachTestSupport",
      dependencies: [
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Logic tests — run on the macOS host via `swift test`. No snapshot/UIKit code.
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
    // App-tailored domain models + semantic enums consumed by reducers/views. Depends ONLY on
    // CoachCore — NO Codable, NO GRDB, NO WireModels (ARCHITECTURE §4.1 / §5). The only model
    // layer features import.
    .target(
      name: "DomainModels",
      dependencies: [
        "CoachCore",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Single source of sample truth — canned wire JSON + DTO/domain factories for previews/tests/
    // snapshots/mocks. Library (not a test target): imported by previews and *Live previewValues, so
    // it links NO XCTest and NO GRDB (§4.4). Depends on the model layers + WireDomainMapping (the
    // DTO→domain free functions live there; 2.2 DECISIONS #1).
    .target(
      name: "SampleData",
      dependencies: [
        "WireModels",
        "DomainModels",
        "WireDomainMapping",
      ],
      resources: [
        .process("Resources"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Pure DTO→domain mapping functions (the read path). Sits at/above the repository-live tier
    // (ARCHITECTURE §3: a repo *Live may depend on all model layers), below features. Depends on
    // BOTH model layers; DomainModels itself never imports WireModels (DECISIONS Decision 1).
    .target(
      name: "WireDomainMapping",
      dependencies: [
        "WireModels",
        "DomainModels",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Wire decode/round-trip tests — pure Foundation, run on the macOS host via `swift test`
    // (no simulator needed).
    .testTarget(
      name: "WireModelsTests",
      dependencies: [
        "WireModels",
        "CoachCore",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Mapping tests — pure functions, host (no simulator).
    .testTarget(
      name: "WireDomainMappingTests",
      dependencies: [
        "WireDomainMapping",
        "WireModels",
        "DomainModels",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // DomainModels pure value/enum tests — host (no simulator).
    .testTarget(
      name: "DomainModelsTests",
      dependencies: [
        "DomainModels",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    .testTarget(
      name: "AppFeatureTests",
      dependencies: [
        "AppFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // View snapshot tests — run only on an iOS 26 simulator via `xcodebuild test`. The whole body is
    // `#if canImport(UIKit)`-guarded so it compiles to an empty module on the host (so `swift test`
    // stays green); SwiftUI image snapshots use the iOS-only ViewImageConfig/.device API.
    .testTarget(
      name: "AppFeatureSnapshotTests",
      dependencies: [
        "AppFeature",
        "CoachTestSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      // Reference images are read from disk by swift-snapshot-testing (not bundled), so exclude them
      // from the target to avoid SwiftPM's "unhandled files" warning.
      exclude: ["__Snapshots__"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
  ]
)
