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
    .library(name: "PersistenceModels", targets: ["PersistenceModels"]),
    .library(name: "TokenClient", targets: ["TokenClient"]),
    .library(name: "TokenClientLive", targets: ["TokenClientLive"]),
    .library(name: "APIClient", targets: ["APIClient"]),
    .library(name: "APIClientLive", targets: ["APIClientLive"]),
    .library(name: "Database", targets: ["Database"]),
    .library(name: "DatabaseLive", targets: ["DatabaseLive"]),
    .library(name: "HealthKitClient", targets: ["HealthKitClient"]),
    .library(name: "HealthKitClientLive", targets: ["HealthKitClientLive"]),
    .library(name: "DevSettings", targets: ["DevSettings"]),
    .library(name: "DevSettingsLive", targets: ["DevSettingsLive"]),
    .library(name: "BriefRepository", targets: ["BriefRepository"]),
    .library(name: "BriefRepositoryLive", targets: ["BriefRepositoryLive"]),
    .library(name: "CheckInRepository", targets: ["CheckInRepository"]),
    .library(name: "CheckInRepositoryLive", targets: ["CheckInRepositoryLive"]),
    .library(name: "StrengthTestRepository", targets: ["StrengthTestRepository"]),
    .library(name: "StrengthTestRepositoryLive", targets: ["StrengthTestRepositoryLive"]),
    .library(name: "SyncRepository", targets: ["SyncRepository"]),
    .library(name: "SyncRepositoryLive", targets: ["SyncRepositoryLive"]),
    .library(name: "ProfileRepository", targets: ["ProfileRepository"]),
    .library(name: "ProfileRepositoryLive", targets: ["ProfileRepositoryLive"]),
    .library(name: "DesignSystem", targets: ["DesignSystem"]),
    // TEMPORARY (Epic 5.5): the design-system gallery dev tool, rooted by App until Epic 06 restores
    // the real AppView shell. Remove this product + target + the App dependency when Epic 06 lands.
    .library(name: "DesignSystemGallery", targets: ["DesignSystemGallery"]),
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
    // GRDB — SQLite record protocols for the PersistenceModels cache layer (§18: GRDB pinned
    // directly; SharingGRDB wraps it in Epic 04, but only the GRDB record protocols are used here).
    .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
    // swift-clocks — `TestClock` to advance the APIClient retry backoff instantly in tests. The
    // `\.continuousClock` dependency key itself is in swift-dependencies; only the test clock is here.
    .package(url: "https://github.com/pointfreeco/swift-clocks", from: "1.0.0"),
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
    // Bearer-token store interface (read/write/clear). Interface target — only Dependencies.
    .target(
      name: "TokenClient",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Keychain-backed TokenClient.liveValue. Links Security (system framework, imported directly).
    .target(
      name: "TokenClientLive",
      dependencies: [
        "TokenClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The network client interface — concrete typed closures for the six routes + a session-event
    // stream, plus `APIError`/`SessionEvent`. No URLSession here (that's APIClientLive). Repos/
    // features depend only on this (§4.2/§6.1).
    .target(
      name: "APIClient",
      dependencies: [
        "CoachCore",
        "WireModels",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/APIClient/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // URLSession-backed APIClient.liveValue — the Endpoint routes, request builder, and the single
    // generic send<R> transport (auth, retry, envelope decode, 401 stream). Depends on the APIClient
    // interface + TokenClient + WireModels (§4.2). The `\.continuousClock` retry key comes from
    // Dependencies.
    .target(
      name: "APIClientLive",
      dependencies: [
        "APIClient",
        "TokenClient",
        "WireModels",
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/APIClient/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // HealthKit data-source interface — plain payload structs + auth status + delta reads. NO
    // HealthKit import (that's HealthKitClientLive); reuses `WireModels.RecordType` as a type tag.
    .target(
      name: "HealthKitClient",
      dependencies: [
        "CoachCore",
        "WireModels",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The live HealthKit reader. All HealthKit code is `#if canImport(HealthKit)`-guarded so the
    // package compiles on the macOS host (HealthKit is iOS-only → the `#else` `liveValue` is empty);
    // the iOS path is exercised on simulator/device.
    .target(
      name: "HealthKitClientLive",
      dependencies: [
        "HealthKitClient",
        "WireModels",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The dumb persistence data-source interface — generic read/write/observe over a GRDB
    // transaction block (Decision #2 puts `GRDB.Database` on the closure signatures, so the
    // interface imports GRDB). No domain methods, no PersistenceModels, no cache policy (§6/D9).
    .target(
      name: "Database",
      dependencies: [
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Clients/Database/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The live DB: a single DatabaseQueue, the DatabaseMigrator (definitions live here per
    // Decision #1), and the read/write/observe implementations. Depends on Database + the record
    // types + GRDB.
    .target(
      name: "DatabaseLive",
      dependencies: [
        "Database",
        "PersistenceModels",
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Clients/Database/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // DEBUG mock/live routing control: a persisted `useMockData` flag + per-endpoint `SampleScenario`
    // selection. Interface target — depends only on swift-dependencies + SampleData (for the scenario
    // vocabulary). Inert in RELEASE (DevSettingsLive collapses it; see §4.2/§7.1).
    .target(
      name: "DevSettings",
      dependencies: [
        "SampleData",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // UserDefaults-backed DevSettings.liveValue + the launch-arg/env override seed. DEBUG-only
    // behaviour; in RELEASE `useMockData()` is hard-`false`, the override body is empty, and the
    // writers are no-ops (`#if DEBUG` guards). Depends only on DevSettings + SampleData + Foundation.
    .target(
      name: "DevSettingsLive",
      dependencies: [
        "DevSettings",
        "SampleData",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // BriefRepository interface — the daily/weekly get-or-generate seam features see. Depends only on
    // DomainModels + CoachCore (ISOWeek) + SampleData (for `.mock`) + Dependencies — NO APIClient /
    // Database / GRDB / *Live (the §3 repo-interface dependency rule). Owns `BriefError`.
    .target(
      name: "BriefRepository",
      dependencies: [
        "DomainModels",
        "CoachCore",
        "SampleData",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Repositories/BriefRepository/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // BriefRepository.live — the network+GRDB daily/weekly cache policy. Depends on the data-source
    // INTERFACES (APIClient owns APIError; Database owns the GRDB transaction block) + all model
    // layers + WireDomainMapping + GRDB. Never a *Live or a feature (§3/§4.3 repo-live rule).
    .target(
      name: "BriefRepositoryLive",
      dependencies: [
        "BriefRepository",
        "APIClient",
        "Database",
        "WireModels",
        "DomainModels",
        "PersistenceModels",
        "WireDomainMapping",
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/BriefRepository/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // CheckInRepository interface — local upsert-by-Sofia-day of the daily check-in. Interface deps:
    // DomainModels + CoachCore + Dependencies only (no Database/PersistenceModels/network).
    .target(
      name: "CheckInRepository",
      dependencies: [
        "DomainModels",
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Repositories/CheckInRepository/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // CheckInRepository.live — GRDB upsert via the Database interface. No network.
    .target(
      name: "CheckInRepositoryLive",
      dependencies: [
        "CheckInRepository",
        "Database",
        "PersistenceModels",
        "DomainModels",
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/CheckInRepository/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // StrengthTestRepository interface — local upsert-by-Sofia-day of the two weekly strength numbers.
    // Interface deps: DomainModels + CoachCore + Dependencies only.
    .target(
      name: "StrengthTestRepository",
      dependencies: [
        "DomainModels",
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Repositories/StrengthTestRepository/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // StrengthTestRepository.live — GRDB upsert + an at-or-before-latest read via the Database
    // interface. No network.
    .target(
      name: "StrengthTestRepositoryLive",
      dependencies: [
        "StrengthTestRepository",
        "Database",
        "PersistenceModels",
        "DomainModels",
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/StrengthTestRepository/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // SyncRepository interface — the no-args sync() orchestrator seam. Interface deps: DomainModels +
    // Dependencies only (SyncResult/SyncError are domain types). No HealthKit/APIClient/Database here.
    .target(
      name: "SyncRepository",
      dependencies: [
        "DomainModels",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Repositories/SyncRepository/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // SyncRepository.live — reads HK deltas since the watermark, attaches inputs, POSTs /sync, advances
    // the watermark only on success. Depends on the data-source + repo INTERFACES + model layers. The
    // HK→wire mapping lives here (3.3 boundary decision).
    .target(
      name: "SyncRepositoryLive",
      dependencies: [
        "SyncRepository",
        "HealthKitClient",
        "APIClient",
        "Database",
        "CheckInRepository",
        "StrengthTestRepository",
        "WireModels",
        "DomainModels",
        "PersistenceModels",
        "SampleData",
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/SyncRepository/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // ProfileRepository interface — cache-first profile fetch + zone-range accessor + recompute stream.
    // Interface deps: DomainModels + SampleData (for .mock/testValue) + Dependencies only.
    .target(
      name: "ProfileRepository",
      dependencies: [
        "DomainModels",
        "SampleData",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Repositories/ProfileRepository/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // ProfileRepository.live — fetch GET /profile, map via WireDomainMapping, cache via Database; owns
    // the recompute AsyncStream. Depends on the data-source INTERFACES + model layers + WireDomainMapping.
    .target(
      name: "ProfileRepositoryLive",
      dependencies: [
        "ProfileRepository",
        "APIClient",
        "Database",
        "WireModels",
        "DomainModels",
        "PersistenceModels",
        "WireDomainMapping",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/ProfileRepository/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The design system — color/typography/spacing tokens + the enum→label boundary (§9, §4.4, D19).
    // Pure SwiftUI value code; depends ONLY on DomainModels + CoachCore (never repositories /
    // WireModels / APIClient / GRDB).
    .target(
      name: "DesignSystem",
      dependencies: [
        "DomainModels",
        "CoachCore",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // TEMPORARY (Epic 5.5): a navigable design-system gallery (Colors/Typography/Icons + a subpage per
    // component) rooted by App until Epic 06 restores the real shell. Depends on DesignSystem +
    // DomainModels only (component states are built from inline DomainModels literals); never
    // repositories / wire / GRDB / TCA.
    .target(
      name: "DesignSystemGallery",
      dependencies: [
        "DesignSystem",
        "DomainModels",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // GRDB record types for the six cached entities + their lossless domain↔record mapping. Depends
    // on CoachCore + GRDB + DomainModels only — NO WireModels, NO SharingGRDB API (§4.1).
    .target(
      name: "PersistenceModels",
      dependencies: [
        "CoachCore",
        "DomainModels",
        .product(name: "GRDB", package: "GRDB.swift"),
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
    // APIClient interface + transport tests (transport bits land in TASK-003/004).
    .testTarget(
      name: "APIClientLiveTests",
      dependencies: [
        "APIClient",
        "APIClientLive",
        "TokenClient",
        "WireModels",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Clocks", package: "swift-clocks"),
      ],
      path: "Sources/Clients/APIClient/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // TokenClient tests — in-memory round-trip + guarded live Keychain round-trip.
    .testTarget(
      name: "TokenClientLiveTests",
      dependencies: [
        "TokenClient",
        "TokenClientLive",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // HealthKitClient interface + test-value tests — host (no HealthKit, no simulator).
    .testTarget(
      name: "HealthKitClientTests",
      dependencies: [
        "HealthKitClient",
        "HealthKitClientLive",
        "WireModels",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Database migrate / read / write / observe tests — host, on an in-memory queue.
    .testTarget(
      name: "DatabaseLiveTests",
      dependencies: [
        "DatabaseLive",
        "Database",
        "PersistenceModels",
        "CoachCore",
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Clients/Database/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // PersistenceModels record + domain round-trip tests — host. GRDB for the record protocols;
    // `SampleData`/`DomainModels` (added in TASK-004) source domain inputs for the round-trip.
    .testTarget(
      name: "PersistenceModelsTests",
      dependencies: [
        "PersistenceModels",
        "DomainModels",
        "SampleData",
        "CoachCore",
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // SampleData decode-every-scenario tests — host. Links XCTest; `SampleData` itself does not.
    .testTarget(
      name: "SampleDataTests",
      dependencies: [
        "SampleData",
        "WireModels",
        "DomainModels",
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
    // DevSettings interface + DevSettingsLive persistence/override/routing tests — pure Foundation,
    // run on the macOS host via `swift test` (no simulator needed).
    .testTarget(
      name: "DevSettingsTests",
      dependencies: [
        "DevSettings",
        "DevSettingsLive",
        "SampleData",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // BriefRepository interface tests (BriefError + testValue/.mock) — host, no simulator.
    .testTarget(
      name: "BriefRepositoryTests",
      dependencies: [
        "BriefRepository",
        "SampleData",
        "DomainModels",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Repositories/BriefRepository/Tests/BriefRepositoryTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // BriefRepositoryLive cache-policy + APIError-mapping tests — host, with a migrated in-memory
    // Database (DatabaseLive.makeInMemory) and a stubbed APIClient. DatabaseLive is a test-only dep
    // here (the live target itself depends only on the Database interface).
    .testTarget(
      name: "BriefRepositoryLiveTests",
      dependencies: [
        "BriefRepositoryLive",
        "BriefRepository",
        "APIClient",
        "Database",
        "DatabaseLive",
        "PersistenceModels",
        "WireModels",
        "DomainModels",
        "SampleData",
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/BriefRepository/Tests/BriefRepositoryLiveTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // CheckInRepository.live upsert/latest-wins tests — host, migrated in-memory Database.
    .testTarget(
      name: "CheckInRepositoryLiveTests",
      dependencies: [
        "CheckInRepositoryLive",
        "CheckInRepository",
        "Database",
        "DatabaseLive",
        "PersistenceModels",
        "DomainModels",
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/CheckInRepository/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // StrengthTestRepository.live upsert + at-or-before-latest read tests — host, in-memory Database.
    .testTarget(
      name: "StrengthTestRepositoryLiveTests",
      dependencies: [
        "StrengthTestRepositoryLive",
        "StrengthTestRepository",
        "Database",
        "DatabaseLive",
        "PersistenceModels",
        "DomainModels",
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/StrengthTestRepository/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // SyncRepository interface tests (SyncResult/SyncError + testValue) — host.
    .testTarget(
      name: "SyncRepositoryTests",
      dependencies: [
        "SyncRepository",
        "DomainModels",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Repositories/SyncRepository/Tests/SyncRepositoryTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // SyncRepository.live orchestration + HK→wire mapping + APIError mapping tests — host, all client
    // deps stubbed + a migrated in-memory Database.
    .testTarget(
      name: "SyncRepositoryLiveTests",
      dependencies: [
        "SyncRepositoryLive",
        "SyncRepository",
        "HealthKitClient",
        "APIClient",
        "Database",
        "DatabaseLive",
        "CheckInRepository",
        "StrengthTestRepository",
        "WireModels",
        "DomainModels",
        "PersistenceModels",
        "SampleData",
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/SyncRepository/Tests/SyncRepositoryLiveTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // ProfileRepository interface + mock tests — host.
    .testTarget(
      name: "ProfileRepositoryTests",
      dependencies: [
        "ProfileRepository",
        "DomainModels",
        "SampleData",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Repositories/ProfileRepository/Tests/ProfileRepositoryTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // ProfileRepository.live cache/refresh/recompute tests — host, stubbed APIClient + in-memory DB.
    .testTarget(
      name: "ProfileRepositoryLiveTests",
      dependencies: [
        "ProfileRepositoryLive",
        "ProfileRepository",
        "APIClient",
        "Database",
        "DatabaseLive",
        "WireModels",
        "DomainModels",
        "PersistenceModels",
        "SampleData",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/ProfileRepository/Tests/ProfileRepositoryLiveTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // DesignSystem enum→label boundary tests — pure logic, host (no UIKit/snapshot).
    .testTarget(
      name: "DesignSystemTests",
      dependencies: [
        "DesignSystem",
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
    // DesignSystem view snapshots (the token/label catalog) — iOS 26 simulator only, via
    // `xcodebuild test`. `#if canImport(UIKit)`-guarded so it compiles to an empty module on the host.
    .testTarget(
      name: "DesignSystemSnapshotTests",
      dependencies: [
        "DesignSystem",
        "DesignSystemGallery",
        "DomainModels",
        "CoachTestSupport",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      exclude: ["__Snapshots__"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
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
